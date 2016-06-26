/**
 * Created by Weex.
 * Copyright (c) 2016, Alibaba, Inc. All rights reserved.
 *
 * This source code is licensed under the Apache Licence 2.0.
 * For the full copyright and license information,please view the LICENSE file in the root directory of this source tree.
 */

#import "WXSDKManager.h"
#import "WXThreadSafeMutableDictionary.h"

//
// 全局唯一
//
@interface WXSDKManager ()

@property (nonatomic, strong) WXBridgeManager *bridgeMgr;

@property (nonatomic, strong) WXModuleManager *moduleMgr;

@property (nonatomic, strong) WXThreadSafeMutableDictionary *instanceDict;

@end

@implementation WXSDKManager

// 单例模式:
static WXSDKManager *_sharedInstance = nil;
+ (WXSDKManager *)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!_sharedInstance) {
            _sharedInstance = [[self alloc] init];
            _sharedInstance.instanceDict = [[WXThreadSafeMutableDictionary alloc] init];
        }
    });
    return _sharedInstance;
}

// 返回: Bridge
+ (WXBridgeManager *)bridgeMgr
{
    WXBridgeManager *bridgeMgr = [self sharedInstance].bridgeMgr;
    if (!bridgeMgr) {
        bridgeMgr = [[WXBridgeManager alloc] init];
        [self sharedInstance].bridgeMgr = bridgeMgr;
    }
    return bridgeMgr;
}

// 返回ModuleMrg
+ (WXModuleManager *)moduleMgr
{
    WXModuleManager *moduleMgr = [self sharedInstance].moduleMgr;
    if (!moduleMgr) {
        moduleMgr = [[WXModuleManager alloc] init];
        [self sharedInstance].moduleMgr = moduleMgr;
    }
    return moduleMgr;
}

+ (id)instanceForID:(NSString *)identifier
{
    return [[self sharedInstance].instanceDict objectForKey:identifier];
}

+ (void)storeInstance:(WXSDKInstance *)instance forID:(NSString *)identifier
{
    // 在: WXSDKManager中存放: WXSDKInstance
    [[self sharedInstance].instanceDict setObject:instance forKey:identifier];
}

+ (void)removeInstanceforID:(NSString *)identifier
{
    [[self sharedInstance].instanceDict removeObjectForKey:identifier];
}

@end
