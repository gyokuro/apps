//
//  XLinks.m
//  Deeplink
//
//  Created by DAVID on 5/11/14.
//  Copyright (c) 2014 QorioLabs. All rights reserved.
//

#import "XLinks.h"

#import <AdSupport/ASIdentifierManager.h>

static XLinks *shared;

@implementation XLinks

+ (XLinks*)sharedInstance {
    if (shared == nil) {
        shared = [[XLinks alloc]init];
    }
    return shared;
}

- (BOOL)clearAppInstall
{
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = dirPaths[0];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cookieFile = [NSString stringWithFormat:@"%@/cookie", docsDir];
    NSError *err;
    return[fileManager removeItemAtPath:cookieFile error:&err];
}

- (BOOL)isAppInstallRegistered
{
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = dirPaths[0];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cookieFile = [NSString stringWithFormat:@"%@/cookie", docsDir];
    return[fileManager fileExistsAtPath:cookieFile];
}

- (void)registerAppInstall:(NSString *)appUrlScheme
{
    // Use the browser to make a call back, which will send any cookies and allow the server to
    // associate the user with a content.  The server will then send a redirect
    
    NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    NSURL *home = [NSURL URLWithString:[NSString stringWithFormat:@"https://qor.io/api/v1/events/install/%@/%@", appUrlScheme, idfa]];
    NSLog(@"Register app install %@", home);
    [[UIApplication sharedApplication] openURL:home];
}

- (BOOL)markAppAsInstalled:(NSString *)cookie
{
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = dirPaths[0];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cookieFile = [NSString stringWithFormat:@"%@/cookie", docsDir];
    return [fileManager createFileAtPath:cookieFile contents:[cookie dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
}

- (NSDictionary *)parseQueryString:(NSString *)query {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:2];
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    for (NSString *pair in pairs) {
        NSArray *elements = [pair componentsSeparatedByString:@"="];
        NSString *key = [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *val = [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [dict setObject:val forKey:key];
    }
    return dict;
}

- (BOOL)handleAppUrl:(NSURL*)url withHandler:(appUrlHandler)handler
{
    NSDictionary *params = [self parseQueryString:[url query]];
    NSArray *pathComponents = [url pathComponents];
    NSString *cookie = [params objectForKey:@"cookie"];
    if (cookie != nil) {
        [self markAppAsInstalled:cookie];
    }
    
    if (handler != nil) {
        return handler(pathComponents, params);
    } else {
        return NO;
    }
}


@end
