//
//  QLConfigViewController.m
//  Deeplink
//
//  Created by DAVID on 5/13/14.
//  Copyright (c) 2014 QorioLabs. All rights reserved.
//

#import "QLConfigViewController.h"
#import <MessageUI/MFMessageComposeViewController.h>
#import <MessageUI/MessageUI.h>

#import "XLinks.h"

@interface QLConfigViewController () <NSURLConnectionDataDelegate, MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate, UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UILabel *shortUrl;
@property (weak, nonatomic) IBOutlet UITextField *appstoreUrl;

@end

@implementation QLConfigViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _appstoreUrl.delegate = self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _appstoreUrl) {
        [_appstoreUrl resignFirstResponder];
    }
    return YES;
}

- (IBAction)onRemoveCookie:(id)sender {
    NSLog(@"Removing cookie file");
    [[XLinks sharedInstance] clearAppInstall];
}
- (IBAction)onReportInstall:(id)sender {
    NSLog(@"Report install");
    [[XLinks sharedInstance] reportInstall];
}
- (IBAction)onGenerateShortURL:(id)sender {
    NSString *json = [self buildJsonWithLongUrl:_contentLocation.text appStoreUrl:_appstoreUrl.text appDeeplinkUrl:_appDeeplinkURL.text];
    NSLog(@"Got JSON %@", json);
    
    NSURL *aUrl = [NSURL URLWithString:@"https://qor.io/api/v1/url"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:aUrl cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60.0];
    
    [request setHTTPMethod:@"POST"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[json dataUsingEncoding:NSUTF8StringEncoding]];

    NSURLConnection *connection= [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [connection start];
}

- (NSString*)buildJsonWithLongUrl: (NSString*)longUrl appStoreUrl:(NSString*)appStoreUrl appDeeplinkUrl:(NSString*)appDeepUrl
{
    NSMutableDictionary *req = [[NSMutableDictionary alloc]init];
    [req setObject:longUrl forKey:@"longUrl"];
    NSMutableArray *rules = [@[] mutableCopy];
    NSMutableDictionary *rule1 = [[NSMutableDictionary alloc]init];
    [rule1 setObject:@"qldeeplink" forKey:@"scheme"];
    [rule1 setObject:appStoreUrl forKey:@"appstore"];
    [rule1 setObject:appDeepUrl forKey:@"destination"];
    [rule1 setObject:@"iPhone" forKey:@"platform"];
    NSMutableDictionary *rule2 = [[NSMutableDictionary alloc]init];
    [rule2 setObject:@"qldeeplink" forKey:@"scheme"];
    [rule2 setObject:appStoreUrl forKey:@"appstore"];
    [rule2 setObject:appDeepUrl forKey:@"destination"];
    [rule2 setObject:@"iPod*" forKey:@"platform"];
    NSMutableDictionary *rule3 = [[NSMutableDictionary alloc]init];
    [rule3 setObject:@"qldeeplink" forKey:@"scheme"];
    [rule3 setObject:@"https://play.google.com/store/apps/details?id=com.yuilop" forKey:@"appstore"];
    [rule3 setObject:longUrl forKey:@"destination"];
    [rule3 setObject:@"Android" forKey:@"os"];
    
    [rules addObject:rule1];
    [rules addObject:rule2];
    [rules addObject:rule3];
    
    [req setObject:rules forKey:@"rules"];
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:req options:NSJSONWritingPrettyPrinted error:&error];
    return [[NSString alloc] initWithData:jsonData
                          encoding:NSUTF8StringEncoding];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSLog(@"receiveResponse: %@", response);
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    if (httpResponse.statusCode != 200) {
        _shortUrl.text = @"ERROR";
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSLog(@"receiveData: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] );
    NSError* error;
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    NSString *code = [json objectForKey:@"id"];
    _shortUrl.text = [NSString stringWithFormat:@"http://qor.io/%@", code];
}

- (IBAction)onShare:(id)sender {
    // Send message
    NSString *message = [NSString stringWithFormat:@"Hi! Please check out my post. You can click on the link to view or install the app: %@", _shortUrl.text];
    if([MFMessageComposeViewController canSendText]) {
        MFMessageComposeViewController *controller = [[MFMessageComposeViewController alloc] init];
        controller.body = message;
        controller.messageComposeDelegate = self;
        [self presentViewController:controller animated:YES completion:^{
            NSLog(@"Finished entering message");
        }];
    } else if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mfc = [[MFMailComposeViewController alloc]init];
        mfc.mailComposeDelegate = self;
        [mfc setSubject:@"Check out my post"];
        [mfc setMessageBody:message isHTML:NO];
        [self presentViewController:mfc animated:YES completion:^{
            NSLog(@"Presented email composer.");
        }];
    }
}


- (void)showAlertTitle:(NSString*)title Message:(NSString*)body {
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:title
                                                      message:body
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
    [message show];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    [self dismissViewControllerAnimated:YES completion:^{
    }];
    
    if (result == MessageComposeResultCancelled) {
        [self showAlertTitle:@"Canceled" Message:@"Canceled sharing short code"];
    } else if (result == MessageComposeResultSent) {
        [self showAlertTitle:@"Success" Message:@"Shared short code!!"];
    } else {
        [self showAlertTitle:@"Failed" Message:@"Failed to share short code :("];
    }
}

#pragma mark - MFMailComposeViewControllerDelegate
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    if (result == MFMailComposeResultSent) {
        [self showAlertTitle:@"Success" Message:@"Shared short code via email!!"];
    } else if (result == MFMailComposeResultCancelled) {
        [self showAlertTitle:@"Canceled" Message:@"Canceled sharing via email!!"];
    } else {
        [self showAlertTitle:@"Failed" Message:@"Failed to share short code via email!!"];
    }
    
    [self dismissViewControllerAnimated:YES completion:^{
        NSLog(@"Email view dismissed.");
    }];
}

@end
