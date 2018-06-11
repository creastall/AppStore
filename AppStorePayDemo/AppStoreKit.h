//
//  AppStoreUtils.h
//  appstoredemo
//
//  Created by creastall on 2018/6/11.
//  Copyright © 2018年 creastall. All rights reserved.
//
#import <StoreKit/StoreKit.h>
#import <Foundation/Foundation.h>

typedef enum : NSInteger {
    AppStorePayStatusNoAuthority = 1,//没有权限支付
    AppStorePayStatusSameProductIdPaying,//同一个productid只能同时发起一笔支付，如果上一笔没有支付完成，那么将出现paying
    AppStorePayStatusSameProductIdPaied,//同一个productid只能同时发起一笔支付，如果上一笔支付完成但是没有消费，那么将出现paied
    AppStorePayStatusReadyPay,//即将启动支付
    AppStorePayStatusPaySuccess,//支付成功
    AppStorePayStatusPayFail,//支付失败
    AppStorePayStatusInvalidProductId,//无效的商品id
    AppStorePayStatusConsume//消费
} AppStorePayStatus;

typedef void(^AppStorePayEventCallBack)(NSDictionary* back);

@interface AppStoreKit : NSObject<SKProductsRequestDelegate,SKPaymentTransactionObserver>

+(instancetype) getInstance;
/**
 初始化苹果支付，需要在didFinishLaunchingWithOptions函数中调用,传入共享数据套件名字，用来保存相关信息
 必须在Capabilities中的app groups中添加该名字的group，否者可能导致支付失败或者未知情况

 @param suiteName Capabilities中的app groups的名字
 @param clear 是否清除缓存数据，包括所有商品列表和所有支付状态缓存,使用一次true运行后应该立即改为false，正式上线的时候必须为：false
 为了保证开发者使用错误，release版本的包变量clear强制为false
 */
-(void) initAppStoreWithSuiteName:(NSString*)suiteName clear:(bool)clear;

/**
 支付函数

 @param productid 商品id
 @param extdata 透传对象，可以为字典、数组或者json字符串
 @param payback 支付回调函数，返回一个字典，有如下key：
         1.key = extdata(value -> NSObject*)：回调函数透传对象
         2.key = price(value -> NSDecimalNumber*)：商品价格，已经转化为支付国家的货币
         3.key = currency(value -> NSString*)：支付国家的货币符号
         4.key = productid(value -> NSString*)：商品id
         5.key = receipt(value -> NSString*)：支付凭据
 */
-(void) pay:(NSString*)productid withExtdata:(NSObject*)extdata withCallBack:(AppStorePayEventCallBack)payback;
/**
 当该笔订单游戏服务器已经发货，玩家已经收到对应的物品的时候调用

 @param productid 商品id
 @param consumeback 支付回调函数，返回一个字典，有如下key：
         1.key = price(value -> NSDecimalNumber*)：商品价格，已经转化为支付国家的货币
         2.key = currency(value -> NSString*)：支付国家的货币符号
         3.key = productid(value -> NSString*)：商品id
         4.key = extdata(value -> NSObject*)：回调函数透传对象
 */
-(void) consume:(NSString*)productid withCallBack:(AppStorePayEventCallBack)consumeback;

/**
 检测：支付成功，但是服务器没有发货的账单

 @param noConsumeBack 支付回调函数，返回一个字典，有如下key：
        1.key = noConsume(value -> NSArray*)：记录所有没有消费的账单，数组中每个值为一个字典，该字典和pay函数返回的字典一样，如下
                 1.key = extdata(value -> NSObject*)：回调函数透传对象
                 2.key = price(value -> NSDecimalNumber*)：商品价格，已经转化为支付国家的货币
                 3.key = currency(value -> NSString*)：支付国家的货币符号
                 4.key = productid(value -> NSString*)：商品id
                 5.key = receipt(value -> NSString*)：支付凭据
 */
-(void) checkNoConsumeWithCallBack:(AppStorePayEventCallBack)noConsumeBack;

@end
