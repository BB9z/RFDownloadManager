
#import "RFFileDownloadOperation.h"
#import "AFURLConnectionOperation.h"
#include <fcntl.h>
#include <unistd.h>
#import "NSFileManager+RFKit.h"
#import "NSString+RFKit.h"
#import "dout.h"

@interface AFURLConnectionOperation (AFInternal)
@property (RF_STRONG, nonatomic) NSURLRequest *request;
@property (readonly, nonatomic) long long totalBytesRead;

@end

@interface RFFileDownloadOperation() {
    NSError *_fileError;
}
@property (RF_STRONG, nonatomic) NSTimer *stausRefreshTimer;
@property (assign, readwrite) float transmissionSpeed;
@property (RF_STRONG, nonatomic) NSString *tempPath;
@property (assign) long long totalContentLength;
@property (assign, nonatomic) long long totalBytesReadPerDownload;
@property (assign, nonatomic) long long lastTotalBytesReadPerDownload;
@property (assign) long long offsetContentLength;       // override
@property (copy, nonatomic) void (^progressiveDownloadProgressBlock)(NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile);
@end


@implementation RFFileDownloadOperation
@synthesize targetPath = _targetPath;
@synthesize shouldResume = _shouldResume;
@synthesize shouldOverwriteOldFile = _shouldOverwriteOldFile;
@synthesize stausRefreshTimer = _stausRefreshTimer;
@synthesize transmissionSpeed = _transmissionSpeed;
@synthesize tempPath = _tempPath;
@synthesize totalContentLength = _totalContentLength;
@synthesize totalBytesReadPerDownload = _totalBytesReadPerDownload;
@synthesize lastTotalBytesReadPerDownload = _lastTotalBytesReadPerDownload;
@synthesize progressiveDownloadProgressBlock = _progressiveDownloadProgressBlock;

- (NSString *)debugDescription {
    NSString *status = self.isFinished? @"isFinished" : (self.isPaused? @"isPaused" : (self.isExecuting? @"isExecuting" : @"Unexpected"));
    return [NSString stringWithFormat:@"%@: status: %@, speed: %f, %lld/%lld", [self.request.URL lastPathComponent], status, self.transmissionSpeed, self.bytesDownloaded, self.bytesFileSize];
}

- (id)initWithRequest:(NSURLRequest *)urlRequest {
    RFAssert(false, @"You can`t creat a RFFileDownloadOperation with this method.");
    return nil;
}

- (id)initWithRequest:(NSURLRequest *)urlRequest targetPath:(NSString *)targetPath {
    return [self initWithRequest:urlRequest targetPath:targetPath shouldResume:YES shouldCoverOldFile:YES];
}

- (id)initWithRequest:(NSURLRequest *)urlRequest targetPath:(NSString *)targetPath shouldResume:(BOOL)shouldResume shouldCoverOldFile:(BOOL)shouldOverwriteOldFile {
    NSParameterAssert(urlRequest != nil && targetPath.length > 0);
    if (!(self = [super initWithRequest:urlRequest])) {
        return nil;
    }
        
    // Check target path
    NSString *destinationPath = nil;
    
    // We assume that at least the directory has to exist on the targetPath
    BOOL isDirectory;
    if(![[NSFileManager defaultManager] fileExistsAtPath:targetPath isDirectory:&isDirectory]) {
        isDirectory = NO;
    }
    // If targetPath is a directory, use the file name we got from the urlRequest.
    if (isDirectory) {
        NSString *fileName = [urlRequest.URL lastPathComponent];
        RFAssert(fileName.length > 0, @"Cannot decide file name.");
        destinationPath = [NSString pathWithComponents:@[targetPath, fileName]];
    }
    else {
        destinationPath = targetPath;
    }
    
    self.shouldOverwriteOldFile = shouldOverwriteOldFile;
    if (!shouldOverwriteOldFile && [[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
        dout_warning(@"RFFileDownloadOperation: File already exist, and cover option was off.");
        return nil;
    }
    
    _targetPath = destinationPath;
    
    // Download is saved into a temporal file and remaned upon completion
    NSString *tempPath = [self tempPath];
    
    // Do we need to resume the file?
    _shouldResume = shouldResume;
    BOOL isResuming = [self updateByteStartRangeForRequest];
    
    // Try to create/open a file at the target location
    if (!isResuming) {
        int fileDescriptor = open([tempPath UTF8String], O_CREAT | O_EXCL | O_RDWR, 0666);
        if (fileDescriptor > 0) close(fileDescriptor);
    }
    
    self.outputStream = [NSOutputStream outputStreamToFileAtPath:tempPath append:isResuming];
    if (!self.outputStream) {
        dout_error(@"Output stream can't be created");
        return nil;
    }
    
    // Give the object its default completionBlock.
    [self setCompletionBlockWithSuccess:nil failure:nil];
    
    // Set defalut value
    _stausRefreshTimeInterval = 1;
    
    return self;
}

// Updates the current request to set the correct start-byte-range.
- (BOOL)updateByteStartRangeForRequest {
    BOOL isResuming = NO;
    if (self.shouldResume) {
        unsigned long long downloadedBytes = [[NSFileManager defaultManager] fileSizeForPath:self.tempPath];
        if (downloadedBytes > 0) {
            NSMutableURLRequest *mutableURLRequest = [self.request mutableCopy];
            NSString *requestRange = [NSString stringWithFormat:@"bytes=%llu-", downloadedBytes];
            [mutableURLRequest setValue:requestRange forHTTPHeaderField:@"Range"];
            self.request = mutableURLRequest;
            isResuming = YES;
        }
    }
    return isResuming;
}


- (void)dealloc {
    dout(@"dealloc: %@", self);
}

#pragma mark - Control
- (void)start {
    [super start];
    [self activeStausRefreshTimer];
}

- (void)resume {
    [super resume];
    [self activeStausRefreshTimer];
}

- (void)pause {
    [super pause];
    [self deactiveStausRefreshTimer];
    [self updateByteStartRangeForRequest];
}

- (void)cancel {
    [super cancel];
    [self deactiveStausRefreshTimer];
}

- (void)activeStausRefreshTimer {
    if (!self.stausRefreshTimer) {
        self.stausRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:self.stausRefreshTimeInterval target:self selector:@selector(stausRefresh) userInfo:nil repeats:YES];
        
        self.transmissionSpeed = 0;
    }
}

- (void)deactiveStausRefreshTimer {
    if (self.stausRefreshTimer) {
        [self.stausRefreshTimer invalidate];
        self.stausRefreshTimer = nil;
        
        self.transmissionSpeed = 0;
    }
}

- (void)stausRefresh {
    self.transmissionSpeed = (self.totalBytesReadPerDownload - self.lastTotalBytesReadPerDownload)/self.stausRefreshTimeInterval;
    self.lastTotalBytesReadPerDownload = self.totalBytesReadPerDownload;
    if (self.transmissionSpeed < 0) {
        dout_float(self.lastTotalBytesReadPerDownload)
        dout_float(self.totalBytesReadPerDownload)
        self.transmissionSpeed = 0;
    }
    _dout_float(self.transmissionSpeed)
}

#pragma mark - Path

+ (NSString *)cacheFolder {
    static NSString *cacheFolder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *cacheDir = NSTemporaryDirectory();
        cacheFolder = [cacheDir stringByAppendingPathComponent:kAFNetworkingIncompleteDownloadFolderName];
        
        // Ensure all cache directories are there (needed only once)
        NSError *error = nil;
        if(![[NSFileManager new] createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
            dout_error(@"Failed to create cache directory at %@", cacheFolder);
        }
    });
    return cacheFolder;
}

- (NSString *)tempPath {
    NSString *tempPath = nil;
    if (self.targetPath) {
        NSString *md5URLString = [NSString MD5String:self.targetPath];
        tempPath = [[[self class] cacheFolder] stringByAppendingPathComponent:md5URLString];
    }
    return tempPath;
}

- (BOOL)deleteTempFileWithError:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager new];
    BOOL success = YES;
    @synchronized(self) {
        NSString *tempPath = [self tempPath];
        if ([fileManager fileExistsAtPath:tempPath]) {
            success = [fileManager removeItemAtPath:[self tempPath] error:error];
        }
    }
    return success;
}

#pragma mark - AFURLRequestOperation

- (void)setCompletionBlockWithSuccess:(void (^)(RFFileDownloadOperation *operation, id responseObject))success
                              failure:(void (^)(RFFileDownloadOperation *operation, NSError *error))failure
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    self.completionBlock = ^ {
        NSError *localError = nil;
        if(self.isCancelled) {
            if (self.isDeletingTempFileOnCancel) {
                [self deleteTempFileWithError:&localError];
                if (localError) {
                    _fileError = localError;
                }
            }
        }
        // Loss of network connections = error set, but not cancel
        else if (!self.error) {
            // Move file to final position and capture error
            @synchronized(self) {
                NSFileManager *fm = [NSFileManager new];
                if (self.shouldOverwriteOldFile && [fm fileExistsAtPath:_targetPath]) {
                    [fm removeItemAtPath:_targetPath error:&localError];
                    if (localError) {
                        dout_error(@"Can`t remove exist file.");
                    }
                }
                if (localError) {
                    _fileError = localError;
                }
                else {
                    [fm moveItemAtPath:[self tempPath] toPath:_targetPath error:&localError];
                    if (localError) {
                        _fileError = localError;
                    }
                }
            }
        }
        
        if (self.error) {
            if (failure) {
                dispatch_async(self.failureCallbackQueue ? self.failureCallbackQueue : dispatch_get_main_queue(), ^{
                    failure(self, self.error);
                });
            }
        } else {
            if (success) {
                dispatch_async(self.successCallbackQueue ? self.failureCallbackQueue : dispatch_get_main_queue(), ^{
                    success(self, _targetPath);
                });
            }
        }
        
        [self deactiveStausRefreshTimer];
    };
#pragma clang diagnostic pop
}

- (NSError *)error {
    return _fileError ? _fileError : [super error];
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [super connection:connection didReceiveResponse:response];
    
    // Check if we have the correct response
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        return;
    }
    
    // Check for valid response to resume the download if possible
    long long totalContentLength = self.response.expectedContentLength;
    long long fileOffset = 0;
    if(httpResponse.statusCode == 206) {
        NSString *contentRange = [httpResponse.allHeaderFields valueForKey:@"Content-Range"];
        if ([contentRange hasPrefix:@"bytes"]) {
            NSArray *bytes = [contentRange componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -/"]];
            if ([bytes count] == 4) {
                fileOffset = [bytes[1] longLongValue];
                totalContentLength = [bytes[2] longLongValue]; // If this is *, it's converted to 0
            }
        }
    }
    
    self.totalBytesReadPerDownload = 0;
    self.lastTotalBytesReadPerDownload = 0;
    self.offsetContentLength = fmaxl(fileOffset, 0);
    self.totalContentLength = totalContentLength;
    [self.outputStream setProperty:@(_offsetContentLength) forKey:NSStreamFileCurrentOffsetKey];
}

- (long long)bytesDownloaded {
    return self.totalBytesReadPerDownload + self.offsetContentLength;
}

- (long long)bytesFileSize {
    return self.totalContentLength;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data  {
    [super connection:connection didReceiveData:data];
    
    // Track custom bytes read because totalBytesRead persists between pause/resume.
    self.totalBytesReadPerDownload += [data length];

    if (self.progressiveDownloadProgressBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressiveDownloadProgressBlock(
                (long long)[data length],
                self.totalBytesRead,
                self.response.expectedContentLength,
                self.totalBytesReadPerDownload + self.offsetContentLength,
                self.totalContentLength
            );
        });
    }
}

@end
