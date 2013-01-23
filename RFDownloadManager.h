/*!
    RFDownloadManager

    Copyright (c) 2012-2013 BB9z
    https://github.com/bb9z/RFDownloadManager

    The MIT License (MIT)
    http://www.opensource.org/licenses/mit-license.php
*/

/**
    RFDownloadManager needs:
    - RFKit <https://github.com/BB9z/RFKit>
    - AFNetworking <https://github.com/AFNetworking/AFNetworking>
 */

#import "RFRuntime.h"
#import "RFFileDownloadOperation.h"

@class RFDownloadManager;

@protocol RFDownloadManagerDelegate <NSObject>
@optional
// 成功下载
- (void)RFDownloadManager:(RFDownloadManager *)downloadManager operationCompleted:(RFFileDownloadOperation *)operation;

// 下载失败
- (void)RFDownloadManager:(RFDownloadManager *)downloadManager operationFailed:(RFFileDownloadOperation *)operation;

// 用于下载状态更新，进度、速度
- (void)RFDownloadManager:(RFDownloadManager *)downloadManager operationStateUpdate:(RFFileDownloadOperation *)operation;

@end

@interface RFDownloadManager : NSObject
@property (RF_WEAK, nonatomic) id<RFDownloadManagerDelegate> delegate;
/// 下载队列中的所有任务
/// 应避免频繁调用该方法
- (NSSet *)operations;

/// 正在下载中的任务
- (NSSet *)downloadingOperations;

/// 是否有下载任务进行中
@property (readonly, nonatomic) BOOL isDownloading;

/// How many file can download at the same time.
/// Default 3.
@property (assign, nonatomic) uint maxRunningTaskCount;

/// Should try to resume download proccess if there are download temp file exsist.
/// Only affect operations which created after this property set.
/// Default YES.
@property (assign, nonatomic) BOOL shouldResume;

- (RFDownloadManager *)initWithDelegate:(id<RFDownloadManagerDelegate>)delegate;
+ (RFDownloadManager *)sharedInstance;

/**
    
    返回nil，如果已经包含该url或者创建新对象失败
 */
- (RFFileDownloadOperation *)addURL:(NSURL *)url fileStorePath:(NSString *)destinationFilePath;

- (void)startAll;
- (void)pauseAll;
- (void)cancelAll;
- (void)startOperation:(RFFileDownloadOperation *)operation;
- (void)pauseOperation:(RFFileDownloadOperation *)operation;
- (void)cancelOperation:(RFFileDownloadOperation *)operation;
- (void)startOperationWithURL:(NSURL *)url;
- (void)pauseOperationWithURL:(NSURL *)url;
- (void)cancelOperationWithURL:(NSURL *)url;

- (RFFileDownloadOperation *)findOperationWithURL:(NSURL *)url;
@end



