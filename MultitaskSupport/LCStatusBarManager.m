//
//  LCStatusBarManager.m
//  LiveContainer
//
//  Double-tap status bar → close frontmost guest / return to LiveContainer.
//  Uses delayed single-tap so double-tap is reliable across iOS versions.
//

#import "LCStatusBarManager.h"
#import "LiveContainerSwiftUI-Swift.h"
#import "VirtualWindowsHostView.h"
#import "DecoratedAppSceneViewController.h"

@interface UIView (LCStatusBarPrivate)
- (UIViewController *)_viewDelegate;
@end

// Prefer slightly longer than system double-tap (~0.3–0.4s); 0.5s is forgiving.
static const NSTimeInterval kLCStatusBarDoubleTapWindow = 0.50;
static NSTimeInterval LCPendingTapTime = 0;
static UIAction *LCPendingTapAction = nil;
static dispatch_block_t LCPendingSingleTapBlock = nil;

static BOOL LCDoubleTapExitEnabled(void) {
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
        return [defaults boolForKey:@"LCDoubleTapStatusBarToExit"];
    }
    return YES; // default on
}

@implementation LCStatusBarManager

- (void)handleTapAction:(UIAction *)action {
    if (!LCDoubleTapExitEnabled()) {
        [self lc_forwardSingleTap:action];
        return;
    }

    NSTimeInterval now = CFAbsoluteTimeGetCurrent();

    // Second tap within window → double-tap exit
    if (LCPendingSingleTapBlock != nil &&
        LCPendingTapTime > 0 &&
        (now - LCPendingTapTime) <= kLCStatusBarDoubleTapWindow) {
        dispatch_block_cancel(LCPendingSingleTapBlock);
        LCPendingSingleTapBlock = nil;
        LCPendingTapAction = nil;
        LCPendingTapTime = 0;
        [self lc_handleDoubleTapExit];
        return;
    }

    // Cancel any previous pending single-tap
    if (LCPendingSingleTapBlock) {
        dispatch_block_cancel(LCPendingSingleTapBlock);
        LCPendingSingleTapBlock = nil;
    }

    LCPendingTapTime = now;
    LCPendingTapAction = action;
    __weak typeof(self) weakSelf = self;
    UIAction *captured = action;
    LCPendingSingleTapBlock = dispatch_block_create(0, ^{
        LCPendingSingleTapBlock = nil;
        LCPendingTapTime = 0;
        LCPendingTapAction = nil;
        [weakSelf lc_forwardSingleTap:captured];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kLCStatusBarDoubleTapWindow * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   LCPendingSingleTapBlock);
}

- (void)lc_forwardSingleTap:(UIAction *)action {
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
    UIImpactFeedbackGenerator *gen =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen prepare];
    [gen impactOccurred];

    if (self.nativeWindowViewController) {
        [self.nativeWindowViewController terminate];
        return;
    }

    VirtualWindowsHostView *host = MultitaskDockManager.shared.windowHostingView;
    if (host) {
        // Frontmost visible window
        for (UIView *sub in [host.subviews reverseObjectEnumerator]) {
            if (sub.hidden || sub.alpha < 0.05) continue;
            id decorated = [sub _viewDelegate];
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
