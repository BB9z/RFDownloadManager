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
#import "RFDownloadManager.h"

@interface ViewController ()
@property (RF_STRONG, nonatomic) RFDownloadManager *DM;
@end

NSString *testUrl1 = @"http://chinamobo.gicp.net/BooksFiles/143/N/143.pdf";
NSString *testUrl2 = @"http://chinamobo.gicp.net/BooksFiles/143/N/143.pdf";


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
    [self.DM addRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:testUrl1] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10]];
    
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

@end
