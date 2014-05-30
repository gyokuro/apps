//
//  XRL.h
//  Deeplink
//
//  Created by DAVID on 5/29/14.
//  Copyright (c) 2014 QorioLabs. All rights reserved.
//

#ifndef Deeplink_XRL_h
#define Deeplink_XRL_h



@interface XRL : NSObject

+ (void)initWithApplicationDelegate:(id<UIApplicationDelegate>)delegate appUrlScheme:(NSString *)appUrlScheme apiToken:(NSString*)apiToken;

@end

#endif
