//
//  MEKSAdapter.m
//  MEAdvSDK
//
//  Created by 刘峰 on 2020/4/9.
//

#import "MEKSAdapter.h"
#import <KSAdSDK/KSAdSDK.h>

@interface MEKSAdapter ()<KSRewardedVideoAdDelegate, KSAdSplashInteractDelegate, KSFeedAdsManagerDelegate, KSFeedAdDelegate, KSFullscreenVideoAdDelegate>

/// 激励视频对象
@property (nonatomic, strong) KSRewardedVideoAd *rewardedAd;
/// 全屏视频广告
@property (nonatomic, strong) KSFullscreenVideoAd *fullscreenVideoAd;
/// 判断激励视频是否能给奖励,每次关闭视频变false
@property (nonatomic, assign) BOOL isEarnRewarded;

@property (nonatomic, strong) UIViewController *rootVc;

/// 信息流广告控制器
@property (nonatomic, strong) KSFeedAdsManager *feedAdsManager;

/// 是否展示误点按钮
@property (nonatomic, assign) BOOL showFunnyBtn;
/// 是否需要展示
@property (nonatomic, assign) BOOL needShow;

@end

@implementation MEKSAdapter

// MARK: - override
+ (instancetype)sharedInstance {
    static MEKSAdapter *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MEKSAdapter alloc] init];
    });
    return sharedInstance;
}

+ (void)launchAdPlatformWithAppid:(NSString *)appid {
    // 快手初始化
    [KSAdSDKManager setAppId:appid];
    // 根据需要设置⽇志级别
    [KSAdSDKManager setLoglevel:KSAdSDKLogLevelOff];
}

- (NSString *)networkName {
    return @"ks";
}

/// 获取广告平台类型
- (MEAdAgentType)platformType{
    return MEAdAgentTypeKS;
}

// MARK: - 激励视频广告
- (BOOL)loadRewardVideoWithPosid:(NSString *)posid {
    self.posid = posid;
    self.isEarnRewarded = false;
    
    self.rewardedAd = nil;
    self.needShow = YES;
    
    if ([self hasRewardedVideoAvailableWithPosid:posid]) {
        self.rewardedAd.delegate = self;
        [self.rewardedAd loadAdData];
    } else {
        self.rewardedAd = [[KSRewardedVideoAd alloc] initWithPosId:self.posid rewardedVideoModel:[KSRewardedVideoModel new]];
        self.rewardedAd.delegate = self;
        [self.rewardedAd loadAdData];
    }
    
    return YES;
}

- (void)showRewardedVideoFromViewController:(UIViewController *)rootVC posid:(NSString *)posid {
    if (rootVC != nil) {
        self.rootVc = rootVC;
    }
    
    if (self.isTheVideoPlaying == NO && self.rewardedAd.isValid) {
        self.needShow = YES;
        [self.rewardedAd showAdFromRootViewController:rootVC showScene:@"" type:KSRewardedVideoAdRewardedTypeNormal];
    }
}

/// 结束当前视频
- (void)stopCurrentVideoWithPosid:(NSString *)posid {
    self.needShow = NO;
    if (self.rewardedAd.isValid) {
        if (self.rootVc) {
            [self.rootVc dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

- (BOOL)hasRewardedVideoAvailableWithPosid:(NSString *)posid {
    return self.rewardedAd.isValid;
}

#pragma mark - KSRewardedVideoAdDelegate
- (void)rewardedVideoAdDidLoad:(KSRewardedVideoAd *)rewardedVideoAd {
    // 这里表示广告素材已经准备好了,下面的代理rewardedVideoAdVideoDidLoad表示可以播放了
    if (self.needShow && self.videoDelegate && [self.videoDelegate respondsToSelector:@selector(adapterVideoLoadSuccess:)]) {
        [self.videoDelegate adapterVideoLoadSuccess:self];
    }
    // 上报日志
    MEAdLogModel *model = [MEAdLogModel new];
    model.event = AdLogEventType_Load;
    model.st_t = AdLogAdType_RewardVideo;
    model.so_t = self.sortType;
    model.posid = self.sceneId;
    model.network = self.networkName;
    model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
    // 先保存到数据库
    [MEAdLogModel saveLogModelToRealm:model];
    // 立即上传
    [MEAdLogModel uploadImmediately];
}

- (void)rewardedVideoAd:(KSRewardedVideoAd *)rewardedVideoAd didFailWithError:(NSError *_Nullable)error {
    self.rootVc = nil;
    
    // 视频广告加载失败
    if (self.needShow) {
        self.isTheVideoPlaying = NO;
        if (self.videoDelegate && [self.videoDelegate respondsToSelector:@selector(adapter:videoShowFailure:)]) {
            [self.videoDelegate adapter:self videoShowFailure:error];
        }
    }
    
    // 上报日志
    MEAdLogModel *model = [MEAdLogModel new];
    model.event = AdLogEventType_Fault;
    model.st_t = AdLogAdType_RewardVideo;
    model.so_t = self.sortType;
    model.posid = self.sceneId;
    model.network = self.networkName;
    model.type = AdLogFaultType_Normal;
    model.code = error.code;
    if (error.localizedDescription != nil || error.localizedDescription.length > 0) {
        model.msg = error.localizedDescription;
    }
    model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
    // 先保存到数据库
    [MEAdLogModel saveLogModelToRealm:model];
    // 立即上传
    [MEAdLogModel uploadImmediately];
}

- (void)rewardedVideoAdVideoDidLoad:(KSRewardedVideoAd *)rewardedVideoAd {
    if (self.needShow) {
        if (self.videoDelegate && [self.videoDelegate respondsToSelector:@selector(adapterVideoDidDownload:)]) {
            [self.videoDelegate adapterVideoDidDownload:self];
        }
    }
    // 这里能获取到ecpm
    NSInteger ecpm = rewardedVideoAd.ecpm;
    DLog(@"ecpm:%zd", (long)ecpm);
}

- (void)rewardedVideoAdWillVisible:(KSRewardedVideoAd *)rewardedVideoAd {
    // 视频即将播放
    self.isTheVideoPlaying = YES;
    if (self.videoDelegate && [self.videoDelegate respondsToSelector:@selector(adapterVideoShowSuccess:)]) {
        [self.videoDelegate adapterVideoShowSuccess:self];
    }
    
    // 上报日志
    MEAdLogModel *model = [MEAdLogModel new];
    model.event = AdLogEventType_Show;
    model.st_t = AdLogAdType_RewardVideo;
    model.so_t = self.sortType;
    model.posid = self.sceneId;
    model.network = self.networkName;
    model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
    // 先保存到数据库
    [MEAdLogModel saveLogModelToRealm:model];
    // 立即上传
    [MEAdLogModel uploadImmediately];
}

- (void)rewardedVideoAdWillClose:(KSRewardedVideoAd *)rewardedVideoAd {
    self.isTheVideoPlaying = NO;
    self.needShow = NO;
    // 预加载
    [self.rewardedAd loadAdData];
    
    // 若没达到奖励条件,则不给回调
    if (self.isEarnRewarded == false) {
        return;
    }
    
    if (self.videoDelegate && [self.videoDelegate respondsToSelector:@selector(adapterVideoClose:)]) {
        [self.videoDelegate adapterVideoClose:self];
    }
    
    // 变回默认的不给奖励
    self.isEarnRewarded = false;
}

- (void)rewardedVideoAdDidClose:(KSRewardedVideoAd *)rewardedVideoAd {
    self.rootVc = nil;
}

- (void)rewardedVideoAdDidClick:(KSRewardedVideoAd *)rewardedVideoAd {
    if (self.videoDelegate && [self.videoDelegate respondsToSelector:@selector(adapterVideoClicked:)]) {
        [self.videoDelegate adapterVideoClicked:self];
    }
    
    // 上报日志
    MEAdLogModel *model = [MEAdLogModel new];
    model.event = AdLogEventType_Click;
    model.st_t = AdLogAdType_RewardVideo;
    model.so_t = self.sortType;
    model.posid = self.sceneId;
    model.network = self.networkName;
    model.type = AdLogFaultType_Render;
    model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
    // 先保存到数据库
    [MEAdLogModel saveLogModelToRealm:model];
    // 立即上传
    [MEAdLogModel uploadImmediately];
}

- (void)rewardedVideoAdDidClickSkip:(KSRewardedVideoAd *)rewardedVideoAd {
    // 点击了跳过, 则不给奖励
    self.isEarnRewarded = false;
}

- (void)rewardedVideoAd:(KSRewardedVideoAd *)rewardedVideoAd hasReward:(BOOL)hasReward {
    NSString *text = [NSString stringWithFormat:@"%@,是否有奖励:%@", NSStringFromSelector(_cmd), hasReward ? @"YES" : @"NO"];
    NSLog(@"%@", text);
    // 可以给收益
    self.isEarnRewarded = hasReward;
}

// MARK: - 全屏视频广告
/// 加载全屏视频
- (BOOL)loadFullscreenWithPosid:(NSString *)posid {
    self.posid = posid;
    self.isEarnRewarded = false;
    
    self.needShow = YES;
    
    if ([self hasFullscreenVideoAvailableWithPosid:posid]) {
        self.fullscreenVideoAd.delegate = self;
        [self.fullscreenVideoAd loadAdData];
    } else {
        self.fullscreenVideoAd = [[KSFullscreenVideoAd alloc]
        initWithPosId:self.posid];
        self.fullscreenVideoAd.delegate = self;
        [self.fullscreenVideoAd loadAdData];
    }
    
    return YES;
}

/// 展示全屏视频
- (void)showFullscreenVideoFromViewController:(UIViewController *)rootVC posid:(NSString *)posid {
    if (rootVC != nil) {
        self.rootVc = rootVC;
    }
    
    if (self.isTheVideoPlaying == NO && self.fullscreenVideoAd.isValid) {
        self.needShow = YES;
        [self.fullscreenVideoAd showAdFromRootViewController:rootVC];
    }
}

/// 关闭当前视频
- (void)stopFullscreenVideoWithPosid:(NSString *)posid {
    self.needShow = NO;
    if (self.fullscreenVideoAd.isValid) {
        if (self.rootVc) {
            [self.rootVc dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

/// 全屏视频是否有效
- (BOOL)hasFullscreenVideoAvailableWithPosid:(NSString *)posid {
    return self.fullscreenVideoAd.isValid;
}

// MARK: KSFullscreenVideoAdDelegate
/**
 This method is called when video ad material loaded successfully.
 */
- (void)fullscreenVideoAdDidLoad:(KSFullscreenVideoAd *)fullscreenVideoAd {
    // 这里表示广告素材已经准备好了,下面的代理rewardedVideoAdVideoDidLoad表示可以播放了
    if (self.needShow && self.fullscreenDelegate && [self.fullscreenDelegate respondsToSelector:@selector(adapterFullscreenVideoLoadSuccess:)]) {
        [self.fullscreenDelegate adapterFullscreenVideoLoadSuccess:self];
    }
    // 上报日志
    MEAdLogModel *model = [MEAdLogModel new];
    model.event = AdLogEventType_Load;
    model.st_t = AdLogAdType_FullVideo;
    model.so_t = self.sortType;
    model.posid = self.sceneId;
    model.network = self.networkName;
    model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
    // 先保存到数据库
    [MEAdLogModel saveLogModelToRealm:model];
    // 立即上传
    [MEAdLogModel uploadImmediately];
}
/**
 This method is called when video ad materia failed to load.
 @param error : the reason of error
 */
- (void)fullscreenVideoAd:(KSFullscreenVideoAd *)fullscreenVideoAd didFailWithError:(NSError *_Nullable)error {
    self.rootVc = nil;
    self.isTheVideoPlaying = NO;
    if (self.needShow && self.fullscreenDelegate && [self.fullscreenDelegate respondsToSelector:@selector(adapter:videoShowFailure:)]) {
        [self.fullscreenDelegate adapter:self fullscreenShowFailure:error];
    }
    
    // 上报日志
    MEAdLogModel *model = [MEAdLogModel new];
    model.event = AdLogEventType_Fault;
    model.st_t = AdLogAdType_FullVideo;
    model.so_t = self.sortType;
    model.posid = self.sceneId;
    model.network = self.networkName;
    model.type = AdLogFaultType_Normal;
    model.code = error.code;
    if (error.localizedDescription != nil || error.localizedDescription.length > 0) {
        model.msg = error.localizedDescription;
    }
    model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
    // 先保存到数据库
    [MEAdLogModel saveLogModelToRealm:model];
    // 立即上传
    [MEAdLogModel uploadImmediately];
}
/**
 This method is called when cached successfully.
 */
- (void)fullscreenVideoAdVideoDidLoad:(KSFullscreenVideoAd *)fullscreenVideoAd {
    if (self.needShow && self.fullscreenDelegate && [self.fullscreenDelegate respondsToSelector:@selector(adapterFullscreenVideoDidDownload:)]) {
        [self.fullscreenDelegate adapterFullscreenVideoDidDownload:self];
    }
}
/**
 This method is called when video ad slot will be showing.
 */
- (void)fullscreenVideoAdWillVisible:(KSFullscreenVideoAd *)fullscreenVideoAd {
    self.isTheVideoPlaying = YES;
    if (self.fullscreenDelegate && [self.fullscreenDelegate respondsToSelector:@selector(adapterFullscreenVideoShowSuccess:)]) {
        [self.fullscreenDelegate adapterFullscreenVideoShowSuccess:self];
    }
}

/**
 This method is called when video ad is about to close.
 */
- (void)fullscreenVideoAdWillClose:(KSFullscreenVideoAd *)fullscreenVideoAd {
    if (self.fullscreenDelegate && [self.fullscreenDelegate respondsToSelector:@selector(adapterFullscreenVideoClose:)]) {
        [self.fullscreenDelegate adapterFullscreenVideoClose:self];
    }
    self.isTheVideoPlaying = NO;
    
    self.needShow = NO;
    [self.fullscreenVideoAd loadAdData];
}
/**
 This method is called when video ad is closed.
 */
- (void)fullscreenVideoAdDidClose:(KSFullscreenVideoAd *)fullscreenVideoAd {
    self.rootVc = nil;
}

/**
 This method is called when video ad is clicked.
 */
- (void)fullscreenVideoAdDidClick:(KSFullscreenVideoAd *)fullscreenVideoAd {
    if (self.fullscreenDelegate && [self.fullscreenDelegate respondsToSelector:@selector(adapterFullscreenVideoClicked:)]) {
        [self.fullscreenDelegate adapterFullscreenVideoClicked:self];
    }
    
    // 上报日志
    MEAdLogModel *model = [MEAdLogModel new];
    model.event = AdLogEventType_Click;
    model.st_t = AdLogAdType_FullVideo;
    model.so_t = self.sortType;
    model.posid = self.sceneId;
    model.network = self.networkName;
    model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
    // 先保存到数据库
    [MEAdLogModel saveLogModelToRealm:model];
    // 立即上传
    [MEAdLogModel uploadImmediately];
}
/**
 This method is called when video ad play completed or an error occurred.
 @param error : the reason of error
 */
- (void)fullscreenVideoAdDidPlayFinish:(KSFullscreenVideoAd *)fullscreenVideoAd didFailWithError:(NSError *_Nullable)error {
    if (error) {
        DLog(@"视频播放失败");
        self.isTheVideoPlaying = NO;
        if (self.fullscreenDelegate && [self.fullscreenDelegate respondsToSelector:@selector(adapter:fullscreenShowFailure:)]) {
            [self.fullscreenDelegate adapter:self fullscreenShowFailure:error];
        }
        
        // 上报日志
        MEAdLogModel *model = [MEAdLogModel new];
        model.event = AdLogEventType_Fault;
        model.st_t = AdLogAdType_FullVideo;
        model.so_t = self.sortType;
        model.posid = self.sceneId;
        model.network = self.networkName;
        model.type = AdLogFaultType_Render;
        model.code = error.code;
        if (error.localizedDescription != nil || error.localizedDescription.length > 0) {
            model.msg = error.localizedDescription;
        }
        model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
        // 先保存到数据库
        [MEAdLogModel saveLogModelToRealm:model];
        // 立即上传
        [MEAdLogModel uploadImmediately];
        
    } else {
        DLog(@"视频播放完毕");
        if (self.fullscreenDelegate && [self.fullscreenDelegate respondsToSelector:@selector(adapterFullscreenVideoFinishPlay:)]) {
            [self.fullscreenDelegate adapterFullscreenVideoFinishPlay:self];
        }
    }
}

/**
 This method is called when the user clicked skip button.
 */
- (void)fullscreenVideoAdDidClickSkip:(KSFullscreenVideoAd *)fullscreenVideoAd {
    if (self.fullscreenDelegate && [self.fullscreenDelegate respondsToSelector:@selector(adapterFullscreenVideoSkip:)]) {
        [self.fullscreenDelegate adapterFullscreenVideoSkip:self];
    }
}

//MARK: 开屏广告
- (void)preloadSplashWithPosid:(NSString *)posid {
    // 开屏⼴广告
    KSAdSplashManager.posId = posid;
    KSAdSplashManager.interactDelegate = self; //预加载闪屏⼴广告，可以选择延迟加载
    [KSAdSplashManager loadSplash];
    if (KSAdSplashManager.hasCachedSplash) {
        //如果有本地已缓存⼴广告，检测⼴广告是否有效，如果⼴广告有效，会返回开屏⼴广告控制器器，具体使⽤用可 ⻅见demo
        [KSAdSplashManager checkSplash:^(KSAdSplashViewController * _Nonnull splashViewController) {
            if (splashViewController) {
            }
        }];
    }
}

- (BOOL)loadAndShowSplashWithPosid:(NSString *)posid {
    return [self loadAndShowSplashWithPosid:posid delay:0 bottomView:nil];
}

- (BOOL)loadAndShowSplashWithPosid:(NSString *)posid delay:(NSTimeInterval)delay bottomView:(UIView *)view {
    
    UIViewController *vc = [self topVC];
    if (!vc || !posid) {
        return NO;
    }
    
    self.posid = posid;
    self.rootVc = vc;
    
    // 开屏⼴广告
    KSAdSplashManager.posId = posid;
    KSAdSplashManager.interactDelegate = self; //预加载闪屏⼴广告，可以选择延迟加载
    [KSAdSplashManager loadSplash];
    if (KSAdSplashManager.hasCachedSplash) {
        //如果有本地已缓存⼴广告，检测⼴广告是否有效，如果⼴广告有效，会返回开屏⼴广告控制器器，具体使⽤用可 ⻅见demo
        [KSAdSplashManager checkSplash:^(KSAdSplashViewController * _Nonnull splashViewController) {
            if (splashViewController) {
                splashViewController.modalTransitionStyle =
                UIModalTransitionStyleCrossDissolve;
                [self.rootVc presentViewController:splashViewController animated:YES completion:nil];
            }
        }];
    }
    
    return YES;
}

- (void)stopSplashRenderWithPosid:(NSString *)posid {
    [self dismissSplashViewController:NO];
}

- (void)dismissSplashViewController:(BOOL)animated {
    [self.rootVc dismissViewControllerAnimated:animated completion:nil];
}

//MARK: 交互回调
//开屏关闭
- (void)ksad_splashAdDismiss:(BOOL)converted {
    //convert为YES时需要直接隐藏掉splash，防⽌止影响后续转化⻚页⾯面展示
    [self dismissSplashViewController:!converted];
    
    if (self.splashDelegate && [self.splashDelegate respondsToSelector:@selector(adapterSplashClose:)]) {
        [self.splashDelegate adapterSplashClose:self];
    }
    DLog(@"----%@", NSStringFromSelector(_cmd));
}
//开屏跳过
- (void)ksad_splashAdVideoDidSkipped:(NSTimeInterval)playDuration {
    
    if (self.splashDelegate && [self.splashDelegate respondsToSelector:@selector(adapterSplashClose:)]) {
        [self.splashDelegate adapterSplashClose:self];
    }
    
    DLog(@"----%@:%f", NSStringFromSelector(_cmd), playDuration);
    
}
//开屏点击
- (void)ksad_splashAdClicked {
    if (self.splashDelegate && [self.splashDelegate respondsToSelector:@selector(adapterVideoClicked:)]) {
        [self.splashDelegate adapterSplashClicked:self];
    }
    
    // 上报日志
       MEAdLogModel *model = [MEAdLogModel new];
       model.event = AdLogEventType_Click;
       model.st_t = AdLogAdType_Splash;
       model.so_t = self.sortType;
       model.posid = self.sceneId;
       model.network = self.networkName;
       model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
       // 先保存到数据库
       [MEAdLogModel saveLogModelToRealm:model];
       // 立即上传
       [MEAdLogModel uploadImmediately];
    
    DLog(@"----%@", NSStringFromSelector(_cmd));
}
//开屏展示
- (void)ksad_splashAdDidShow {
    // 因快手没有给加载成功的回调,所以选择在 show 回调之前回调加载成功
    if (self.splashDelegate && [self.splashDelegate respondsToSelector:@selector(adapterSplashLoadSuccess:)]) {
        [self.splashDelegate adapterSplashLoadSuccess:self];
    }
    

    if (self.splashDelegate && [self.splashDelegate respondsToSelector:@selector(adapterSplashShowSuccess:)]) {
        [self.splashDelegate adapterSplashShowSuccess:self];
    }
    // 上报日志
    MEAdLogModel *model = [MEAdLogModel new];
    model.event = AdLogEventType_Show;
    model.st_t = AdLogAdType_Splash;
    model.so_t = self.sortType;
    model.posid = self.sceneId;
    model.network = self.networkName;
    model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
    // 先保存到数据库
    [MEAdLogModel saveLogModelToRealm:model];
    // 立即上传
    [MEAdLogModel uploadImmediately];
    
    DLog(@"----%@", NSStringFromSelector(_cmd));
}
//开屏⼴广告开始播放
- (void)ksad_splashAdVideoDidStartPlay {
    DLog(@"----%@", NSStringFromSelector(_cmd));
}
//开屏⼴广告播放失败
- (void)ksad_splashAdVideoFailedToPlay:(NSError *)error {
    
    [self dismissSplashViewController:NO];

    if (self.splashDelegate && [self.splashDelegate respondsToSelector:@selector(adapter:splashShowFailure:)]) {
        [self.splashDelegate adapter:self splashShowFailure:error];
    }
    
    // 上报日志
    MEAdLogModel *model = [MEAdLogModel new];
    model.event = AdLogEventType_Fault;
    model.st_t = AdLogAdType_Splash;
    model.so_t = self.sortType;
    model.posid = self.sceneId;
    model.network = self.networkName;
    model.type = AdLogFaultType_Normal;
    model.code = error.code;
    if (error.localizedDescription != nil || error.localizedDescription.length > 0) {
        model.msg = error.localizedDescription;
    }
    model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
    // 先保存到数据库
    [MEAdLogModel saveLogModelToRealm:model];
    // 立即上传
    [MEAdLogModel uploadImmediately];
    
    DLog(@"----%@, %@", NSStringFromSelector(_cmd), error);
    
}
//开屏⼴广告转化根控制器器，默认keyWindow.rootViewController
//- (UIViewController *)ksad_splashAdConversionRootVC {
//    return self.window.rootViewController;
//
//}

//MARK: 信息流

/// 显示信息流视图
/// @param feedWidth 广告位宽度
/// @param posId 广告位id
- (BOOL)showFeedViewWithWidth:(CGFloat)feedWidth
                        posId:(nonnull NSString *)posId count:(NSInteger)count {
    return [self showFeedViewWithWidth:feedWidth posId:posId count:count withDisplayTime:0];
}

/// 显示信息流视图
/// @param feedWidth 父视图feedWidth
/// @param posId 广告位id
/// @param displayTime 展示时长,0表示不限制时长
- (BOOL)showFeedViewWithWidth:(CGFloat)feedWidth
                        posId:(nonnull NSString *)posId
                        count:(NSInteger)count
              withDisplayTime:(NSTimeInterval)displayTime {
    
    self.needShow = YES;
    self.posid = posId;
    
    self.feedAdsManager = [[KSFeedAdsManager alloc] initWithPosId:self.posid size:CGSizeMake(feedWidth, 0)];
    self.feedAdsManager.delegate = self;
    [self.feedAdsManager loadAdDataWithCount:count];
    
    return YES;
}

- (void)removeFeedViewWithPosid:(NSString *)posid {
    self.needShow = NO;
}
   
#pragma mark - KSFeedAdsManagerDelegate
- (void)feedAdsManagerSuccessToLoad:(KSFeedAdsManager *)adsManager nativeAds: (NSArray<KSFeedAd *> *_Nullable)feedAdDataArray {
    
    NSMutableArray *expressionViews = [NSMutableArray array];
    [feedAdDataArray enumerateObjectsUsingBlock:^(KSFeedAd * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        KSFeedAd *feedAd = obj;
        feedAd.delegate = self;
        
        UIView *feedView = feedAd.feedView;
        [expressionViews addObject:feedView];
        
        // 上报日志
        MEAdLogModel *model = [MEAdLogModel new];
        model.event = AdLogEventType_Load;
        model.st_t = AdLogAdType_Feed;
        model.so_t = self.sortType;
        model.posid = self.sceneId;
        model.network = self.networkName;
        model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
        // 先保存到数据库
        [MEAdLogModel saveLogModelToRealm:model];
        // 立即上传
        [MEAdLogModel uploadImmediately];
    }];
    
    if (self.feedDelegate && [self.feedDelegate respondsToSelector:@selector(adapterFeedLoadSuccess:feedViews:)]) {
        [self.feedDelegate adapterFeedLoadSuccess:self feedViews:expressionViews];
    }
}
- (void)feedAdsManager:(KSFeedAdsManager *)adsManager didFailWithError: (NSError *_Nullable)error {
    if (self.needShow) {
        if (self.feedDelegate && [self.feedDelegate respondsToSelector:@selector(adapter:bannerShowFailure:)]) {
            [self.feedDelegate adapter:self bannerShowFailure:error];
        }
    }
    
    // 上报日志
    MEAdLogModel *model = [MEAdLogModel new];
    model.event = AdLogEventType_Fault;
    model.st_t = AdLogAdType_Feed;
    model.so_t = self.sortType;
    model.posid = self.sceneId;
    model.network = self.networkName;
    model.type = AdLogFaultType_Normal;
    model.code = error.code;
    if (error.localizedDescription != nil || error.localizedDescription.length > 0) {
        model.msg = error.localizedDescription;
    }
    model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
    // 先保存到数据库
    [MEAdLogModel saveLogModelToRealm:model];
    // 立即上传
    [MEAdLogModel uploadImmediately];
    
}
#pragma mark - KSFeedAdDelegate
- (void)feedAdViewWillShow:(KSFeedAd *)feedAd {
    
    if (self.feedDelegate && [self.feedDelegate respondsToSelector:@selector(adapterFeedShowSuccess:feedView:)]) {
        [self.feedDelegate adapterFeedShowSuccess:self feedView:feedAd.feedView];
    }
    
    // 上报日志
    MEAdLogModel *model = [MEAdLogModel new];
    model.event = AdLogEventType_Show;
    model.st_t = AdLogAdType_Feed;
    model.so_t = self.sortType;
    model.posid = self.sceneId;
    model.network = self.networkName;
    model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
    // 先保存到数据库
    [MEAdLogModel saveLogModelToRealm:model];
    // 立即上传
    [MEAdLogModel uploadImmediately];
    
}
- (void)feedAdDidClick:(KSFeedAd *)feedAd {
    
    if (self.feedDelegate && [self.feedDelegate respondsToSelector:@selector(adapterFeedClicked:)]) {
        [self.feedDelegate adapterFeedClicked:self];
    }
    
    // 上报日志
    MEAdLogModel *model = [MEAdLogModel new];
    model.event = AdLogEventType_Click;
    model.st_t = AdLogAdType_Feed;
    model.so_t = self.sortType;
    model.posid = self.sceneId;
    model.network = self.networkName;
    model.tk = [self stringMD5:[NSString stringWithFormat:@"%@%ld%@%ld", model.posid, model.so_t, @"mobi", (long)([[NSDate date] timeIntervalSince1970]*1000)]];
    // 先保存到数据库
    [MEAdLogModel saveLogModelToRealm:model];
    // 立即上传
    [MEAdLogModel uploadImmediately];
    
}
- (void)feedAdDislike:(KSFeedAd *)feedAd {
    if (self.feedDelegate && [self.feedDelegate respondsToSelector:@selector(adapterFeedClose:)]) {
        [self.feedDelegate adapterFeedClose:self];
    }
   
}
- (void)feedAdDidShowOtherController:(KSFeedAd *)nativeAd interactionType: (KSAdInteractionType)interactionType {
    
}
- (void)feedAdDidCloseOtherController:(KSFeedAd *)nativeAd interactionType: (KSAdInteractionType)interactionType {
    
}
@end
