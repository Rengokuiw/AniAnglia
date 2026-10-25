//
//  iOS10Compat.h
//  AniAnglia
//
//  Compatibility layer for iOS 10 support.
//

#ifndef iOS10Compat_h
#define iOS10Compat_h

#ifdef __OBJC__
#import <Foundation/Foundation.h>
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

#ifndef UIMenuOptionsDestructive
#define UIMenuOptionsDestructive (1UL << 1)
#endif

@interface AniAngliaCompatAction : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) NSUInteger attributes;
@property (nonatomic, copy) void (^handler)(id action);
+ (instancetype)actionWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier handler:(void (^)(id action))handler;
@end

@interface AniAngliaCompatMenu : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) NSUInteger options;
@property (nonatomic, strong) NSArray *children;
+ (instancetype)menuWithChildren:(NSArray *)children;
+ (instancetype)menuWithTitle:(NSString *)title children:(NSArray *)children;
+ (instancetype)menuWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier options:(NSUInteger)options children:(NSArray *)children;
@end

@interface AniAngliaCompatContextMenuInteraction : NSObject
@property (nonatomic, weak) id delegate;
- (instancetype)initWithDelegate:(id)delegate;
@end

@interface AniAngliaCompatContextMenuConfiguration : NSObject
@property (nonatomic, strong) id identifier;
+ (instancetype)configurationWithIdentifier:(id)identifier previewProvider:(id)previewProvider actionProvider:(id)actionProvider;
@end

@interface UIImage (iOS10Compat)
+ (UIImage *)compat_systemImageNamed:(NSString *)name;
@end

@interface UIBarButtonItem (iOS10PrimaryActionHelper)
- (instancetype)initWithPrimaryActionCompat:(id)primaryAction;
@end

@interface UIButton (iOS10MenuHelper)
- (void)setMenuCompat:(id)menu;
@end

@interface UIButton (AniAngliaiOS10Compat)
- (void)setShowsMenuAsPrimaryAction:(BOOL)shows;
- (BOOL)showsMenuAsPrimaryAction;
@end

#ifndef UIAction
#define UIAction AniAngliaCompatAction
#endif

#ifndef UIMenu
#define UIMenu AniAngliaCompatMenu
#endif

#ifndef UIContextMenuConfiguration
#define UIContextMenuConfiguration AniAngliaCompatContextMenuConfiguration
#endif

#ifndef UIContextMenuInteraction
#define UIContextMenuInteraction AniAngliaCompatContextMenuInteraction
#endif

#ifndef initWithPrimaryAction
#define initWithPrimaryAction initWithPrimaryActionCompat
#endif

#ifndef setMenu
#define setMenu setMenuCompat
#endif

#endif /* __OBJC__ */
#endif /* iOS10Compat_h */
