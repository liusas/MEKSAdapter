//
//  MobiKSRewardedVideoCustomEvent.m
//  MobiAdSDK
//
//  Created by 刘峰 on 2020/9/27.
//

#import "MobiKSRewardedVideoCustomEvent.h"
#import <KSAdSDK/KSAdSDK.h>

#if __has_include("MobiPub.h")
#import "MPLogging.h"
#import "MobiRewardedVideoError.h"
#import "MobiRewardedVideoReward.h"
#endif


@interface MobiKSRewardedVideoCustomEvent ()<KSRewardedVideoAdDelegate>

@property(nonatomic, copy) NSString *posid;
/// 激励视频对象
@property (nonatomic, strong) KSRewardedVideoAd *rewardedAd;
/// 判断激励视频是否能给奖励,每次关闭视频变false
@property (nonatomic, assign) BOOL isEarnRewarded;

/// 用来弹出广告的 viewcontroller
@property (nonatomic, strong) UIViewController *rootVC;

@end

@implementation MobiKSRewardedVideoCustomEvent

- (void)requestRewardedVideoWithCustomEventInfo:(NSDictionary *)info adMarkup:(NSString *)adMarkup {
    NSString *adUnitId = [info objectForKey:@"adunit"];
    
    if (adUnitId == nil) {
        NSError *error =
        [NSError errorWithDomain:MobiRewardedVideoAdsSDKDomain
                            code:MobiRewardedVideoAdErrorInvalidPosid
                        userInfo:@{NSLocalizedDescriptionKey : @"Ad Unit ID cannot be nil."}];
        [self.delegate rewardedVideoDidFailToLoadAdForCustomEvent:self error:error];
        return;
    }
    
    self.rewardedAd = [[KSRewardedVideoAd alloc] initWithPosId:adUnitId rewardedVideoModel:[KSRewardedVideoModel new]];
    self.rewardedAd.delegate = self;
    [self.rewardedAd loadAdData];
}

/// 上层调用`presentRewardedVideoFromViewController`展示广告之前,
/// 需要判断这个广告是否还有效,需要在此处返回广告有效性(是否可以直接展示)
- (BOOL)hasAdAvailable {
    return self.rewardedAd.isValid;
}

/// 展示激励视频广告
/// 一般在广告加载成功后调用,需要重写这个类,实现弹出激励视频广告
/// 注意,如果重写的`enableAutomaticImpressionAndClickTracking`方法返回NO,
/// 那么需要自行实现`trackImpression`方法进行数据上报,否则不用处理,交由上层的adapter处理即可
/// @param viewController 弹出激励视频广告的类
- (void)presentRewardedVideoFromViewController:(UIViewController *)viewController {
    if (viewController != nil) {
        self.rootVC = viewController;
    }
    
    if (self.rewardedAd.isValid == YES) {
        [self.rewardedAd showAdFromRootViewController:viewController];
        return;
    }
    
    // We will send the error if the rewarded ad has already been presented.
    NSError *error = [NSError
                      errorWithDomain:MobiRewardedVideoAdsSDKDomain
                      code:MobiRewardedVideoAdErrorNoAdReady
                      userInfo:@{NSLocalizedDescriptionKey : @"Rewarded ad is not ready to be presented."}];
    [self.delegate rewardedVideoDidFailToPlayForCustomEvent:self error:error];
}

/// 子类重写次方法,决定由谁处理展现和点击上报
/// 默认return YES;由上层adapter处理展现和点击上报,
/// 若return NO;则由子类实现trackImpression和trackClick方法,实现上报,但要保证每个广告只上报一次
- (BOOL)enableAutomaticImpressionAndClickTracking {
    return YES;
}

 /** MoPub's API includes this method because it's technically possible for two MoPub custom events or
  adapters to wrap the same SDK and therefore both claim ownership of the same cached ad. The
  method will be called if 1) this custom event has already invoked
  rewardedVideoDidLoadAdForCustomEvent: on the delegate, and 2) some other custom event plays a
  rewarded video ad. It's a way of forcing this custom event to double-check that its ad is
  definitely still available and is not the one that just played. If the ad is still available, no
  action is necessary. If it's not, this custom event should call
  rewardedVideoDidExpireForCustomEvent: to let the MoPub SDK know that it's no longer ready to play
  and needs to load another ad. That event will be passed on to the publisher app, which can then
  trigger another load.
  */
- (void)handleAdPlayedForCustomEventNetwork {
    if (!self.rewardedAd.isValid) {
        [self.delegate rewardedVideoDidExpireForCustomEvent:self];
    }
}

/// 在激励视频系统不再需要这个custom event类时,会调用这个方法,目的是让custom event能够成功释放掉,如果能保证custom event不会造成内存泄漏,则这个方法不用重写
- (void)handleCustomEventInvalidated {
    
}

#pragma mark - KSRewardedVideoAdDelegate
- (void)rewardedVideoAdDidLoad:(KSRewardedVideoAd *)rewardedVideoAd {
    // 这里表示广告素材已经准备好了,下面的代理rewardedVideoAdVideoDidLoad表示可以播放了
    if (self.delegate && [self.delegate respondsToSelector:@selector(rewardedVideoDidLoadAdForCustomEvent:)]) {
        [self.delegate rewardedVideoDidLoadAdForCustomEvent:self];
    }
}

- (void)rewardedVideoAd:(KSRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error {
    self.rootVC = nil;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(rewardedVideoDidFailToLoadAdForCustomEvent:error:)]) {
        [self.delegate rewardedVideoDidFailToLoadAdForCustomEvent:self error:error];
    }
}

- (void)rewardedVideoAdVideoDidLoad:(KSRewardedVideoAd *)rewardedVideoAd {
    if (self.delegate && [self.delegate respondsToSelector:@selector(rewardedVideoAdVideoDidLoadForCustomEvent:)]) {
        [self.delegate rewardedVideoAdVideoDidLoadForCustomEvent:self];
    }
    
    // 这里能获取到ecpm
//    NSInteger ecpm = rewardedVideoAd.ecpm;
    
}

- (void)rewardedVideoAdWillVisible:(KSRewardedVideoAd *)rewardedVideoAd {
    if (self.delegate && [self.delegate respondsToSelector:@selector(rewardedVideoWillAppearForCustomEvent:)]) {
        [self.delegate rewardedVideoWillAppearForCustomEvent:self];
    }
}

- (void)rewardedVideoAdWillClose:(KSRewardedVideoAd *)rewardedVideoAd {
    // 若没达到奖励条件,则不给回调
    if (self.isEarnRewarded == false) {
        return;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(rewardedVideoWillDisappearForCustomEvent:)]) {
        [self.delegate rewardedVideoWillDisappearForCustomEvent:self];
    }
    
    // 变回默认的不给奖励
    self.isEarnRewarded = false;
}

- (void)rewardedVideoAdDidClose:(KSRewardedVideoAd *)rewardedVideoAd {
    self.rootVC = nil;
    if (self.delegate && [self.delegate respondsToSelector:@selector(rewardedVideoDidDisappearForCustomEvent:)]) {
        [self.delegate rewardedVideoDidDisappearForCustomEvent:self];
    }
}

- (void)rewardedVideoAdDidClick:(KSRewardedVideoAd *)rewardedVideoAd {
    if (self.delegate && [self.delegate respondsToSelector:@selector(rewardedVideoDidReceiveTapEventForCustomEvent:)]) {
        [self.delegate rewardedVideoDidReceiveTapEventForCustomEvent:self];
    }
}

- (void)rewardedVideoAdDidClickSkip:(KSRewardedVideoAd *)rewardedVideoAd {
    // 点击了跳过, 则不给奖励
    self.isEarnRewarded = false;
}

- (void)rewardedVideoAd:(KSRewardedVideoAd *)rewardedVideoAd hasReward:(BOOL)hasReward {
//    NSString *text = [NSString stringWithFormat:@"%@,是否有奖励:%@", NSStringFromSelector(_cmd), hasReward ? @"YES" : @"NO"];
    // 可以给收益
    self.isEarnRewarded = hasReward;
}

@end
