//
//  MobiInterstitialManager.m
//  MobiPubSDK
//
//  Created by 刘峰 on 2020/6/18.
//

#import "MobiInterstitialManager.h"
#import "MobiInterstitialAdapter.h"
#import "MobiAdConfigServer.h"
#import "MobiConfig.h"
#import "NSMutableArray+MPAdditions.h"
#import "NSDate+MPAdditions.h"
#import "NSError+MPAdditions.h"
#import "MPStopwatch.h"
#import "MobiInterstitialError.h"
#import "MobiAdServerURLBuilder.h"

@interface MobiInterstitialManager ()<MobiAdConfigServerDelegate, MobiInterstitialAdapterDelegate>

@property (nonatomic, strong) MobiInterstitialAdapter *adapter;
@property (nonatomic, strong) MobiAdConfigServer *communicator;
@property (nonatomic, strong) MobiConfig *configuration;
@property (nonatomic, strong) NSMutableArray<MobiConfig *> *remainingConfigurations;
@property (nonatomic, strong) NSURL *mostRecentlyLoadedURL;  // ADF-4286: avoid infinite ad reloads
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL playedAd;
@property (nonatomic, assign) BOOL ready;
/// 从广告开始加载到加载成功或加载失败的时间间隔
@property (nonatomic, strong) MPStopwatch *loadStopwatch;

@end

@implementation MobiInterstitialManager

- (instancetype)initWithPosid:(NSString *)posid delegate:(id<MobiInterstitialManagerDelegate>)delegate {
    if (self = [super init]) {
        _posid = [posid copy];
        _communicator = [[MobiAdConfigServer alloc] initWithDelegate:self];
        _delegate = delegate;
        _loadStopwatch = MPStopwatch.new;
    }

    return self;
}

- (void)dealloc {
    [_communicator cancel];
}

/**
* 加载信息流广告
* @param userId 用户的唯一标识
* @param targeting 精准广告投放的一些参数,可为空
*/
- (void)loadInterstitialAdWithUserId:(NSString *)userId targeting:(MobiAdTargeting *)targeting {
    //    MPLogAdEvent(MPLogEvent.adLoadAttempt, self.posid);
    // 若视频广告已经准备好展示了,我们就告诉上层加载完毕;若当前ad manager正在展示视频广告,则继续请求视频广告资源
    if (self.ready && !self.playedAd) {
        // 若已经有广告了,就不需要再绑定userid了,因为有可能这个广告已经绑定了旧的userid.
        [self.delegate unifiedInterstitialSuccessToLoadAdForManager:self];
    } else {
        // 这里设置userid会覆盖我们之前设置的userid,在其他广告展示时我们会用这个新的userid
        self.userId = userId;
        self.targeting = targeting;
        [self loadAdWithURL:[MobiAdServerURLBuilder URLWithAdPosid:self.posid targeting:targeting]];
    }
}

/**
 * 判断这个ad manager下的广告是否是有效且可以直接展示的
 */
- (BOOL)hasAdAvailable {
    // 广告未准备好,或已经过期
    if (!self.ready) {
        return NO;
    }
    
    // 若正在展示广告,则返回No,因为我们不允许同时播放两个视频广告
    if (self.playedAd) {
        return NO;
    }
    
    // 让adapter从Custom evnet中得知这个广告是否有效
    return [self.adapter hasAdAvailable];
}

/**
 * 在出现多个广告单元调用同一个广告平台展示广告时,我们要通知custom event类,它们的广告已经失效,当前已经有正在播放的广告
 * 当然广告失效后需要回调`[-nativeExpressAdDidExpireForAdManager:]`方法告诉用户这个广告已不再有效
 */
- (void)handleAdPlayedForCustomEventNetwork {
    // 只有在广告已经准备好展示时,告诉后台广告平台做相应处理
    if (self.ready) {
        [self.adapter handleAdPlayedForCustomEventNetwork];
    }
}

/**
 *  弹出信息流广告
 *  @param rootViewController 用来弹出信息流广告的根视图
 */
- (void)showInterstitialAdFromViewController:(UIViewController *)rootViewController {
//    MPLogAdEvent(MPLogEvent.adShowAttempt, self.adUnitId);

    // 若广告没准备好,则不展示
    if (!self.ready) {
        NSError *error = [NSError errorWithDomain:MobiInterstitialAdsSDKDomain code:MobiInterstitialAdErrorNoAdReady userInfo:@{ NSLocalizedDescriptionKey: @"Rewarded video ad view is not ready to be shown"}];
        //        MPLogInfo(@"%@ error: %@", NSStringFromSelector(_cmd), error.localizedDescription);
        [self.delegate unifiedInterstitialFailToPresentForManager:self error:error];
        return;
    }
    
    // 若当前正在展示广告,则不展示这个广告,激励视频每次只能展示一个
    if (self.playedAd) {
        NSError *error = [NSError errorWithDomain:MobiInterstitialAdsSDKDomain code:MobiInterstitialAdErrorAdAlreadyPlayed userInfo:nil];
        [self.delegate unifiedInterstitialFailToPresentForManager:self error:error];
        return;
    }
    
    // 通过adapter调用custom event执行广告展示
    [self.adapter showInterstitialAdFromViewController:rootViewController];

}

// MARK: - Private
- (void)loadAdWithURL:(NSURL *)URL {
    self.playedAd = NO;

    if (self.loading) {
//        MPLogEvent([MPLogEvent error:NSError.adAlreadyLoading message:nil]);
        return;
    }

    self.loading = YES;
    self.mostRecentlyLoadedURL = URL;
    [self.communicator loadURL:URL];
}

- (void)fetchAdWithConfiguration:(MobiConfig *)configuration {
//    MPLogInfo(@"Rewarded video ad is fetching ad type: %@", configuration.adType);

    if (configuration.adUnitWarmingUp) {
//        MPLogInfo(kMPWarmingUpErrorLogFormatWithAdUnitID, self.adUnitId);
        self.loading = NO;
        NSError *error = [NSError errorWithDomain:MobiInterstitialAdsSDKDomain code:MobiInterstitialAdErrorAdUnitWarmingUp userInfo:nil];
        [self.delegate unifiedInterstitialFailToLoadAdForManager:self error:error];
        return;
    }

    if (configuration.adType == MobiAdTypeUnknown) {
//        MPLogInfo(kMPClearErrorLogFormatWithAdUnitID, self.adUnitId);
        self.loading = NO;
        NSError *error = [NSError errorWithDomain:MobiInterstitialAdsSDKDomain code:MobiInterstitialAdErrorNoAdsAvailable userInfo:nil];
        [self.delegate unifiedInterstitialFailToLoadAdForManager:self error:error];
        return;
    }

    // 告诉服务器马上要加载广告了
//    [self.communicator sendBeforeLoadUrlWithConfiguration:configuration];

    // 开始加载计时
    [self.loadStopwatch start];

    MobiInterstitialAdapter *adapter = [[MobiInterstitialAdapter alloc] initWithDelegate:self];

    if (adapter == nil) {
        // 提示应用未知错误
        NSError *error = [NSError errorWithDomain:MobiInterstitialAdsSDKDomain code:MobiInterstitialAdErrorUnknown userInfo:nil];
        [self.delegate unifiedInterstitialFailToLoadAdForManager:self error:error];
        return;
    }

    self.adapter = adapter;
    // 让adapter找到合适的custom event请求拉取视频广告
    [self.adapter getAdWithConfiguration:configuration targeting:self.targeting];
}

// MARK: - MobiAdConfigServerDelegate
/// 请求服务器拉取广告配置成功的回调
- (void)communicatorDidReceiveAdConfigurations:(NSArray<MobiConfig *> *)configurations {
    self.remainingConfigurations = [configurations mutableCopy];
    self.configuration = [self.remainingConfigurations removeFirst];

    // There are no configurations to try. Consider this a clear response by the server.
    // 若没拉回来广告配置,则可能是kAdTypeClear类型(暂时没广告)
    if (self.remainingConfigurations.count == 0 && self.configuration == nil) {
//        MPLogInfo(kMPClearErrorLogFormatWithAdUnitID, self.adUnitId);
        self.loading = NO;
        NSError *error = [NSError errorWithDomain:MobiInterstitialAdsSDKDomain code:MobiInterstitialAdErrorNoAdsAvailable userInfo:nil];
        [self.delegate unifiedInterstitialFailToLoadAdForManager:self error:error];
        return;
    }

    [self fetchAdWithConfiguration:self.configuration];
}

- (void)communicatorDidFailWithError:(NSError *)error {
    self.ready = NO;
    self.loading = NO;

    [self.delegate unifiedInterstitialFailToLoadAdForManager:self error:error];
}

- (BOOL)isFullscreenAd {
    return YES;
}

- (NSString *)adUnitId {
    return self.posid;
}

// MARK: - MobiInterstitialAdapterDelegate
/**
 *  插屏2.0广告预加载成功回调
 *  当接收服务器返回的广告数据成功且预加载后调用该函数
 */
- (void)unifiedInterstitialSuccessToLoadAdForAdapter:(MobiInterstitialAdapter *)adapter {
    self.remainingConfigurations = nil;
    self.ready = YES;
    self.loading = NO;
    
    // 记录该广告从开始加载,到加载完成的时长,并上报
    NSTimeInterval duration = [self.loadStopwatch stop];
//    [self.communicator sendAfterLoadUrlWithConfiguration:self.configuration adapterLoadDuration:duration adapterLoadResult:MPAfterLoadResultAdLoaded];
    
    //    MPLogAdEvent(MPLogEvent.adDidLoad, self.adUnitId);
    [self.delegate unifiedInterstitialSuccessToLoadAdForManager:self];
}

/**
 *  插屏2.0广告预加载失败回调
 *  当接收服务器返回的广告数据失败后调用该函数
 */
- (void)unifiedInterstitialFailToLoadAdForAdapter:(MobiInterstitialAdapter *)adapter error:(NSError *)error {
    // 记录加载失败的时长,并在MobiAdConfigServer中判断选择合适URL上报失败日志
    NSTimeInterval duration = [self.loadStopwatch stop];
//    MPAfterLoadResult result = (error.isAdRequestTimedOutError ? MPAfterLoadResultTimeout : (adapter == nil ? MPAfterLoadResultMissingAdapter : MPAfterLoadResultError));
//    [self.communicator sendAfterLoadUrlWithConfiguration:self.configuration adapterLoadDuration:duration adapterLoadResult:result];

    // 若请求拉取下来多个配置,则尝试用不同配置拉取一下广告
    if (self.remainingConfigurations.count > 0) {
        // 取出配置后就把这个配置从配置数组中删除了
        self.configuration = [self.remainingConfigurations removeFirst];
        [self fetchAdWithConfiguration:self.configuration];
    } else {
        // 若没有广告配置可用,也没有备用url可拉取广告配置,则提示没有广告
        self.ready = NO;
        self.loading = NO;
        NSString *errorDescription = [NSString stringWithFormat:@"There are no ads of this posid = %@", self.adUnitId];
        NSError * clearResponseError = [NSError errorWithDomain:MobiInterstitialAdsSDKDomain
                                                           code:MobiInterstitialAdErrorNoAdsAvailable
                                                       userInfo:@{NSLocalizedDescriptionKey: errorDescription}];
        //        MPLogAdEvent([MPLogEvent adFailedToLoadWithError:clearResponseError], self.adUnitId);
        [self.delegate unifiedInterstitialFailToLoadAdForManager:self error:error];
    }
}

/**
 *  插屏2.0广告将要展示回调
 *  插屏2.0广告即将展示回调该函数
 */
- (void)unifiedInterstitialWillPresentScreenForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialWillPresentScreenForManager:self];
}

/**
 *  插屏2.0广告视图展示成功回调
 *  插屏2.0广告展示成功回调该函数
 */
- (void)unifiedInterstitialDidPresentScreenForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialDidPresentScreenForManager:self];
}

/**
 *  插屏2.0广告视图展示失败回调
 *  插屏2.0广告展示失败回调该函数
 */
- (void)unifiedInterstitialFailToPresentForAdapter:(MobiInterstitialAdapter *)adapter error:(NSError *)error {
    // 若视频播放失败,则立即重置激励视频状态,保证下一个广告可以正常播放
    self.ready = NO;
    self.playedAd = NO;

    [self.delegate unifiedInterstitialFailToPresentForManager:self error:error];
}

/**
 *  插屏2.0广告展示结束回调
 *  插屏2.0广告展示结束回调该函数
 */
- (void)unifiedInterstitialDidDismissScreenForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialDidDismissScreenForManager:self];
}

/**
 *  当点击下载应用时会调用系统程序打开其它App或者Appstore时回调
 */
- (void)unifiedInterstitialWillLeaveApplicationForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialWillLeaveApplicationForManager:self];
}

/**
 *  插屏2.0广告曝光回调
 */
- (void)unifiedInterstitialWillExposureForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialWillExposureForManager:self];
}

/**
 *  插屏2.0广告点击回调
 */
- (void)unifiedInterstitialClickedForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialClickedForManager:self];
}

/**
 *  点击插屏2.0广告以后即将弹出全屏广告页
 */
- (void)unifiedInterstitialAdWillPresentFullScreenModalForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialAdWillPresentFullScreenModalForManager:self];
}

/**
 *  点击插屏2.0广告以后弹出全屏广告页
 */
- (void)unifiedInterstitialAdDidPresentFullScreenModalForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialAdDidPresentFullScreenModalForManager:self];
}

/**
 *  全屏广告页将要关闭
 */
- (void)unifiedInterstitialAdWillDismissFullScreenModalForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialAdWillDismissFullScreenModalForManager:self];
}

/**
 *  全屏广告页被关闭
 */
- (void)unifiedInterstitialAdDidDismissFullScreenModalForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialAdDidDismissFullScreenModalForManager:self];
}

/**
 * 当一个posid加载完的开屏广告资源失效时(过期),回调此方法
 */
- (void)unifiedInterstitialAdDidExpireForAdapter:(MobiInterstitialAdapter *)adapter {
    self.ready = NO;
    [self.delegate unifiedInterstitialAdDidExpireForManager:self];
}

/**
 * 插屏2.0视频广告 player 播放状态更新回调
 */
- (void)unifiedInterstitialAdForAdapter:(MobiInterstitialAdapter *)adapter playerStatusChanged:(MobiMediaPlayerStatus)status {
    [self.delegate unifiedInterstitialAdForManager:self playerStatusChanged:status];
}

/**
 * 插屏2.0视频广告详情页 WillPresent 回调
 */
- (void)unifiedInterstitialAdViewWillPresentVideoVCForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialWillPresentScreenForManager:self];
}

/**
 * 插屏2.0视频广告详情页 DidPresent 回调
 */
- (void)unifiedInterstitialAdViewDidPresentVideoVCForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialAdViewDidPresentVideoVCForManager:self];
}

/**
 * 插屏2.0视频广告详情页 WillDismiss 回调
 */
- (void)unifiedInterstitialAdViewWillDismissVideoVCForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialAdViewDidDismissVideoVCForManager:self];
}

/**
 * 插屏2.0视频广告详情页 DidDismiss 回调
 */
- (void)unifiedInterstitialAdViewDidDismissVideoVCForAdapter:(MobiInterstitialAdapter *)adapter {
    [self.delegate unifiedInterstitialAdViewDidDismissVideoVCForManager:self];
}

@end
