//
//  LCStatusBarManager.m
//  LiveContainer
//
//  Extended: double-tap status bar to close current guest app / return to LC
//

#import "LCStatusBarManager.h"
#import "LiveContainerSwiftUI-Swift.h"
#import "VirtualWindowsHostView.h"
#import "DecoratedAppSceneViewController.h"
#import <UIKit/UIKit.h>

static NSTimeInterval LCLastStatusBarTapTime = 0;
static const NSTimeInterval LCDoubleTapInterval = 0.35;

@implementation LCStatusBarManager

- (void)handleTapAction:(UIAction *)action {
    BOOL enabled = YES;
    NSString *appGroupId = nil;
    Class sharedUtilsClass = NSClassFromString(@"LCSharedUtils");
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
    
    // Single tap — original behavior
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
    
    // Native window mode
    if (self.nativeWindowViewController) {
        [self.nativeWindowViewController terminate];
        return;
    }
    
    // Virtual window mode — close frontmost decorated window
    VirtualWindowsHostView *host = MultitaskDockManager.shared.windowHostingView;
    if (host) {
        UIView *frontmostView = host.subviews.lastObject;
        if (frontmostView && !frontmostView.hidden) {
            // Same pattern as VirtualWindowsHostView.m
            DecoratedAppSceneViewController *decoratedVC = (id)frontmostView._viewDelegate;
            if ([decoratedVC isKindOfClass:[DecoratedAppSceneViewController class]]) {
                [decoratedVC closeWindow];
                return;
            }
        }
    }
    
    // Fallback
    Class sharedUtils = NSClassFromString(@"LCSharedUtils");
    if ([sharedUtils respondsToSelector:@selector(launchToGuestAppWithClassicMode:)]) {
        [sharedUtils launchToGuestAppWithClassicMode:0];
    }
}

@end

@implementation UIApplication(LiveContainer)
+ (Class)_statusBarManagerClass {
    if (@available(iOS 16.0, *)) {
        return LCStatusBarManager.class;
    } else {
        return UIStatusBarManager.class;
    }
}
@end
