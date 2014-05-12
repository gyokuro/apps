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

typedef bool(^appUrlHandler)(NSArray *pathComponents, NSDictionary *params);

- (BOOL)isAppInstallRegistered;
- (BOOL)clearAppInstall;
- (void)registerAppInstall:(NSString *)appUrlScheme;
- (BOOL)markAppAsInstalled:(NSString *)cookie;
- (BOOL)handleAppUrl:(NSURL*)url withHandler:(appUrlHandler)handler;

@end
