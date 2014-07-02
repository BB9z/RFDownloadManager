/*!
    AFDownloadRequestOperation+RFFileDownload
    RFDownloadManager

    Copyright (c) 2014 BB9z
    https://github.com/BB9z/RFDownloadManager

    The MIT License (MIT)
    http://www.opensource.org/licenses/mit-license.php
 */
#import "AFDownloadRequestOperation.h"

@interface AFDownloadRequestOperation (RFFileDownload)

- (long long)bytesDownloaded;
- (long long)bytesFileSize;

@end
