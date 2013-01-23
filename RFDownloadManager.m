
#import "RFDownloadManager.h"
#import "AFNetworking.h"
#import "dout.h"

@interface RFDownloadManager ()
@property (RF_STRONG, atomic) NSMutableSet *requrestURLs;
@property (RF_STRONG, atomic) NSMutableSet *requrestOperationsQueue;
@property (RF_STRONG, atomic) NSMutableSet *requrestOperationsDownloading;
@property (RF_STRONG, atomic) NSMutableSet *requrestOperationsPaused;

@property (assign, readwrite, nonatomic) BOOL isDownloading;
@property (copy, nonatomic) NSString *tempFileStorePath;
@end

@implementation RFDownloadManager
- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, downloading:%@, queue:%@, paused:%@>", [self class], self, self.requrestOperationsDownloading, self.requrestOperationsQueue, self.requrestOperationsPaused];
}

#pragma mark - Property
- (NSSet *)operations {
    return [[self.requrestOperationsDownloading setByAddingObjectsFromSet:self.requrestOperationsQueue] setByAddingObjectsFromSet:self.requrestOperationsPaused];
}

- (NSUInteger)operationsCountInQueue {
    return self.requrestOperationsDownloading.count+self.requrestOperationsQueue.count;
}

- (NSSet *)downloadingOperations {
    return [self.requrestOperationsDownloading copy];
}

- (BOOL)isDownloading {
    return (self.requrestOperationsDownloading.count > 0);
}

#pragma mark -
- (RFDownloadManager *)init {
    if ((self = [super init])) {
        _isDownloading = NO;
        _requrestURLs = [NSMutableSet set];
        _requrestOperationsQueue = [NSMutableSet set];
        _requrestOperationsDownloading = [NSMutableSet setWithCapacity:5];
        _requrestOperationsPaused = [NSMutableSet set];
        _maxRunningTaskCount = 3;
        _shouldResume = YES;
        return self;
    }
    return nil;
}

- (RFDownloadManager *)initWithDelegate:(id<RFDownloadManagerDelegate>)delegate {
    if ((self = [self init])) {
        self.delegate = delegate;
        return self;
    }
    return nil;
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
- (RFFileDownloadOperation *)addURL:(NSURL *)url fileStorePath:(NSString *)destinationFilePath {
    if ([self.requrestURLs containsObject:url]) {
        dout_warning(@"RFDownloadManager: the url already existed. %@", url);
        return nil;
    }

    RFFileDownloadOperation *downloadOperation = [[RFFileDownloadOperation alloc] initWithRequest:[NSURLRequest requestWithURL:url] targetPath:destinationFilePath shouldResume:self.shouldResume shouldCoverOldFile:YES];
    if (downloadOperation == nil) {
        return nil;
    }
    
    [self setupDownloadOperation:downloadOperation];
    [self.requrestOperationsQueue addObject:downloadOperation];
    [self.requrestURLs addObject:url];
    
    return downloadOperation;
}

- (void)setupDownloadOperation:(RFFileDownloadOperation *)downloadOperation {
    __weak RFFileDownloadOperation *operation = downloadOperation;
    operation.deleteTempFileOnCancel = YES;
    
    [operation setProgressiveDownloadProgressBlock:^(NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile) {
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(RFDownloadManager:operationStateUpdate:)]) {
            [self.delegate RFDownloadManager:self operationStateUpdate:operation];
        }
    }];
    
    [operation setCompletionBlockWithSuccess:^(RFFileDownloadOperation *operation, id responseObject) {
        // 完成，尝试下载下一个
        [self.requrestURLs removeObject:operation.request.URL];
        [self.requrestOperationsDownloading removeObject:operation];
        [self startNextQueuedOperation];

        if (self.delegate && [self.delegate respondsToSelector:@selector(RFDownloadManager:operationCompleted:)]) {
            [self.delegate RFDownloadManager:self operationCompleted:operation];
        }
    } failure:^(RFFileDownloadOperation *operation, NSError *error) {
        // 回退回队列
        [self.requrestOperationsDownloading removeObject:operation];
        [self.requrestOperationsPaused addObject:operation];
        [self startNextQueuedOperation];
        dout_error(@"%@", operation.error);
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(RFDownloadManager:operationFailed:)]) {
            [self.delegate RFDownloadManager:self operationFailed:operation];
        }
    }];
}

- (void)startAll {
    // Paused => Queue
    [self.requrestOperationsQueue unionSet:self.requrestOperationsPaused];
    [self.requrestOperationsPaused removeAllObjects];
    
    // Queue => Start
    while (self.requrestOperationsDownloading.count < _maxRunningTaskCount) {
        RFFileDownloadOperation *operation = [self.requrestOperationsQueue anyObject];
        if (!operation) break;
        
        [self startOperation:operation];
    }
}
- (void)pauseAll {
    RFFileDownloadOperation *operation;
    // Downloading => Pause
    while ((operation = [self.requrestOperationsDownloading anyObject])) {
        [self pauseOperation:operation];
    }
    
    // Queue => Pause
    [self.requrestOperationsPaused unionSet:self.requrestOperationsQueue];
    [self.requrestOperationsQueue removeAllObjects];
}
- (void)cancelAll {
    RFFileDownloadOperation *operation;
    while ((operation = [self.requrestOperationsDownloading anyObject])) {
        [self cancelOperation:operation];
    }
    while ((operation = [self.requrestOperationsQueue anyObject])) {
        [self cancelOperation:operation];
    }
    while ((operation = [self.requrestOperationsPaused anyObject])) {
        [self cancelOperation:operation];
    }
}

// Note: 这些方法本身会管理队列
- (void)startOperation:(RFFileDownloadOperation *)operation {
    if (!operation) {
        dout_warning(@"RFDownloadManager > startOperation: operation is nil")
        return;
    }
    
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
    
    [self.requrestOperationsPaused removeObject:operation];
}
- (void)pauseOperation:(RFFileDownloadOperation *)operation {
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
- (void)cancelOperation:(RFFileDownloadOperation *)operation {
    if (!operation) {
        dout_warning(@"RFDownloadManager > cancelOperation: operation is nil")
        return;
    }
    [operation cancel];
    
    [self.requrestURLs removeObject:operation.request.URL];
    [self.requrestOperationsDownloading removeObject:operation];
    [self.requrestOperationsQueue removeObject:operation];
    [self.requrestOperationsPaused removeObject:operation];
}
- (void)startNextQueuedOperation {
    if (self.requrestOperationsQueue.count > 0) {
        RFFileDownloadOperation *operationNext = [self.requrestOperationsQueue anyObject];
        [self startOperation:operationNext];
    }
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

- (RFFileDownloadOperation *)findOperationWithURL:(NSURL *)url {
    RFFileDownloadOperation *operation = nil;
    
    for (operation in self.requrestOperationsDownloading) {
        if ([operation.request.URL.path isEqualToString:url.path]) {
            return operation;
        }
    }
    
    if (!operation) {
        for (operation in self.requrestOperationsQueue) {
            if ([operation.request.URL.path isEqualToString:url.path]) {
                return operation;
            }
        }
    }
    
    if (!operation) {
        for (operation in self.requrestOperationsPaused) {
            if ([operation.request.URL.path isEqualToString:url.path]) {
                return operation;
            }
        }
    }
    
    return nil;
}


@end

