//
//  XLinks.h
//  Deeplink
//
//  Created by DAVID on 5/11/14.
//  Copyright (c) 2014 QorioLabs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XRL.h"


@interface XLinks : NSObject

+ (XLinks*)sharedInstance;
+ (NSString*)getCookieFile;
+ (NSString*)getAppUUID;


+ (void)initWithApplicationDelegate:(id<UIApplicationDelegate>)delegate appUrlScheme:(NSString *)appUrlScheme apiToken:(NSString*)apiToken;

+ (BOOL)clearAppInstall;
+ (void)reportInstall;


// Intercepts
+ (BOOL)application:(UIApplication*)application openURL:(NSURL*)url sourceApplication:(NSString*)sourceApplication annotation:(id)annotation;
+ (void)applicationDidBecomeActive:(UIApplication *)application;

@end

