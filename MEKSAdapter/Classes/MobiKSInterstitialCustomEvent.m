//
//  MobiKSInterstitialCustomEvent.m
//  MobiAdSDK
//
//  Created by 刘峰 on 2020/9/27.
//

#import "MobiKSInterstitialCustomEvent.h"

#if __has_include("MobiPub.h")
#import "MPLogging.h"
#import "MobiInterstitialError.h"
#endif

@interface MobiKSInterstitialCustomEvent ()

@end

@implementation MobiKSInterstitialCustomEvent

- (void)requestInterstitialWithCustomEventInfo:(NSDictionary *)info adMarkup:(NSString *)adMarkup {
    NSString *adUnitId = [info objectForKey:@"adunit"];
    if (adUnitId == nil) {
        NSError *error =
        [NSError errorWithDomain:MobiInterstitialAdsSDKDomain
                            code:MobiInterstitialAdErrorInvalidPosid
                        userInfo:@{NSLocalizedDescriptionKey : @"KS Ad Unit ID cannot be nil."}];
        [self.delegate interstitialCustomEvent:self didFailToLoadAdWithError:error];
        return;
    }
    
    NSError *error =
    [NSError errorWithDomain:MobiInterstitialAdsSDKDomain
                        code:MobiInterstitialAdErrorUnknown
                    userInfo:@{NSLocalizedDescriptionKey : @"KS unknown error"}];
    [self.delegate interstitialCustomEvent:self didFailToLoadAdWithError:error];
}

/**
 * Called when the interstitial should be displayed.
 *
 * This message is sent sometime after an interstitial has been successfully loaded, as a result
 * of your code calling `-[MPInterstitialAdController showFromViewController:]`. Your implementation
 * of this method should present the interstitial ad from the specified view controller.
 *
 * If you decide to [opt out of automatic impression tracking](enableAutomaticImpressionAndClickTracking), you should place your
 * manual calls to [-trackImpression]([MPInterstitialCustomEventDelegate trackImpression]) in this method to ensure correct metrics.
 *
 * @param rootViewController The controller to use to present the interstitial modally.
 *
 */
- (void)showInterstitialFromRootViewController:(UIViewController *)rootViewController {
    NSError *error =
    [NSError errorWithDomain:MobiInterstitialAdsSDKDomain
                        code:MobiInterstitialAdErrorNoAdsAvailable
                    userInfo:@{NSLocalizedDescriptionKey : @"Cannot present intersitial ads. Cause interstitial ad is invalid"}];
    [self.delegate interstitialCustomEvent:self didFailToLoadAdWithError:error];
}

- (BOOL)hasAdAvailable
{
    return NO;
}

/** @name Impression and Click Tracking */

/**
 * Override to opt out of automatic impression and click tracking.
 *
 * By default, the  MPInterstitialCustomEventDelegate will automatically record impressions and clicks in
 * response to the appropriate callbacks. You may override this behavior by implementing this method
 * to return `NO`.
 *
 * @warning **Important**: If you do this, you are responsible for calling the `[-trackImpression]([MPInterstitialCustomEventDelegate trackImpression])` and
 * `[-trackClick]([MPInterstitialCustomEventDelegate trackClick])` methods on the custom event delegate. Additionally, you should make sure that these
 * methods are only called **once** per ad.
 */
- (BOOL)enableAutomaticImpressionAndClickTracking {
    return YES;
}


@end
