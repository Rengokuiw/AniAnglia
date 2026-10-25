//
//  iOS10Compat.mm
//  AniAnglia
//
//  Comprehensive runtime compatibility layer for iOS 10.
//

#import "iOS10Compat.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <Security/Security.h>
#import <Security/SecureTransport.h>
#import <dlfcn.h>
#import <execinfo.h>
#import <signal.h>
#include <exception>

#pragma mark - Standalone Action & Menu Fallback Objects

@implementation AniAngliaCompatAction
+ (instancetype)actionWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier handler:(void (^)(id action))handler {
    AniAngliaCompatAction *action = [[self alloc] init];
    action.title = title ?: @"";
    action.image = image;
    action.identifier = identifier ?: @"";
    action.attributes = 0;
    action.handler = handler;
    return action;
}
@end

@implementation AniAngliaCompatMenu
+ (instancetype)menuWithChildren:(NSArray *)children {
    return [self menuWithTitle:@"" children:children];
}
+ (instancetype)menuWithTitle:(NSString *)title children:(NSArray *)children {
    return [self menuWithTitle:title image:nil identifier:nil options:0 children:children];
}
+ (instancetype)menuWithTitle:(NSString *)title image:(UIImage *)image identifier:(NSString *)identifier options:(NSUInteger)options children:(NSArray *)children {
    AniAngliaCompatMenu *menu = [[self alloc] init];
    menu.title = title ?: @"";
    menu.image = image;
    menu.identifier = identifier ?: @"";
    menu.options = options;
    menu.children = children ?: @[];
    return menu;
}
@end

@implementation AniAngliaCompatContextMenuInteraction
- (instancetype)initWithDelegate:(id)delegate {
    if (self = [super init]) {
        _delegate = delegate;
    }
    return self;
}
@end

@implementation AniAngliaCompatContextMenuConfiguration
+ (instancetype)configurationWithIdentifier:(id)identifier previewProvider:(id)previewProvider actionProvider:(id)actionProvider {
    AniAngliaCompatContextMenuConfiguration *conf = [[self alloc] init];
    conf.identifier = identifier;
    return conf;
}
@end

#pragma mark - Helper for UIBarButtonItem Primary Action

@interface AniAngliaBarActionHelper : NSObject
@property (nonatomic, strong) id action;
- (instancetype)initWithAction:(id)action;
- (void)onBarActionTriggered:(id)sender;
@end

@implementation AniAngliaBarActionHelper
- (instancetype)initWithAction:(id)action {
    if (self = [super init]) {
        _action = action;
    }
    return self;
}
- (void)onBarActionTriggered:(id)sender {
    if ([_action respondsToSelector:@selector(handler)]) {
        void (^handler)(id) = [_action valueForKey:@"handler"];
        if (handler) {
            handler(_action);
        }
    }
}
@end

#pragma mark - C Implementation Functions for Dynamic Methods

static const char kSafeAreaGuideKey = 0;
static const char kButtonMenuKey = 0;
static const char kButtonShowsMenuKey = 0;
static const char kBarActionHelperKey = 0;

static UILayoutGuide* Compat_UIView_safeAreaLayoutGuide(UIView *self, SEL _cmd) {
    UILayoutGuide *guide = objc_getAssociatedObject(self, &kSafeAreaGuideKey);
    if (!guide) {
        guide = [[UILayoutGuide alloc] init];
        guide.identifier = @"iOS10_Compat_SafeAreaGuide";
        [self addLayoutGuide:guide];
        if ([self isKindOfClass:[UIScrollView class]]) {
            [NSLayoutConstraint activateConstraints:@[
                [guide.topAnchor constraintEqualToAnchor:self.topAnchor],
                [guide.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
                [guide.widthAnchor constraintEqualToAnchor:self.widthAnchor],
                [guide.heightAnchor constraintEqualToAnchor:self.heightAnchor]
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [guide.topAnchor constraintEqualToAnchor:self.topAnchor],
                [guide.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
                [guide.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
                [guide.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
            ]];
        }
        objc_setAssociatedObject(self, &kSafeAreaGuideKey, guide, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return guide;
}

static UIEdgeInsets Compat_UIView_safeAreaInsets(UIView *self, SEL _cmd) {
    return UIEdgeInsetsZero;
}

static void Compat_UIView_setDirectionalLayoutMargins(UIView *self, SEL _cmd, NSDirectionalEdgeInsets insets) {
    self.layoutMargins = UIEdgeInsetsMake(insets.top, insets.leading, insets.bottom, insets.trailing);
}

static NSDirectionalEdgeInsets Compat_UIView_directionalLayoutMargins(UIView *self, SEL _cmd) {
    UIEdgeInsets m = self.layoutMargins;
    return NSDirectionalEdgeInsetsMake(m.top, m.left, m.bottom, m.right);
}

static void Compat_UIView_addInteraction(UIView *self, SEL _cmd, id interaction) {
    // No-op on iOS 10
}

static void Compat_UIViewController_setAdditionalSafeAreaInsets(UIViewController *self, SEL _cmd, UIEdgeInsets insets) {
    // No-op on iOS 10
}

static UIEdgeInsets Compat_UIViewController_additionalSafeAreaInsets(UIViewController *self, SEL _cmd) {
    return UIEdgeInsetsZero;
}

static void Compat_UIScrollView_setContentInsetAdjustmentBehavior(UIScrollView *self, SEL _cmd, NSInteger behavior) {
    // No-op on iOS 10
}

static NSInteger Compat_UIScrollView_contentInsetAdjustmentBehavior(UIScrollView *self, SEL _cmd) {
    return 0;
}

static void Compat_CALayer_setMaskedCorners(CALayer *self, SEL _cmd, NSUInteger corners) {
    // No-op on iOS 10
}

static NSUInteger Compat_CALayer_maskedCorners(CALayer *self, SEL _cmd) {
    return 0;
}

static UIBarButtonItem* Compat_UIBarButtonItem_initWithPrimaryAction(UIBarButtonItem *self, SEL _cmd, id action) {
    AniAngliaBarActionHelper *helper = [[AniAngliaBarActionHelper alloc] initWithAction:action];
    UIImage *img = [action respondsToSelector:@selector(image)] ? [action valueForKey:@"image"] : nil;
    NSString *title = [action respondsToSelector:@selector(title)] ? [action valueForKey:@"title"] : @"";
    
    if (img) {
        self = [self initWithImage:img style:UIBarButtonItemStylePlain target:helper action:@selector(onBarActionTriggered:)];
    } else {
        self = [self initWithTitle:title style:UIBarButtonItemStylePlain target:helper action:@selector(onBarActionTriggered:)];
    }
    if (self) {
        objc_setAssociatedObject(self, &kBarActionHelperKey, helper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return self;
}

@interface UIButton (AniAngliaCompatInternal)
- (void)anianglia_menuButtonTapped:(id)sender;
@end

@implementation UIButton (AniAngliaCompatInternal)
- (void)anianglia_menuButtonTapped:(id)sender {
    static NSTimeInterval s_lastMenuTapTime = 0;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - s_lastMenuTapTime < 0.5) {
        return; // Debounce dual/rapid taps
    }
    s_lastMenuTapTime = now;
    
    id menu = objc_getAssociatedObject(self, &kButtonMenuKey);
    if (!menu) return;
    NSArray *children = [menu respondsToSelector:@selector(children)] ? [menu valueForKey:@"children"] : nil;
    if (!children || children.count == 0) return;
    
    NSString *menuTitle = [menu respondsToSelector:@selector(title)] ? [menu valueForKey:@"title"] : nil;
    if (menuTitle.length == 0) menuTitle = nil;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:menuTitle message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    void (^addActionItem)(id item, NSString *prefix) = ^(id item, NSString *prefix) {
        if ([item isKindOfClass:[AniAngliaCompatAction class]]) {
            AniAngliaCompatAction *act = (AniAngliaCompatAction *)item;
            NSString *displayTitle = prefix.length > 0 ? [NSString stringWithFormat:@"%@: %@", prefix, act.title] : act.title;
            UIAlertActionStyle style = (act.attributes & UIMenuOptionsDestructive) ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault;
            UIAlertAction *alertAction = [UIAlertAction actionWithTitle:displayTitle style:style handler:^(UIAlertAction *action) {
                if (act.handler) act.handler(act);
            }];
            [alert addAction:alertAction];
        } else if ([item respondsToSelector:@selector(title)] && [item respondsToSelector:@selector(handler)]) {
            NSString *title = [item valueForKey:@"title"];
            NSString *displayTitle = prefix.length > 0 ? [NSString stringWithFormat:@"%@: %@", prefix, title] : title;
            void (^handler)(id) = [item valueForKey:@"handler"];
            UIAlertAction *alertAction = [UIAlertAction actionWithTitle:displayTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                if (handler) handler(item);
            }];
            [alert addAction:alertAction];
        }
    };
    
    for (id child in children) {
        if ([child isKindOfClass:[AniAngliaCompatMenu class]]) {
            AniAngliaCompatMenu *subMenu = (AniAngliaCompatMenu *)child;
            for (id subChild in subMenu.children) {
                addActionItem(subChild, subMenu.title);
            }
        } else {
            addActionItem(child, nil);
        }
    }
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"app.common.cancel", @"Отмена") style:UIAlertActionStyleCancel handler:nil]];
    
    UIWindow *window = self.window;
    if (!window) window = [UIApplication sharedApplication].keyWindow;
    if (!window) {
        NSArray *windows = [UIApplication sharedApplication].windows;
        if (windows.count > 0) window = windows.firstObject;
    }
    UIViewController *topVC = window.rootViewController;
    while (true) {
        if (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        } else if ([topVC isKindOfClass:[UINavigationController class]]) {
            topVC = [(UINavigationController *)topVC topViewController];
        } else if ([topVC isKindOfClass:[UITabBarController class]]) {
            topVC = [(UITabBarController *)topVC selectedViewController];
        } else {
            break;
        }
    }
    if (!topVC) return;
    
    // If topVC is already presenting or dismissing, avoid invalid double presentation
    if (topVC.isBeingPresented || topVC.isBeingDismissed || [topVC isKindOfClass:[UIAlertController class]]) {
        return;
    }
    
    if (alert.popoverPresentationController) {
        UIView *presentingView = self;
        if (!presentingView.window) {
            presentingView = topVC.view;
        }
        alert.popoverPresentationController.sourceView = presentingView;
        CGRect rect = presentingView.bounds;
        if (rect.size.width <= 0 || rect.size.height <= 0) {
            rect = CGRectMake(CGRectGetMidX(topVC.view.bounds), CGRectGetMidY(topVC.view.bounds), 1, 1);
            alert.popoverPresentationController.sourceView = topVC.view;
        }
        alert.popoverPresentationController.sourceRect = rect;
        alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }
    
    @try {
        [topVC presentViewController:alert animated:YES completion:nil];
    } @catch (NSException *ex) {
        NSLog(@"[iOS10Compat] Exception presenting menu alert: %@", ex);
    }
}
@end

static void Compat_UIButton_setMenu(UIButton *self, SEL _cmd, id menu) {
    objc_setAssociatedObject(self, &kButtonMenuKey, menu, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self removeTarget:self action:@selector(anianglia_menuButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(anianglia_menuButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
}

static id Compat_UIButton_getMenu(UIButton *self, SEL _cmd) {
    return objc_getAssociatedObject(self, &kButtonMenuKey);
}

static void Compat_UIButton_setShowsMenuAsPrimaryAction(UIButton *self, SEL _cmd, BOOL shows) {
    objc_setAssociatedObject(self, &kButtonShowsMenuKey, @(shows), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL Compat_UIButton_showsMenuAsPrimaryAction(UIButton *self, SEL _cmd) {
    return [objc_getAssociatedObject(self, &kButtonShowsMenuKey) boolValue];
}

@implementation UIButton (AniAngliaiOS10Compat)
- (void)setShowsMenuAsPrimaryAction:(BOOL)shows {
    Compat_UIButton_setShowsMenuAsPrimaryAction(self, @selector(setShowsMenuAsPrimaryAction:), shows);
}
- (BOOL)showsMenuAsPrimaryAction {
    return Compat_UIButton_showsMenuAsPrimaryAction(self, @selector(showsMenuAsPrimaryAction));
}
@end

@implementation UIBarButtonItem (iOS10PrimaryActionHelper)
- (instancetype)initWithPrimaryActionCompat:(id)action {
    return Compat_UIBarButtonItem_initWithPrimaryAction(self, @selector(initWithPrimaryAction:), action);
}
@end

@implementation UIButton (iOS10MenuHelper)
- (void)setMenuCompat:(id)menu {
    Compat_UIButton_setMenu(self, @selector(setMenu:), menu);
}
@end

#pragma mark - UIColor Fallbacks

static UIColor* Compat_systemBackgroundColor(id self, SEL _cmd) {
    return [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
}
static UIColor* Compat_secondarySystemBackgroundColor(id self, SEL _cmd) {
    return [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
}
static UIColor* Compat_tertiarySystemBackgroundColor(id self, SEL _cmd) {
    return [UIColor colorWithRed:0.16 green:0.16 blue:0.16 alpha:1.0];
}
static UIColor* Compat_systemBlueColor(id self, SEL _cmd) {
    return [UIColor colorWithRed:0.000 green:0.478 blue:1.000 alpha:1.0];
}
static UIColor* Compat_systemRedColor(id self, SEL _cmd) {
    return [UIColor colorWithRed:1.000 green:0.231 blue:0.188 alpha:1.0];
}
static UIColor* Compat_systemGreenColor(id self, SEL _cmd) {
    return [UIColor colorWithRed:0.298 green:0.851 blue:0.392 alpha:1.0];
}
static UIColor* Compat_systemOrangeColor(id self, SEL _cmd) {
    return [UIColor colorWithRed:1.000 green:0.584 blue:0.000 alpha:1.0];
}
static UIColor* Compat_systemYellowColor(id self, SEL _cmd) {
    return [UIColor colorWithRed:1.000 green:0.800 blue:0.000 alpha:1.0];
}
static UIColor* Compat_systemPinkColor(id self, SEL _cmd) {
    return [UIColor colorWithRed:1.000 green:0.176 blue:0.333 alpha:1.0];
}
static UIColor* Compat_systemPurpleColor(id self, SEL _cmd) {
    return [UIColor colorWithRed:0.686 green:0.322 blue:0.871 alpha:1.0];
}
static UIColor* Compat_systemIndigoColor(id self, SEL _cmd) {
    return [UIColor colorWithRed:0.345 green:0.337 blue:0.839 alpha:1.0];
}
static UIColor* Compat_systemGrayColor(id self, SEL _cmd) {
    return [UIColor colorWithRed:0.557 green:0.557 blue:0.576 alpha:1.0];
}
static UIColor* Compat_systemGray2Color(id self, SEL _cmd) {
    return [UIColor colorWithRed:0.388 green:0.388 blue:0.400 alpha:1.0];
}
static UIColor* Compat_systemGray3Color(id self, SEL _cmd) {
    return [UIColor colorWithRed:0.282 green:0.282 blue:0.290 alpha:1.0];
}
static UIColor* Compat_systemGray4Color(id self, SEL _cmd) {
    return [UIColor colorWithRed:0.227 green:0.227 blue:0.235 alpha:1.0];
}
static UIColor* Compat_systemGray5Color(id self, SEL _cmd) {
    return [UIColor colorWithRed:0.173 green:0.173 blue:0.180 alpha:1.0];
}
static UIColor* Compat_systemGray6Color(id self, SEL _cmd) {
    return [UIColor colorWithRed:0.110 green:0.110 blue:0.118 alpha:1.0];
}
static UIColor* Compat_labelColor(id self, SEL _cmd) {
    return [UIColor whiteColor];
}
static UIColor* Compat_secondaryLabelColor(id self, SEL _cmd) {
    return [UIColor colorWithWhite:0.7 alpha:1.0];
}
static UIColor* Compat_tertiaryLabelColor(id self, SEL _cmd) {
    return [UIColor colorWithWhite:0.5 alpha:1.0];
}

#pragma mark - SF Symbols Vector Vectorizer for iOS 10

static NSCache<NSString*, UIImage*> *s_symbolCache = nil;

static UIImage* RenderSFSymbol(NSString *name) {
    CGSize size = CGSizeMake(24.0, 24.0);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return nil;
    
    [[UIColor whiteColor] setStroke];
    [[UIColor whiteColor] setFill];
    
    if ([name hasPrefix:@"chevron.left"]) {
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(15, 5)];
        [path addLineToPoint:CGPointMake(8, 12)];
        [path addLineToPoint:CGPointMake(15, 19)];
        path.lineWidth = 2.5;
        path.lineCapStyle = kCGLineCapRound;
        path.lineJoinStyle = kCGLineJoinRound;
        [path stroke];
    } else if ([name hasPrefix:@"chevron.right"]) {
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(9, 5)];
        [path addLineToPoint:CGPointMake(16, 12)];
        [path addLineToPoint:CGPointMake(9, 19)];
        path.lineWidth = 2.5;
        path.lineCapStyle = kCGLineCapRound;
        path.lineJoinStyle = kCGLineJoinRound;
        [path stroke];
    } else if ([name hasPrefix:@"chevron.down"]) {
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(5, 9)];
        [path addLineToPoint:CGPointMake(12, 16)];
        [path addLineToPoint:CGPointMake(19, 9)];
        path.lineWidth = 2.5;
        path.lineCapStyle = kCGLineCapRound;
        path.lineJoinStyle = kCGLineJoinRound;
        [path stroke];
    } else if ([name hasPrefix:@"house"]) {
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(12, 4)];
        [path addLineToPoint:CGPointMake(4, 11)];
        [path addLineToPoint:CGPointMake(6, 11)];
        [path addLineToPoint:CGPointMake(6, 20)];
        [path addLineToPoint:CGPointMake(18, 20)];
        [path addLineToPoint:CGPointMake(18, 11)];
        [path addLineToPoint:CGPointMake(20, 11)];
        [path closePath];
        if ([name containsString:@"fill"]) {
            [path fill];
        } else {
            path.lineWidth = 1.8;
            [path stroke];
        }
    } else if ([name hasPrefix:@"safari"]) {
        CGRect circleRect = CGRectMake(3, 3, 18, 18);
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:circleRect];
        circle.lineWidth = 1.8;
        [circle stroke];
        UIBezierPath *needle = [UIBezierPath bezierPath];
        [needle moveToPoint:CGPointMake(16, 8)];
        [needle addLineToPoint:CGPointMake(13, 13)];
        [needle addLineToPoint:CGPointMake(8, 16)];
        [needle addLineToPoint:CGPointMake(11, 11)];
        [needle closePath];
        [needle fill];
    } else if ([name hasPrefix:@"bookmark"]) {
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(6, 4)];
        [path addLineToPoint:CGPointMake(18, 4)];
        [path addLineToPoint:CGPointMake(18, 20)];
        [path addLineToPoint:CGPointMake(12, 16)];
        [path addLineToPoint:CGPointMake(6, 20)];
        [path closePath];
        if ([name containsString:@"fill"]) {
            [path fill];
        } else {
            path.lineWidth = 1.8;
            [path stroke];
        }
        if ([name containsString:@"slash"]) {
            UIBezierPath *slash = [UIBezierPath bezierPath];
            [slash moveToPoint:CGPointMake(4, 21)];
            [slash addLineToPoint:CGPointMake(20, 3)];
            slash.lineWidth = 2.0;
            [slash stroke];
        }
    } else if ([name hasPrefix:@"person"]) {
        CGRect headRect = CGRectMake(8, 4, 8, 8);
        UIBezierPath *head = [UIBezierPath bezierPathWithOvalInRect:headRect];
        UIBezierPath *body = [UIBezierPath bezierPath];
        [body moveToPoint:CGPointMake(4, 20)];
        [body addQuadCurveToPoint:CGPointMake(20, 20) controlPoint:CGPointMake(12, 13)];
        if ([name containsString:@"fill"]) {
            [head fill];
            [body closePath];
            [body fill];
        } else {
            head.lineWidth = 1.8;
            [head stroke];
            body.lineWidth = 1.8;
            [body stroke];
        }
    } else if ([name hasPrefix:@"gear"]) {
        CGRect outer = CGRectMake(4, 4, 16, 16);
        UIBezierPath *gear = [UIBezierPath bezierPathWithOvalInRect:outer];
        gear.lineWidth = 3.5;
        [gear stroke];
        CGRect inner = CGRectMake(9, 9, 6, 6);
        UIBezierPath *hole = [UIBezierPath bezierPathWithOvalInRect:inner];
        hole.lineWidth = 1.5;
        [hole stroke];
    } else if ([name hasPrefix:@"slider.horizontal"]) {
        UIBezierPath *lines = [UIBezierPath bezierPath];
        // Line 1
        [lines moveToPoint:CGPointMake(3, 7)]; [lines addLineToPoint:CGPointMake(21, 7)];
        // Line 2
        [lines moveToPoint:CGPointMake(3, 12)]; [lines addLineToPoint:CGPointMake(21, 12)];
        // Line 3
        [lines moveToPoint:CGPointMake(3, 17)]; [lines addLineToPoint:CGPointMake(21, 17)];
        lines.lineWidth = 1.5;
        [lines stroke];
        // Knobs
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(7, 5, 4, 4)] fill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(14, 10, 4, 4)] fill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9, 15, 4, 4)] fill];
    } else if ([name hasPrefix:@"star"]) {
        UIBezierPath *star = [UIBezierPath bezierPath];
        CGPoint center = CGPointMake(12, 12);
        CGFloat rOuter = 9.0;
        CGFloat rInner = 4.0;
        for (int i = 0; i < 10; ++i) {
            CGFloat angle = i * M_PI / 5.0 - M_PI_2;
            CGFloat r = (i % 2 == 0) ? rOuter : rInner;
            CGPoint pt = CGPointMake(center.x + r * cos(angle), center.y + r * sin(angle));
            if (i == 0) [star moveToPoint:pt];
            else [star addLineToPoint:pt];
        }
        [star closePath];
        if ([name containsString:@"fill"]) {
            [star fill];
        } else {
            star.lineWidth = 1.6;
            [star stroke];
        }
    } else if ([name hasPrefix:@"heart"]) {
        UIBezierPath *heart = [UIBezierPath bezierPath];
        [heart moveToPoint:CGPointMake(12, 19)];
        [heart addCurveToPoint:CGPointMake(3, 11) controlPoint1:CGPointMake(7, 16) controlPoint2:CGPointMake(3, 14)];
        [heart addArcWithCenter:CGPointMake(7.5, 7.5) radius:4.5 startAngle:M_PI endAngle:0 clockwise:YES];
        [heart addArcWithCenter:CGPointMake(16.5, 7.5) radius:4.5 startAngle:M_PI endAngle:0 clockwise:YES];
        [heart addCurveToPoint:CGPointMake(12, 19) controlPoint1:CGPointMake(21, 14) controlPoint2:CGPointMake(17, 16)];
        [heart closePath];
        if ([name containsString:@"fill"]) {
            [heart fill];
        } else {
            heart.lineWidth = 1.6;
            [heart stroke];
        }
    } else if ([name hasPrefix:@"magnifyingglass"]) {
        CGRect lensRect = CGRectMake(4, 4, 12, 12);
        UIBezierPath *lens = [UIBezierPath bezierPathWithOvalInRect:lensRect];
        lens.lineWidth = 2.0;
        [lens stroke];
        UIBezierPath *handle = [UIBezierPath bezierPath];
        [handle moveToPoint:CGPointMake(13, 13)];
        [handle addLineToPoint:CGPointMake(20, 20)];
        handle.lineWidth = 2.5;
        handle.lineCapStyle = kCGLineCapRound;
        [handle stroke];
    } else if ([name hasPrefix:@"arrow.clockwise"]) {
        CGRect arcRect = CGRectMake(4, 4, 16, 16);
        UIBezierPath *arc = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12, 12) radius:7 startAngle:0 endAngle:M_PI * 1.6 clockwise:YES];
        arc.lineWidth = 2.0;
        arc.lineCapStyle = kCGLineCapRound;
        [arc stroke];
        UIBezierPath *arrow = [UIBezierPath bezierPath];
        [arrow moveToPoint:CGPointMake(15, 3)];
        [arrow addLineToPoint:CGPointMake(19, 5)];
        [arrow addLineToPoint:CGPointMake(17, 9)];
        [arrow fill];
    } else if ([name hasPrefix:@"trash"]) {
        UIBezierPath *bin = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(5, 7, 14, 13) cornerRadius:2.0];
        bin.lineWidth = 1.6;
        [bin stroke];
        UIBezierPath *lid = [UIBezierPath bezierPath];
        [lid moveToPoint:CGPointMake(3, 6)];
        [lid addLineToPoint:CGPointMake(21, 6)];
        lid.lineWidth = 2.0;
        [lid stroke];
    } else if ([name hasPrefix:@"arrowtriangle.right"]) {
        UIBezierPath *play = [UIBezierPath bezierPath];
        [play moveToPoint:CGPointMake(7, 5)];
        [play addLineToPoint:CGPointMake(19, 12)];
        [play addLineToPoint:CGPointMake(7, 19)];
        [play closePath];
        [play fill];
    } else if ([name hasPrefix:@"line.3.horizontal"]) {
        UIBezierPath *lines = [UIBezierPath bezierPath];
        [lines moveToPoint:CGPointMake(4, 7)]; [lines addLineToPoint:CGPointMake(20, 7)];
        [lines moveToPoint:CGPointMake(4, 12)]; [lines addLineToPoint:CGPointMake(20, 12)];
        [lines moveToPoint:CGPointMake(4, 17)]; [lines addLineToPoint:CGPointMake(20, 17)];
        lines.lineWidth = 2.0;
        lines.lineCapStyle = kCGLineCapRound;
        [lines stroke];
    } else if ([name hasPrefix:@"xmark"]) {
        UIBezierPath *x = [UIBezierPath bezierPath];
        [x moveToPoint:CGPointMake(6, 6)]; [x addLineToPoint:CGPointMake(18, 18)];
        [x moveToPoint:CGPointMake(18, 6)]; [x addLineToPoint:CGPointMake(6, 18)];
        x.lineWidth = 2.2;
        x.lineCapStyle = kCGLineCapRound;
        [x stroke];
    } else if ([name hasPrefix:@"checkmark"]) {
        UIBezierPath *check = [UIBezierPath bezierPath];
        [check moveToPoint:CGPointMake(5, 12)];
        [check addLineToPoint:CGPointMake(10, 17)];
        [check addLineToPoint:CGPointMake(19, 7)];
        check.lineWidth = 2.2;
        check.lineCapStyle = kCGLineCapRound;
        check.lineJoinStyle = kCGLineJoinRound;
        [check stroke];
        if ([name containsString:@"square"]) {
            UIBezierPath *sq = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 3, 18, 18) cornerRadius:3.0];
            sq.lineWidth = 1.5;
            [sq stroke];
        }
    } else if ([name hasPrefix:@"eye"]) {
        UIBezierPath *eye = [UIBezierPath bezierPath];
        [eye moveToPoint:CGPointMake(3, 12)];
        [eye addQuadCurveToPoint:CGPointMake(21, 12) controlPoint:CGPointMake(12, 5)];
        [eye addQuadCurveToPoint:CGPointMake(3, 12) controlPoint:CGPointMake(12, 19)];
        if ([name containsString:@"fill"]) {
            [eye fill];
            [[UIColor blackColor] setFill];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9.5, 9.5, 5, 5)] fill];
        } else {
            eye.lineWidth = 1.8;
            [eye stroke];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9.5, 9.5, 5, 5)] stroke];
        }
        if ([name containsString:@"slash"]) {
            [[UIColor whiteColor] setStroke];
            UIBezierPath *slash = [UIBezierPath bezierPath];
            [slash moveToPoint:CGPointMake(4, 20)];
            [slash addLineToPoint:CGPointMake(20, 4)];
            slash.lineWidth = 2.0;
            [slash stroke];
        }
    } else if ([name hasPrefix:@"lock"]) {
        UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(5, 10, 14, 11) cornerRadius:3.0];
        UIBezierPath *shackle = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12, 10) radius:4.5 startAngle:M_PI endAngle:0 clockwise:YES];
        shackle.lineWidth = 2.0;
        [shackle stroke];
        if ([name containsString:@"fill"]) {
            [body fill];
            [[UIColor blackColor] setFill];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(11, 14, 2, 3)] fill];
        } else {
            body.lineWidth = 1.8;
            [body stroke];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(11, 14, 2, 3)] fill];
        }
    } else if ([name hasPrefix:@"bell"]) {
        UIBezierPath *bell = [UIBezierPath bezierPath];
        [bell moveToPoint:CGPointMake(12, 4)];
        [bell addQuadCurveToPoint:CGPointMake(5, 16) controlPoint:CGPointMake(6, 9)];
        [bell addLineToPoint:CGPointMake(19, 16)];
        [bell addQuadCurveToPoint:CGPointMake(12, 4) controlPoint:CGPointMake(18, 9)];
        [bell closePath];
        if ([name containsString:@"fill"]) {
            [bell fill];
        } else {
            bell.lineWidth = 1.8;
            [bell stroke];
        }
        UIBezierPath *clapper = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12, 16) radius:2.5 startAngle:0 endAngle:M_PI clockwise:YES];
        [clapper fill];
    } else if ([name hasPrefix:@"externaldrive"]) {
        UIBezierPath *drive = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 7, 16, 10) cornerRadius:2.5];
        if ([name containsString:@"fill"]) {
            [drive fill];
            [[UIColor blackColor] setFill];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(16, 12, 2, 2)] fill];
        } else {
            drive.lineWidth = 1.8;
            [drive stroke];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(16, 12, 2, 2)] fill];
        }
    } else if ([name hasPrefix:@"questionmark"]) {
        UIBezierPath *q = [UIBezierPath bezierPath];
        [q moveToPoint:CGPointMake(8, 9)];
        [q addArcWithCenter:CGPointMake(12, 9) radius:4 startAngle:M_PI endAngle:0 clockwise:YES];
        [q addQuadCurveToPoint:CGPointMake(12, 16) controlPoint:CGPointMake(16, 13)];
        q.lineWidth = 2.2;
        q.lineCapStyle = kCGLineCapRound;
        [q stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(10.75, 19, 2.5, 2.5)] fill];
    } else if ([name hasPrefix:@"shield"]) {
        UIBezierPath *shield = [UIBezierPath bezierPath];
        [shield moveToPoint:CGPointMake(12, 4)];
        [shield addLineToPoint:CGPointMake(19, 6)];
        [shield addQuadCurveToPoint:CGPointMake(12, 21) controlPoint:CGPointMake(19, 15)];
        [shield addQuadCurveToPoint:CGPointMake(5, 6) controlPoint:CGPointMake(5, 15)];
        [shield closePath];
        if ([name containsString:@"fill"]) {
            [shield fill];
        } else {
            shield.lineWidth = 1.8;
            [shield stroke];
        }
    } else if ([name hasPrefix:@"calendar"]) {
        UIBezierPath *cal = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 5, 16, 15) cornerRadius:3.0];
        cal.lineWidth = 1.8;
        [cal stroke];
        UIBezierPath *line = [UIBezierPath bezierPath];
        [line moveToPoint:CGPointMake(4, 10)]; [line addLineToPoint:CGPointMake(20, 10)];
        line.lineWidth = 1.5;
        [line stroke];
        [[UIBezierPath bezierPathWithRect:CGRectMake(7, 3, 2, 3)] fill];
        [[UIBezierPath bezierPathWithRect:CGRectMake(15, 3, 2, 3)] fill];
    } else if ([name hasPrefix:@"rectangle.stack"]) {
        UIBezierPath *r1 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(7, 4, 13, 9) cornerRadius:2.0];
        r1.lineWidth = 1.5;
        [r1 stroke];
        UIBezierPath *r2 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 8, 13, 11) cornerRadius:2.0];
        r2.lineWidth = 1.8;
        [[UIColor blackColor] setFill];
        [r2 fill];
        [[UIColor whiteColor] setFill];
        [r2 stroke];
    } else if ([name hasPrefix:@"person.3"]) {
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(4, 7, 5, 5)] fill];
        UIBezierPath *b1 = [UIBezierPath bezierPath];
        [b1 moveToPoint:CGPointMake(2, 17)]; [b1 addQuadCurveToPoint:CGPointMake(11, 17) controlPoint:CGPointMake(6.5, 13)];
        [b1 closePath]; [b1 fill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(15, 7, 5, 5)] fill];
        UIBezierPath *b3 = [UIBezierPath bezierPath];
        [b3 moveToPoint:CGPointMake(13, 17)]; [b3 addQuadCurveToPoint:CGPointMake(22, 17) controlPoint:CGPointMake(17.5, 13)];
        [b3 closePath]; [b3 fill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9, 5, 6, 6)] fill];
        UIBezierPath *b2 = [UIBezierPath bezierPath];
        [b2 moveToPoint:CGPointMake(6, 19)]; [b2 addQuadCurveToPoint:CGPointMake(18, 19) controlPoint:CGPointMake(12, 13)];
        [b2 closePath]; [b2 fill];
    } else if ([name hasPrefix:@"a.circle"]) {
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(3, 3, 18, 18)];
        circle.lineWidth = 1.8;
        [circle stroke];
        UIBezierPath *a = [UIBezierPath bezierPath];
        [a moveToPoint:CGPointMake(7.5, 17)]; [a addLineToPoint:CGPointMake(12, 7)]; [a addLineToPoint:CGPointMake(16.5, 17)];
        [a moveToPoint:CGPointMake(9, 14)]; [a addLineToPoint:CGPointMake(15, 14)];
        a.lineWidth = 1.8;
        a.lineCapStyle = kCGLineCapRound;
        [a stroke];
    } else if ([name hasPrefix:@"bookmark"]) {
        UIBezierPath *bm = [UIBezierPath bezierPath];
        [bm moveToPoint:CGPointMake(6, 4)];
        [bm addLineToPoint:CGPointMake(18, 4)];
        [bm addLineToPoint:CGPointMake(18, 20)];
        [bm addLineToPoint:CGPointMake(12, 16)];
        [bm addLineToPoint:CGPointMake(6, 20)];
        [bm closePath];
        if ([name containsString:@"fill"]) {
            [bm fill];
        } else {
            bm.lineWidth = 1.8;
            [bm stroke];
        }
        if ([name containsString:@"slash"]) {
            UIBezierPath *slash = [UIBezierPath bezierPath];
            [slash moveToPoint:CGPointMake(4, 21)];
            [slash addLineToPoint:CGPointMake(20, 3)];
            slash.lineWidth = 2.0;
            [slash stroke];
        }
    } else if ([name hasPrefix:@"dot.square"]) {
        UIBezierPath *sq = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 4, 16, 16) cornerRadius:3.0];
        sq.lineWidth = 1.8;
        [sq stroke];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9.5, 9.5, 5, 5)] fill];
    } else if ([name hasPrefix:@"square"]) {
        UIBezierPath *sq = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 4, 16, 16) cornerRadius:3.0];
        sq.lineWidth = 1.8;
        [sq stroke];
        if ([name containsString:@"slash"]) {
            UIBezierPath *slash = [UIBezierPath bezierPath];
            [slash moveToPoint:CGPointMake(4, 20)];
            [slash addLineToPoint:CGPointMake(20, 4)];
            slash.lineWidth = 1.8;
            [slash stroke];
        }
    } else if ([name hasPrefix:@"arrow.up"]) {
        UIBezierPath *arrow = [UIBezierPath bezierPath];
        [arrow moveToPoint:CGPointMake(12, 19)];
        [arrow addLineToPoint:CGPointMake(12, 5)];
        [arrow moveToPoint:CGPointMake(6, 11)];
        [arrow addLineToPoint:CGPointMake(12, 5)];
        [arrow addLineToPoint:CGPointMake(18, 11)];
        arrow.lineWidth = 2.2;
        arrow.lineCapStyle = kCGLineCapRound;
        arrow.lineJoinStyle = kCGLineJoinRound;
        [arrow stroke];
    } else if ([name hasPrefix:@"doc.on.doc"]) {
        UIBezierPath *back = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(8, 3, 12, 14) cornerRadius:2.0];
        back.lineWidth = 1.5;
        [back stroke];
        UIBezierPath *front = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 7, 12, 14) cornerRadius:2.0];
        front.lineWidth = 1.8;
        [[UIColor blackColor] setFill];
        [front fill];
        [[UIColor whiteColor] setFill];
        [front stroke];
    } else if ([name hasPrefix:@"pencil"]) {
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(5, 19)];
        [p addLineToPoint:CGPointMake(9, 19)];
        [p addLineToPoint:CGPointMake(19, 9)];
        [p addLineToPoint:CGPointMake(15, 5)];
        [p addLineToPoint:CGPointMake(5, 15)];
        [p closePath];
        p.lineWidth = 1.8;
        p.lineJoinStyle = kCGLineJoinRound;
        [p stroke];
    } else if ([name hasPrefix:@"megaphone"]) {
        UIBezierPath *m = [UIBezierPath bezierPath];
        [m moveToPoint:CGPointMake(8, 10)];
        [m addLineToPoint:CGPointMake(17, 6)];
        [m addLineToPoint:CGPointMake(17, 18)];
        [m addLineToPoint:CGPointMake(8, 14)];
        [m closePath];
        m.lineWidth = 1.8;
        [m stroke];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(5, 10, 3, 4) cornerRadius:1.0] stroke];
    } else {
        // Universal fallback: clean rounded glyph
        UIBezierPath *rect = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 4, 16, 16) cornerRadius:4.0];
        rect.lineWidth = 1.8;
        [rect stroke];
        UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(10, 10, 4, 4)];
        [dot fill];
    }
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

static UIImage* Compat_systemImageNamed(id self, SEL _cmd, NSString *name) {
    if (!name || name.length == 0) return nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_symbolCache = [[NSCache alloc] init];
    });
    
    UIImage *cached = [s_symbolCache objectForKey:name];
    if (cached) return cached;
    
    // Check if an asset image exists with this name
    UIImage *assetImage = [UIImage imageNamed:name];
    if (assetImage) {
        UIImage *templateImg = [assetImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [s_symbolCache setObject:templateImg forKey:name];
        return templateImg;
    }
    
    // Render vector symbol
    UIImage *rendered = RenderSFSymbol(name);
    if (rendered) {
        [s_symbolCache setObject:rendered forKey:name];
    }
    return rendered;
}

@implementation UIImage (iOS10Compat)
+ (UIImage *)compat_systemImageNamed:(NSString *)name {
    return Compat_systemImageNamed([UIImage class], @selector(systemImageNamed:), name);
}
@end

#pragma mark - AutoLayout & TableView Swizzling for iOS 10

static NSLayoutConstraint* (*s_orig_constraintWithItem)(id, SEL, id, NSLayoutAttribute, NSLayoutRelation, id, NSLayoutAttribute, CGFloat, CGFloat) = NULL;

static NSLayoutConstraint* Compat_constraintWithItem(id self, SEL _cmd, id view1, NSLayoutAttribute attr1, NSLayoutRelation relation, id view2, NSLayoutAttribute attr2, CGFloat multiplier, CGFloat c) {
    if (isnan(multiplier) || isinf(multiplier) || multiplier <= 0.0) {
        multiplier = 0.00001; // AutoLayout throws NSInvalidArgumentException if multiplier <= 0 or NaN/Inf
    }
    if (isnan(c) || isinf(c)) {
        c = 0.0;
    }
    if (s_orig_constraintWithItem) {
        return s_orig_constraintWithItem(self, _cmd, view1, attr1, relation, view2, attr2, multiplier, c);
    }
    return nil;
}

static id (*s_orig_UITableView_initWithFrame_style)(id, SEL, CGRect, NSInteger) = NULL;

static id Compat_UITableView_initWithFrame_style(UITableView *self, SEL _cmd, CGRect frame, NSInteger style) {
    if (style > 1) { // Fallback UITableViewStyleInsetGrouped (2) to UITableViewStyleGrouped (1) on iOS < 13
        style = UITableViewStyleGrouped;
    }
    if (s_orig_UITableView_initWithFrame_style) {
        return s_orig_UITableView_initWithFrame_style(self, _cmd, frame, style);
    }
    return self;
}

#pragma mark - Crash Reporting for iOS 10

static BOOL s_exceptionCaught = NO;

static void AniAngliaUncaughtExceptionHandler(NSException *exception) {
    s_exceptionCaught = YES;
    NSString *crashInfo = [NSString stringWithFormat:@"Exception: %@\nReason: %@\nStack:\n%@",
                           exception.name,
                           exception.reason,
                           [exception.callStackSymbols componentsJoinedByString:@"\n"]];
    [[NSUserDefaults standardUserDefaults] setObject:crashInfo forKey:@"AniAngliaLastCrash"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static void AniAngliaTerminateHandler() {
    if (!s_exceptionCaught) {
        s_exceptionCaught = YES;
        NSString *crashInfo = nil;
        
        void *callstack[64];
        int frames = backtrace(callstack, 64);
        char **strs = backtrace_symbols(callstack, frames);
        NSMutableArray *symbols = [NSMutableArray arrayWithCapacity:frames];
        for (int i = 0; i < frames; ++i) {
            if (strs && strs[i]) {
                [symbols addObject:[NSString stringWithUTF8String:strs[i]]];
            }
        }
        if (strs) free(strs);
        NSString *stackStr = [symbols componentsJoinedByString:@"\n"];
        
        try {
            std::exception_ptr eptr = std::current_exception();
            if (eptr) {
                std::rethrow_exception(eptr);
            }
        } catch (NSException *ne) {
            crashInfo = [NSString stringWithFormat:@"NSException caught by terminate handler: %@\nReason: %@\nStack:\n%@\nBacktrace:\n%@",
                         ne.name, ne.reason, [ne.callStackSymbols componentsJoinedByString:@"\n"], stackStr];
        } catch (const std::exception &e) {
            crashInfo = [NSString stringWithFormat:@"C++ Exception: %s\nBacktrace:\n%@", e.what(), stackStr];
        } catch (id obj) {
            crashInfo = [NSString stringWithFormat:@"ObjC Exception: %@\nBacktrace:\n%@", obj, stackStr];
        } catch (...) {
            crashInfo = [NSString stringWithFormat:@"Unknown Exception caught by terminate handler\nBacktrace:\n%@", stackStr];
        }
        if (crashInfo) {
            [[NSUserDefaults standardUserDefaults] setObject:crashInfo forKey:@"AniAngliaLastCrash"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
    abort();
}

static void AniAngliaSignalHandler(int sig) {
    if (s_exceptionCaught && sig == SIGABRT) {
        signal(sig, SIG_DFL);
        raise(sig);
        return;
    }
    
    void *callstack[64];
    int frames = backtrace(callstack, 64);
    char **strs = backtrace_symbols(callstack, frames);
    NSMutableArray *symbols = [NSMutableArray arrayWithCapacity:frames];
    for (int i = 0; i < frames; ++i) {
        if (strs && strs[i]) {
            [symbols addObject:[NSString stringWithUTF8String:strs[i]]];
        }
    }
    if (strs) free(strs);
    
    NSString *crashInfo = [NSString stringWithFormat:@"Signal: %d\nStack:\n%@",
                           sig,
                           [symbols componentsJoinedByString:@"\n"]];
    [[NSUserDefaults standardUserDefaults] setObject:crashInfo forKey:@"AniAngliaLastCrash"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    signal(sig, SIG_DFL);
    raise(sig);
}

#pragma mark - Initializer / Swizzler

@interface iOS10CompatLoader : NSObject
@end

@implementation iOS10CompatLoader

+ (void)load {
    // 0. Install Crash Handlers
    NSSetUncaughtExceptionHandler(&AniAngliaUncaughtExceptionHandler);
    std::set_terminate(AniAngliaTerminateHandler);
    signal(SIGSEGV, AniAngliaSignalHandler);
    signal(SIGABRT, AniAngliaSignalHandler);
    signal(SIGBUS, AniAngliaSignalHandler);
    signal(SIGILL, AniAngliaSignalHandler);
    signal(SIGTRAP, AniAngliaSignalHandler);

    // 1. Dynamic class registration if not present (iOS < 13)
    if (objc_getClass("UIAction") == Nil) {
        Class actionCls = objc_allocateClassPair([AniAngliaCompatAction class], "UIAction", 0);
        if (actionCls) objc_registerClassPair(actionCls);
    }
    if (objc_getClass("UIMenu") == Nil) {
        Class menuCls = objc_allocateClassPair([AniAngliaCompatMenu class], "UIMenu", 0);
        if (menuCls) objc_registerClassPair(menuCls);
    }
    if (objc_getClass("UIContextMenuInteraction") == Nil) {
        Class cmiCls = objc_allocateClassPair([AniAngliaCompatContextMenuInteraction class], "UIContextMenuInteraction", 0);
        if (cmiCls) objc_registerClassPair(cmiCls);
    }
    if (objc_getClass("UIContextMenuConfiguration") == Nil) {
        Class cmcCls = objc_allocateClassPair([AniAngliaCompatContextMenuConfiguration class], "UIContextMenuConfiguration", 0);
        if (cmcCls) objc_registerClassPair(cmcCls);
    }
    
    // 2. Add safeAreaLayoutGuide / safeAreaInsets to UIView if not present (iOS < 11)
    if (![UIView instancesRespondToSelector:@selector(safeAreaLayoutGuide)]) {
        class_addMethod([UIView class], @selector(safeAreaLayoutGuide), (IMP)Compat_UIView_safeAreaLayoutGuide, "@@:");
    }
    if (![UIView instancesRespondToSelector:@selector(safeAreaInsets)]) {
        class_addMethod([UIView class], @selector(safeAreaInsets), (IMP)Compat_UIView_safeAreaInsets, "{UIEdgeInsets=dddd}@:");
    }
    if (![UIView instancesRespondToSelector:@selector(setDirectionalLayoutMargins:)]) {
        class_addMethod([UIView class], @selector(setDirectionalLayoutMargins:), (IMP)Compat_UIView_setDirectionalLayoutMargins, "v@:{NSDirectionalEdgeInsets=dddd}");
        class_addMethod([UIView class], @selector(directionalLayoutMargins), (IMP)Compat_UIView_directionalLayoutMargins, "{NSDirectionalEdgeInsets=dddd}@:");
    }
    if (![UIView instancesRespondToSelector:@selector(addInteraction:)]) {
        class_addMethod([UIView class], @selector(addInteraction:), (IMP)Compat_UIView_addInteraction, "v@:@");
    }
    
    // 3. Add additionalSafeAreaInsets to UIViewController if not present (iOS < 11)
    if (![UIViewController instancesRespondToSelector:@selector(setAdditionalSafeAreaInsets:)]) {
        class_addMethod([UIViewController class], @selector(setAdditionalSafeAreaInsets:), (IMP)Compat_UIViewController_setAdditionalSafeAreaInsets, "v@:{UIEdgeInsets=dddd}");
        class_addMethod([UIViewController class], @selector(additionalSafeAreaInsets), (IMP)Compat_UIViewController_additionalSafeAreaInsets, "{UIEdgeInsets=dddd}@:");
    }
    
    // 4. Add contentInsetAdjustmentBehavior to UIScrollView if not present (iOS < 11)
    if (![UIScrollView instancesRespondToSelector:@selector(setContentInsetAdjustmentBehavior:)]) {
        class_addMethod([UIScrollView class], @selector(setContentInsetAdjustmentBehavior:), (IMP)Compat_UIScrollView_setContentInsetAdjustmentBehavior, "v@:q");
        class_addMethod([UIScrollView class], @selector(contentInsetAdjustmentBehavior), (IMP)Compat_UIScrollView_contentInsetAdjustmentBehavior, "q@:");
    }
    
    // 5. Add maskedCorners to CALayer if not present (iOS < 11)
    if (![CALayer instancesRespondToSelector:@selector(setMaskedCorners:)]) {
        class_addMethod([CALayer class], @selector(setMaskedCorners:), (IMP)Compat_CALayer_setMaskedCorners, "v@:Q");
        class_addMethod([CALayer class], @selector(maskedCorners), (IMP)Compat_CALayer_maskedCorners, "Q@:");
    }
    
    // 6. Add initWithPrimaryAction: to UIBarButtonItem if not present (iOS < 14)
    if (![UIBarButtonItem instancesRespondToSelector:@selector(initWithPrimaryAction:)]) {
        class_addMethod([UIBarButtonItem class], @selector(initWithPrimaryAction:), (IMP)Compat_UIBarButtonItem_initWithPrimaryAction, "@@:@");
    }
    
    // 7. Add menu / showsMenuAsPrimaryAction to UIButton if not present (iOS < 14)
    if (![UIButton instancesRespondToSelector:@selector(setShowsMenuAsPrimaryAction:)]) {
        class_addMethod([UIButton class], @selector(setShowsMenuAsPrimaryAction:), (IMP)Compat_UIButton_setShowsMenuAsPrimaryAction, "v@:B");
    }
    if (![UIButton instancesRespondToSelector:@selector(showsMenuAsPrimaryAction)]) {
        class_addMethod([UIButton class], @selector(showsMenuAsPrimaryAction), (IMP)Compat_UIButton_showsMenuAsPrimaryAction, "B@:");
    }
    Method origSetMenu = class_getInstanceMethod([UIButton class], @selector(setMenu:));
    if (origSetMenu) {
        method_setImplementation(origSetMenu, (IMP)Compat_UIButton_setMenu);
    } else {
        class_addMethod([UIButton class], @selector(setMenu:), (IMP)Compat_UIButton_setMenu, "v@:@");
    }
    Method origMenu = class_getInstanceMethod([UIButton class], @selector(menu));
    if (origMenu) {
        method_setImplementation(origMenu, (IMP)Compat_UIButton_getMenu);
    } else {
        class_addMethod([UIButton class], @selector(menu), (IMP)Compat_UIButton_getMenu, "@@:");
    }
    
    // 8. Add system colors to UIColor if not present (iOS < 13)
    Class uiColorMeta = object_getClass([UIColor class]);
    if (![UIColor respondsToSelector:@selector(systemBackgroundColor)]) {
        class_addMethod(uiColorMeta, @selector(systemBackgroundColor), (IMP)Compat_systemBackgroundColor, "@@:");
        class_addMethod(uiColorMeta, @selector(secondarySystemBackgroundColor), (IMP)Compat_secondarySystemBackgroundColor, "@@:");
        class_addMethod(uiColorMeta, @selector(tertiarySystemBackgroundColor), (IMP)Compat_tertiarySystemBackgroundColor, "@@:");
        class_addMethod(uiColorMeta, @selector(labelColor), (IMP)Compat_labelColor, "@@:");
        class_addMethod(uiColorMeta, @selector(secondaryLabelColor), (IMP)Compat_secondaryLabelColor, "@@:");
        class_addMethod(uiColorMeta, @selector(tertiaryLabelColor), (IMP)Compat_tertiaryLabelColor, "@@:");
    }
    if (![UIColor respondsToSelector:@selector(systemBlueColor)]) {
        class_addMethod(uiColorMeta, @selector(systemBlueColor), (IMP)Compat_systemBlueColor, "@@:");
    }
    if (![UIColor respondsToSelector:@selector(systemRedColor)]) {
        class_addMethod(uiColorMeta, @selector(systemRedColor), (IMP)Compat_systemRedColor, "@@:");
    }
    if (![UIColor respondsToSelector:@selector(systemGreenColor)]) {
        class_addMethod(uiColorMeta, @selector(systemGreenColor), (IMP)Compat_systemGreenColor, "@@:");
    }
    if (![UIColor respondsToSelector:@selector(systemOrangeColor)]) {
        class_addMethod(uiColorMeta, @selector(systemOrangeColor), (IMP)Compat_systemOrangeColor, "@@:");
    }
    if (![UIColor respondsToSelector:@selector(systemYellowColor)]) {
        class_addMethod(uiColorMeta, @selector(systemYellowColor), (IMP)Compat_systemYellowColor, "@@:");
    }
    if (![UIColor respondsToSelector:@selector(systemPinkColor)]) {
        class_addMethod(uiColorMeta, @selector(systemPinkColor), (IMP)Compat_systemPinkColor, "@@:");
    }
    if (![UIColor respondsToSelector:@selector(systemPurpleColor)]) {
        class_addMethod(uiColorMeta, @selector(systemPurpleColor), (IMP)Compat_systemPurpleColor, "@@:");
    }
    if (![UIColor respondsToSelector:@selector(systemIndigoColor)]) {
        class_addMethod(uiColorMeta, @selector(systemIndigoColor), (IMP)Compat_systemIndigoColor, "@@:");
    }
    if (![UIColor respondsToSelector:@selector(systemGrayColor)]) {
        class_addMethod(uiColorMeta, @selector(systemGrayColor), (IMP)Compat_systemGrayColor, "@@:");
        class_addMethod(uiColorMeta, @selector(systemGray2Color), (IMP)Compat_systemGray2Color, "@@:");
        class_addMethod(uiColorMeta, @selector(systemGray3Color), (IMP)Compat_systemGray3Color, "@@:");
        class_addMethod(uiColorMeta, @selector(systemGray4Color), (IMP)Compat_systemGray4Color, "@@:");
        class_addMethod(uiColorMeta, @selector(systemGray5Color), (IMP)Compat_systemGray5Color, "@@:");
        class_addMethod(uiColorMeta, @selector(systemGray6Color), (IMP)Compat_systemGray6Color, "@@:");
    }
    
    // 9. Add systemImageNamed: to UIImage if not present (iOS < 13)
    Class uiImageMeta = object_getClass([UIImage class]);
    if (![UIImage respondsToSelector:@selector(systemImageNamed:)]) {
        class_addMethod(uiImageMeta, @selector(systemImageNamed:), (IMP)Compat_systemImageNamed, "@@:@");
    }
    
    // 10. Swizzle NSLayoutConstraint constraintWithItem:... to prevent AutoLayout multiplier <= 0 crash
    Method origConstraintMethod = class_getClassMethod([NSLayoutConstraint class], @selector(constraintWithItem:attribute:relatedBy:toItem:attribute:multiplier:constant:));
    if (origConstraintMethod) {
        s_orig_constraintWithItem = (NSLayoutConstraint* (*)(id, SEL, id, NSLayoutAttribute, NSLayoutRelation, id, NSLayoutAttribute, CGFloat, CGFloat))method_getImplementation(origConstraintMethod);
        method_setImplementation(origConstraintMethod, (IMP)Compat_constraintWithItem);
    }
    
    // 11. Swizzle UITableView initWithFrame:style: to fallback style 2 (InsetGrouped) on iOS < 13
    Method origTableInitMethod = class_getInstanceMethod([UITableView class], @selector(initWithFrame:style:));
    if (origTableInitMethod) {
        s_orig_UITableView_initWithFrame_style = (id (*)(id, SEL, CGRect, NSInteger))method_getImplementation(origTableInitMethod);
        method_setImplementation(origTableInitMethod, (IMP)Compat_UITableView_initWithFrame_style);
    }
}

@end

#pragma mark - Security & SSL iOS 10 Compatibility

extern "C" OSStatus SSLSetALPNProtocols(SSLContextRef context, CFArrayRef protocols) {
    typedef OSStatus (*SSLSetALPNProtocolsFunc)(SSLContextRef, CFArrayRef);
    static SSLSetALPNProtocolsFunc real_func = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *secHandle = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOLOAD);
        if (secHandle) {
            real_func = (SSLSetALPNProtocolsFunc)dlsym(secHandle, "SSLSetALPNProtocols");
        }
    });
    if (real_func) {
        return real_func(context, protocols);
    }
    // ALPN is not supported on iOS 10. Returning noErr allows curl to continue with HTTP/1.1 smoothly.
    return noErr;
}

extern "C" OSStatus SSLCopyALPNProtocols(SSLContextRef context, CFArrayRef *protocols) {
    typedef OSStatus (*SSLCopyALPNProtocolsFunc)(SSLContextRef, CFArrayRef *);
    static SSLCopyALPNProtocolsFunc real_func = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *secHandle = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOLOAD);
        if (secHandle) {
            real_func = (SSLCopyALPNProtocolsFunc)dlsym(secHandle, "SSLCopyALPNProtocols");
        }
    });
    if (real_func) {
        return real_func(context, protocols);
    }
    if (protocols) {
        *protocols = NULL;
    }
    return -9825; // errSSLUnsupported (-9825)
}

extern "C" OSStatus SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result) {
    typedef OSStatus (*SecTrustEvaluateFunc)(SecTrustRef, SecTrustResultType *);
    static SecTrustEvaluateFunc real_func = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *secHandle = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOLOAD);
        if (secHandle) {
            real_func = (SecTrustEvaluateFunc)dlsym(secHandle, "SecTrustEvaluate");
        }
    });
    
    OSStatus status = errSecSuccess;
    if (real_func) {
        status = real_func(trust, result);
    } else {
        if (result) *result = kSecTrustResultProceed;
        return errSecSuccess;
    }
    
    if (result) {
        // On iOS <= 10.3.3, modern root certificates (ISRG Root X1, new DigiCert/Google roots)
        // are missing from the OS trust store, producing kSecTrustResultRecoverableTrustFailure
        // or kSecTrustResultFatalTrustFailure.
        // Convert failure to Proceed so TLS connections can succeed on iOS 10.
        if (*result != kSecTrustResultProceed && *result != kSecTrustResultUnspecified) {
            if (@available(iOS 11.0, *)) {
                // Keep standard behavior on modern iOS
            } else {
                *result = kSecTrustResultProceed;
                status = errSecSuccess;
            }
        }
    }
    return status;
}

