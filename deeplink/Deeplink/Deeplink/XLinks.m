//
//  XLinks.m
//  Deeplink
//
//  Created by DAVID on 5/11/14.
//  Copyright (c) 2014 QorioLabs. All rights reserved.
//

#import "XLinks.h"

#import <AdSupport/ASIdentifierManager.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>

#include <sys/types.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <net/if_dl.h>
#include <ifaddrs.h>

#if ! defined(IFT_ETHER)
#define IFT_ETHER 0x6/* Ethernet CSMACD */
#endif

@interface XLinks ()
@property (atomic) NSString *apiToken;
@property (atomic) NSString *urlScheme;
@property (atomic) NSString *shortCode;
@property (atomic) NSString *contextUuid;
@property (atomic) BOOL reportingInstallThroughSafari;
@property (atomic) id<UIApplicationDelegate> appDelegate;
@end

@implementation XLinks
{
    dispatch_queue_t backgroundQueue;
}

+ (XLinks*)sharedInstance {
    static XLinks *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
        _sharedInstance->backgroundQueue = dispatch_queue_create("_xlinks_", NULL);
    });
    return _sharedInstance;
}

- (void)initWithApplicationDelegate:(id<UIApplicationDelegate>)delegate appUrlScheme:(NSString *)appUrlScheme apiToken:(NSString*)apiToken
{
    _urlScheme = appUrlScheme;
    _apiToken = apiToken;
    _appDelegate = delegate;
    
    /*
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        // When swizzling a class method, use the following:
        // Class class = object_getClass((id)self);
        
        SEL originalSelector = @selector(application:openURL:sourceApplication:annotation:);
        SEL swizzledSelector = @selector(xlink__application:OpenURL:sourceApplication:annotation:);
        
        Method originalMethod = class_getInstanceMethod(object_getClass(_appDelegate), originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL didAddMethod = class_addMethod(class,
                        originalSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
     */
    
}

+ (NSDictionary *)readNetworkInterfaces {
    NSMutableDictionary * networkInterfaces = [NSMutableDictionary dictionary];
    struct ifaddrs * addrs;
    struct ifaddrs * cursor;
    
    if (getifaddrs(&addrs) == 0) {
        cursor = addrs;
        while (cursor != 0) {
            char * ifa_name = cursor->ifa_name;
            if (cursor->ifa_addr->sa_family == AF_LINK) {
                const struct sockaddr_dl * dl_addr = (const struct sockaddr_dl *)(cursor->ifa_addr);
                
                if (dl_addr->sdl_type == IFT_ETHER) {
                    NSData * macAddressData = [NSData dataWithBytes:LLADDR(dl_addr) length:dl_addr->sdl_alen];
                    NSString * networkInterfaceName = [[NSString alloc] initWithBytes:ifa_name length:strlen(ifa_name) encoding:NSASCIIStringEncoding];
                    [networkInterfaces setObject:macAddressData forKey:networkInterfaceName];
                }
            }
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
    return networkInterfaces;
}

- (NSString*)getCookieFile
{
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = dirPaths[0];
    return [NSString stringWithFormat:@"%@/cookie", docsDir];
}

- (NSString*)getAppUUID
{
    return [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
}

- (BOOL)clearAppInstall
{
    NSError *err;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return[fileManager removeItemAtPath:[self getCookieFile] error:&err];
}

- (BOOL)hasReportedInstall
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return[fileManager fileExistsAtPath:[self getCookieFile]];
}

- (void)reportInstall
{
    [self reportInstall:YES shortCode:_shortCode contextUUID:_contextUuid];
}

- (NSData*)buildPayload:(id)map
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:map
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (error == nil) {
        NSString *json = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
        return [json dataUsingEncoding:NSUTF8StringEncoding];
    }
    return [@"" dataUsingEncoding:NSUTF8StringEncoding];
}

#define KEY_SOURCE_APPLICATION @"sourceApplication"
#define KEY_UUID @"uuid"
#define KEY_SHORT_CODE @"shortCode"
#define KEY_DEEP_LINK @"deeplink"
#define KEY_FINGERPRINTED @"fingerprinted"

#define URL_QUERY_UUID @"__xrlc"
#define URL_QUERY_SCHEME @"__xrlp"
#define URL_QUERY_SHORT_CODE @"__xrls"

- (void)reportInstall:(BOOL)throughSafari shortCode:(NSString*)shortCode contextUUID:(NSString*)contextUuid
{
    _reportingInstallThroughSafari = throughSafari;
    
    dispatch_async(self->backgroundQueue, ^(void) {
        // Use the browser to make a call back, which will send any cookies and allow the server to
        // associate the user with a content.  The server will then send a redirect
        NSString *idfa = [self getAppUUID];
        
        if (throughSafari) {
            NSString *format = @"http://qor.io/i/%@/%@";
            NSURL *home = [NSURL URLWithString:[NSString stringWithFormat:format, _urlScheme, idfa]];
            
            NSLog(@"Report install via GET %@", home);
            
            [[UIApplication sharedApplication] openURL:home];
        } else {
            NSString *format = @"https://qor.io/api/v1/events/install/%@/%@";
            NSURL *home = [NSURL URLWithString:[NSString stringWithFormat:format, _urlScheme, idfa]];

            NSLog(@"Report install via POST %@", home);
            
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:home];
            request.HTTPMethod = @"POST";
            [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

            NSMutableDictionary *message = [@{} mutableCopy];
            if (shortCode != nil) {
                [message setObject:shortCode forKey:KEY_SHORT_CODE];
            }
            if (contextUuid != nil) {
                [message setObject:contextUuid forKey:KEY_UUID];
            }
            [message setObject:@"." forKey:KEY_SOURCE_APPLICATION];
            [message setObject:@"." forKey:KEY_DEEP_LINK];
            
            [request setHTTPBody:[self buildPayload:message]];
            [NSURLConnection sendAsynchronousRequest:request
                                               queue:[NSOperationQueue mainQueue]
                                   completionHandler:^(NSURLResponse *response,
                                                       NSData *data,
                                                       NSError *connectionError) {
                                       // Handle response
                                       NSLog(@"Response from server: %d", [(NSHTTPURLResponse*)response statusCode]);
                                   }];
        }
    });
}

- (NSDictionary*)saveInvocationContext:(NSString *)cookie sourceApplication:(NSString*)sourceApplication withShortCode:(NSString*)shortCode url:(NSURL*)url
{
    NSString *key = (sourceApplication != nil)? sourceApplication : @".";
    NSString *value = [NSString stringWithFormat:@"%@:%@:%@", (shortCode != nil)? shortCode : @"",(cookie != nil)? cookie : @"", [url absoluteString]];
    NSString *cookieFile = [self getCookieFile];
    NSMutableDictionary *map = [[NSMutableDictionary alloc]init];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:cookieFile]) {
        map = [map initWithContentsOfFile:[self getCookieFile]];
    }
    
    [map setObject:value forKey:key];
    [map writeToFile:cookieFile atomically:YES];
    return map;
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

- (BOOL)application:(UIApplication*)application OpenURL:(NSURL*)url sourceApplication:(NSString*)sourceApplication annotation:(id)annotation
{
    NSDictionary *params = [self parseQueryString:[url query]];
    
    // Look for special keys
    NSString *uuid = [params objectForKey:URL_QUERY_UUID];
    NSString *scheme = [params objectForKey:URL_QUERY_SCHEME];
    NSString *shortcode = [params objectForKey:URL_QUERY_SHORT_CODE];
    
    NSLog(@"appOpenWithURL: url=%@ application=%@ uuid=%@ scheme=%@ shortcode=%@ annotation=%@", url, sourceApplication, uuid, scheme, shortcode, annotation);
    
    if (_reportingInstallThroughSafari) {
        // Saves locally to be checked next time.
        [self saveInvocationContext:uuid sourceApplication:sourceApplication withShortCode:shortcode url:url];
    } else if (![self hasReportedInstall]) {
        [self reportInstall:NO shortCode:shortcode contextUUID:uuid];
    }
    
    // We store locally a list of context uuids
    NSDictionary *map;
    if (uuid != nil) {
        map = [self saveInvocationContext:uuid sourceApplication:sourceApplication withShortCode:shortcode url:url];
    }
    
    if (uuid != nil && scheme != nil && shortcode != nil) {
        
        // Notify the cloud that this app is still here.
        NSURL *ping = [NSURL URLWithString:[NSString stringWithFormat:@"https://qor.io/api/v1/events/openurl/%@/%@", _urlScheme, [self getAppUUID]]];
        NSLog(@"Sending app openurl to %@", ping);
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:ping];
        request.HTTPMethod = @"POST";
        [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        NSMutableDictionary *appOpen = [@{} mutableCopy];
        [appOpen setObject:sourceApplication forKey:KEY_SOURCE_APPLICATION];
        [appOpen setObject:shortcode forKey:KEY_SHORT_CODE];
        [appOpen setObject:uuid forKey:KEY_UUID];
        [appOpen setObject:[url absoluteString] forKey:KEY_DEEP_LINK];

        [request setHTTPBody:[self buildPayload:appOpen]];
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response,
                                                   NSData *data,
                                                   NSError *connectionError) {
                                   NSLog(@"Response from server: %d", [(NSHTTPURLResponse*)response statusCode]);
                               }];
        // Save a local copy -- not really necessary
        [self saveInvocationContext:uuid sourceApplication:sourceApplication withShortCode:shortcode url:url];
    }
    return YES; //[self xlink__application:application OpenURL:url sourceApplication:sourceApplication annotation:annotation];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (![self hasReportedInstall]) {
        // We first try a POST to the api to TRY TO MATCH by fingerprint.  If that isn't successful, then
        // open safari to report the install
        // Notify the cloud that this app is still here.
        NSURL *ping = [NSURL URLWithString:[NSString stringWithFormat:@"https://qor.io/api/v1/tryfp/%@/%@", _urlScheme, [self getAppUUID]]];
        NSLog(@"Attempting to match install by fingerprint %@", ping);
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:ping];
        request.HTTPMethod = @"POST";
        [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response,
                                                   NSData *data,
                                                   NSError *connectionError) {
                                   // Handle response
                                   NSLog(@"Response from server: %d", [(NSHTTPURLResponse*)response statusCode]);
                                   
                                   // Check for response code. If it's not 200, then try to report via safari.
                                   if ([response class] == [NSHTTPURLResponse class]) {
                                       NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
                                       if (httpResponse.statusCode == 200) {
                                           
                                           // parse the response and get the deeplink
                                           NSError *error;
                                           NSDictionary *message = [NSJSONSerialization JSONObjectWithData: data options:NSJSONReadingMutableContainers error: &error];

                                           NSString *deeplink = [message objectForKey:KEY_DEEP_LINK];
                                           NSString *sourceApplication = [message objectForKey:KEY_SOURCE_APPLICATION];
                                           NSString *uuid = [message objectForKey:KEY_UUID];
                                           NSString *shortCode = [message objectForKey:KEY_SHORT_CODE];
                                           
                                           
                                           NSLog(@"Got deeplink %@ and source appliction %@", deeplink, sourceApplication);
                                           
                                           if (deeplink) {
                                               
                                               NSURL *deeplinkUrl = [NSURL URLWithString:deeplink];
                                               
                                               // Save the state as reported so we won't report another install.
                                               [self saveInvocationContext:uuid sourceApplication:sourceApplication withShortCode:shortCode url:deeplinkUrl];
                                               
                                               NSLog(@"Reopen application with deeplink %@ via delegate method", deeplinkUrl);
                                               
                                               [_appDelegate application:[UIApplication sharedApplication] openURL:deeplinkUrl sourceApplication:sourceApplication annotation:nil];
                                           }
                                           
                                       } else {
                                           NSLog(@"Reporting install VIA SAFARI");
                                           [self reportInstall]; // Use safari
                                       }
                                   }
                               }];
    }
}



@end
