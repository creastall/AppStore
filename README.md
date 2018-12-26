# AppStore
集成了苹果内购，将苹果内购抽象成一个单例类，方便使用，这里提供使用的demo
使用xcode9.4编译的demo，只适合消耗型内购

流程：

1.调用支付函数(pay:withExt:withCallBack:)，等待用户支付成功后，回调返回苹果支付收据；

2.将收据发送给服务器进行验证，服务器将验证结果返回给前端；

3.前端根据服务器验证结果是否消费(consume:withCallBack:)该笔订单;

注意：

需要在didFinishLaunchingWithOptions:函数中调用
[[AppStoreKit getInstance] initAppStoreWithClear:false]函数，具体参考demo

