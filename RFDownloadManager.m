
#import "RFDownloadManager.h"
#import "dout.h"

@interface RFDownloadManager ()
@property (RF_STRONG, atomic) NSMutableSet *requrestURLs;
@property (RF_STRONG, atomic) NSMutableSet *requrestOperationsQueue;
@property (RF_STRONG, atomic) NSMutableSet *requrestOperationsDownloading;

@property (assign, readwrite, nonatomic) BOOL isDownloading;
@property (copy, nonatomic) NSString *tempFileStorePath;
@end

@implementation RFDownloadManager
- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, downloading:%@, queue:%@>", [self class], self, self.requrestOperationsDownloading, self.requrestOperationsQueue];
}

#pragma mark - Property
- (NSSet *)operations {
    return [self.requrestOperationsDownloading setByAddingObjectsFromSet:self.requrestOperationsQueue];
}

- (NSSet *)downloadingOperations {
    return [self.requrestOperationsDownloading copy];
}

- (BOOL)isDownloading {
    return (self.requrestOperationsDownloading.count > 0);
}

#pragma mark -
- (RFDownloadManager *)init {
    if (self = [super init]) {
        _isDownloading = NO;
        _requrestURLs = [NSMutableSet set];
        _requrestOperationsQueue = [NSMutableSet set];
        _requrestOperationsDownloading = [NSMutableSet setWithCapacity:5];
        _maxRunningTaskCount = 3;
        return self;
    }
    return nil;
}

- (RFDownloadManager *)initWithDelegate:(id<RFDownloadManagerDelegate>)delegate {
    if (self = [self init]) {
        self.delegate = delegate;
        return self;
    }
    return nil;
}

+ (RFDownloadManager *)sharedInstance {
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
        dout_warning(@"RFDownloadManager: the url already existed. %@", url)
        return nil;
    }

    RFFileDownloadOperation *downloadOperation = [[RFFileDownloadOperation alloc] initWithRequest:[NSURLRequest requestWithURL:url] targetPath:destinationFilePath shouldCoverOldFile:YES];
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
        if (self.delegate && [self.delegate respondsToSelector:@selector(RFDownloadManager:operationCompleted:)]) {
            [self.delegate RFDownloadManager:self operationCompleted:operation];
        }
        // 完成，尝试下载下一个
        [self.requrestURLs removeObject:operation.request.URL];
        [self.requrestOperationsDownloading removeObject:operation];
        if (self.requrestOperationsQueue.count > 0) {
            RFFileDownloadOperation *operationNext = [self.requrestOperationsQueue anyObject];
            [self startOperation:operationNext];
        }

    } failure:^(RFFileDownloadOperation *operation, NSError *error) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(RFDownloadManager:operationFailed:)]) {
            [self.delegate RFDownloadManager:self operationFailed:operation];
        }
        // 回退回队列
        // TODO: 破除反复重试
        [self.requrestOperationsDownloading removeObject:operation];
        [self.requrestOperationsQueue addObject:operation];
        dout_error(@"%@", operation.error);
    }];
}

- (void)startAll {
    while (self.requrestOperationsDownloading.count < _maxRunningTaskCount) {
        RFFileDownloadOperation *operation = [self.requrestOperationsQueue anyObject];
        if (!operation) break;
        
        [self startOperation:operation];
    }
}
- (void)pauseAll {
    RFFileDownloadOperation *operation;
    while ((operation = [self.requrestOperationsDownloading anyObject])) {
        [self pauseOperation:operation];
    }
}
- (void)cancelAll {
    RFFileDownloadOperation *operation;
    while ((operation = [self.requrestOperationsDownloading anyObject])) {
        [self cancelOperation:operation];
    }
    while ((operation = [self.requrestOperationsQueue anyObject])) {
        [self cancelOperation:operation];
    }
}

- (void)startOperation:(RFFileDownloadOperation *)operation {
    if (!operation) {
        dout_warning(@"RFDownloadManager > startOperation: operation is nil")
        return;
    }
    
    if ([operation isPaused]) {
        [operation resume];
    }
    else {
        [operation start];
    }
    
    if (self.requrestOperationsDownloading.count >= self.maxRunningTaskCount) {
        RFFileDownloadOperation *anyObject = [self.requrestOperationsDownloading anyObject];
        RFAssert(anyObject != operation, @"operation already in requrestOperationsDownloading");
        
        [self pauseOperation:anyObject];
    }
    
    if ([self.requrestOperationsQueue containsObject:operation]) {
        [self.requrestOperationsDownloading addObject:operation];
        [self.requrestOperationsQueue removeObject:operation];
    }
}
- (void)pauseOperation:(RFFileDownloadOperation *)operation {
    if (!operation) {
        dout_warning(@"RFDownloadManager > pauseOperation: operation is nil")
        return;
    }
    if (![operation isPaused]) {
        [operation pause];
        [self.requrestOperationsQueue addObject:operation];
        [self.requrestOperationsDownloading removeObject:operation];
    }
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
    
    return nil;
}


@end

