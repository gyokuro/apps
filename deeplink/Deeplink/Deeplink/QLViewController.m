//
//  QLViewController.m
//  Deeplink
//
//  Created by DAVID on 5/7/14.
//  Copyright (c) 2014 QorioLabs. All rights reserved.
//

#import "QLViewController.h"
#import "QLConfigViewController.h"

#import "XLinks.h"


@interface QLViewController () <UITextFieldDelegate, UIWebViewDelegate, UITabBarControllerDelegate>
@property (weak, nonatomic) IBOutlet UITextField *contentLocation;
@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end




@implementation NSString (NSString_Extended)

- (NSString *)urlencode {
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[self UTF8String];
    int sourceLen = strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}
@end


@implementation QLViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    ((QLAppDelegate*)([UIApplication sharedApplication].delegate)).deeplinkDelegate = self;
    _contentLocation.delegate = self;
    _webView.scalesPageToFit = YES;
    _webView.delegate = self;
    ((UITabBarController*)self.parentViewController).delegate = self;
    
    // load whatever is in the text field
    [self textFieldDidEndEditing:_contentLocation];
}

-(void)handleContent:(NSString*)key
{
    NSLog(@"Handle deeplink content key = %@", key);
    _contentLocation.text = key;
    [self textFieldDidEndEditing:_contentLocation];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)textFieldDidEndEditing:(UITextField *)textField
{
    NSURL *go = [NSURL URLWithString:textField.text];
    NSURLRequest *req = [NSURLRequest requestWithURL:go];
    [_webView loadRequest:req];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [_contentLocation resignFirstResponder];
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    _contentLocation.text = webView.request.URL.absoluteString;
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
    NSLog(@"Selected %@", viewController);
    if ([viewController class] == [QLConfigViewController class]) {
        QLConfigViewController *target = (QLConfigViewController*)viewController;
        target.contentLocation.text = _contentLocation.text;
        target.appDeeplinkURL.text = [NSString stringWithFormat:@"qldeeplink://content?url=%@", [target.contentLocation.text urlencode]];
    }
}

@end



