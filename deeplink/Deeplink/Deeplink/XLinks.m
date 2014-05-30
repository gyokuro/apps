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
#import <objc/message.h>

#include <sys/types.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <net/if_dl.h>
#include <ifaddrs.h>

#define KEY_SOURCE_APPLICATION @"sourceApplication"
#define KEY_UUID @"uuid"
#define KEY_SHORT_CODE @"shortCode"
#define KEY_DEEP_LINK @"deeplink"
#define KEY_FINGERPRINTED @"fingerprinted"

#define URL_QUERY_UUID @"__xrlc"
#define URL_QUERY_SCHEME @"__xrlp"
#define URL_QUERY_SHORT_CODE @"__xrls"


@interface NSDictionary(JSON)
- (NSData*)toJSON;
@end

@implementation NSDictionary(JSON)
- (NSData*)toJSON
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:NSJSONWritingPrettyPrinted error:&error];
    if (error == nil) {
        NSString *json = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
        return [json dataUsingEncoding:NSUTF8StringEncoding];
    }
    return [@"" dataUsingEncoding:NSUTF8StringEncoding];
}
@end

@interface XLinks ()
@property (atomic, readwrite) NSString *urlScheme;
@property (atomic, readwrite) BOOL reportingInstallThroughSafari;

@property (atomic) NSString *apiToken;
@property (atomic) NSString *shortCode;
@property (atomic) NSString *contextUuid;
@property (atomic) id<UIApplicationDelegate> appDelegate;

+(NSDictionary *)parseQueryString:(NSString *)query;
- (NSDictionary*)saveInvocationContext:(NSString *)cookie sourceApplication:(NSString*)sourceApplication withShortCode:(NSString*)shortCode url:(NSURL*)url;
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

+ (void)initWithApplicationDelegate:(id<UIApplicationDelegate>)delegate appUrlScheme:(NSString *)appUrlScheme apiToken:(NSString*)apiToken
{
    XLinks *inst = [XLinks sharedInstance];
    
    inst.urlScheme = appUrlScheme;
    inst.apiToken = apiToken;
    inst.appDelegate = delegate;
}

+ (NSString*)getCookieFile
{
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = dirPaths[0];
    return [NSString stringWithFormat:@"%@/cookie", docsDir];
}

+ (NSString*)getAppUUID
{
    return [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
}

+ (BOOL)clearAppInstall
{
    return [[XLinks sharedInstance]clearAppInstall];
}

+ (void)reportInstall
{
    if ([[XLinks sharedInstance] hasReportedInstall]) {
        [[XLinks sharedInstance]reportInstall];
        
    }
}

+ (BOOL)application:(UIApplication*)application openURL:(NSURL*)url sourceApplication:(NSString*)sourceApplication annotation:(id)annotation
{
    return [[XLinks sharedInstance]handleApplication:application openURL:url sourceApplication:sourceApplication annotation:annotation];
}

+ (void)applicationDidBecomeActive:(UIApplication *)application
{
    [[XLinks sharedInstance]handleApplicationDidBecomeActive:application];
}


- (dispatch_queue_t) queue
{
    return backgroundQueue;
}

- (BOOL)clearAppInstall
{
    NSError *err;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return[fileManager removeItemAtPath:[XLinks getCookieFile] error:&err];
}

- (BOOL)hasReportedInstall
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return[fileManager fileExistsAtPath:[XLinks getCookieFile]];
}

- (void)reportInstall
{
    [self reportInstall:YES shortCode:_shortCode contextUUID:_contextUuid url:nil sourceApplication:nil];
}

- (void)reportInstall:(BOOL)throughSafari shortCode:(NSString*)shortCode contextUUID:(NSString*)contextUuid url:(NSURL*)url sourceApplication:(NSString*)sourceApplication
{
    _reportingInstallThroughSafari = throughSafari;
    
    dispatch_async([[XLinks sharedInstance] queue], ^(void) {
        // Use the browser to make a call back, which will send any cookies and allow the server to
        // associate the user with a content.  The server will then send a redirect
        NSString *idfa = [XLinks getAppUUID];
        
        if (throughSafari) {
            NSString *format = @"http://qor.io/i/%@/%@";
            NSURL *home = [NSURL URLWithString:[NSString stringWithFormat:format, _urlScheme, idfa]];
            
            NSLog(@"XLinks - Report install via GET %@", home);
            
            [[UIApplication sharedApplication] openURL:home];
            
            // Saves locally to be checked next time.
            [[XLinks sharedInstance] saveInvocationContext:contextUuid sourceApplication:sourceApplication withShortCode:shortCode url:url];

        } else {
            NSString *format = @"https://qor.io/api/v1/events/install/%@/%@";
            NSURL *home = [NSURL URLWithString:[NSString stringWithFormat:format, _urlScheme, idfa]];

            NSLog(@"XLinks - Report install via POST %@", home);
            
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:home];
            request.HTTPMethod = @"POST";
            [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

            NSMutableDictionary *message = [@{} mutableCopy];
            if (shortCode) [message setObject:shortCode forKey:KEY_SHORT_CODE];
            if (contextUuid) [message setObject:contextUuid forKey:KEY_UUID];
            [message setObject:@"." forKey:KEY_SOURCE_APPLICATION];
            [message setObject:@"." forKey:KEY_DEEP_LINK];
            
            [request setHTTPBody:[message toJSON]];
            [NSURLConnection sendAsynchronousRequest:request
                                               queue:[NSOperationQueue mainQueue]
                                   completionHandler:^(NSURLResponse *response,
                                                       NSData *data,
                                                       NSError *connectionError) {
                                       // Handle response
                                       NSLog(@"XLinks - install - Response from server: %d", [(NSHTTPURLResponse*)response statusCode]);
                                       if ([(NSHTTPURLResponse*)response statusCode] == 200) {

                                           [[XLinks sharedInstance] saveInvocationContext:(contextUuid)?contextUuid:idfa sourceApplication:@"." withShortCode:shortCode?shortCode:@"." url:url];
                                       }
                                   }];
        }
    });
}

- (NSDictionary*)saveInvocationContext:(NSString *)cookie sourceApplication:(NSString*)sourceApplication withShortCode:(NSString*)shortCode url:(NSURL*)url
{
    NSString *key = (sourceApplication)? sourceApplication : @".";
    NSString *value = [NSString stringWithFormat:@"%@:%@:%@", shortCode?shortCode:@"",cookie?cookie:@"", [url absoluteString]];
    NSString *cookieFile = [XLinks getCookieFile];
    NSMutableDictionary *map = [[NSMutableDictionary alloc]init];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:cookieFile]) {
        map = [map initWithContentsOfFile:[XLinks getCookieFile]];
    }
    
    [map setObject:value forKey:key];
    [map writeToFile:cookieFile atomically:YES];
    NSLog(@"XLink - Saved cookie file.");
    return map;
}

+ (NSDictionary *)parseQueryString:(NSString *)query
{
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


- (BOOL)callAppDelegateOpenUrl:(NSURL*)url annotation:(id)annotation sourceApplication:(NSString*)sourceApplication
{
    return [_appDelegate application:[UIApplication sharedApplication] openURL:url sourceApplication:sourceApplication annotation:annotation];
}

- (BOOL)handleApplication:(UIApplication*)application openURL:(NSURL*)url sourceApplication:(NSString*)sourceApplication annotation:(id)annotation
{
    NSDictionary *params = [XLinks parseQueryString:[url query]];
    
    // Look for special keys
    NSString *uuid = [params objectForKey:URL_QUERY_UUID];
    NSString *scheme = [params objectForKey:URL_QUERY_SCHEME];
    NSString *shortcode = [params objectForKey:URL_QUERY_SHORT_CODE];
    
    NSLog(@"XLinks - appOpenWithURL: url=%@ application=%@ uuid=%@ scheme=%@ shortcode=%@ annotation=%@", url, sourceApplication, uuid, scheme, shortcode, annotation);
    
    if (![[XLinks sharedInstance] hasReportedInstall]) {
        [[XLinks sharedInstance] reportInstall:NO shortCode:shortcode contextUUID:uuid url:url sourceApplication:sourceApplication];
    }
    
    // Important to check -- since other apps could call this without passing in these params
    if (uuid != nil && scheme != nil && shortcode != nil) {
        // Notify the cloud that this app is still here.
        NSURL *ping = [NSURL URLWithString:[NSString stringWithFormat:@"https://qor.io/api/v1/events/openurl/%@/%@", scheme, [XLinks getAppUUID]]];
        NSLog(@"XLinks - Sending app openurl to %@", ping);
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:ping];
        request.HTTPMethod = @"POST";
        [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        NSMutableDictionary *appOpen = [@{} mutableCopy];
        [appOpen setObject:sourceApplication forKey:KEY_SOURCE_APPLICATION];
        [appOpen setObject:shortcode forKey:KEY_SHORT_CODE];
        [appOpen setObject:uuid forKey:KEY_UUID];
        [appOpen setObject:[url absoluteString] forKey:KEY_DEEP_LINK];

        [request setHTTPBody:[appOpen toJSON]];
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response,
                                                   NSData *data,
                                                   NSError *connectionError) {
                                   NSLog(@"XLinks - openurl - Response from server: %d", [(NSHTTPURLResponse*)response statusCode]);
                                   // TODO - do we want to retry this if failed?
                               }];
    }
    return  YES;
}

- (void)handleApplicationDidBecomeActive:(UIApplication *)application
{
    if ([[XLinks sharedInstance] hasReportedInstall]) {
        NSLog(@"XLinks - Reported install already. Skipping.");
    } else {
        // We first try a POST to the api to TRY TO MATCH by fingerprint.  If that isn't successful, then
        // open safari to report the install
        // Notify the cloud that this app is still here.
        NSURL *ping = [NSURL URLWithString:[NSString stringWithFormat:@"https://qor.io/api/v1/tryfp/%@/%@", _urlScheme, [XLinks getAppUUID]]];
        NSLog(@"XLinks - Attempting to match install by fingerprint %@", ping);
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:ping];
        request.HTTPMethod = @"POST";
        [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response,
                                                   NSData *data,
                                                   NSError *connectionError) {
                                   // Handle response
                                   NSLog(@"XLinks - tryfp - Response from server: %d", [(NSHTTPURLResponse*)response statusCode]);
                                   
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
                                           
                                           
                                           NSLog(@"XLinks - Got deeplink %@ and source appliction %@", deeplink, sourceApplication);
                                           
                                           if (deeplink) {
                                               
                                               NSURL *deeplinkUrl = [NSURL URLWithString:deeplink];
                                               
                                               // Save the state as reported so we won't report another install.
                                               [[XLinks sharedInstance] saveInvocationContext:uuid sourceApplication:sourceApplication withShortCode:shortCode url:deeplinkUrl];
                                               
                                               NSLog(@"XLinks - Reopen application with deeplink %@ via delegate method", deeplinkUrl);
                                               
                                               [[XLinks sharedInstance] callAppDelegateOpenUrl:deeplinkUrl annotation:nil sourceApplication:sourceApplication];
                                           }
                                           
                                       } else {
                                           NSLog(@"XLinks - Reporting install VIA SAFARI");
                                           [self reportInstall]; // Use safari
                                       }
                                   }
                               }];
    }
}

#if ! defined(IFT_ETHER)
#define IFT_ETHER 0x6/* Ethernet CSMACD */
#endif

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

@end


// Wrapper for swizzling

static XRL *singleton;

@interface  XRL()
+ (void) swizzleClass:(Class)originalClass originalSelector:(SEL)originalSelector swizzledClass:(Class)swizzledClass swizzledSelector:(SEL)swizzledSelector;
@end

@interface XRL()
@property(atomic) id<UIApplicationDelegate> delegate;
- (BOOL)xrl__application:(UIApplication*)application openURL:(NSURL*)url sourceApplication:(NSString*)sourceApplication annotation:(id)annotation;
- (void)xrl__applicationDidBecomeActive:(UIApplication *)application;
@end


@implementation XRL

+ (void) swizzleClass:(Class)originalClass originalSelector:(SEL)originalSelector swizzledClass:(Class)swizzledClass swizzledSelector:(SEL)swizzledSelector
{
    // The methods can be optional... in which case we will just add the implementation
    Method originalMethod = class_getInstanceMethod(originalClass, originalSelector);
    assert(originalMethod);
    // Dynamically attach the xrl__ methods to the delegate instance.  Note this at runtime is similar to adding the methods
    // statically via category methods.
    Method swizzledMethod = class_getInstanceMethod(swizzledClass, swizzledSelector);
    BOOL didAddMethod = class_addMethod(originalClass, swizzledSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    // Once we added the methods, do the swap.
    if (didAddMethod) {
        method_exchangeImplementations(class_getInstanceMethod(originalClass, originalSelector), class_getInstanceMethod(originalClass, swizzledSelector));
    }
}

+ (void)initWithApplicationDelegate:(id<UIApplicationDelegate>)delegate appUrlScheme:(NSString *)appUrlScheme apiToken:(NSString*)apiToken
{
    // swizzle
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        singleton = [[XRL alloc] init];
        singleton.delegate = delegate;
        
        [XLinks initWithApplicationDelegate:delegate appUrlScheme:appUrlScheme apiToken:apiToken];
        
        // Check to see if delegate implements the protocol methods we care about.
        bool hasBecomeActive = class_getInstanceMethod(object_getClass(delegate), @selector(applicationDidBecomeActive:)) != NULL;
        bool hasApplicationOpenUrl = class_getInstanceMethod(object_getClass(delegate), @selector(application:openURL:sourceApplication:annotation:)) != NULL;

        // This is important -- force the app developers to add the implementation.
        NSLog(@"Asserting that UIApplicationDelegate:applicationDidBecomeActive and application:openURL:sourceApplication:annotation are implemented.");
        assert(hasBecomeActive && hasApplicationOpenUrl);
        
        [XRL swizzleClass:object_getClass(delegate) originalSelector:@selector(applicationDidBecomeActive:) swizzledClass:object_getClass(singleton) swizzledSelector:@selector(xrl__applicationDidBecomeActive:)];
        [XRL swizzleClass:object_getClass(delegate) originalSelector:@selector(application:openURL:sourceApplication:annotation:) swizzledClass:object_getClass(singleton) swizzledSelector:@selector(xrl__application:openURL:sourceApplication:annotation:)];
    });
}

- (BOOL)xrl__application:(UIApplication*)application openURL:(NSURL*)url sourceApplication:(NSString*)sourceApplication annotation:(id)annotation
{
    [XLinks application:application openURL:url sourceApplication:sourceApplication annotation:annotation];
    return [self xrl__application:application openURL:url sourceApplication:sourceApplication annotation:annotation];
}

- (void)xrl__applicationDidBecomeActive:(UIApplication *)application
{
    [XLinks applicationDidBecomeActive:application];
    [self xrl__applicationDidBecomeActive:application];
}
@end



