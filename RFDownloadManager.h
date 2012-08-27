//
//  RFDownloadManager.h
//  RFDownloadManager example
//
//  Created by BB9z on 12-8-20.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFNetworking.h"

@interface RFDownloadManager : NSObject

@property (readonly, atomic) BOOL isDownloading;

+ (RFDownloadManager *)sharedInstance;
- (BOOL)addURL:(NSURL *)url fileStorePath:(NSString *)destinationFilePath;
- (BOOL)startQueue;

@end

@interface RFFileDownloadOperation : AFURLConnectionOperation

@property (copy, nonatomic) NSString *destinationFilePath;

- (RFFileDownloadOperation *)initWithRequest:(NSURLRequest *)urlRequest fileStorePath:(NSString *)destinationFilePath;

@end

