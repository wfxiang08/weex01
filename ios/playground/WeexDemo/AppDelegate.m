/**
 * Created by Weex.
 * Copyright (c) 2016, Alibaba, Inc. All rights reserved.
 *
 * This source code is licensed under the Apache Licence 2.0.
 * For the full copyright and license information,please view the LICENSE file in the root directory of this source tree.
 */

#import "AppDelegate.h"
#import "WXDemoViewController.h"
#import "UIViewController+WXDemoNaviBar.h"
#import "WXStreamModule.h"
#import "WXEventModule.h"
#import "WXNavigationDefaultImpl.h"
#import "WXImgLoaderDefaultImpl.h"
#import "DemoDefine.h"
#import "WXScannerVC.h"
#import <WeexSDK/WXSDKEngine.h>
#import <WeexSDK/WXLog.h>
#import <WeexSDK/WXDebugTool.h>
#import <WeexSDK/WXAppConfiguration.h>
#import <AVFoundation/AVFoundation.h>
#import <ATSDK/ATManager.h>

@interface AppDelegate ()
@end

@implementation AppDelegate

#pragma mark
#pragma mark application

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // 1. 创建Window
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    
    // 2. 初始化: Weex
    [self initWeexSDK];
    
    // 3. 创建: rootViewController, 添加第一个Controller
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[self demoController]];
    [self.window makeKeyAndVisible];
    
    // Override point for customization after application launch.
    [self startSplashScreen];
    
    return YES;
}

// 这是什么东西呢?
-(void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler
{
    // ShortcutItem如何配置呢？
    if ([shortcutItem.type isEqualToString:QRSCAN]) {
        WXScannerVC * scanViewController = [[WXScannerVC alloc] init];
        [(UINavigationController*)self.window.rootViewController pushViewController:scanViewController animated:YES];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    
#ifdef UITEST
#if !TARGET_IPHONE_SIMULATOR
    // 后台情况下该做什么事情呢?
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    setenv("GCOV_PREFIX", [documentsDirectory cStringUsingEncoding:NSUTF8StringEncoding], 1);
    setenv("GCOV_PREFIX_STRIP", "6", 1);
#endif
    extern void __gcov_flush(void);
    __gcov_flush();
#endif
}

#pragma mark weex
- (void)initWeexSDK
{
    // 1. 设置WeexApp的 Config
    [WXAppConfiguration setAppGroup:@"AliApp"];
    [WXAppConfiguration setAppName:@"WeexDemo"];
    [WXAppConfiguration setAppVersion:@"1.8.3"];
    [WXAppConfiguration setExternalUserAgent:@"ExternalUA"];
    
    // 2. 
    [WXSDKEngine initSDKEnviroment];
    
    // 3. 注册Handler
    [WXSDKEngine registerHandler:[WXImgLoaderDefaultImpl new] withProtocol:@protocol(WXImgLoaderProtocol)];
    [WXSDKEngine registerHandler:[WXEventModule new] withProtocol:@protocol(WXEventModuleProtocol)];
    
    [WXSDKEngine registerComponent:@"select" withClass:NSClassFromString(@"WXSelectComponent")];
    [WXSDKEngine registerModule:@"event" withClass:[WXEventModule class]];
    
    // 4. 添加Plugin
    [self atAddPlugin];
    
    // 5. Debug状态的设置
#ifdef DEBUG
    [WXDebugTool setDebug:YES];
    [WXLog setLogLevel:WXLogLevelInfo];
#else
    [WXDebugTool setDebug:NO];
#endif
 
#ifndef UITEST
    //
    [[ATManager shareInstance] show];
#else
    [WXDebugTool setDebug:NO];
    [WXLog setLogLevel:WXLogLevelError];
#endif
    
}

-(UIViewController *)demoController
{
    
    UIViewController *demo = [[WXDemoViewController alloc] init];
    
    // 1. 设置: WXDemoViewController的url
#if DEBUG
    //If you are debugging in device , please change the host to current IP of your computer.
    ((WXDemoViewController *)demo).url = [NSURL URLWithString:HOME_URL];
#else
    ((WXDemoViewController *)demo).url = [NSURL URLWithString:BUNDLE_URL];
#endif
    
#ifdef UITEST
    ((WXDemoViewController *)demo).url = [NSURL URLWithString:UITEST_HOME_URL];
#endif
    
    return demo;
}

#pragma mark 
#pragma mark animation when startup

- (void)startSplashScreen
{
    // 如何闪屏呢?
    UIView* splashView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    splashView.backgroundColor = WEEX_COLOR;
    
    // UIImageRenderingModeAlwaysTemplate: 忽略图片本身的颜色，全部以tintColor为准
    UIImageView *iconImageView = [UIImageView new];
    UIImage *icon = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"weex-icon" ofType:@"png"]];
    if ([icon respondsToSelector:@selector(imageWithRenderingMode:)]) {
        iconImageView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        iconImageView.tintColor = [UIColor whiteColor];
    } else {
        iconImageView.image = icon;
    }
    
    // 设置: iconImageView的大小，位置
    iconImageView.frame = CGRectMake(0, 0, 320, 320);
    iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    iconImageView.center = splashView.center;
    [splashView addSubview:iconImageView];
    
    // 添加到window上
    [self.window addSubview:splashView];
    
    float animationDuration = 1.4;
    CGFloat shrinkDuration = animationDuration * 0.3;
    CGFloat growDuration = animationDuration * 0.7;
    
    // 7.0以上的系统怎么着?
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        [UIView animateWithDuration:shrinkDuration delay:1.0 usingSpringWithDamping:0.7f initialSpringVelocity:10 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            // 首先缩小
            CGAffineTransform scaleTransform = CGAffineTransformMakeScale(0.75, 0.75);
            iconImageView.transform = scaleTransform;
        } completion:^(BOOL finished) {
            // 然后放大
            [UIView animateWithDuration:growDuration animations:^{
                CGAffineTransform scaleTransform = CGAffineTransformMakeScale(20, 20);
                iconImageView.transform = scaleTransform;
                splashView.alpha = 0;
            } completion:^(BOOL finished) {
                // 关闭
                [splashView removeFromSuperview];
            }];
        }];
    } else {
        [UIView animateWithDuration:shrinkDuration delay:1.0 options:0 animations:^{
            CGAffineTransform scaleTransform = CGAffineTransformMakeScale(0.75, 0.75);
            iconImageView.transform = scaleTransform;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:growDuration animations:^{
                CGAffineTransform scaleTransform = CGAffineTransformMakeScale(20, 20);
                iconImageView.transform = scaleTransform;
                splashView.alpha = 0;
            } completion:^(BOOL finished) {
                [splashView removeFromSuperview];
            }];
        }];
    }
}

#pragma mark

- (void)atAddPlugin {
    
    [[ATManager shareInstance] addPluginWithId:@"weex" andName:@"weex" andIconName:@"weex" andEntry:@"" andArgs:@[@""]];
    [[ATManager shareInstance] addSubPluginWithParentId:@"weex" andSubId:@"logger" andName:@"logger" andIconName:@"log" andEntry:@"WXATLoggerPlugin" andArgs:@[@""]];
//    [[ATManager shareInstance] addSubPluginWithParentId:@"weex" andSubId:@"viewHierarchy" andName:@"hierarchy" andIconName:@"log" andEntry:@"WXATViewHierarchyPlugin" andArgs:@[@""]];
    [[ATManager shareInstance] addSubPluginWithParentId:@"weex" andSubId:@"test2" andName:@"test" andIconName:@"at_arr_refresh" andEntry:@"" andArgs:@[]];
    [[ATManager shareInstance] addSubPluginWithParentId:@"weex" andSubId:@"test3" andName:@"test" andIconName:@"at_arr_refresh" andEntry:@"" andArgs:@[]];
}

@end
