//
//  MainWindow.h
//  AniAnglia
//
//  Created by Toilettrauma on 05.04.2025.
//

#ifndef MainWindow_h
#define MainWindow_h

#import <UIKit/UIKit.h>

@interface MainWindow : UIWindow

-(instancetype)initWithFrame:(CGRect)frame;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
-(instancetype)initWithWindowScene:(UIWindowScene*)scene API_AVAILABLE(ios(13.0));
#endif

-(void)setRootViewController:(UIViewController*)root_view_controller;

@end

#endif /* MainWindow_h */
