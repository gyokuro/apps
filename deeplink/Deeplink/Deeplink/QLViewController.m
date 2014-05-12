//
//  QLViewController.m
//  Deeplink
//
//  Created by DAVID on 5/7/14.
//  Copyright (c) 2014 QorioLabs. All rights reserved.
//

#import "QLViewController.h"
#import "XLinks.h"

@interface QLViewController ()
@property (weak, nonatomic) IBOutlet UILabel *contentKey;

@end

@implementation QLViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    ((QLAppDelegate*)([UIApplication sharedApplication].delegate)).deeplinkDelegate = self;
}

-(void)handleContent:(NSString*)key
{
    NSLog(@"Handle deeplink content key = %@", key);
    _contentKey.text = key;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)onRemoveCookie:(id)sender {
    NSLog(@"Removing cookie file");
    [[XLinks sharedInstance] clearAppInstall];
}
- (IBAction)onReportInstall:(id)sender {
    NSLog(@"Report install");
    [[XLinks sharedInstance] registerAppInstall:@"qldeeplink"];
}

@end
