//
//  LCStatusBarManager.m
//  LiveContainer
//
//  Extended: double-tap status bar closes current guest window / returns to LC
//

#import "LCStatusBarManager.h"
#import "LiveContainerSwiftUI-Swift.h"
#import "VirtualWindowsHostView.h"
#import "DecoratedAppSceneViewController.h"

@interface UIView (LCStatusBarPrivate)
- (UIViewController *)_viewDelegate;
@end

static NSTimeInterval LCLastStatusBarTapTime = 0;
static const NSTimeInterval LCDoubleTapInterval = 0.35;

@implementation LCStatusBarManager

- (void)handleTapAction:(UIAction *)action {
    BOOL enabled = YES;
    Class sharedUtilsClass = NSClassFromString(@"LCSharedUtils");
    NSString *appGroupId = nil;
    if ([sharedUtilsClass respondsToSelector:@selector(appGroupID)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        appGroupId = [sharedUtilsClass performSelector:@selector(appGroupID)];
#pragma clang diagnostic pop
    }
    NSUserDefaults *defaults = appGroupId
        ? [[NSUserDefaults alloc] initWithSuiteName:appGroupId]
        : [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"LCDoubleTapStatusBarToExit"] != nil) {
        enabled = [defaults boolForKey:@"LCDoubleTapStatusBarToExit"];
    }

    if (enabled) {
        NSTimeInterval now = CFAbsoluteTimeGetCurrent();
        if (LCLastStatusBarTapTime > 0 && (now - LCLastStatusBarTapTime) <= LCDoubleTapInterval) {
            LCLastStatusBarTapTime = 0;
            [self lc_handleDoubleTapExit];
            return;
        }
        LCLastStatusBarTapTime = now;
    }

    if (self.nativeWindowViewController) {
        [self.nativeWindowViewController handleStatusBarTapAction:action];
        return;
    }
    BOOL handledByVirtualWindow = [MultitaskDockManager.shared.windowHostingView handleStatusBarTapAction:action];
    if (!handledByVirtualWindow) {
        [super handleTapAction:action];
    }
}

- (void)lc_handleDoubleTapExit {
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen impactOccurred];

    if (self.nativeWindowViewController) {
        [self.nativeWindowViewController terminate];
        return;
    }

    VirtualWindowsHostView *host = MultitaskDockManager.shared.windowHostingView;
    if (host) {
        UIView *frontmostView = host.subviews.lastObject;
        if (frontmostView && !frontmostView.hidden) {
            id decorated = [frontmostView _viewDelegate];
            // closeWindow is private to the .m — call via performSelector
            if (decorated && [decorated respondsToSelector:@selector(closeWindow)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [decorated performSelector:@selector(closeWindow)];
#pragma clang diagnostic pop
                return;
            }
            if ([decorated isKindOfClass:[DecoratedAppSceneViewController class]]) {
                AppSceneViewController *sceneVC = [(DecoratedAppSceneViewController *)decorated appSceneVC];
                if (sceneVC) {
                    [sceneVC terminate];
                    return;
                }
            }
        }
    }

    Class sharedUtils = NSClassFromString(@"LCSharedUtils");
    if ([sharedUtils respondsToSelector:@selector(launchToGuestAppWithClassicMode:)]) {
        [sharedUtils launchToGuestAppWithClassicMode:0];
    }
}

@end

@implementation UIApplication (LiveContainer)
+ (Class)_statusBarManagerClass {
    if (@available(iOS 16.0, *)) {
        return [LCStatusBarManager class];
    } else {
        return [UIStatusBarManager class];
    }
}
@end
