//
//  iOS10Compat.h
//  AniAnglia
//
//  Compatibility layer for iOS 10 support.
//

#ifndef iOS10Compat_h
#define iOS10Compat_h

#import <UIKit/UIKit.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED < 110000
#ifndef NSDirectionalEdgeInsetsDefined
#define NSDirectionalEdgeInsetsDefined
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 110000
typedef struct NSDirectionalEdgeInsets {
    CGFloat top;
    CGFloat leading;
    CGFloat bottom;
    CGFloat trailing;
} NSDirectionalEdgeInsets;

static inline NSDirectionalEdgeInsets NSDirectionalEdgeInsetsMake(CGFloat top, CGFloat leading, CGFloat bottom, CGFloat trailing) {
    NSDirectionalEdgeInsets insets = {top, leading, bottom, trailing};
    return insets;
}
#endif
#endif
#endif

#if __IPHONE_OS_VERSION_MIN_REQUIRED < 130000
#ifndef UIUserInterfaceStyleDefined
#define UIUserInterfaceStyleDefined
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 130000
typedef NS_ENUM(NSInteger, UIUserInterfaceStyle) {
    UIUserInterfaceStyleUnspecified,
    UIUserInterfaceStyleLight,
    UIUserInterfaceStyleDark
};
#endif
#endif
#endif

@interface UIImage (iOS10Compat)
+ (UIImage *)compat_systemImageNamed:(NSString *)name;
@end

#endif /* iOS10Compat_h */
