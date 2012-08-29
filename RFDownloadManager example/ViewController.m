//
//  ViewController.m
//  RFDownloadManager example
//
//  Created by BB9z on 12-8-20.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#import "AFHTTPRequestOperationLogger.h"
#import "AFNetworking.h"

@interface ViewController ()
@property (RF_STRONG, nonatomic) RFDownloadManager *DM;
@end

NSString *testUrl1 = @"http://192.168.1.168/m.tar.gz";
NSString *testUrl2 = @"http://192.168.1.168/a.apk";


@implementation ViewController
@synthesize progress;
@synthesize timerSlider;

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [[AFHTTPRequestOperationLogger sharedLogger] startLogging];
    [[AFHTTPRequestOperationLogger sharedLogger] setLevel:AFLoggerLevelInfo];
    
    [NSTimer scheduledTimerWithTimeInterval:.6 target:self selector:@selector(timerCallback) userInfo:nil repeats:YES];
    
    
    self.DM = [RFDownloadManager sharedInstance];
    self.DM.delegate = self;
    [self.DM addURL:[NSURL URLWithString:testUrl1] fileStorePath:[[NSBundle mainBundlePathForDocuments] stringByAppendingPathComponent:@"m.gz"]];
    [self.DM addURL:[NSURL URLWithString:testUrl2] fileStorePath:[[NSBundle mainBundlePathForDocuments] stringByAppendingPathComponent:@"a.apk"]];

    [self.DM startAll];
//    [NSObject performBlock:^{
//        douts(@"pause")
//        [self.DM pauseAll];
//    } afterDelay:3];
//    [NSObject performBlock:^{
//        douts(@"start")
//        [self.DM startAll];
//    } afterDelay:20];
}

- (void)timerCallback {
    float r = random()/2044897792.0;
    _dout_float(r)
    self.timerSlider.value = r;
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (void)RFDownloadManager:(RFDownloadManager *)downloadManager operationCompleted:(RFFileDownloadOperation *)operation {
    doutwork()
    douto(operation.targetPath)
}
- (void)RFDownloadManager:(RFDownloadManager *)downloadManager operationFailed:(RFFileDownloadOperation *)operation {
    doutwork()
    douto(operation.error)
}
- (void)RFDownloadManager:(RFDownloadManager *)downloadManager operationStateUpdate:(RFFileDownloadOperation *)operation {
    doutwork()
    dout_float(operation.bytesDownloaded)
    dout_float(operation.bytesFileSize)
}
@end
