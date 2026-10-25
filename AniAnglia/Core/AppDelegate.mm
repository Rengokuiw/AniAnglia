//
//  AppDelegate.m
//  iOSAnixart
//
//  Created by Toilettrauma on 16.08.2024.
//

#import "AppDelegate.h"
#import "AppDataController.h"
#import "LibanixartApi.h"
#import "StringCvt.h"
#import "MainWindow.h"

#import <AVFoundation/AVFoundation.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    // setup audio
    AVAudioSession* audio_sess = [AVAudioSession sharedInstance];
    [audio_sess setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audio_sess setActive:NO error:nil];
    
    if (@available(iOS 13.0, *)) {
        // Managed by SceneDelegate
    } else {
        self.window = [[MainWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [self.window makeKeyAndVisible];
        
        NSString *lastCrash = [[NSUserDefaults standardUserDefaults] stringForKey:@"AniAngliaLastCrash"];
        if (lastCrash.length > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Краш приложения" message:lastCrash preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Скопировать" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    [UIPasteboard generalPasteboard].string = lastCrash;
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AniAngliaLastCrash"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }]];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AniAngliaLastCrash"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }]];
                UIViewController *rootVC = self.window.rootViewController;
                while (rootVC.presentedViewController) {
                    rootVC = rootVC.presentedViewController;
                }
                [rootVC presentViewController:alert animated:YES completion:nil];
            });
        }
    }
    
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options API_AVAILABLE(ios(13.0)) {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions API_AVAILABLE(ios(13.0)) {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
