//
//  MEKSAdapter.m
//  MobiAdSDK
//
//  Created by 刘峰 on 2020/9/25.
//

#import "MEKSAdapter.h"
#import <KSAdSDK/KSAdSDK.h>

// Initialization configuration keys
static NSString * const kKSAppID = @"appid";

// Errors
static NSString * const kAdapterErrorDomain = @"com.mobipub.mobipub-ios-sdk.mobipub-ks-adapter";

typedef NS_ENUM(NSInteger, KSAdapterErrorCode) {
    KSAdapterErrorCodeMissingAppId,
};

@implementation MEKSAdapter

#pragma mark - Caching

+ (void)updateInitializationParameters:(NSDictionary *)parameters {
    // These should correspond to the required parameters checked in
    // `initializeNetworkWithConfiguration:complete:`
    NSString * appId = parameters[kKSAppID];
    
    if (appId != nil) {
        NSDictionary * configuration = @{ kKSAppID: appId };
        [MEKSAdapter setCachedInitializationParameters:configuration];
    }
}

#pragma mark - MPAdapterConfiguration

- (NSString *)adapterVersion {
    return @"1.0.5";
}

- (NSString *)biddingToken {
    return nil;
}

- (NSString *)mobiNetworkName {
    return @"ks";
}

- (NSString *)networkSdkVersion {
    return [KSAdSDKManager SDKVersion];
}

#pragma mark - MobiPub ad type
- (Class)getSplashCustomEvent {
    return NSClassFromString(@"MobiKSplashCustomEvent");
}

- (Class)getBannerCustomEvent {
    return NSClassFromString(@"MobiKSBannerCustomEvent");
}

- (Class)getFeedCustomEvent {
    return NSClassFromString(@"MobiKSFeedCustomEvent");
}

- (Class)getInterstitialCustomEvent {
    return NSClassFromString(@"MobiKSInterstitialCustomEvent");
}

- (Class)getRewardedVideoCustomEvent {
    return NSClassFromString(@"MobiKSRewardedVideoCustomEvent");
}

- (Class)getFullscreenCustomEvent {
    return NSClassFromString(@"MobiKSFullscreenCustomEvent");
}

- (void)initializeNetworkWithConfiguration:(NSDictionary<NSString *,id> *)configuration complete:(void (^)(NSError * _Nullable))complete {

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *appid = configuration[kKSAppID];
        
        // 快手初始化
        [KSAdSDKManager setAppId:appid];
        // 根据需要设置⽇志级别
        [KSAdSDKManager setLoglevel:KSAdSDKLogLevelOff];
        
        if (complete != nil) {
            complete(nil);
        }
    });
}

// MoPub collects GDPR consent on behalf of Google
+ (NSString *)npaString
{
//    return !MobiPub.sharedInstance.canCollectPersonalInfo ? @"1" : @"";
    return @"";
}
@end
