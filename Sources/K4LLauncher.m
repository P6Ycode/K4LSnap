#import "K4LLauncher.h"
#import "K4LPreferences.h"
#import "K4LGalleryUploadCoordinator.h"
#import "K4LVaultViewController.h"
#import "K4LSettingsViewController.h"
#import <UIKit/UIKit.h>

@interface K4LLauncher ()
@property (nonatomic, strong, nullable) UIButton *button;
@end

@implementation K4LLauncher

+ (instancetype)shared {
    static id value;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ value = [self new]; });
    return value;
}

- (void)install {
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(windowBecameKey:) name:UIWindowDidBecomeKeyNotification object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{ [self attachToKeyWindow]; });
}

- (void)windowBecameKey:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{ [self attachToKeyWindow]; });
}

- (UIWindow *)keyWindow {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) if (window.isKeyWindow) return window;
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

- (void)attachToKeyWindow {
    if (![[K4LPreferences shared] boolForKey:@"launcherEnabled" defaultValue:YES]) {
        [self.button removeFromSuperview];
        self.button = nil;
        return;
    }

    UIWindow *window = [self keyWindow];
    if (!window) return;
    if (!self.button) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(18, 180, 52, 52);
        button.layer.cornerRadius = 26;
        button.layer.shadowColor = UIColor.blackColor.CGColor;
        button.layer.shadowOpacity = 0.22;
        button.layer.shadowRadius = 8;
        button.layer.shadowOffset = CGSizeMake(0, 3);
        button.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.92];
        [button setTitle:@"K4L" forState:UIControlStateNormal];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        [button addTarget:self action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];
        [button addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
        button.accessibilityLabel = @"Open K4LSnap";
        self.button = button;
    }
    if (self.button.superview != window) {
        [self.button removeFromSuperview];
        [window addSubview:self.button];
    }
    [window bringSubviewToFront:self.button];
}

- (void)reloadVisibility {
    dispatch_async(dispatch_get_main_queue(), ^{ [self attachToKeyWindow]; });
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *view = gesture.view;
    UIView *container = view.superview;
    if (!view || !container) return;
    CGPoint translation = [gesture translationInView:container];
    CGPoint center = CGPointMake(view.center.x + translation.x, view.center.y + translation.y);
    CGFloat halfWidth = CGRectGetWidth(view.bounds) / 2.0;
    CGFloat halfHeight = CGRectGetHeight(view.bounds) / 2.0;
    UIEdgeInsets insets = container.safeAreaInsets;
    center.x = MAX(insets.left + halfWidth + 4, MIN(CGRectGetWidth(container.bounds) - insets.right - halfWidth - 4, center.x));
    center.y = MAX(insets.top + halfHeight + 4, MIN(CGRectGetHeight(container.bounds) - insets.bottom - halfHeight - 4, center.y));
    view.center = center;
    [gesture setTranslation:CGPointZero inView:container];
}

- (UIViewController *)topViewController {
    UIViewController *controller = [self keyWindow].rootViewController;
    while (controller) {
        if (controller.presentedViewController) { controller = controller.presentedViewController; continue; }
        if ([controller isKindOfClass:UINavigationController.class]) { controller = ((UINavigationController *)controller).visibleViewController; continue; }
        if ([controller isKindOfClass:UITabBarController.class]) { controller = ((UITabBarController *)controller).selectedViewController; continue; }
        break;
    }
    return controller;
}

- (void)dismissPresentedController {
    UIViewController *controller = [self topViewController];
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (UIBarButtonItem *)closeButton {
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(dismissPresentedController)];
}

- (void)showMenu {
    UIViewController *presenter = [self topViewController];
    if (!presenter) return;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"K4LSnap" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Gallery Upload" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [[K4LGalleryUploadCoordinator sharedCoordinator] presentGalleryFromViewController:presenter];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Import from Files" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [[K4LGalleryUploadCoordinator sharedCoordinator] presentFilesFromViewController:presenter];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Media Vault" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        K4LVaultViewController *vault = [K4LVaultViewController new];
        vault.navigationItem.leftBarButtonItem = [self closeButton];
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:vault];
        navigation.modalPresentationStyle = UIModalPresentationFullScreen;
        [presenter presentViewController:navigation animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        K4LSettingsViewController *settings = [K4LSettingsViewController new];
        settings.navigationItem.leftBarButtonItem = [self closeButton];
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:settings];
        navigation.modalPresentationStyle = UIModalPresentationFormSheet;
        [presenter presentViewController:navigation animated:YES completion:nil];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.button;
        sheet.popoverPresentationController.sourceRect = self.button.bounds;
    }
    [presenter presentViewController:sheet animated:YES completion:nil];
}

@end
