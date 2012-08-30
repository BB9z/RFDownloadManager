/*!
    RFDownloadManager

    Copyright (c) 2012 BB9z
    http://github.com/bb9z/RFKit

    The MIT License (MIT)
    http://www.opensource.org/licenses/mit-license.php
*/

/** Example
    
 
 
 */

#import <Foundation/Foundation.h>
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
/// 下载队列中的任务
@property (readonly) NSMutableArray *requrestOperations;

// 未完成
/// 是否有下载任务进行中
@property (readonly, nonatomic) BOOL isDownloading;

// 未完成
/// 正在下载任务的个数
@property (readonly, nonatomic) uint runningTaskCount;

// 未完成
/// 同时允许的任务数
@property (assign, nonatomic) uint maxRunningTaskCount;

- (RFDownloadManager *)initWithDelegate:(id<RFDownloadManagerDelegate>)delegate;
+ (RFDownloadManager *)sharedInstance;

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

@end



