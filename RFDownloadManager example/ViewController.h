//
//  ViewController.h
//  RFDownloadManager example
//
//  Created by BB9z on 12-8-20.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (RF_WEAK, nonatomic) IBOutlet UIProgressView *progress;
@property (RF_WEAK, nonatomic) IBOutlet UISlider *timerSlider;
@end
