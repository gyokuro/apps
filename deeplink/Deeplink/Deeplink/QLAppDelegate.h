//
//  QLAppDelegate.h
//  Deeplink
//
//  Created by DAVID on 5/7/14.
//  Copyright (c) 2014 QorioLabs. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol DeeplinkUrlDelegate <NSObject>
-(void)handleContent:(NSString*)key;
@end

@interface QLAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (weak, nonatomic) id<DeeplinkUrlDelegate> deeplinkDelegate;

@end
