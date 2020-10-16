//
//  MobiKSBannerCustomEvent.m
//  MobiAdSDK
//
//  Created by 刘峰 on 2020/9/28.
//

#import "MobiKSBannerCustomEvent.h"

#if __has_include("MobiPub.h")
#import "MPLogging.h"
#import "MobiBannerError.h"
#endif

@implementation MobiKSBannerCustomEvent

- (void)requestAdWithSize:(CGSize)size customEventInfo:(NSDictionary *)info adMarkup:(NSString *)adMarkup {
    NSString *adUnitId = [info objectForKey:@"adunit"];
    CGFloat whRatio = [[info objectForKey:@"whRatio"] floatValue];
    NSTimeInterval interval = [[info objectForKey:@"interval"] floatValue];
    UIViewController *rootVC = [info objectForKey:@"rootVC"];
    
    
    if (adUnitId == nil) {
        NSError *error =
        [NSError errorWithDomain:MobiBannerAdsSDKDomain
                            code:MobiBannerAdErrorInvalidPosid
                        userInfo:@{NSLocalizedDescriptionKey : @"Ad Unit ID cannot be nil."}];
        [self.delegate bannerCustomEvent:self didFailToLoadAdWithError:error];
        return;
    }
    
    NSError *error =
    [NSError errorWithDomain:MobiBannerAdsSDKDomain
                        code:MobiBannerAdErrorUnknown
                    userInfo:@{NSLocalizedDescriptionKey : @"KS banner custom event was not recognized"}];
    [self.delegate bannerCustomEvent:self didFailToLoadAdWithError:error];
    
}

- (BOOL)enableAutomaticImpressionAndClickTracking
{
    return YES;
}

@end
