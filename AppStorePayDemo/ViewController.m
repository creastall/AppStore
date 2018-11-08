//
//  ViewController.m
//  AppStorePayDemo
//
//  Created by creastall on 2018/6/8.
//  Copyright © 2018年 creastall. All rights reserved.
//

#import "ViewController.h"
#import "AppStoreKit.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)payClick:(UIButton *)sender {
    NSString* productid = sender.titleLabel.text;
    [[AppStoreKit getInstance] pay:productid withExt:@"{\"price\":128,\"orderid\":\"4514514125\"}" withCallBack:^(NSDictionary *payback) {
        NSNumber* status = [payback objectForKey:@"status"];
        AppStorePayStatus appstorestatus = (AppStorePayStatus)status.intValue;
        switch(appstorestatus){
            case AppStorePayStatusNoAuthority:
            {
                //可以提示没有权限支付
                NSLog(@"ViewController 没有权限。。。。");
                NSLog(@"%@",payback);
            }
                break;
            case AppStorePayStatusSameProductIdPaying:
            {
                //可以提示有正在支付的商品
                NSLog(@"ViewController 同商品id订单正在支付。。。。");
                NSLog(@"%@",payback);
            }
                break;
            case AppStorePayStatusSameProductIdPaied:
            {
                //获取支付凭据，然后发送给服务器，让服务器进行验证
                NSLog(@"ViewController 同商品id订单支付完成，但是没有消费。。。。");
                NSLog(@"%@",payback);
            }
                break;
            case AppStorePayStatusReadyPay:
            {
                //可以用来第三方sdk统计数据使用
                NSLog(@"ViewController 启动支付。。。。");
                NSLog(@"%@",payback);
            }
                break;
            case AppStorePayStatusPaySuccess:
            {
                //获取支付凭据，然后发送给服务器，让服务器进行验证
                NSLog(@"ViewController 支付成功，请服务器发货后通知前端消费。。。。");
                NSLog(@"%@",payback);
            }
                break;
            case AppStorePayStatusPayFail:
            {
                //提示支付失败
                NSLog(@"ViewController 支付失败。。。。");
                NSLog(@"%@",payback);
            }
                break;
            case AppStorePayStatusInvalidProductId:
            {
                NSLog(@"ViewController 无效的商品id。。。。");
                NSLog(@"%@",payback);
            }
            case AppStorePayStatusRestartAppToRestorePaied:
            {
                NSLog(@"ViewController 需要重启app后，点击同样商品或者调用checkNoConsumeWithCallBack函数来恢复已经购买的商品。。。。");
                NSLog(@"%@",payback);
            }
                break;
            default:
                break;
        }
    }];
}
- (IBAction)consume:(UIButton *)sender {
    NSString* productid = [NSString stringWithFormat:@"ggggg%@",@(sender.tag)];
    [[AppStoreKit getInstance] consume:productid withCallBack:^(NSDictionary *consumeback) {
        NSNumber* sonsumestatus = [consumeback objectForKey:@"status"];
        if (sonsumestatus.intValue == AppStorePayStatusConsumeSuccess) {
            NSLog(@"ViewController 消费成功：%@",consumeback);
        }
        else if(sonsumestatus.intValue == AppStorePayStatusConsumeFail){
            NSLog(@"ViewController 消费失败: %@",consumeback);
        }
    }];
}
- (IBAction)checkNoConsumeOrder:(UIButton *)sender {
    [[AppStoreKit getInstance] checkNoConsumeWithCallBack:^(NSDictionary *back) {
        NSNumber* checkstatus = [back objectForKey:@"status"];
        if (checkstatus.intValue == AppStorePayStatusExistNoConsumes) {
            NSArray* noConsumes = [back objectForKey:@"noConsumes"];
            NSLog(@"ViewController noConsumes count = %@",@(noConsumes.count));
            NSLog(@"ViewController 未消费订单如下：");
            for (NSDictionary* backdict in noConsumes) {
                NSLog(@"%@",backdict);
            }
        }
        else{
            NSLog(@"ViewController 没有未消费订单");
        }
    }];
}
- (IBAction)invalidProductId:(UIButton *)sender {
    if (0 == sender.tag) {
        [[AppStoreKit getInstance] pay:@"jjfhiekjgsde" withExt:nil withCallBack:^(NSDictionary *payback) {
            NSNumber* status = [payback objectForKey:@"status"];
            if (status.intValue == AppStorePayStatusInvalidProductId) {
                NSLog(@"ViewController 购买无效的商品id。。。。");
                NSLog(@"%@",payback);
            }
        }];
    }
    else if (1 == sender.tag) {
        [[AppStoreKit getInstance] consume:@"144551gefsd" withCallBack:^(NSDictionary *consumeback) {
            NSNumber* sonsumestatus = [consumeback objectForKey:@"status"];
            if (sonsumestatus.intValue == AppStorePayStatusConsumeSuccess) {
                NSLog(@"ViewController 消费成功：%@",consumeback);
            }
            else if(sonsumestatus.intValue == AppStorePayStatusConsumeFail){
                NSLog(@"ViewController 消费失败: %@",consumeback);
            }
        }];
    }
}

@end
