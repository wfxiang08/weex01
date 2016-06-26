/**
 * Created by Weex.
 * Copyright (c) 2016, Alibaba, Inc. All rights reserved.
 *
 * This source code is licensed under the Apache Licence 2.0.
 * For the full copyright and license information,please view the LICENSE file in the root directory of this source tree.
 */

#import "WXSDKInstance.h"
#import "WXSDKInstance_private.h"
#import "WXSDKManager.h"
#import "WXAppMonitorProtocol.h"
#import "WXNetworkProtocol.h"
#import "WXModuleFactory.h"
#import "WXHandlerFactory.h"
#import "WXDebugTool.h"
#import "WXUtility.h"
#import "WXLog.h"
#import "WXView.h"

NSString *const bundleUrlOptionKey = @"bundleUrl";

NSTimeInterval JSLibInitTime = 0;

@implementation WXSDKInstance
{
    id<WXNetworkProtocol> _networkHandler;
    
    // 单例
    WXComponentManager *_componentManager;
}

- (void) dealloc
{
    [self removeObservers];
}

- (instancetype)init
{
    self = [super init];
    if(self){
        // instanceId如何控制? 递增， 是否会出现重复呢?
        // 可能暂时不会遇到这个问题
        // TODO:
        NSInteger instanceId = 0;
        @synchronized(self){
            static NSInteger __instance = 0;
            instanceId = __instance % (1024*1024);
            __instance++;
        }
        _instanceId = [NSString stringWithFormat:@"%ld", (long)instanceId];

        // 将当前对象保存到: WXSDKManager中
        [WXSDKManager storeInstance:self forID:_instanceId];
        _frame = CGRectMake(NAN, NAN, NAN, NAN);
        
        _bizType = @"";
        _pageName = @"";
        _screenRenderTime = 0;
        
        _frame = CGRectMake(NAN, NAN, NAN, NAN);
        _moduleInstances = [NSMutableDictionary new];
        _styleConfigs = [NSMutableDictionary new];
        _attrConfigs = [NSMutableDictionary new];
       
        [self addObservers];
    }
    return self;
}

#pragma mark Public Mehtods

- (void)renderWithURL:(NSURL *)url
{
    [self renderWithURL:url options:nil data:nil];
}

- (void)renderWithURL:(NSURL *)url options:(NSDictionary *)options data:(id)data
{
    WXLogInfo(@"Render URL: %@", url);
    if (!url) {
        WXLogError(@"Url must be passed if you use renderWithURL");
        return;
    }
    
    // 1. 如何render指定的URL呢?
    _scriptURL = url;
    
    // 2. 构建Options: bundleUrl
    NSMutableDictionary *newOptions = [options mutableCopy];
    newOptions[bundleUrlOptionKey] = url.absoluteString;
    
    // 3. PageName的构建
    if (!self.pageName || [self.pageName isEqualToString:@""]) {
        self.pageName = url.absoluteString ? : @"";
    }
    
    __weak typeof(self) weakSelf = self;
    if ([url isFileURL]) {
        // 本地文件
        // dispatch_get_global_queue 和 main_queue有关系吗?
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // 读取scripts的内容
            NSString *path = [url path];
            NSData *scriptData = [[NSFileManager defaultManager] contentsAtPath:path];
            NSString *script = [[NSString alloc] initWithData:scriptData encoding:NSUTF8StringEncoding];
            
            if (!script) {
                NSString *errorDesc = [NSString stringWithFormat:@"File read error at url: %@", url];
                WXLogError(@"%@", errorDesc);
                if (weakSelf.onFailed) {
                    weakSelf.onFailed([NSError errorWithDomain:WX_ERROR_DOMAIN code:0 userInfo:@{NSLocalizedDescriptionKey: errorDesc}]);
                }
                return;
            }
            
            // 调用: renderView
            [weakSelf renderView:script options:newOptions data:data];
        });
    } else {
        NSDate *networkStart = [NSDate date];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setValue:[WXUtility userAgent] forHTTPHeaderField:@"User-Agent"];
        
        id<WXNetworkProtocol> networkHandler = [self networkHandler];
        
        // 发送网络请求
        __block NSURLResponse *urlResponse;
        [networkHandler sendRequest:request
                   withSendingData:^(int64_t bytesSent, int64_t totalBytes) {}
                      withResponse:^(NSURLResponse *response) {
                          // 记录URL Response
                          urlResponse = response;
                      }
                   withReceiveData:^(NSData *data) {}
                   withCompeletion:^(NSData *totalData, NSError *error) {
            //TODO 304
            if (!error && [urlResponse isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)urlResponse).statusCode != 200) {
                error = [NSError errorWithDomain:WX_ERROR_DOMAIN
                                                     code:((NSHTTPURLResponse *)urlResponse).statusCode
                                                 userInfo:@{@"message":@"status code error."}];
            }
            
           if (error) {
               WXLogError(@"Connection to %@ occurs an error:%@", request.URL, error);
               if (weakSelf.onFailed) {
                   weakSelf.onFailed(error);
               }
               return ;
           }
            
            // UTF8格式的script
            NSString *script = [[NSString alloc] initWithData:totalData encoding:NSUTF8StringEncoding];
            weakSelf.networkTime = -[networkStart timeIntervalSinceNow];
                       
            // 正式Render代码内容
            [weakSelf renderView:script options:newOptions data:data];
        }];
    }
}

- (void)renderView:(NSString *)source options:(NSDictionary *)options data:(id)data
{
    WXLogVerbose(@"Render view: %@, data:%@", self, [WXUtility JSONString:data]);
    
    if (!self.instanceId) {
        WXLogError(@"Fail to find instance！");
        return;
    }
    
    _renderStartDate = [NSDate new];
    
    NSMutableDictionary *dictionary = [options mutableCopy];
    if ([WXLog logLevel] >= WXLogLevelVerbose) {
        dictionary[@"debug"] = @(YES);
    }
    
    if ([WXDebugTool getReplacedBundleJS]) {
        source = [WXDebugTool getReplacedBundleJS];
    }
    
    // XXX: 重建RootView
    //TODO WXRootView
    self.rootView = [[WXView alloc] initWithFrame:self.frame];
    if(self.onCreate) {
        self.onCreate(self.rootView);
    }
    
    // 这个createInstance和 self.rootView 有什么关系呢?
    [[WXSDKManager bridgeMgr] createInstance:self.instanceId template:source options:dictionary data:data];
}

- (void)setFrame:(CGRect)frame
{
    _frame = frame;
//    [self.componentManager changeRootFrame];
}

- (void)reloadData:(id)data
{
    [self refreshInstance:data];
}

- (void)refreshInstance:(id)data
{
    WXLogVerbose(@"refresh instance: %@, data:%@", self, [WXUtility JSONString:data]);
    
    if (!self.instanceId) {
        WXLogError(@"Fail to find instance！");
        return;
    }
    
    [[WXSDKManager bridgeMgr] refreshInstance:self.instanceId data:data];
}

- (void)destroyInstance
{
    if (!self.instanceId) {
        WXLogError(@"Fail to find instance！");
        return;
    }
    
    [[WXSDKManager bridgeMgr] destroyInstance:self.instanceId];
    
    __weak typeof(self) weakSelf = self;
    WXPerformBlockOnComponentThread(^{
        [weakSelf.componentManager unload];
        dispatch_async(dispatch_get_main_queue(), ^{
            [WXSDKManager removeInstanceforID:weakSelf.instanceId];
        });
    });
}

- (void)updateState:(WXState)state
{
    if (!self.instanceId) {
        WXLogError(@"Fail to find instance！");
        return;
    }
    
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    [data setObject:[NSNumber numberWithLong:state] forKey:@"state"];
    [[WXSDKManager bridgeMgr] updateState:self.instanceId data:data];
}

- (id)moduleForClass:(Class)moduleClass
{
    if (!moduleClass)
        return nil;
    
    id<WXModuleProtocol> moduleInstance = self.moduleInstances[NSStringFromClass(moduleClass)];
    if (!moduleInstance) {
        moduleInstance = [[moduleClass alloc] init];
        if ([moduleInstance respondsToSelector:@selector(setWeexInstance:)])
            [moduleInstance setWeexInstance:self];
        self.moduleInstances[NSStringFromClass(moduleClass)] = moduleInstance;
    }
    
    return moduleInstance;
}

- (WXComponent *)componentForRef:(NSString *)ref
{
    return [self.componentManager componentForRef:ref];
}

- (void)finishPerformance
{
    NSTimeInterval totalTime = 0;
    if (_renderStartDate) {
        totalTime = [[NSDate new] timeIntervalSinceDate:_renderStartDate];
    }
    else {
        NSAssert(NO, @"");
    }
    
    NSDictionary* dict = @{BIZTYPE:self.bizType,
                           PAGENAME:self.pageName,
                           WXSDKVERSION:WX_SDK_VERSION,
                           NETWORKTIME:@(_networkTime * 1000),
                           COMMUNICATETIME:[NSNumber numberWithDouble:_communicateTime * 1000],
                           JSLIBINITTIME:[NSNumber numberWithDouble:JSLibInitTime * 1000],
                           SCREENRENDERTIME:[NSNumber numberWithDouble:(_screenRenderTime > 0 ? _screenRenderTime : totalTime) * 1000],
                           TOTALTIME:[NSNumber numberWithDouble:totalTime * 1000]
                           };
    WXLogInfo(@"Performance: %@", dict);
    
    id<WXAppMonitorProtocol> appMonitor = [WXHandlerFactory handlerForProtocol:@protocol(WXAppMonitorProtocol)];
    if (appMonitor && [appMonitor respondsToSelector:@selector(commitAppMonitorArgs:)]){
        [appMonitor commitAppMonitorArgs:dict];
    }
}

#pragma mark Private Methods

- (void)addObservers
{
//    [self addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)removeObservers
{
//    [self removeObserver:self forKeyPath:@"state"];
}

- (WXComponentManager *)componentManager
{
    if (!_componentManager) {
        _componentManager = [[WXComponentManager alloc] initWithWeexInstance:self];
    }
    
    return _componentManager;
}

- (id<WXNetworkProtocol>)networkHandler
{
    if (!_networkHandler) {
        // 通过WXHandlerFactory实现代码的插件式管理
        _networkHandler = [WXHandlerFactory handlerForProtocol:@protocol(WXNetworkProtocol)];
    }
    
    return _networkHandler;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"state"]) {
        WXState state = [change[@"new"] longValue];
        [self updateState:state];
        
        if (state == WeexInstanceDestroy) {
            [self destroyInstance];
        }
    }
}

@end
