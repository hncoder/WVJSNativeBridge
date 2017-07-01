//
//  WVJSNativeBridge.m
//  WVJSNativeBridge
//
//  Created by hncoder on 2017/7/1.
//  Copyright © 2017年 hncoder. All rights reserved.
//

#import "WVJSNativeBridge.h"
#import <JavaScriptCore/JavaScriptCore.h>

@implementation WVJSNativeHandler

+ (instancetype)jsHandlerWithName:(NSString *)name target:(id)target selector:(SEL)selector
{
    if(name.length == 0 || target == nil || selector == nil)
    {
        return nil;
    }
    
    if(![target respondsToSelector:selector])
    {
        return nil;
    }
    
    WVJSNativeHandler *handler = [[WVJSNativeHandler alloc] init];
    handler.name = name;
    handler.target = target;
    handler.selector = selector;
    
    return handler;
    
}

@end

@protocol WVJSNativeExport <JSExport>
JSExportAs
(call,
 - (void)jsToCall:(id)data
 );
@end

@interface WVJSNativeBridge()<WVJSNativeExport>

@property (nonatomic, copy) NSString *jsBridgeName;
@property (nonatomic, strong, readwrite) UIWebView *webView;
@property (nonatomic, weak) JSContext *context;
@property (nonatomic, strong) NSMutableDictionary *jsHanlders;
@property (nonatomic, strong) NSString *jsBridgeEvent;

@end

@implementation WVJSNativeBridge

- (id)initWithBridgeName:(NSString *)name delegate:(id<UIWebViewDelegate>)delegate {
    self = [super init];
    if (self) {
        self.webView = [[UIWebView alloc] initWithFrame:CGRectZero];
        self.webView.delegate = self;
        self.delegate = delegate;
        
        self.jsBridgeName = name;
        if (self.jsBridgeName.length == 0) {
            self.jsBridgeName = @"native";
        }
        
        self.jsHanlders = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (BOOL)registerHandler:(NSString*)name target:(id)target selector:(SEL)selector {
    BOOL registered = NO;
    WVJSNativeHandler *jsHandler =  [WVJSNativeHandler jsHandlerWithName:name target:target selector:selector];
    if (jsHandler) {
        [_jsHanlders setObject:jsHandler forKey:jsHandler.name];
        registered = YES;
    }
    
    return registered;
}

- (void)callHandler:(WVJSNativeHandler*)handler data:(id)data {
    id target =  handler.target;
    if (target && [data isKindOfClass:[NSDictionary class]]) {
        SEL selector = handler.selector;
        
        NSMethodSignature * sig = [[target class]
                                   instanceMethodSignatureForSelector:selector];
        NSInvocation * invocation = [NSInvocation invocationWithMethodSignature:sig];
        [invocation setTarget: target];
        [invocation setSelector: selector];
        
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *param = [data objectForKey:@"param"];
            [invocation setArgument: &param atIndex: 2];
            [invocation retainArguments];
        }
        
        NSString *cb = [data objectForKey:@"callback"];
        if (cb.length > 0) {
            __block typeof(self) weakSelf = self;
            WVJSNativeCallback callback = ^(NSDictionary *data){
                if ([NSThread isMainThread]) {
                    [weakSelf.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@')",cb,[self messageJSON:data]]];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@('%@')",cb,[self messageJSON:data]]];
                    });
                }
            };
            [invocation setArgument:&callback atIndex:3];
            [invocation retainArguments];
        }

        [invocation invoke];
    }
}

- (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString {
    
    if (jsonString == nil) {
        return nil;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    return [NSJSONSerialization JSONObjectWithData:jsonData
                         
                                                        options:NSJSONReadingMutableContainers
                         
                                                          error:nil];
}

- (NSString*)messageJSON:(NSDictionary *)dic {
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    NSString *messageJSON = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\f" withString:@"\\f"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2028" withString:@"\\u2028"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2029" withString:@"\\u2029"];
    
    return messageJSON;
}

- (void)jsToCall:(id)data {
    if ([data isKindOfClass:[NSString class]]) {
        data = [self dictionaryWithJsonString:data];
    }
    
    if ([data isKindOfClass:[NSDictionary class]]) {
        NSString *method = [data objectForKey:@"method"];
        if (method.length > 0) {
            WVJSNativeHandler *hander = [_jsHanlders objectForKey:method];
            if (hander != nil)
            {
                [self callHandler:hander data:data];
            }
        }
    }
}

#define JSBRIDGEEVENT @"(function(){if(window.$$EventDispatched == undefined && window.$$ != undefined){var readyEvent = document.createEvent('Events');readyEvent.initEvent('$$Ready');readyEvent.bridge = $$;window.dispatchEvent(readyEvent); window.$$EventDispatched=1;}})();"
- (NSString *)jsBridgeEvent
{
    if (!_jsBridgeEvent)
    {
        _jsBridgeEvent = [JSBRIDGEEVENT stringByReplacingOccurrencesOfString:@"$$" withString:self.jsBridgeName];
    }
    
    return _jsBridgeEvent;
}

#pragma mark - UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([_delegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)])
    {
        return [_delegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    }
    
    return YES;
    
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    if (_delegate && [_delegate respondsToSelector:@selector(webViewDidStartLoad:)])
    {
        [_delegate webViewDidStartLoad:webView];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (_delegate && [_delegate respondsToSelector:@selector(webView:didFailLoadWithError:)])
    {
        [_delegate webView:webView didFailLoadWithError:error];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    self.context = [webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    self.context.exceptionHandler =
    ^(JSContext *context, JSValue *exceptionValue)
    {
        context.exception = exceptionValue;
        NSLog(@"%@", exceptionValue);
    };
    self.context[self.jsBridgeName] = self;
    [webView stringByEvaluatingJavaScriptFromString:self.jsBridgeEvent];
    
    if (_delegate && [_delegate respondsToSelector:@selector(webViewDidFinishLoad:)])
    {
        [_delegate webViewDidFinishLoad:webView];
    }
}

@end
