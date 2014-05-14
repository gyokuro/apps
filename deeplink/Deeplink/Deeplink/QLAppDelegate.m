//
//  QLAppDelegate.m
//  Deeplink
//
//  Created by DAVID on 5/7/14.
//  Copyright (c) 2014 QorioLabs. All rights reserved.
//

#import "QLAppDelegate.h"
#import "XLinks.h"


@implementation QLAppDelegate



- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSLog(@"didFinishLaunchingWithOptions app=%@ options=%@", application, launchOptions);
    return YES;
}
							
- (void)applicationWillEnterForeground:(UIApplication *)application
{
    NSLog(@"applciationWillEnterForeground app=%@", application);
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"applicationDidBecomeActive app=%@", application);
    if (![[XLinks sharedInstance] isAppInstallRegistered]) {
        [[XLinks sharedInstance] registerAppInstall:@"qldeeplink"];
    }
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    NSLog(@"openURL app=%@ source=%@ annotation=%@ url=%@", application, sourceApplication, annotation, url);
    return [[XLinks sharedInstance] handleAppUrl:url withHandler:^bool(NSArray *pathComponents, NSDictionary *params) {
        NSLog(@"handled url with parts %@ and params %@", pathComponents, params);
        [_deeplinkDelegate handleContent:[params objectForKey:@"url"]];
        return YES;
    }];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}


@end
