//
//  AppUIColor.m
//  iOSAnixart
//
//  Created by Toilettrauma on 18.08.2024.
//

#import <Foundation/Foundation.h>
#import "AppColor.h"

@implementation AppDefaultDarkTheme
-(UIColor*)backgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemBackgroundColor];
    }
    return [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
}
-(UIColor*)foregroundColor1 {
    if (@available(iOS 13.0, *)) {
        return [UIColor secondarySystemBackgroundColor];
    }
    return [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
}
-(UIColor*)foregroundColor2 {
    if (@available(iOS 13.0, *)) {
        return [UIColor tertiarySystemBackgroundColor];
    }
    return [UIColor colorWithRed:0.16 green:0.16 blue:0.16 alpha:1.0];
}
-(UIColor*)primaryColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemBlueColor];
    }
    return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
}
-(UIColor*)secondaryColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemRedColor];
    }
    return [UIColor colorWithRed:1.0 green:0.231 blue:0.188 alpha:1.0];
}
-(UIColor*)alertColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemRedColor];
    }
    return [UIColor colorWithRed:1.0 green:0.231 blue:0.188 alpha:1.0];
}
-(UIColor*)successColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemGreenColor];
    }
    return [UIColor colorWithRed:0.298 green:0.851 blue:0.392 alpha:1.0];
}
-(UIColor*)idleColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemOrangeColor];
    }
    return [UIColor colorWithRed:1.0 green:0.584 blue:0.0 alpha:1.0];
}
-(UIColor*)textColor {
    return [UIColor whiteColor];
}
-(UIColor*)textSecondaryColor {
    return [UIColor lightGrayColor];
}
-(UIColor*)textShyColor {
    return [UIColor grayColor];
}
@end

@implementation AppDefaultLightTheme
-(UIColor*)backgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemBackgroundColor];
    }
    return [UIColor whiteColor];
}
-(UIColor*)foregroundColor1 {
    if (@available(iOS 13.0, *)) {
        return [UIColor secondarySystemBackgroundColor];
    }
    return [UIColor colorWithRed:0.95 green:0.95 blue:0.97 alpha:1.0];
}
-(UIColor*)foregroundColor2 {
    if (@available(iOS 13.0, *)) {
        return [UIColor tertiarySystemBackgroundColor];
    }
    return [UIColor colorWithRed:0.90 green:0.90 blue:0.92 alpha:1.0];
}
-(UIColor*)primaryColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemBlueColor];
    }
    return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
}
-(UIColor*)secondaryColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemRedColor];
    }
    return [UIColor colorWithRed:1.0 green:0.231 blue:0.188 alpha:1.0];
}
-(UIColor*)alertColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemRedColor];
    }
    return [UIColor colorWithRed:1.0 green:0.231 blue:0.188 alpha:1.0];
}
-(UIColor*)successColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemGreenColor];
    }
    return [UIColor colorWithRed:0.298 green:0.851 blue:0.392 alpha:1.0];
}
-(UIColor*)idleColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemOrangeColor];
    }
    return [UIColor colorWithRed:1.0 green:0.584 blue:0.0 alpha:1.0];
}
-(UIColor*)textColor {
    return [UIColor blackColor];
}
-(UIColor*)textSecondaryColor {
    return [UIColor darkGrayColor];
}
-(UIColor*)textShyColor {
    return [UIColor grayColor];
}
@end

struct AppThemes {
    id<AppColorTheme> light;
    id<AppColorTheme> dark;
};
@implementation AppColorProvider
static UIUserInterfaceStyle default_style = UIUserInterfaceStyleDark;
static AppThemes app_themes = {
    .light = [AppDefaultLightTheme new],
    .dark = [AppDefaultDarkTheme new]
};

+(id<AppColorTheme>)getThemeForStyle:(UIUserInterfaceStyle)style {
    auto getTheme = [](const UIUserInterfaceStyle style) -> id<AppColorTheme> {
        switch (style) {
            case UIUserInterfaceStyleLight:
                return app_themes.light;
            case UIUserInterfaceStyleDark:
                return app_themes.dark;
            default:
                return nil;
        }
    };
    id<AppColorTheme> theme = getTheme(style);
    if (!theme) {
        // Unspecified
        theme = getTheme(default_style);
    }
    return theme;
}
+(void)setTheme:(id<AppColorTheme>)theme forStyle:(UIUserInterfaceStyle)style {
    switch (style) {
        case UIUserInterfaceStyleLight:
            app_themes.light = theme;
            return;
        case UIUserInterfaceStyleDark:
            app_themes.dark = theme;
            return;
        default:
            return;
    }
}
+(UIColor*)colorFromThemeDynamic:(app_theme_color_getter_t)getter {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor*(UITraitCollection* trait_collection) {
            id<AppColorTheme> theme = [self getThemeForStyle:trait_collection.userInterfaceStyle];
            return getter(theme);
        }];
    } else {
        id<AppColorTheme> theme = [self getThemeForStyle:default_style];
        return getter(theme);
    }
}

+(UIColor*)backgroundColor {
    return [AppColorProvider colorFromThemeDynamic:^UIColor*(id<AppColorTheme> theme){
        return [theme backgroundColor];
    }];
}
+(UIColor*)foregroundColor1 {
    return [AppColorProvider colorFromThemeDynamic:^UIColor*(id<AppColorTheme> theme){
        return [theme foregroundColor1];
    }];
}
+(UIColor*)foregroundColor2 {
    return [AppColorProvider colorFromThemeDynamic:^UIColor*(id<AppColorTheme> theme){
        return [theme foregroundColor2];
    }];
}
+(UIColor*)primaryColor {
    return [AppColorProvider colorFromThemeDynamic:^UIColor*(id<AppColorTheme> theme){
        return [theme primaryColor];
    }];
}
+(UIColor*)secondaryColor {
    return [AppColorProvider colorFromThemeDynamic:^UIColor*(id<AppColorTheme> theme){
        return [theme secondaryColor];
    }];
}
+(UIColor*)alertColor {
    return [AppColorProvider colorFromThemeDynamic:^UIColor*(id<AppColorTheme> theme){
        return [theme alertColor];
    }];
}
+(UIColor*)successColor {
    return [AppColorProvider colorFromThemeDynamic:^UIColor*(id<AppColorTheme> theme){
        return [theme successColor];
    }];
}
+(UIColor*)idleColor {
    return [AppColorProvider colorFromThemeDynamic:^UIColor*(id<AppColorTheme> theme){
        return [theme idleColor];
    }];
}
+(UIColor*)textColor {
    return [AppColorProvider colorFromThemeDynamic:^UIColor*(id<AppColorTheme> theme){
        return [theme textColor];
    }];
}
+(UIColor*)textSecondaryColor {
    return [AppColorProvider colorFromThemeDynamic:^UIColor*(id<AppColorTheme> theme){
        return [theme textSecondaryColor];
    }];
}
+(UIColor*)textShyColor {
    return [AppColorProvider colorFromThemeDynamic:^UIColor*(id<AppColorTheme> theme){
        return [theme textShyColor];
    }];
}
@end
