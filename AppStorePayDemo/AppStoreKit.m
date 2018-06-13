//
//  AppStoreKit.m
//  AppStorePayDemo
//
//  Created by creastall on 2018/6/11.
//  Copyright © 2018年 creastall. All rights reserved.
//
#import "AppStoreKit.h"

@interface AppStoreKit ()

@property (strong,nonatomic) NSMutableDictionary* dictWithSKProductForProductId;//key=productid,value=SKProduct
//请求商品列表然后重新支付
@property (strong,nonatomic) NSMutableDictionary* payfunForProductid;
//保存支付回调函数key=productid，value=PayCallBack
@property (strong,nonatomic) NSMutableDictionary* paycallbackForProductid;
@property (strong,nonatomic) NSMutableDictionary* dictWithTransactionForProductId;//保存没有消费的订单和交易的集合
@property (strong,nonatomic) NSUserDefaults* userDefaults;
@property (strong,nonatomic) SKProductsRequest *productRequest;


@end

@implementation AppStoreKit

+(instancetype) getInstance{
    static AppStoreKit * appstorekit = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appstorekit = [[AppStoreKit alloc] init];
    });
    return appstorekit;
}

-(id)init{
    if (self = [super init]) {
        self.dictWithSKProductForProductId = [NSMutableDictionary dictionary];
        self.payfunForProductid = [NSMutableDictionary dictionary];
        self.paycallbackForProductid = [NSMutableDictionary dictionary];
        self.dictWithTransactionForProductId = [NSMutableDictionary dictionary];
        self.productRequest = nil;
    }
    return self;
}

- (void) showTitle:(NSString*)title message:(NSString*)message{
#if defined(DEBUG)||defined(_DEBUG)
    static bool showed = false;
    if (!showed) {
        showed = true;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [NSThread sleepForTimeInterval:0.2];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"show view");
                UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                               message:message
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction * action) {
                                                                          showed = false;
                                                                      }];
                [alert addAction:defaultAction];
                [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
            });
        });
    }
#endif
}

-(void) initAppStoreWithSuiteName:(NSString*)suiteName clear:(bool)clear{
#if defined(DEBUG)||defined(_DEBUG)
    [[NSUserDefaults standardUserDefaults] setBool:clear forKey:@"AppStoreClearCache"];
#endif
    [[SKPaymentQueue defaultQueue] addTransactionObserver: self];
    @try{
        if (nil == suiteName || 0 == suiteName.length) {
            NSLog(@"suiteName 不能为空或空字符");
            [self showTitle:@"空或空字符" message:@"initAppStoreWithSuiteName 函数，suiteName 不能为空或空字符"];
            return;
        }
        self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        NSArray* products = [self.userDefaults objectForKey:@"productIdArray"];
#if defined(DEBUG)||defined(_DEBUG)
        if (products && clear) {
            for (NSString* productid in products) {
                [self.userDefaults removeObjectForKey:productid];
            }
            [self.userDefaults removeObjectForKey:@"productIdArray"];
            products = nil;
        }
#endif
        if(products){
            NSSet *productsets = [NSSet setWithArray:products];
            self.productRequest = nil;
            self.productRequest = [[SKProductsRequest alloc] initWithProductIdentifiers: productsets];
            self.productRequest.delegate = self;
            [self.productRequest start];
        }else{
            NSLog(@"productIdArray is nil");
        }
    }
    @catch(NSException *exception){
        NSArray* stacks = [exception callStackSymbols];
        NSString* stack = [stacks componentsJoinedByString:@"\n"];
        NSLog(@"exception = %@",exception);
        NSLog(@"stack = %@",stack);
        [self showTitle:exception.reason message:stack];
    }
}

-(void) pay:(NSString*)productid withExtdata:(NSObject*)extdata withCallBack:(AppStorePayEventCallBack)payback{
    @try{
        if (nil == payback) {
            NSLog(@"支付回调函数不能为空");
            [self showTitle:@"空" message:@"pay 函数，支付回调函数不能为空"];
            return;
        }
        if (nil == productid || 0 == productid.length) {
            NSLog(@"productid 不能为空或空字符");
             [self showTitle:@"空或空字符" message:@"pay 函数，productid 不能为空或空字符"];
            return;
        }
        if(![SKPaymentQueue canMakePayments]){
            payback(@{@"status":@(AppStorePayStatusNoAuthority)});
            return;
        }
        void(^executePay)(SKProduct*) = ^(SKProduct* product){
            NSDictionary* oldsaveExtDict = [self.userDefaults objectForKey:productid];
            if (oldsaveExtDict) {
                if ([oldsaveExtDict objectForKey:@"receipt"]) {
                    NSMutableDictionary* mutOldsaveExtDict = [NSMutableDictionary dictionaryWithDictionary:oldsaveExtDict];
                    [mutOldsaveExtDict setObject:@(AppStorePayStatusSameProductIdPaied) forKey:@"status"];
                    payback(mutOldsaveExtDict);
                }
                else{
                    NSNumber* status = [oldsaveExtDict objectForKey:@"status"];
                    if (status && status.intValue == AppStorePayStatusRestartAppToRestorePaied) {
                        payback(oldsaveExtDict);
                    }
                    else{
                        NSMutableDictionary* tmp = [NSMutableDictionary dictionaryWithDictionary:oldsaveExtDict];
                        [tmp setObject:@(AppStorePayStatusSameProductIdPaying) forKey:@"status"];
                        payback(tmp);
                    }
                }
            }
            else
            {
                SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
                NSString* currency = [product.priceLocale objectForKey:NSLocaleCurrencyCode];
                NSMutableDictionary* saveExtDict = [NSMutableDictionary dictionary];
                if (extdata) {
                    [saveExtDict setObject:extdata forKey:@"extdata"];
                }
                [saveExtDict setObject:product.price forKey:@"price"];
                [saveExtDict setObject:currency forKey:@"currency"];
                [saveExtDict setObject:payment.productIdentifier forKey:@"productid"];
                [self.userDefaults setObject:saveExtDict forKey:productid];
                [saveExtDict setObject:@(AppStorePayStatusReadyPay) forKey:@"status"];
                payback(saveExtDict);
                //保存支付回调函数,不需要判断是否存在，存在即覆盖原来的回调函数
                [self.paycallbackForProductid setObject:payback forKey:product.productIdentifier];
                //发起支付
                [[SKPaymentQueue defaultQueue] addPayment: payment];
            }
        };
        
        SKProduct* product = [self.dictWithSKProductForProductId objectForKey:productid];
        if (product){
            executePay(product);
        }
        else{
            //请求商品列表然后重新支付
            [self.payfunForProductid setObject:^(SKProduct* p){
                if (p) {
                    executePay(p);
                }
                else{
                    payback(@{@"status":@(AppStorePayStatusInvalidProductId),@"productId":productid});
                }
            } forKey:productid];
            self.productRequest = nil;
            self.productRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:@[productid]]];
            self.productRequest.delegate = self;
            [self.productRequest start];
        }
    }
    @catch(NSException* exception){
        NSArray* stacks = [exception callStackSymbols];
        NSString* stack = [stacks componentsJoinedByString:@"\n"];
        NSLog(@"exception = %@",exception);
        NSLog(@"stack = %@",stack);
        [self showTitle:exception.reason message:stack];
    }
}

-(void) consume:(NSString*)productid withCallBack:(AppStorePayEventCallBack)consumeback{
    @try{
        if (nil == productid || 0 == productid.length) {
            NSLog(@"productid 不能为空或空字符");
            [self showTitle:@"空或空字符" message:@"consume 函数，productid 不能为空或空字符"];
            return;
        }
        SKPaymentTransaction* transaction = [self.dictWithTransactionForProductId objectForKey:productid];
        NSDictionary* extdict = [self.userDefaults objectForKey:productid];
        if (transaction && extdict && [extdict objectForKey:@"receipt"]) {
            [self.dictWithTransactionForProductId removeObjectForKey:productid];
            [self.userDefaults removeObjectForKey:productid];
            if (consumeback) {
                NSMutableDictionary* mutExtdict = [NSMutableDictionary dictionaryWithDictionary:extdict];
                [mutExtdict setObject:@(AppStorePayStatusConsumeSuccess) forKey:@"status"];
                [mutExtdict removeObjectForKey:@"receipt"];
                consumeback(mutExtdict);
            }
            [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
        }
        else{
            NSLog(@"不存在没有消费的交易或消费有异常的交易");
            if (consumeback) {
                consumeback(@{@"status":@(AppStorePayStatusConsumeFail),@"productid":productid});
            }
        }
    }
    @catch(NSException* exception){
        NSArray* stacks = [exception callStackSymbols];
        NSString* stack = [stacks componentsJoinedByString:@"\n"];
        NSLog(@"exception = %@",exception);
        NSLog(@"stack = %@",stack);
        [self showTitle:exception.reason message:stack];
    }
}

-(void) checkNoConsumeWithCallBack:(AppStorePayEventCallBack)noConsumeBack{
    @try{
        if (nil == noConsumeBack) {
            NSLog(@"检测是否有支付了但是没有消费的订单 noConsumeBack 不能为空");
            [self showTitle:@"空" message:@"checkNoConsumeWithCallBack 函数，noConsumeBack 不能为空"];
            return;
        }
        NSArray* productIds = [self.userDefaults objectForKey:@"productIdArray"];
        if (productIds) {
            NSMutableArray* noConsumes = [NSMutableArray array];
            for (NSString* productId in productIds) {
                NSDictionary* extReceiptDict = [self.userDefaults objectForKey:productId];
                if (extReceiptDict && [extReceiptDict objectForKey:@"receipt"]) {
                    [noConsumes addObject:extReceiptDict];
                }
            }
            if (noConsumes.count > 0) {
                NSMutableDictionary* consumedict = [NSMutableDictionary dictionary];
                [consumedict setObject:noConsumes forKey:@"noConsumes"];
                [consumedict setObject:@(AppStorePayStatusExistNoConsumes) forKey:@"status"];
                noConsumeBack(consumedict);
            }
            else{
                noConsumeBack(nil);
            }
        }
        else{
            NSLog(@"没有任何初始化商品列表");
        }
    }
    @catch(NSException* exception){
        NSArray* stacks = [exception callStackSymbols];
        NSString* stack = [stacks componentsJoinedByString:@"\n"];
        NSLog(@"exception = %@",exception);
        NSLog(@"stack = %@",stack);
        [self showTitle:exception.reason message:stack];
    }
}

//这个是响应的delegate方法,返回获取的商品列表
- (void)productsRequest: (SKProductsRequest *)request didReceiveResponse: (SKProductsResponse *)response
{
    @try{
        for (SKProduct* pro in response.products) {
            NSDecimalNumber * price = pro.price;
            NSString* productIdentifier = pro.productIdentifier;
            NSString* currency = [pro.priceLocale objectForKey:NSLocaleCurrencyCode];
            NSLog(@"price = %@",price);
            NSLog(@"currency = %@",currency);
            NSLog(@"productIdentifier = %@",productIdentifier);
            if (nil == [self.dictWithSKProductForProductId objectForKey:productIdentifier]) {
                [self.dictWithSKProductForProductId setObject:pro forKey:productIdentifier];
                NSArray* saveProductids = [self.userDefaults objectForKey:@"productIdArray"];
                saveProductids = (nil == saveProductids ? [NSArray array] : saveProductids);
                if (false == [saveProductids containsObject:productIdentifier]) {
                    NSMutableArray* tmpMutableArray = [NSMutableArray arrayWithArray:saveProductids];
                    [tmpMutableArray addObject:productIdentifier];
                    [self.userDefaults setObject:tmpMutableArray forKey:@"productIdArray"];
                }
            }
            void(^tmppayfunForProductid)(SKProduct*) = [self.payfunForProductid objectForKey:productIdentifier];
            if (tmppayfunForProductid) {
                tmppayfunForProductid(pro);
                [self.payfunForProductid removeObjectForKey:productIdentifier];
            }
        }
        for (NSString* invalidProductid in response.invalidProductIdentifiers) {
            void(^tmppayfunForProductid)(SKProduct*) = [self.payfunForProductid objectForKey:invalidProductid];
            if (tmppayfunForProductid) {
                tmppayfunForProductid(nil);
                [self.payfunForProductid removeObjectForKey:invalidProductid];
            }
        }
    }
    @catch(NSException *exception){
        NSArray* stacks = [exception callStackSymbols];
        NSString* stack = [stacks componentsJoinedByString:@"\n"];
        NSLog(@"exception = %@",exception);
        NSLog(@"stack = %@",stack);
        [self showTitle:exception.reason message:stack];
    }
}

-(void) dealSuccessTransaction:(SKPaymentTransaction*)transaction {
    @try{
        SKPayment* payment = transaction.payment;
        NSDictionary* saveExtDict = [self.userDefaults objectForKey:payment.productIdentifier];
        if (nil == saveExtDict) {
            NSLog(@"dealSuccessTransaction saveExtDict == nil");
            [self showTitle:@"空" message:@"dealSuccessTransaction 函数，有不可用的支付缓存，请初始化的时候清除支付缓存"];
            return;
        }
        [self.dictWithTransactionForProductId setObject:transaction forKey:payment.productIdentifier];
        NSMutableDictionary* extSaveDict = [NSMutableDictionary dictionaryWithDictionary:saveExtDict];
        //从沙盒中获取交易凭证并且拼接成请求体数据
        NSURL *receiptUrl=[[NSBundle mainBundle] appStoreReceiptURL];
        if (nil == receiptUrl) {
            NSLog(@"dealSuccessTransaction nil == receiptUrl");
            return;
        }
        NSData *receiptData=[NSData dataWithContentsOfURL:receiptUrl];
        if (nil == receiptData) {
            //如果卸载游戏前有支付成功但是没有消费的账单，当游戏再次安装后第一次启动的时候会出现这种情况
            NSLog(@"dealSuccessTransaction nil == receiptData");
            if (nil == [extSaveDict objectForKey:@"receipt"]) {
                [extSaveDict setObject:@(AppStorePayStatusRestartAppToRestorePaied) forKey:@"status"];
                [self.userDefaults setObject:extSaveDict forKey:payment.productIdentifier];
            }
            return;
        }
        NSString *receiptString=[receiptData base64EncodedStringWithOptions:0];//转化为base64字符串
        if (nil == receiptString) {
            NSLog(@"dealSuccessTransaction nil == receiptString");
            return;
        }
        [extSaveDict setObject:receiptString forKey:@"receipt"];
        //test code
//        [self verifyReceipt:receiptString];
        [self.userDefaults setObject:extSaveDict forKey:payment.productIdentifier];
        AppStorePayEventCallBack callBack = [self.paycallbackForProductid objectForKey:payment.productIdentifier];
        if (callBack) {
            [extSaveDict setObject:@(AppStorePayStatusPaySuccess) forKey:@"status"];
            callBack(extSaveDict);
            [self.paycallbackForProductid removeObjectForKey:payment.productIdentifier];
        }
        else{
            NSLog(@"dealSuccessTransaction 支付成功，回调函数为空 productid = %@",payment.productIdentifier);
        }
    }
    @catch(NSException* exception){
        NSArray* stacks = [exception callStackSymbols];
        NSString* stack = [stacks componentsJoinedByString:@"\n"];
        NSLog(@"exception = %@",exception);
        NSLog(@"stack = %@",stack);
        [self showTitle:exception.reason message:stack];
    }
}

-(void) dealFailTransaction:(SKPaymentTransaction*)transaction {
    @try{
        SKPayment* payment = transaction.payment;
        if (payment) {
            NSDictionary* saveExtDict = [self.userDefaults objectForKey:payment.productIdentifier];
            NSMutableDictionary* extSaveDict = [NSMutableDictionary dictionaryWithDictionary:saveExtDict];
            [self.userDefaults removeObjectForKey:payment.productIdentifier];
            [extSaveDict setObject:@(AppStorePayStatusPayFail) forKey:@"status"];
            AppStorePayEventCallBack callBack = [self.paycallbackForProductid objectForKey:payment.productIdentifier];
            if (callBack) {
                callBack(extSaveDict);
                [self.paycallbackForProductid removeObjectForKey:payment.productIdentifier];
            }
            else{
                NSLog(@"支付失败的时候，支付回调函数找不到了,回调内容为： %@",extSaveDict);
            }
        }
        else{
            NSLog(@"支付失败 payment is nil");
        }
        [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    }
    @catch(NSException* exception){
        NSArray* stacks = [exception callStackSymbols];
        NSString* stack = [stacks componentsJoinedByString:@"\n"];
        NSLog(@"exception = %@",exception);
        NSLog(@"stack = %@",stack);
        [self showTitle:exception.reason message:stack];
    }

}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    NSLog(@"updatedTransactions counts = %@",@(transactions.count));
    for(SKPaymentTransaction * transaction in transactions)
    {
#if defined(DEBUG)||defined(_DEBUG)
        //清除所有没有消费的交易信息，避免干扰测试
        bool clear = [[NSUserDefaults standardUserDefaults] boolForKey:@"AppStoreClearCache"];
        if (clear) {
            if (transaction.transactionState != SKPaymentTransactionStatePurchasing) {
                [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
                return;
            }
        }
#endif
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchasing:
            {
                NSLog(@"SKPaymentTransactionStatePurchasing");
            }
                break;
            case SKPaymentTransactionStateDeferred:
            {
                NSLog(@"SKPaymentTransactionStateDeferred");
            }
                break;
            case SKPaymentTransactionStatePurchased:
            {
                NSLog(@"SKPaymentTransactionStatePurchased");
                [self dealSuccessTransaction:transaction];
            }
                break;
            case SKPaymentTransactionStateRestored:
            {
                NSLog(@"SKPaymentTransactionStateRestored");
                [self dealSuccessTransaction:transaction];
            }
                break;
            case SKPaymentTransactionStateFailed:
            {
                NSLog(@"SKPaymentTransactionStateFailed");
                [self dealFailTransaction:transaction];
            }
                break;
            default:
                break;
        }
    }
}

// Sent when transactions are removed from the queue (via finishTransaction:).
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
    NSLog(@"removedTransactions");
}

// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error{
    NSLog(@"restoreCompletedTransactionsFailedWithError");
}

// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue{
    NSLog(@"paymentQueueRestoreCompletedTransactionsFinished");
}

// Sent when the download state has changed.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray<SKDownload *> *)downloads{
    NSLog(@"updatedDownloads");
}

//沙盒测试环境验证
#define SANDBOX @"https://sandbox.itunes.apple.com/verifyReceipt"
//正式环境验证
#define AppStore @"https://buy.itunes.apple.com/verifyReceipt"

-(void) verifyReceipt:(NSString*)receipt {
    NSString *bodyString = [NSString stringWithFormat:@"{\"receipt-data\":\"%@\"}",receipt];//拼接请求数据
    NSData*bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    //创建请求到苹果官方进行购买验证
    NSURL *url=[NSURL URLWithString:SANDBOX];
    NSMutableURLRequest *requestM=[NSMutableURLRequest requestWithURL:url];
    requestM.HTTPBody=bodyData;
    requestM.HTTPMethod=@"POST";
    NSURLSession* session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:requestM completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            return;
        }
        NSString* responseData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"verifyReceiptResponse = %@",responseData);

    }];
    [task resume];
}


@end
