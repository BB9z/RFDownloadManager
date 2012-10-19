
#import "RFFileDownloadOperation.h"
#import "AFURLConnectionOperation.h"
#include <fcntl.h>
#include <unistd.h>
#import "NSFileManager+RFKit.h"

@interface AFURLConnectionOperation (AFInternal)
@property (nonatomic, strong) NSURLRequest *request;
@property (readonly, nonatomic, assign) long long totalBytesRead;

@end

@interface RFFileDownloadOperation() {
    NSError *_fileError;
}
@property (assign, readwrite) float transmissionSpeed;
@property (nonatomic, strong) NSString *tempPath;
@property (assign) long long totalContentLength;
@property (assign) long long offsetContentLength;
@property (nonatomic, copy) void (^progressiveDownloadProgressBlock)(NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile);
@end


@implementation RFFileDownloadOperation

- (id)initWithRequest:(NSURLRequest *)urlRequest {
    NSAssert(false, @"You can`t creat a RFFileDownloadOperation with this method.");
    return nil;
}

- (id)initWithRequest:(NSURLRequest *)urlRequest targetPath:(NSString *)targetPath {
    return [self initWithRequest:urlRequest targetPath:targetPath shouldCoverOldFile:YES];
}

- (id)initWithRequest:(NSURLRequest *)urlRequest targetPath:(NSString *)targetPath  shouldCoverOldFile:(BOOL)shouldCoverOldFile {
    NSParameterAssert(urlRequest != nil && targetPath.length > 0);
    
    if (!(self = [super initWithRequest:urlRequest])) {
        return nil;
    }
    
    // Check target path
    NSString *destinationPath = nil;
    
    // we assume that at least the directory has to exist on the targetPath
    BOOL isDirectory;
    if(![[NSFileManager defaultManager] fileExistsAtPath:targetPath isDirectory:&isDirectory]) {
        isDirectory = NO;
    }
    // if targetPath is a directory, use the file name we got from the urlRequest.
    if (isDirectory) {
        NSString *fileName = [urlRequest.URL lastPathComponent];
        NSAssert(fileName.length > 0, @"Cannot decide file name.");
        destinationPath = [NSString pathWithComponents:[NSArray arrayWithObjects:targetPath, fileName, nil]];
    }
    else {
        destinationPath = targetPath;
    }
    
    self.shouldCoverOldFile = shouldCoverOldFile;
    if (!shouldCoverOldFile && [[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
        dout_warning(@"RFFileDownloadOperation: File already exist.")
        return nil;
    }
    
    _targetPath = destinationPath;
    
    // download is saved into a temporal file and remaned upon completion
    NSString *tempPath = [self tempPath];
    
    // do we need to resume the file?
    BOOL isResuming = NO;
    
    unsigned long long downloadedBytes = [[NSFileManager defaultManager] fileSizeForPath:tempPath];
    if (downloadedBytes > 0) {
        NSMutableURLRequest *mutableURLRequest = [urlRequest mutableCopy];
        NSString *requestRange = [NSString stringWithFormat:@"bytes=%llu-", downloadedBytes];
        [mutableURLRequest setValue:requestRange forHTTPHeaderField:@"Range"];
        self.request = mutableURLRequest;
        isResuming = YES;
    }
    
    // try to create/open a file at the target location
    if (!isResuming) {
        int fileDescriptor = open([tempPath UTF8String], O_CREAT | O_EXCL | O_RDWR, 0666);
        if (fileDescriptor > 0) {
            close(fileDescriptor);
        }
    }
    
    self.outputStream = [NSOutputStream outputStreamToFileAtPath:tempPath append:isResuming];
    if (!self.outputStream) {
        dout_error(@"Output stream can't be created");
        return nil;
    }

    return self;
}

- (void)dealloc {
    dout(@"dealloc: %@", self)
}

#pragma mark - Path

+ (NSString *)cacheFolder {
    static NSString *cacheFolder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *cacheDir = NSTemporaryDirectory();
        cacheFolder = [cacheDir stringByAppendingPathComponent:kAFNetworkingIncompleteDownloadFolderName];
        
        // ensure all cache directories are there (needed only once)
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

- (void)setCompletionBlockWithSuccess:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                              failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    self.completionBlock = ^ {
        NSError *localError = nil;
        if([self isCancelled]) {
            // should we clean up? most likely we don't.
            if (self.isDeletingTempFileOnCancel) {
                [self deleteTempFileWithError:&localError];
                if (localError) {
                    _fileError = localError;
                }
            }
            return;
        }
        else {
            // move file to final position and capture error
            @synchronized(self) {
                NSFileManager *fm = [NSFileManager new];
                if (self.shouldCoverOldFile && [fm fileExistsAtPath:_targetPath]) {
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
            dispatch_async(self.failureCallbackQueue ?: dispatch_get_main_queue(), ^{
                failure(self, self.error);
            });
        } else {
            dispatch_async(self.successCallbackQueue ?: dispatch_get_main_queue(), ^{
                success(self, _targetPath);
            });
        }
    };
#pragma clang diagnostic pop
}

- (NSError *)error {
    if (_fileError) {
        return _fileError;
    } else {
        return [super error];
    }
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [super connection:connection didReceiveResponse:response];
    
    // check if we have the correct response
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        return;
    }
    
    // check for valid response to resume the download if possible
    long long totalContentLength = self.response.expectedContentLength;
    long long fileOffset = 0;
    if(httpResponse.statusCode == 206) {
        NSString *contentRange = [httpResponse.allHeaderFields valueForKey:@"Content-Range"];
        if ([contentRange hasPrefix:@"bytes"]) {
            NSArray *bytes = [contentRange componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -/"]];
            if ([bytes count] == 4) {
                fileOffset = [[bytes objectAtIndex:1] longLongValue];
                totalContentLength = [[bytes objectAtIndex:2] longLongValue]; // if this is *, it's converted to 0
            }
        }
    }
    
    self.offsetContentLength = MAX(fileOffset, 0);
    self.totalContentLength = totalContentLength;
    [self.outputStream setProperty:[NSNumber numberWithLongLong:_offsetContentLength] forKey:NSStreamFileCurrentOffsetKey];
}

- (long long)bytesDownloaded {
    return self.totalBytesRead + self.offsetContentLength;
}

- (long long)bytesFileSize {
    return self.totalContentLength;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data  {
    [super connection:connection didReceiveData:data];
    
    if (self.progressiveDownloadProgressBlock) {
        self.progressiveDownloadProgressBlock((long long)[data length],
                                         self.totalBytesRead,
                                         self.response.expectedContentLength,
                                         self.totalBytesRead + self.offsetContentLength,
                                         self.totalContentLength);
    }
}

@end
