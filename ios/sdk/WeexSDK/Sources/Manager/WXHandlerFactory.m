/**
 * Created by Weex.
 * Copyright (c) 2016, Alibaba, Inc. All rights reserved.
 *
 * This source code is licensed under the Apache Licence 2.0.
 * For the full copyright and license information,please view the LICENSE file in the root directory of this source tree.
 */

#import "WXHandlerFactory.h"
#import "WXThreadSafeMutableDictionary.h"
#import "WXNetworkDefaultImpl.h"
#import "WXNavigationDefaultImpl.h"
#import "WXAssert.h"

@interface WXHandlerFactory ()

@property (nonatomic, strong) WXThreadSafeMutableDictionary *handlers;

@end

@implementation WXHandlerFactory

+ (instancetype)sharedInstance {
    static WXHandlerFactory* _sharedInstance = nil;
    
    // 初始化: _sharedInstance
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[self alloc] init];
        _sharedInstance.handlers = [[WXThreadSafeMutableDictionary alloc] init];
    });
    return _sharedInstance;
}

+ (void)registerHandler:(id)handler withProtocol:(Protocol *)protocol
{
    WXAssert(handler && protocol, @"Handler or protocol for registering can not be nil.");
    WXAssertProtocol(handler, protocol);
    
    // protocol如何作为key呢?
    // NSStringFromProtocol: 估计是签名变成NSString
    [[WXHandlerFactory sharedInstance].handlers setObject:handler forKey:NSStringFromProtocol(protocol)];
}

+ (id)handlerForProtocol:(Protocol *)protocol
{
    WXAssert(protocol, @"Can not find handler for a nil protocol");
    // 获取Handler
    id handler = [[WXHandlerFactory sharedInstance].handlers objectForKey:NSStringFromProtocol(protocol)];
    return handler;
}

@end
