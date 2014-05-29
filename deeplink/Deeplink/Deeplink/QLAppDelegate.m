//
//  QLAppDelegate.m
//  Deeplink
//
//  Created by DAVID on 5/7/14.
//  Copyright (c) 2014 QorioLabs. All rights reserved.
//

#import "QLAppDelegate.h"
#import "XLinks.h"
#import "TSTapstream.h"
#import <AdSupport/ASIdentifierManager.h>

@implementation QLAppDelegate



- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSLog(@"didFinishLaunchingWithOptions app=%@ options=%@", application, launchOptions);
    
    TSConfig *config = [TSConfig configWithDefaults];
    config.idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    [TSTapstream createWithAccountName:@"dchung" developerSecret:@"p3kBmgmyQK61vnT6ywtjUg" config:config];

    [[XLinks sharedInstance] initWithApplicationDelegate:self appUrlScheme:@"qldeeplink" apiToken:@"xyz12345"];
    return YES;
}
							
- (void)applicationWillEnterForeground:(UIApplication *)application
{
    NSLog(@"applciationWillEnterForeground app=%@", application);
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"applicationDidBecomeActive app=%@", application);
    [[XLinks sharedInstance]applicationDidBecomeActive:application];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    // Intercepts
    //[[XLinks sharedInstance] application:application OpenURL:url sourceApplication:sourceApplication annotation:annotation];
    
    // Normal program processing
    NSDictionary *params = [self parseQueryString:[url query]];
    [_deeplinkDelegate handleContent:[params objectForKey:@"url"]];

    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
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


@end
