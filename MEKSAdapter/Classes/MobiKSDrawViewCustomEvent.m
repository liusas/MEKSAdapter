//
//  MobiKSDrawViewCustomEvent.m
//  MEKSAdapter
//
//  Created by 刘峰 on 2020/11/12.
//

#import "MobiKSDrawViewCustomEvent.h"
#import <KSAdSDK/KSAdSDK.h>

@interface MobiKSDrawViewCustomEvent ()<KSDrawAdsManagerDelegate, KSDrawAdDelegate>

@property (nonatomic, copy) NSArray *dataArray;

@property (nonatomic, strong) KSDrawAdsManager *drawAdsManager;

@end

@implementation MobiKSDrawViewCustomEvent
#if 0
- (void)requestDrawViewWithCustomEventInfo:(NSDictionary *)info adMarkup:(NSString *)adMarkup {
    NSString *adUnitId = [info objectForKey:@"adunit"];
//    CGFloat width = [[info objectForKey:@"width"] floatValue];
//    CGFloat height = [[info objectForKey:@"height"] floatValue];
    NSInteger count = [[info objectForKey:@"count"] intValue];
    
    if (adUnitId == nil) {
        NSError *error =
        [NSError errorWithDomain:MobiDrawViewAdsSDKDomain
                            code:MobiDrawViewAdErrorInvalidPosid
                        userInfo:@{NSLocalizedDescriptionKey : @"Ad Unit ID cannot be nil."}];
        [self.delegate nativeExpressAdFailToLoadForCustomEvent:self error:error];
        return;
    }
    
    self.dataArray = [NSMutableArray array];
    
//    NSString *posId = @"4000000010";
    self.drawAdsManager = [[KSDrawAdsManager alloc] initWithPosId:adUnitId];
    self.drawAdsManager.delegate = self;
    [self.drawAdsManager loadAdDataWithCount:count];
}

/// 在回传信息流广告之前,
/// 需要判断这个广告是否还有效,需要在此处返回广告有效性(是否可以直接展示)
- (BOOL)hasAdAvailable {
    return YES;
}

/// 子类重写次方法,决定由谁处理展现和点击上报
/// 默认return YES;由上层adapter处理展现和点击上报,
/// 若return NO;则由子类实现trackImpression和trackClick方法,实现上报,但要保证每个广告只上报一次
- (BOOL)enableAutomaticImpressionAndClickTracking {
    return YES;
}

/// 这个方法存在的意义是聚合广告,因为聚合广告可能会出现两个广告单元用同一个广告平台加载广告
/// 在出现多个广告单元调用同一个广告平台展示广告时,我们要通知custom event类,它们的广告已经失效,当前已经有正在播放的广告
/// 当然广告失效后需要回调`[-rewardedVideoDidExpireForCustomEvent:]([MPRewardedVideoCustomEventDelegate rewardedVideoDidExpireForCustomEvent:])`方法告诉用户这个广告已不再有效
/// 并且我们要重写这个方法,让这个Custom event类能释放掉
/// 默认这个方法不会做任何事情
- (void)handleAdPlayedForCustomEventNetwork {
    [self.delegate nativeExpressAdDidExpireForCustomEvent:self];
}

/// 在激励视频系统不再需要这个custom event类时,会调用这个方法,目的是让custom event能够成功释放掉,如果能保证custom event不会造成内存泄漏,则这个方法不用重写
- (void)handleCustomEventInvalidated {
    
}

#pragma mark - KSDrawAdsManagerDelegate
- (void)drawAdsManagerSuccessToLoad:(KSDrawAdsManager *)adsManager drawAds:(NSArray<KSDrawAd *> *_Nullable)drawAdDataArray {
    NSMutableArray *expressionViews = [NSMutableArray array];
    self.dataArray = expressionViews;
    
    [drawAdDataArray enumerateObjectsUsingBlock:^(KSDrawAd * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        KSDrawAd *drawAd = adsManager.data[idx];
        drawAd.delegate = self;
        
        UIView *feedView = feedAd.feedView;
        [expressionViews addObject:feedView];
    }];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(nativeExpressAdSuccessToLoadForCustomEvent:views:)]) {
        [self.delegate nativeExpressAdSuccessToLoadForCustomEvent:self views:expressionViews];
    }
}
- (void)drawAdsManager:(KSDrawAdsManager *)adsManager didFailWithError:(NSError *_Nullable)error {
    if (self.delegate && [self.delegate respondsToSelector:@selector(nativeExpressAdFailToLoadForCustomEvent:error:)]) {
        [self.delegate nativeExpressAdFailToLoadForCustomEvent:self error:error];
    }
}

#pragma mark - KSDrawAdDelegate
- (void)drawAdViewWillShow:(KSDrawAd *)drawAd {
    if (self.delegate && [self.delegate respondsToSelector:@selector(nativeExpressAdViewRenderSuccessForCustomEvent:)]) {
        [self.delegate nativeExpressAdViewRenderSuccessForCustomEvent:nativeExpressAdView];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(nativeExpressAdViewExposureForCustomEvent:)]) {
        [self.delegate nativeExpressAdViewExposureForCustomEvent:nativeExpressAdView];
    }
}
- (void)drawAdDidClick:(KSDrawAd *)drawAd {
    if (self.delegate && [self.delegate respondsToSelector:@selector(nativeExpressAdViewClickedForCustomEvent:)]) {
        [self.delegate nativeExpressAdViewClickedForCustomEvent:nativeExpressAdView];
    }
}
- (void)drawAdDidShowOtherController:(KSDrawAd *)drawAd interactionType:(KSAdInteractionType)interactionType {
    if (self.delegate && [self.delegate respondsToSelector:@selector(nativeExpressAdViewWillPresentScreenForCustomEvent:)]) {
        [self.delegate nativeExpressAdViewWillPresentScreenForCustomEvent:nativeExpressAdView];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(nativeExpressAdViewDidPresentScreenForCustomEvent:)]) {
        [self.delegate nativeExpressAdViewDidPresentScreenForCustomEvent:nativeExpressAdView];
    }
}
- (void)drawAdDidCloseOtherController:(KSDrawAd *)drawAd interactionType:(KSAdInteractionType)interactionType {
    if (self.delegate && [self.delegate respondsToSelector:@selector(nativeExpressAdViewWillDissmissScreenForCustomEvent:)]) {
        [self.delegate nativeExpressAdViewWillDissmissScreenForCustomEvent:nativeExpressAdView];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(nativeExpressAdViewDidDissmissScreenForCustomEvent:)]) {
        [self.delegate nativeExpressAdViewDidDissmissScreenForCustomEvent:nativeExpressAdView];
    }
}

#endif

@end
