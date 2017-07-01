//
//  ViewController.m
//  WVJSNativeBridge
//
//  Created by hncoder on 2017/7/1.
//  Copyright © 2017年 hncoder. All rights reserved.
//

#import "ViewController.h"
#import "WVJSNativeBridge.h"

@interface ViewController ()<UIWebViewDelegate>

@property (nonatomic, strong) WVJSNativeBridge *bridge;
@property (nonatomic, strong) UIWebView *webView;

@end

@implementation ViewController

//window.testCallback = function(data){console.log(data)}
//window.native.call({method:"test",param:{},callback:"testCallback"})

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // Create `WVJSBridge` object firstly.
    self.bridge = [[WVJSNativeBridge alloc] initWithBridgeName:@"native" delegate:self];
    
    // Add webview secondly
    self.bridge.webView.frame = self.view.bounds;
    [self.view addSubview:self.bridge.webView];
    
    // Register native methods for javascript to call.
    [_bridge registerHandler:@"test" target:self selector:@selector(test:callback:)];
    
    // Load web page url.
    [self.bridge.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.baidu.com/"]]];
}

- (void)test:(id)data callback:(WVJSNativeCallback)cb
{
    // `data` is kind of NSDictionary object.
    NSLog(@"Receive data from web page:%@",[data description]);
    
    // Return data to javascript.
    if (cb)
    {
        cb(@{@"code":@(0)});
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
