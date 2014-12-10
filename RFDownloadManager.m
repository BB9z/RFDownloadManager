
#import "RFDownloadManager.h"
#import "dout.h"

@interface RFDownloadManager ()
@property (strong, atomic) NSMutableSet *requrestURLs;
@property (strong, atomic) NSMutableArray *requrestOperationsDownloading;
@property (strong, atomic) NSMutableArray *requrestOperationsQueue;
@property (strong, atomic) NSMutableArray *requrestOperationsPaused;

@property (assign, readwrite, nonatomic) BOOL isDownloading;
@end

@implementation RFDownloadManager

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, downloading:%@, queue:%@, paused:%@>", [self class], self, self.requrestOperationsDownloading, self.requrestOperationsQueue, self.requrestOperationsPaused];
}

#pragma mark - Property
- (NSArray *)downloadingOperations {
    return [self.requrestOperationsDownloading copy];
}

- (NSArray *)operationsInQueue {
    return [self.requrestOperationsQueue copy];
}

- (NSArray *)pausedOperations {
    return [self.requrestOperationsPaused copy];
}

- (NSArray *)operations {
    NSMutableArray *total = [NSMutableArray arrayWithArray:self.requrestOperationsDownloading];
    [total addObjectsFromArray:self.requrestOperationsQueue];
    [total addObjectsFromArray:self.pausedOperations];
    return total;
}

- (void)setMaxRunningTaskCount:(uint)maxRunningTaskCount {
    if (_maxRunningTaskCount != maxRunningTaskCount) {
        int diffCount = self.downloadingOperations.count - maxRunningTaskCount;
        if (diffCount > 0) {
            for (int i = diffCount; i > 0; i--) {
                AFDownloadRequestOperation *operation = [self.downloadingOperations lastObject];
                [operation pause];
                [self.requrestOperationsPaused addObject:operation];
                [self.requrestOperationsDownloading removeObject:operation];
            }
        }
        else {
            for (int i = diffCount; i > 0; i--) {
                [self startNextQueuedOperation];
            }
        }
        _maxRunningTaskCount = maxRunningTaskCount;
    }
}

#pragma mark -
- (instancetype)init {
    self = [super init];
    if (self) {
        _isDownloading = NO;
        _requrestURLs = [NSMutableSet set];
        _requrestOperationsQueue = [NSMutableArray array];
        _requrestOperationsDownloading = [NSMutableArray arrayWithCapacity:5];
        _requrestOperationsPaused = [NSMutableArray array];
        _maxRunningTaskCount = 3;
        _shouldResume = YES;
    }
    return self;
}

- (instancetype)initWithDelegate:(id<RFDownloadManagerDelegate>)delegate {
    self = [self init];
    if (self) {
        self.delegate = delegate;
    }
    return self;
}

+ (instancetype)sharedInstance {
	static RFDownloadManager *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
    });
	return sharedInstance;
}

#pragma mark -
- (AFDownloadRequestOperation *)addURL:(NSURL *)url fileStorePath:(NSString *)destinationFilePath {
    if ([self.requrestURLs containsObject:url]) {
        dout_warning(@"RFDownloadManager: the url already existed. %@", url);
        return nil;
    }

    AFDownloadRequestOperation *downloadOperation = [[AFDownloadRequestOperation alloc] initWithRequest:[NSURLRequest requestWithURL:url] targetPath:destinationFilePath shouldResume:self.shouldResume];
    if (downloadOperation == nil) {
        return nil;
    }
    
    [self setupDownloadOperation:downloadOperation];
    [self.requrestOperationsQueue addObject:downloadOperation];
    [self.requrestURLs addObject:url];
    
    return downloadOperation;
}

- (AFDownloadRequestOperation *)findOperationWithURL:(NSURL *)url {
    AFDownloadRequestOperation *operation = nil;
    
#define _RFDownloadManagerFindOperationInSet(RequrestOperations)\
    for (operation in RequrestOperations) {\
        if ([operation.request.URL.path isEqualToString:url.path]) {\
            return operation;\
        }\
    }
    
    _RFDownloadManagerFindOperationInSet(self.requrestOperationsDownloading)
    _RFDownloadManagerFindOperationInSet(self.requrestOperationsQueue)
    _RFDownloadManagerFindOperationInSet(self.requrestOperationsPaused)
#undef _RFDownloadManagerFindOperationInSet
    return nil;
}

- (void)setupDownloadOperation:(AFDownloadRequestOperation *)downloadOperation {
    __weak AFDownloadRequestOperation *aOperation = downloadOperation;
    aOperation.deleteTempFileOnCancel = YES;
    
    [aOperation setProgressiveDownloadProgressBlock:^(AFDownloadRequestOperation *operation, NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile) {
        if ([self.delegate respondsToSelector:@selector(RFDownloadManager:operationStateUpdate:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate RFDownloadManager:self operationStateUpdate:operation];
            });
        }
    }];

    [aOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *op, id responseObject) {
        [self onFileDownloadOperationComplete:(id)op success:YES];
    } failure:^(AFHTTPRequestOperation *op, NSError *error) {
        [self onFileDownloadOperationComplete:(id)op success:NO];
    }];
}

- (void)onFileDownloadOperationComplete:(AFDownloadRequestOperation *)operation success:(BOOL)success {
    [self.requrestOperationsDownloading removeObject:operation];
    [self startNextQueuedOperation];

    if (success) {
        [self.requrestURLs removeObject:operation.request.URL];
        
        if ([self.delegate respondsToSelector:@selector(RFDownloadManager:operationCompleted:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate RFDownloadManager:self operationCompleted:operation];
            });
        }
    }
    else {
        [self.requrestOperationsPaused addObject:operation];
        dout_error(@"%@", operation.error);
        
        if ([self.delegate respondsToSelector:@selector(RFDownloadManager:operationFailed:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate RFDownloadManager:self operationFailed:operation];
            });
        }
    }
}

#pragma mark - Queue Manage
- (void)startAll {
    // Paused => Queue
    [self.requrestOperationsQueue removeObjectsInArray:self.requrestOperationsPaused];
    [self.requrestOperationsPaused removeAllObjects];
    
    // Queue => Start
    while (self.requrestOperationsDownloading.count < _maxRunningTaskCount) {
        AFDownloadRequestOperation *operation = [self.requrestOperationsQueue firstObject];
        if (!operation) break;
        
        [self startOperation:operation];
    }
}
- (void)pauseAll {
    AFDownloadRequestOperation *operation;
    // Downloading => Pause
    while ((operation = [self.requrestOperationsDownloading lastObject])) {
        [self pauseOperation:operation];
    }
    
    // Queue => Pause
    [self.requrestOperationsPaused addObjectsFromArray:self.requrestOperationsQueue];
    [self.requrestOperationsQueue removeAllObjects];
}
- (void)cancelAll {
    AFDownloadRequestOperation *operation;
    while ((operation = [self.requrestOperationsPaused lastObject])) {
        [self cancelOperation:operation];
    }
    while ((operation = [self.requrestOperationsQueue lastObject])) {
        [self cancelOperation:operation];
    }
    while ((operation = [self.requrestOperationsDownloading lastObject])) {
        [self cancelOperation:operation];
    }
}

- (void)startNextQueuedOperation {
    if (self.requrestOperationsQueue.count > 0 && self.requrestOperationsDownloading.count < self.maxRunningTaskCount) {
        AFDownloadRequestOperation *operationNext = [self.requrestOperationsQueue firstObject];
        [self startOperation:operationNext];
    }
}

// Note: 这些方法本身会管理队列
- (void)startOperation:(AFDownloadRequestOperation *)operation {
    if (!operation) {
        dout_warning(@"RFDownloadManager > startOperation: operation is nil")
        return;
    }
    
    [self.requrestOperationsPaused removeObject:operation];
    if (self.requrestOperationsDownloading.count < self.maxRunningTaskCount) {
        // 开始下载
        if ([operation isPaused]) {
            [operation resume];
        }
        else {
            [operation start];
        }
        
        [self.requrestOperationsDownloading addObject:operation];
        [self.requrestOperationsQueue removeObject:operation];
    }
    else {
        // 加入到队列
        [self.requrestOperationsQueue addObject:operation];
    }
}
- (void)pauseOperation:(AFDownloadRequestOperation *)operation {
    if (!operation) {
        dout_warning(@"RFDownloadManager > pauseOperation: operation is nil")
        return;
    }
    if (![operation isPaused]) {
        [operation pause];
        [self startNextQueuedOperation];
    }
    
    [self.requrestOperationsPaused addObject:operation];
    [self.requrestOperationsQueue removeObject:operation];
    [self.requrestOperationsDownloading removeObject:operation];
}
- (void)cancelOperation:(AFDownloadRequestOperation *)operation {
    if (!operation) {
        dout_warning(@"RFDownloadManager > cancelOperation: operation is nil")
        return;
    }
    [operation cancel];
    
    [self.requrestURLs removeObject:operation.request.URL];
    [self.requrestOperationsDownloading removeObject:operation];
    [self.requrestOperationsQueue removeObject:operation];
    [self.requrestOperationsPaused removeObject:operation];
    [self startNextQueuedOperation];
}

- (void)startOperationWithURL:(NSURL *)url {
    [self startOperation:[self findOperationWithURL:url]];
}
- (void)pauseOperationWithURL:(NSURL *)url {
    [self pauseOperation:[self findOperationWithURL:url]];
}
- (void)cancelOperationWithURL:(NSURL *)url {
    [self cancelOperation:[self findOperationWithURL:url]];
}


@end

