/*!
    RFFileDownloadOperation
    RFDownloadManager

    Copyright (c) 2012 BB9z
    http://github.com/bb9z/RFKit

    The MIT License (MIT)
    http://www.opensource.org/licenses/mit-license.php
 */

// Code base on AFDownloadRequestOperation
//
// Copyright (c) 2012 Peter Steinberger (http://petersteinberger.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "RFRuntime.h"
#import "AFHTTPRequestOperation.h"

#define kAFNetworkingIncompleteDownloadFolderName @"Incomplete"


/// `AFDownloadRequestOperation` is a subclass of `AFHTTPRequestOperation` for streamed file downloading. Supports Content-Range. (http://tools.ietf.org/html/rfc2616#section-14.16)
@interface RFFileDownloadOperation : AFHTTPRequestOperation

#pragma mark -
/**
 Creates and returns an `AFDownloadRequestOperation`
 @param urlRequest The request object to be loaded asynchronously during execution of the operation
 @param targetPath The target path (with or without file name)
 @param shouldCoverOldFile If YES, will cover file ex.
 @return A new download request operation
 */
- (id)initWithRequest:(NSURLRequest *)urlRequest targetPath:(NSString *)targetPath  shouldCoverOldFile:(BOOL)shouldCoverOldFile;
- (id)initWithRequest:(NSURLRequest *)urlRequest targetPath:(NSString *)targetPath;

/**
 A String value that defines the target path or directory.
 
 We try to be clever here and understand both a directory or a filename.
 The target directory should already be create, or the download fill fail.
 
 If the target is a directory, we use the last part of the URL as a default file name.
 */
@property (RF_STRONG) NSString *targetPath;

/// Default YES
@property (assign, nonatomic) BOOL shouldCoverOldFile;

#pragma mark - Status

/// 文件大小
/// Expected total length. This is different than expectedContentLength if the file is resumed.
/// Note: this can also be zero if the file size is not sent (*)
- (long long)bytesFileSize;

/// 已下载大小
- (long long)bytesDownloaded;

/// 下载速度/每秒
- (float)transmissionSpeed;

/// Indicator for the file offset on partial downloads. This is greater than zero if the file download is resumed.
@property (readonly) long long offsetContentLength;

@property (assign, nonatomic) NSTimeInterval stausRefreshTimeInterval;

//  其他信息
@property (RF_STRONG, readwrite) NSDictionary *userInfo;

/**
 Sets a callback to be called when an undetermined number of bytes have been downloaded from the server. This is a variant of setDownloadProgressBlock that adds support for progressive downloads and adds the
 
 @param block A block object to be called when an undetermined number of bytes have been downloaded from the server. This block has no return value and takes five arguments: the number of bytes read since the last time the download progress block was called, the bytes expected to be read during the request, the bytes already read during this request, the total bytes read (including from previous partial downloads), and the total bytes expected to be read for the file. This block may be called multiple times.
 
 @see setDownloadProgressBlock
 */
- (void)setProgressiveDownloadProgressBlock:(void (^)(NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile))block;

- (void)setCompletionBlockWithSuccess:(void (^)(RFFileDownloadOperation *operation, id responseObject))success failure:(void (^)(RFFileDownloadOperation *operation, NSError *error))failure;

#pragma mark - Temp file

/// Deletes the temporary file if operations is cancelled. Defaults to `NO`.
@property (assign, getter=isDeletingTempFileOnCancel) BOOL deleteTempFileOnCancel;

/// Deletes the temporary file.
/// Returns `NO` if an error happened, `YES` if the file is removed or did not exist in the first place.
- (BOOL)deleteTempFileWithError:(NSError **)error;

/// Returns the path used for the temporary file. Returns `nil` if the targetPath has not been set.
- (NSString *)tempPath;

@end
