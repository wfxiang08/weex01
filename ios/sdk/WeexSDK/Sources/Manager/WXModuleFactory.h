/**
 * Created by Weex.
 * Copyright (c) 2016, Alibaba, Inc. All rights reserved.
 *
 * This source code is licensed under the Apache Licence 2.0.
 * For the full copyright and license information,please view the LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

//
// WXModuleFactory的作用:
// 1. 注册Module
//    ModuleName, ModuleClass -->
//                                WXModuleConfig: name, class, method list
// 2. 获取Module的Method List
// 3. 获取moudle, method的Selector
// 4. 获取module对应的class
//
@interface WXModuleFactory : NSObject

/**
 * @abstract Returns the class of specific module
 *
 * @param name The module name
 *
 **/
+ (Class)classWithModuleName:(NSString *)name;

/**
 * @abstract Returns the instance method implemented by the module 
 *
 * @param name The module name
 *
 * @param method The module method
 *
 **/
+ (SEL)methodWithModuleName:(NSString *)name withMethod:(NSString *)method;

/**
 * @abstract Registers a module for a given name and the implemented class
 *
 * @param module The module name to register
 *
 * @param clazz The module class to register
 *
 **/
+ (NSString *)registerModule:(NSString *)name withClass:(Class)clazz;

/**
 * @abstract Returns the export methods in the specific module
 *
 * @param name The module name
 **/
+ (NSMutableDictionary *)moduleMethodMapsWithName:(NSString *)name;
       
@end

