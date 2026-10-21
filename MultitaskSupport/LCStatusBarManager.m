//
//  LCStatusBarManager.m
//  LiveContainer
//
//  Double-tap near the clock (leading status-bar region) → close guest / return to LC.
//

#import "LCStatusBarManager.h"
#import "LiveContainerSwiftUI-Swift.h"
#import "VirtualWindowsHostView.h"
#import "DecoratedAppSceneViewController.h"

@interface UIView (LCStatusBarPrivate)
- (UIViewController *)_viewDelegate;
@end

// ~system double-tap; slightly under 0.5s so it tracks clock taps naturally
static const NSTimeInterval kLCStatusBarDoubleTapWindow = 0.40;
static NSTimeInterval LCPendingTapTime = 0;
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
    return YES;
}

/// Prefer the clock side of the status bar (leading ~48% in LTR, trailing in RTL).
static BOOL LCTapIsOnClockSide(UIAction *action) {
    id sender = nil;
    if ([action respondsToSelector:@selector(sender)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        sender = [action performSelector:@selector(sender)];
#pragma clang diagnostic pop
    }
    if (![sender isKindOfClass:[UIView class]]) {
        // No geometry — treat as clock-side so double-tap still works.
        return YES;
    }
    UIView *view = (UIView *)sender;
    CGRect frame = [view convertRect:view.bounds toView:nil];
    CGFloat midX = CGRectGetMidX(frame);
    CGFloat width = CGRectGetWidth(UIScreen.mainScreen.bounds);
    if (width < 1) return YES;

    BOOL rtl = NO;
    if (@available(iOS 13.0, *)) {
        rtl = (view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
    }
    if (rtl) {
        return midX >= width * 0.52;
    }
    // Clock sits under the left status region; keep a little margin past the island edge.
    return midX <= width * 0.48;
}

@implementation LCStatusBarManager

- (void)handleTapAction:(UIAction *)action {
    if (!LCDoubleTapExitEnabled() || !LCTapIsOnClockSide(action)) {
        [self lc_forwardSingleTap:action];
        return;
    }

    NSTimeInterval now = CFAbsoluteTimeGetCurrent();

    if (LCPendingSingleTapBlock != nil &&
        LCPendingTapTime > 0 &&
        (now - LCPendingTapTime) <= kLCStatusBarDoubleTapWindow) {
        dispatch_block_cancel(LCPendingSingleTapBlock);
        LCPendingSingleTapBlock = nil;
        LCPendingTapTime = 0;
        [self lc_handleDoubleTapExit];
        return;
    }

    if (LCPendingSingleTapBlock) {
        dispatch_block_cancel(LCPendingSingleTapBlock);
        LCPendingSingleTapBlock = nil;
    }

    LCPendingTapTime = now;
    __weak typeof(self) weakSelf = self;
    UIAction *captured = action;
    LCPendingSingleTapBlock = dispatch_block_create(0, ^{
        LCPendingSingleTapBlock = nil;
        LCPendingTapTime = 0;
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
