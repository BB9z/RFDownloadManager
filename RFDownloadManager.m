//
//  RFDownloadManager.m
//  RFDownloadManager example
//
//  Created by BB9z on 12-8-20.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "RFDownloadManager.h"

@interface RFDownloadManager ()
@property (RF_STRONG, atomic) NSMutableArray *requrests;
@property (RF_STRONG, atomic) NSMutableArray *requrestOperations;
@property (assign, readwrite, atomic) BOOL isDownloading;

@property (copy, nonatomic) NSString *tempFileStorePath;
@end

@implementation RFDownloadManager

- (RFDownloadManager *)init {
    if (self = [super init]) {
        self.isDownloading = NO;
    }
    return self;
}

+ (RFDownloadManager *)sharedInstance {
	static RFDownloadManager *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
    });
	return sharedInstance;
}

- (BOOL)addURL:(NSURL *)url fileStorePath:(NSString *)destinationFilePath {
    if (![self.requrests containsObject:url]) {
        [self.requrests addObject:url];
        
        RFFileDownloadOperation *downloadOperation = [[RFFileDownloadOperation alloc] initWithRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:40] fileStorePath:destinationFilePath];
        [self.requrestOperations addObject:downloadOperation];
        
        return YES;
    }
    return NO;
}

- (BOOL)startQueue {
    if (!self.isDownloading) {
        // start
        self.isDownloading = YES;
        return YES;
    }
    return NO;
}

@end

@implementation RFFileDownloadOperation
- (RFFileDownloadOperation *)initWithRequest:(NSURLRequest *)urlRequest fileStorePath:(NSString *)destinationFilePath {
    self = [super initWithRequest:urlRequest];
    if (self) {
        self.destinationFilePath = destinationFilePath;
        self.outputStream = [NSOutputStream outputStreamToFileAtPath:destinationFilePath append:YES];
    }
    return self;
}

@end
