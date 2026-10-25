//
//  PlayerViewController.m
//  iOSAnixart
//
//  Created by Toilettrauma on 07.10.2024.
//

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import "PlayerViewController.h"
#import "AppColor.h"
#import "LibanixartApi.h"
#import "StringCvt.h"

@interface SeekIndicatorView : UIView
@property (nonatomic, strong) UILabel *label;
- (void)showInView:(UIView *)parentView isForward:(BOOL)isForward;
@end

@implementation SeekIndicatorView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
        self.layer.masksToBounds = YES;
        self.userInteractionEnabled = NO;
        self.alpha = 0.0;
        
        _label = [[UILabel alloc] initWithFrame:self.bounds];
        _label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _label.textAlignment = NSTextAlignmentCenter;
        _label.textColor = [UIColor whiteColor];
        _label.font = [UIFont boldSystemFontOfSize:16];
        [self addSubview:_label];
    }
    return self;
}

- (void)showInView:(UIView *)parentView isForward:(BOOL)isForward {
    [parentView addSubview:self];
    
    CGFloat pw = parentView.bounds.size.width;
    CGFloat ph = parentView.bounds.size.height;
    CGFloat size = 80.0;
    CGFloat cx = isForward ? (pw * 0.75) : (pw * 0.25);
    CGFloat cy = ph * 0.5;
    
    self.frame = CGRectMake(cx - size / 2.0, cy - size / 2.0, size, size);
    self.layer.cornerRadius = size / 2.0;
    self.label.frame = self.bounds;
    self.label.text = isForward ? @"+10с ▶▶" : @"◀◀ -10с";
    
    [self.layer removeAllAnimations];
    self.transform = CGAffineTransformMakeScale(0.7, 0.7);
    self.alpha = 0.0;
    
    [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.alpha = 1.0;
        self.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        if (finished) {
            [UIView animateWithDuration:0.25 delay:0.35 options:UIViewAnimationOptionCurveEaseIn animations:^{
                self.alpha = 0.0;
                self.transform = CGAffineTransformMakeScale(1.15, 1.15);
            } completion:^(BOOL fin) {
                if (fin) {
                    [self removeFromSuperview];
                }
            }];
        }
    }];
}

@end

@interface PlayerViewController : AVPlayerViewController <UIGestureRecognizerDelegate> {
    UITapGestureRecognizer *_doubleTapGesture;
    SeekIndicatorView *_indicatorView;
}
- (void)seekByDelta:(Float64)delta;
@end

@implementation PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _indicatorView = [[SeekIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 80, 80)];
    
    _doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    _doubleTapGesture.numberOfTapsRequired = 2;
    _doubleTapGesture.numberOfTouchesRequired = 1;
    _doubleTapGesture.delegate = self;
    [self.view addGestureRecognizer:_doubleTapGesture];
    
    [self setupRemoteCommandCenter];
}

- (void)setupRemoteCommandCenter {
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    [commandCenter.skipBackwardCommand removeTarget:nil];
    [commandCenter.skipForwardCommand removeTarget:nil];
    
    commandCenter.skipBackwardCommand.enabled = YES;
    commandCenter.skipBackwardCommand.preferredIntervals = @[@10];
    __weak PlayerViewController *weakSelf = self;
    [commandCenter.skipBackwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        MPSkipIntervalCommandEvent *skipEvent = (MPSkipIntervalCommandEvent *)event;
        Float64 interval = (skipEvent.interval > 0) ? skipEvent.interval : 10.0;
        [weakSelf seekByDelta:-interval];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    commandCenter.skipForwardCommand.enabled = YES;
    commandCenter.skipForwardCommand.preferredIntervals = @[@10];
    [commandCenter.skipForwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        MPSkipIntervalCommandEvent *skipEvent = (MPSkipIntervalCommandEvent *)event;
        Float64 interval = (skipEvent.interval > 0) ? skipEvent.interval : 10.0;
        [weakSelf seekByDelta:interval];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self configureSingleTapGesturesInView:self.view];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self configureSingleTapGesturesInView:self.view];
}

- (void)configureSingleTapGesturesInView:(UIView *)rootView {
    for (UIGestureRecognizer *gr in rootView.gestureRecognizers) {
        if ([gr isKindOfClass:[UITapGestureRecognizer class]]) {
            UITapGestureRecognizer *tgr = (UITapGestureRecognizer *)gr;
            if (tgr.numberOfTapsRequired == 1 && tgr != _doubleTapGesture) {
                [tgr requireGestureRecognizerToFail:_doubleTapGesture];
            }
        }
    }
    for (UIView *sub in rootView.subviews) {
        [self configureSingleTapGesturesInView:sub];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer == _doubleTapGesture) {
        UIView *v = touch.view;
        while (v && v != self.view) {
            if ([v isKindOfClass:[UIControl class]]) {
                return NO;
            }
            v = v.superview;
        }
    }
    return YES;
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    
    CGPoint loc = [gesture locationInView:self.view];
    CGFloat width = self.view.bounds.size.width;
    BOOL isForward = (loc.x >= (width / 2.0));
    Float64 delta = isForward ? 10.0 : -10.0;
    
    [self seekByDelta:delta];
    [_indicatorView showInView:self.view isForward:isForward];
}

- (void)seekByDelta:(Float64)delta {
    AVPlayer *p = self.player;
    if (!p) return;
    
    CMTime current = p.currentTime;
    if (CMTIME_IS_INVALID(current)) return;
    Float64 curSeconds = CMTimeGetSeconds(current);
    Float64 targetSeconds = curSeconds + delta;
    if (targetSeconds < 0.0) targetSeconds = 0.0;
    
    AVPlayerItem *item = p.currentItem;
    if (item && CMTIME_IS_VALID(item.duration) && item.duration.timescale > 0) {
        Float64 dur = CMTimeGetSeconds(item.duration);
        if (dur > 0 && targetSeconds > dur) {
            targetSeconds = dur;
        }
    }
    
    CMTime targetTime = CMTimeMakeWithSeconds(targetSeconds, NSEC_PER_SEC);
    CMTime tolerance = (targetSeconds <= 0.0) ? kCMTimeZero : CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC);
    [p seekToTime:targetTime toleranceBefore:tolerance toleranceAfter:tolerance completionHandler:nil];
}

@end

@interface PlayerController ()
@property(atomic) anixart::ReleaseID release_id;
@property(atomic) anixart::EpisodeSourceID source_id;
@property(atomic) long source_position;
@property(nonatomic, retain) LibanixartApi* api_proxy;
@property(nonatomic) std::unordered_map<std::string, std::string> streams_arr;
@property(nonatomic, retain) NSURL* selected_stream_url;
@property(nonatomic, weak) PlayerViewController* player_view_controller;
@property(nonatomic, retain) AVPictureInPictureController* pip_controller;
@property(nonatomic) BOOL just_restored_pip;

@end

static const std::string_view preferred_quality = "720";
static inline std::string choose_quality(const std::unordered_map<std::string, std::string>& quals, const std::string_view preferred) {
    if (quals.empty()) {
        return "";
    }
    
    std::string pref_str(preferred.data(), preferred.size());
    // Direct match check without triggering hash
    for (const auto& item : quals) {
        if (item.first == pref_str) {
            return item.second;
        }
    }
    
    // Fallback: pick highest numeric quality, or the first available stream
    long best_quality = -1;
    std::string best_url;
    for (const auto& item : quals) {
        long q_val = strtol(item.first.c_str(), nullptr, 10);
        if (q_val > best_quality || best_url.empty()) {
            best_quality = q_val;
            best_url = item.second;
        }
    }
    return best_url;
}

@implementation PlayerController

-(instancetype)init {
    self = [super init];
    
    _release_id = static_cast<anixart::ReleaseID>(-1);
    _source_id = static_cast<anixart::EpisodeSourceID>(-1);
    _source_position = -1;
    _api_proxy = [LibanixartApi sharedInstance];
    [self setupLayout];
    
    return self;
}

-(void)loadStreamsAndAutoPlay:(BOOL)auto_play completion:(void(^)(BOOL errored))completion_handler {
    __block BOOL stream_founded = NO;
    [_api_proxy performAsyncBlock:^BOOL(anixart::Api* api){
        @try {
            try {
                auto ep_target = self->_api_proxy.api->episodes().get_episode_target(self->_release_id, self->_source_id, static_cast<int32_t>(self->_source_position));
                if (!ep_target || ep_target->url.empty()) {
                    stream_founded = NO;
                    return YES;
                }
                self->_streams_arr = self->_api_proxy.parsers->extract_info(ep_target->url);
                auto selected_stream = choose_quality(self->_streams_arr, preferred_quality);
                if (!selected_stream.empty()) {
                    self->_selected_stream_url = [NSURL URLWithString:TO_NSSTRING(selected_stream)];
                    stream_founded = YES;
                } else {
                    stream_founded = NO;
                }
                return YES;
            } catch (const std::exception& e) {
                NSLog(@"[PlayerController] C++ exception loading stream: %s", e.what());
                stream_founded = NO;
                return YES;
            } catch (...) {
                NSLog(@"[PlayerController] Unknown C++ exception loading stream");
                stream_founded = NO;
                return YES;
            }
        } @catch (NSException *ex) {
            NSLog(@"[PlayerController] Exception loading stream: %@", ex);
            stream_founded = NO;
            return YES;
        }
    } withUICompletion:^{
        completion_handler(!stream_founded);
        if (!stream_founded) {
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"app.player.stream_not_found_error.title", "") message:NSLocalizedString(@"app.player.stream_not_found_error.message", "") preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* default_action = [UIAlertAction actionWithTitle:NSLocalizedString(@"app.player.stream_not_found_error.default_action.text", "") style:UIAlertActionStyleDefault
               handler:^(UIAlertAction * action) {
                [self->_player_view_controller dismissViewControllerAnimated:YES completion:nil];
            }];
            [alert addAction:default_action];
            [self showViewController:alert];
            return;
        }
        if (auto_play) {
            [self runPlayer];
        }
    }];
}

-(void)playWithReleaseID:(anixart::ReleaseID)release_id sourceID:(anixart::EpisodeSourceID)source_id position:(long)position autoShow:(BOOL)auto_show completion:(void(^)(BOOL errored))completion_handler {
    _release_id = release_id;
    _source_id = source_id;
    _source_position = position;
    
    if (_player_view_controller) {
        _player_view_controller.player = nil;
    }
    
    PlayerViewController* player_view_controller = [PlayerViewController new];
    [player_view_controller setDelegate:self];
    player_view_controller.modalPresentationStyle = UIModalPresentationFullScreen;
    
    _player_view_controller = player_view_controller;
    
    [_pip_controller setDelegate:self];
    [self loadStreamsAndAutoPlay:YES completion:completion_handler];
    if (auto_show) {
        [self showViewController:player_view_controller];
    }
}

-(void)showAndRunPlayer {
    [self showViewController:_player_view_controller];
    [self runPlayer];
}

-(void)showViewController:(UIViewController*)view_controller {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [[UIApplication sharedApplication].delegate window];
    UIViewController* top_view_controller = window.rootViewController;
    while (top_view_controller.presentedViewController) {
        top_view_controller = top_view_controller.presentedViewController;
    }
    if (top_view_controller.isBeingPresented || top_view_controller.isBeingDismissed) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showViewController:view_controller];
        });
        return;
    }
    @try {
        [top_view_controller presentViewController:view_controller animated:NO completion:nil];
    } @catch (NSException *ex) {
        NSLog(@"[PlayerController] Exception in showViewController: %@", ex);
    }
}

-(void)playWithURL:(NSURL*)url {
    _selected_stream_url = url;
    [self runPlayer];
}

-(void)runPlayer {
    if (!_selected_stream_url) return;
    _player_view_controller.player = [AVPlayer playerWithURL:_selected_stream_url];
    [_player_view_controller.player play];
    
    _player_view_controller.view.backgroundColor = [UIColor blackColor];
    
    if ([_player_view_controller.player.currentItem respondsToSelector:@selector(setExternalMetadata:)]) {
        AVMutableMetadataItem* title = [AVMutableMetadataItem new];
        title.identifier = AVMetadataCommonIdentifierTitle;
        title.value = @"YO";
        title.extendedLanguageTag = @"und";
        AVMutableMetadataItem* desc = [AVMutableMetadataItem new];
        desc.identifier = AVMetadataCommonIdentifierArtist;
        desc.value = @"HO";
        desc.extendedLanguageTag = @"und";
        _player_view_controller.player.currentItem.externalMetadata = @[
            title,
            desc
        ];
    }
}

-(void)setupLayout {
//    _player_view_controller.view.backgroundColor = [AppColorProvider backgroundColor];
}

-(AVPlayerViewController*)getPlayer {
    return _player_view_controller;
}

+(instancetype)sharedInstance {
    static PlayerController* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [PlayerController new];
    });
    return sharedInstance;
}

-(void)playerViewControllerWillStartPictureInPicture:(AVPlayerViewController*)player_view_controller{

}
-(void)playerViewControllerDidStopPictureInPicture:(AVPlayerViewController*)player_view_controller {
    if (!_just_restored_pip) {
        _player_view_controller.player = nil;
    }
    _just_restored_pip = false;
}

-(void)playerViewController:(AVPlayerViewController *)player_view_controller restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completion_handler {
    /* cancelled by PlayerController */
    _just_restored_pip = true;
    if (!player_view_controller.player) {
        completion_handler(YES);
        return;
    }
    [self showViewController:player_view_controller];
//    completion_handler(YES);
}

@end
