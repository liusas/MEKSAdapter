//
//  MobiKSplashCustomEvent.m
//  MobiAdSDK
//
//  Created by 刘峰 on 2020/9/27.
//

#import "MobiKSplashCustomEvent.h"
#import <KSAdSDK/KSAdSDK.h>

#if __has_include("MobiPub.h")
#import "MPLogging.h"
#import "MobiSplashError.h"
#endif

@interface MobiKSplashCustomEvent ()<KSAdSplashInteractDelegate>

@property (nonatomic, strong) UIViewController *rootVC;

@end

@implementation MobiKSplashCustomEvent

- (void)requestSplashWithCustomEventInfo:(NSDictionary *)info adMarkup:(NSString *)adMarkup {
    NSString *adUnitId = [info objectForKey:@"adunit"];
    NSTimeInterval delay = [[info objectForKey:@"delay"] floatValue];
    
    if (adUnitId == nil) {
        NSError *error = [NSError splashErrorWithCode:MobiSplashAdErrorNoAdsAvailable localizedDescription:@"posid cannot be nil"];
        if ([self.delegate respondsToSelector:@selector(splashAdFailToPresentForCustomEvent:withError:)]) {
            [self.delegate splashAdFailToPresentForCustomEvent:self withError:error];
        }
        return;
    }

    // 开屏⼴广告
    KSAdSplashManager.posId = adUnitId;
    KSAdSplashManager.interactDelegate = self; //预加载闪屏⼴广告，可以选择延迟加载
    [KSAdSplashManager loadSplash];
    
    UIViewController *vc = [self topVC];
    if (!vc) {
        return;
    }
    
    self.rootVC = vc;
    
    //如果有本地已缓存⼴广告，检测⼴广告是否有效，如果⼴广告有效，会返回开屏⼴广告控制器器，具体使⽤用可 ⻅见demo
    [KSAdSplashManager checkSplash:^(KSAdSplashViewController * _Nonnull splashViewController) {
        if (splashViewController) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(splashAdDidLoadForCustomEvent:)]) {
                [self.delegate splashAdDidLoadForCustomEvent:self];
            }
            splashViewController.modalTransitionStyle =
            UIModalTransitionStyleCrossDissolve;
            [self.rootVC presentViewController:splashViewController animated:YES completion:nil];
        } else {
            NSError *error = [NSError errorWithDomain:MobiSplashAdsSDKDomain code:MobiSplashAdErrorNoAdReady userInfo:nil];
            if (self.delegate && [self.delegate respondsToSelector:@selector(splashAdFailToPresentForCustomEvent:withError:)]) {
                [self.delegate splashAdFailToPresentForCustomEvent:self withError:error];
            }
        }
    }];
}

- (void)presentSplashFromWindow:(UIWindow *)window {
    
    UIViewController *vc = [self topVC];
    if (!vc) {
        return;
    }
    
    self.rootVC = vc;
}

- (BOOL)hasAdAvailable
{
    return [KSAdSplashManager hasCachedSplash];
}

- (void)handleAdPlayedForCustomEventNetwork
{
    if (![self hasAdAvailable]) {
        [self.delegate splashAdDidExpireForCustomEvent:self];
    }
}

- (void)handleCustomEventInvalidated
{
}

//MARK: 交互回调
/**
 * 闪屏广告展示
 */
- (void)ksad_splashAdDidShow {
    if (self.delegate && [self.delegate respondsToSelector:@selector(splashAdSuccessPresentScreenForCustomEvent:)]) {
        [self.delegate splashAdSuccessPresentScreenForCustomEvent:self];
    }
}
/**
 * 闪屏广告点击转化
 */
- (void)ksad_splashAdClicked {
    if (self.delegate && [self.delegate respondsToSelector:@selector(splashAdClickedForCustomEvent:)]) {
        [self.delegate splashAdClickedForCustomEvent:self];
    }
}
/**
 * 视频闪屏广告开始播放
 */
- (void)ksad_splashAdVideoDidStartPlay {
    
}
/**
 * 视频闪屏广告播放失败
 */
- (void)ksad_splashAdVideoFailedToPlay:(NSError *)error {
    
    [self.rootVC dismissViewControllerAnimated:NO completion:nil];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(splashAdFailToPresentForCustomEvent:withError:)]) {
        [self.delegate splashAdFailToPresentForCustomEvent:self withError:error];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(splashAdWillClosedForCustomEvent:)]) {
        [self.delegate splashAdWillClosedForCustomEvent:self];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(splashAdClosedForCustomEvent:)]) {
        [self.delegate splashAdClosedForCustomEvent:self];
    }
}
/**
 * 视频闪屏广告跳过
 */
- (void)ksad_splashAdVideoDidSkipped:(NSTimeInterval)playDuration {
    if (self.delegate && [self.delegate respondsToSelector:@selector(splashAdDidClickSkipForCustomEvent:)]) {
        [self.delegate splashAdDidClickSkipForCustomEvent:self];
    }
}
/**
 * 闪屏广告关闭，需要在这个方法里关闭闪屏页面
 * @param converted      是否转化
 */
- (void)ksad_splashAdDismiss:(BOOL)converted {
    [self.rootVC dismissViewControllerAnimated:!converted completion:nil];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(splashAdWillClosedForCustomEvent:)]) {
        [self.delegate splashAdWillClosedForCustomEvent:self];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(splashAdClosedForCustomEvent:)]) {
        [self.delegate splashAdClosedForCustomEvent:self];
    }
}
/**
 * 转化控制器容器，如果未实现则默认闪屏页面的上级控制器
 */
- (UIViewController *)ksad_splashAdConversionRootVC {
    return [self topVC];
}

/// 获取顶层VC
- (UIViewController *)topVC {
    UIWindow *rootWindow = [UIApplication sharedApplication].keyWindow;
    if (![[UIApplication sharedApplication].windows containsObject:rootWindow]
        && [UIApplication sharedApplication].windows.count > 0) {
        rootWindow = [UIApplication sharedApplication].windows[0];
    }
    UIViewController *topVC = rootWindow.rootViewController;
    // 未读到keyWindow的rootViewController，则读UIApplicationDelegate的window，但该window不一定存在
    if (nil == topVC && [[UIApplication sharedApplication].delegate respondsToSelector:@selector(window)]) {
        topVC = [UIApplication sharedApplication].delegate.window.rootViewController;
    }
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}


@end
