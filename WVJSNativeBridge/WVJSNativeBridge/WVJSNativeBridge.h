//
//  WVJSNativeBridge.h
//  WVJSNativeBridge
//
//  Created by hncoder on 2017/7/1.
//  Copyright © 2017年 hncoder. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^WVJSNativeCallback)(NSDictionary *respData);

@interface WVJSNativeHandler : NSObject

@property(nonatomic, copy)      NSString    * name;
@property(nonatomic, weak)      id          target;
@property(nonatomic, assign)    SEL         selector;

/**
 *  JS处理记录
 *
 *  @param name     对应的JS方法
 *  @param target   处理对象
 *  @param selector 处理方法
 */
+ (instancetype)jsHandlerWithName:(NSString *)name target:(id)target selector:(SEL)selector;

@end

@interface WVJSNativeBridge : NSObject<UIWebViewDelegate>
@property (nonatomic, weak) id<UIWebViewDelegate> delegate;
@property (nonatomic, strong, readonly) UIWebView *webView;

/**
 *  初始化JSBridge
 *
 *  @param name     brighe对象名称
 *  @param delegate webView委托方法
 *
 *  @return id
 */
- (id)initWithBridgeName:(NSString *)name delegate:(id<UIWebViewDelegate>)delegate;

/**
 *  注册一个js处理
 *
 *  @param name     js对应的方法名
 *  @param target   native处理对象
 *  @param selector native对应的处理方法
 *
 *  @return YES:注册成功，NO:注册失败（可能是target不存在selector方法）
 */
- (BOOL)registerHandler:(NSString*)name target:(id)target selector:(SEL)selector;

@end
