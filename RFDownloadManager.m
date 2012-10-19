
#import "RFDownloadManager.h"

@interface RFDownloadManager ()
@property (RF_STRONG, atomic) NSMutableArray *requrests;
@property (RF_STRONG, readwrite, atomic) NSMutableArray *requrestOperations;
@property (assign, readwrite, nonatomic) BOOL isDownloading;

@property (copy, nonatomic) NSString *tempFileStorePath;
@end

@implementation RFDownloadManager

- (RFDownloadManager *)init {
    if (self = [super init]) {
        self.isDownloading = NO;
        self.requrests = [NSMutableArray array];
        self.requrestOperations = [NSMutableArray array];
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

- (RFFileDownloadOperation *)addURL:(NSURL *)url fileStorePath:(NSString *)destinationFilePath {
    if ([self.requrests containsObject:url]) {
        dout_warning(@"RFDownloadManager: the url already existed. %@", url)
        return nil;
    }

    __block RFFileDownloadOperation *downloadOperation = [[RFFileDownloadOperation alloc] initWithRequest:[NSURLRequest requestWithURL:url] targetPath:destinationFilePath shouldCoverOldFile:YES];
    if (downloadOperation == nil) {
        return nil;
    }
    
    downloadOperation.deleteTempFileOnCancel = YES;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    
    [downloadOperation setProgressiveDownloadProgressBlock:^(NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile) {
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(RFDownloadManager:operationStateUpdate:)]) {
            [self.delegate RFDownloadManager:self operationStateUpdate:downloadOperation];
        }
    }];
    
    [downloadOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(RFDownloadManager:operationCompleted:)]) {
            [self.delegate RFDownloadManager:self operationCompleted:downloadOperation];
        }
        [self.requrests removeObject:operation.request.URL];
        [self.requrestOperations removeObject:operation];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(RFDownloadManager:operationFailed:)]) {
            [self.delegate RFDownloadManager:self operationFailed:downloadOperation];
        }
    }];
    
#pragma clang diagnostic pop
    
    [self.requrestOperations addObject:downloadOperation];
    [self.requrests addObject:url];
    
    return downloadOperation;
}

- (void)startAll {
    for (RFFileDownloadOperation *operation in self.requrestOperations) {
        [self startOperation:operation];
    }
}
- (void)pauseAll {
    for (RFFileDownloadOperation *operation in self.requrestOperations) {
        [self pauseOperation:operation];
    }
}
- (void)cancelAll {
    for (RFFileDownloadOperation *operation in self.requrestOperations) {
        [self cancelOperation:operation];
    }
}

- (void)startOperation:(RFFileDownloadOperation *)operation {
    if (!operation) {
        douts(@"RFDownloadManager > startOperation: operation is nil")
    }
    if ([operation isPaused]) {
        [operation resume];
    }
    else {
        [operation start];
    }
}
- (void)pauseOperation:(RFFileDownloadOperation *)operation {
    if (!operation) {
        douts(@"RFDownloadManager > pauseOperation: operation is nil")
    }
    if (![operation isPaused]) {
        [operation pause];
    }
}
- (void)cancelOperation:(RFFileDownloadOperation *)operation {
    if (!operation) {
        douts(@"RFDownloadManager > cancelOperation: operation is nil")
    }
    [operation cancel];
    [self.requrests removeObject:operation.request.URL];
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
    for (RFFileDownloadOperation *operation in self.requrestOperations) {
        if ([operation.request.URL isEqual:url]) {
            return operation;
        }
    }
    return nil;
}


@end

