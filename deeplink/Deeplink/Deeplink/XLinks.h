//
//  XLinks.h
//  Deeplink
//
//  Created by DAVID on 5/11/14.
//  Copyright (c) 2014 QorioLabs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XLinks : NSObject

+ (XLinks*)sharedInstance;
+ (NSString*)getCookieFile;
+ (NSString*)getAppUUID;


- (void)initWithApplicationDelegate:(id<UIApplicationDelegate>)delegate appUrlScheme:(NSString *)appUrlScheme apiToken:(NSString*)apiToken;

- (BOOL)clearAppInstall;
- (void)reportInstall;

//- (NSDictionary*)saveInvocationContext:(NSString *)cookie sourceApplication:(NSString*)sourceApplication withShortCode:(NSString*)shortCode url:(NSURL*)url;
//- (void)reportInstall:(BOOL)throughSafari shortCode:(NSString*)shortCode contextUUID:(NSString*)contextUuid;
//- (BOOL)hasReportedInstall;


// Intercepts
- (BOOL)application:(UIApplication*)application OpenURL:(NSURL*)url sourceApplication:(NSString*)sourceApplication annotation:(id)annotation;
- (void)applicationDidBecomeActive:(UIApplication *)application;

@end
