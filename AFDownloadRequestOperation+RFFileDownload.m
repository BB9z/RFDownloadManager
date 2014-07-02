
#import "AFDownloadRequestOperation+RFFileDownload.h"

@interface AFDownloadRequestOperation ()
@property (assign) long long totalContentLength;
@property (nonatomic, assign) long long totalBytesReadPerDownload;
@property (assign) long long offsetContentLength;
@end

@implementation AFDownloadRequestOperation (RFFileDownload)

- (long long)bytesDownloaded {
    return self.totalBytesReadPerDownload + self.offsetContentLength;
}

- (long long)bytesFileSize {
    return self.totalContentLength;
}

@end
