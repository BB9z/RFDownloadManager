/*!
    RFDownloadManager
    ver 0.1

    Copyright (c) 2012-2014 BB9z
    https://github.com/BB9z/RFDownloadManager

    The MIT License (MIT)
    http://www.opensource.org/licenses/mit-license.php
*/

/**
    RFDownloadManager needs:
    - RFKit <https://github.com/RFUI/Core>
    - AFNetworking <https://github.com/AFNetworking/AFNetworking>
 */

#import <Foundation/Foundation.h>
#import "AFDownloadRequestOperation+RFFileDownload.h"

@class RFDownloadManager;

@protocol RFDownloadManagerDelegate <NSObject>
@optional
// 成功下载
- (void)RFDownloadManager:(RFDownloadManager *)downloadManager operationCompleted:(AFDownloadRequestOperation *)operation;

// 下载失败
- (void)RFDownloadManager:(RFDownloadManager *)downloadManager operationFailed:(AFDownloadRequestOperation *)operation;

// 用于下载状态更新，进度、速度
- (void)RFDownloadManager:(RFDownloadManager *)downloadManager operationStateUpdate:(AFDownloadRequestOperation *)operation;

@end

@interface RFDownloadManager : NSObject
+ (instancetype)sharedInstance;
- (instancetype)initWithDelegate:(id<RFDownloadManagerDelegate>)delegate;
@property (weak, nonatomic) id<RFDownloadManagerDelegate> delegate;

- (NSArray *)downloadingOperations;
- (NSArray *)operationsInQueue;
- (NSArray *)pausedOperations;

/// All operations: downloadingOperations + operationsInQueue + pausedOperations
- (NSArray *)operations DEPRECATED_ATTRIBUTE;

/// 是否有下载任务进行中
/// Not Implemented yet.
@property (readonly, nonatomic) BOOL isDownloading;

/// How many file can download at the same time.
/// Default 3.
@property (assign, nonatomic) uint maxRunningTaskCount;

/// Should try to resume download proccess if there are download temp file exsist.
/// Only affect operations which created after this property set.
/// Default YES.
@property (assign, nonatomic) BOOL shouldResume;

/// Return nil, if has the url or operation creat failure.
- (AFDownloadRequestOperation *)addURL:(NSURL *)url fileStorePath:(NSString *)destinationFilePath;
- (AFDownloadRequestOperation *)findOperationWithURL:(NSURL *)url;

/// Subclass can override this method to change operation option.
- (void)setupDownloadOperation:(AFDownloadRequestOperation *)downloadOperation;

- (void)startAll;
- (void)pauseAll;
- (void)cancelAll;
- (void)startOperation:(AFDownloadRequestOperation *)operation;
- (void)pauseOperation:(AFDownloadRequestOperation *)operation;
- (void)cancelOperation:(AFDownloadRequestOperation *)operation;
- (void)startOperationWithURL:(NSURL *)url;
- (void)pauseOperationWithURL:(NSURL *)url;
- (void)cancelOperationWithURL:(NSURL *)url;

@end



