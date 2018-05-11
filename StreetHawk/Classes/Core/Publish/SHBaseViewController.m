/*
 * Copyright (c) StreetHawk, All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3.0 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library.
 */

#import "SHBaseViewController.h"
//header from StreetHawk
#import "SHApp.h" //for `StreetHawk shNotifyPageEnter/Exit`
#import "SHViewController.h" //for checking internal vc to avoid enter/exit log
#import "SHUtils.h" //for shIsSDKViewController
#import "SHCoverView.h" //for cover view
//header from System
#import <objc/runtime.h> //for associate object
//header from third-party
#import "Aspects.h"

@interface NSString (SHEnterExitExt)

//Before logline enter or exit the page name, do some refinement.
- (NSString *)refinePageName;

@end

@implementation NSString (private)

- (NSString *)refinePageName
{
    NSString *page = self;
    //Swift class name contains App name, remove it before logline.
    if ([page rangeOfString:@"."].location != NSNotFound)
    {
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
        NSString *appPrefix = [NSString stringWithFormat:@"%@.", appName];
        if ([page hasPrefix:appPrefix])
        {
            page = [page substringFromIndex:appPrefix.length];
        }
    }
    return page;
}

@end

@implementation StreetHawkViewControllerSwizzle

+ (void)aspect
{
    //aspect UIViewController
    [UIViewController aspect_hookSelector:@selector(viewDidLoad)
                              withOptions:AspectPositionAfter
                               usingBlock:^(id<AspectInfo> aspectInfo, BOOL animated) {
                                   UIViewController *vc = (UIViewController *)aspectInfo.instance;
                                   if (![self checkReactNative])
                                   {
                                       [self _doViewDidLoad:vc];
                                   }
        NSLog(@"View Controller %@ viewDidLoad", aspectInfo.instance);
    } error:NULL];
    
    //tricky: Record `viewWillAppear` as backup, become in canceled pop up `viewDidAppear` is not called.
    [UIViewController aspect_hookSelector:@selector(viewWillAppear:)
                              withOptions:AspectPositionAfter
                               usingBlock:^(id<AspectInfo> aspectInfo, BOOL animated) {
                                   UIViewController *vc = (UIViewController *)aspectInfo.instance;
                                   if (![self checkReactNative]) {
                                       [self _doViewWillAppear:vc];
                                   }
                                   [self hookReactNative:vc];
                                   NSLog(@"View Controller %@ viewWillAppear", aspectInfo.instance);
                               } error:NULL];
    
    //tricky: Here must use `viewDidAppear` and `viewWillDisappear`.
    //if use `viewWillAppear`, two issues: 1) Launch App `viewWillAppear` is called before `didFinishLaunchingWithOptions`, making home page not logged; 2) `viewWillAppear` cannot get self.view.window, always null, making it's unknown to check `SHCoverWindow`(deprecated).
    //if use `viewDidDisappear`, present modal view controller has problem. For example, A present modal B, first call B `viewDidAppear` then call A `viewDidDisappear`, making the order wrong, expecting A disappear first and then B appear. Use `viewWillDisappear` solve this problem.
    //the mix just match requirement: disappear first and appear.
    [UIViewController aspect_hookSelector:@selector(viewDidAppear:)
                              withOptions:AspectPositionAfter
                               usingBlock:^(id<AspectInfo> aspectInfo, BOOL animated) {
                                   UIViewController *vc = (UIViewController *)aspectInfo.instance;
                                   if (![self checkReactNative])
                                   {
                                       [self _doViewDidAppear:vc];
                                   }
                                   NSLog(@"View Controller %@ viewDidAppear", aspectInfo.instance);
                               } error:NULL];
    
    [UIViewController aspect_hookSelector:@selector(viewWillDisappear:)
                              withOptions:AspectPositionAfter
                               usingBlock:^(id<AspectInfo> aspectInfo, BOOL animated) {
                                   UIViewController *vc = (UIViewController *)aspectInfo.instance;
                                   if (![self checkReactNative])
                                   {
                                       [self _doViewWillDisappear:vc];
                                   }
                                   NSLog(@"View Controller %@ viewWillDisappear", aspectInfo.instance);
                               } error:NULL];
    
    //aspect UITableViewController
    [UITableViewController aspect_hookSelector:@selector(viewDidLoad)
                              withOptions:AspectPositionAfter
                               usingBlock:^(id<AspectInfo> aspectInfo, BOOL animated) {
                                   UITableViewController *vc = (UITableViewController *)aspectInfo.instance;
                                   if ([vc respondsToSelector:@selector(displayDeepLinkingToUI)])
                                   {
                                       [vc performSelector:@selector(displayDeepLinkingToUI)];
                                   }
                                   if (!shIsSDKViewController(vc)) //Not show tip and super tag for SDK vc
                                   {
                                       [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ShowTip_Notification" object:nil userInfo:@{@"vc": vc}];
                                       [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_CustomFeed_Notification" object:nil userInfo:@{@"vc": vc}];
                                       [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_SuperTag_Notification" object:nil userInfo:@{@"vc": vc}];
                                   }
                                   NSLog(@"View Controller %@ viewWillDisappear", aspectInfo.instance);
                               } error:NULL];
    
    [UITableViewController aspect_hookSelector:@selector(viewWillAppear:)
                                   withOptions:AspectPositionAfter
                                    usingBlock:^(id<AspectInfo> aspectInfo, BOOL animated) {
                                        UITableViewController *vc = (UITableViewController *)aspectInfo.instance;
                                        if (!shIsSDKViewController(vc))
                                        {
                                            [[NSUserDefaults standardUserDefaults] setObject:vc.class.description forKey:@"ENTERBAK_PAGE_HISTORY"];
                                            [[NSUserDefaults standardUserDefaults] synchronize];
                                        }
                                        NSLog(@"View Controller %@ viewWillDisappear", aspectInfo.instance);
                                    } error:NULL];
    
    [UITableViewController aspect_hookSelector:@selector(viewDidAppear:)
                                   withOptions:AspectPositionAfter
                                    usingBlock:^(id<AspectInfo> aspectInfo, BOOL animated) {
                                        UITableViewController *vc = (UITableViewController *)aspectInfo.instance;
                                        if (!shIsSDKViewController(vc))
                                        {
                                            [StreetHawk shNotifyPageEnter:[vc.class.description refinePageName]];
                                            [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_EnterVC_Notification" object:nil userInfo:@{@"vc": vc}];
                                            [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ShowAuthor_Notification" object:nil userInfo:@{@"vc": vc}];
                                        }
                                        NSLog(@"View Controller %@ viewWillDisappear", aspectInfo.instance);
                                    } error:NULL];
    
    [UITableViewController aspect_hookSelector:@selector(viewWillDisappear:)
                                   withOptions:AspectPositionAfter
                                    usingBlock:^(id<AspectInfo> aspectInfo, BOOL animated) {
                                        UITableViewController *vc = (UITableViewController *)aspectInfo.instance;
                                        if (!shIsSDKViewController(vc))
                                        {
                                            [StreetHawk shNotifyPageExit:[vc.class.description refinePageName]];
                                            [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ForceDismissTip_Notification" object:nil userInfo:@{@"vc": vc}];
                                            [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ExitVC_Notification" object:nil userInfo:@{@"vc": vc}];
                                        }
                                        NSLog(@"View Controller %@ viewWillDisappear", aspectInfo.instance);
                                    } error:NULL];
}

+ (void)_doViewDidLoad:(UIViewController *)vc
{
    if ([vc respondsToSelector:@selector(displayDeepLinkingToUI)])
    {
        [vc performSelector:@selector(displayDeepLinkingToUI)];
    }
    if (!shIsSDKViewController(vc)) //Not show tip and super tag for SDK vc
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ShowTip_Notification" object:nil userInfo:@{@"vc": vc}];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_CustomFeed_Notification" object:nil userInfo:@{@"vc": vc}];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_SuperTag_Notification" object:nil userInfo:@{@"vc": vc}];
    }
}

+ (void)_doViewWillAppear:(UIViewController *)vc
{
    if (!shIsSDKViewController(vc))
    {
        [[NSUserDefaults standardUserDefaults] setObject:[shAppendUniqueSuffix(vc) refinePageName] forKey:@"ENTERBAK_PAGE_HISTORY"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+ (void)_doViewDidAppear:(UIViewController *)vc
{
    if (!shIsSDKViewController(vc)) //several internal used vc not need log, such as SHFeedbackViewController, SHSlideWebViewController (it calls appear even not show).
    {
        [StreetHawk shNotifyPageEnter:[shAppendUniqueSuffix(vc) refinePageName]];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_EnterVC_Notification" object:nil userInfo:@{@"vc": vc}];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ShowAuthor_Notification" object:nil userInfo:@{@"vc": vc}];
    }
}

+ (void)_doViewWillDisappear:(UIViewController *)vc
{
    if (!shIsSDKViewController(vc)) //several internal used vc not need log, such as SHFeedbackViewController, SHSlideWebViewController (it calls appear even not show).
    {
        [StreetHawk shNotifyPageExit:[shAppendUniqueSuffix(vc) refinePageName]];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ForceDismissTip_Notification" object:nil userInfo:@{@"vc": vc}];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ExitVC_Notification" object:nil userInfo:@{@"vc": vc}];
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

+ (BOOL)checkReactNative {
    Class rcClass = NSClassFromString(@"RCTRootView");
    return (rcClass != nil);
}

+ (void)hookReactNative:(UIViewController *)vc {
    Class rcClass = NSClassFromString(@"RCTRootView");
    if (!rcClass) {
        return;
    }
    
    if (![vc.view respondsToSelector:@selector(bridge)]) {
        return;
    }
    id bridge = [vc.view valueForKey:@"bridge"];
    if (!bridge) {
        return;
    }
    
    if (![bridge respondsToSelector:@selector(uiManager)]) {
        return;
    }
    id uiManager = [bridge performSelector:@selector(uiManager) withObject:nil];
    if (!uiManager) {
        return;
    }
    
    if (![uiManager respondsToSelector:@selector(observerCoordinator)]) {
        return;
    }
    id observerCoordinator = [uiManager valueForKey:@"observerCoordinator"];
    if (!observerCoordinator) {
        return;
    }
    if (![observerCoordinator respondsToSelector:@selector(addObserver:)]) {
        return;
    }
    [observerCoordinator performSelector:@selector(addObserver:) withObject:self];
}

#pragma clang diagnostic pop

//BOOL _uiMayChange = false;
//NSDate *_lastChangeDate = nil;
//
//- (void)uiManagerWillPerformMounting:(id)manager{
//    id blocks = nil;
//    @try {
//        blocks = [manager valueForKey:@"_pendingUIBlocks"];
//    }
//    @catch(NSException *e) {}
//    if (!blocks) {
//        return;
//    }
//    if (![blocks respondsToSelector:@selector(count)]) {
//        return;
//    }
//    int changePageCount = (int)[blocks performSelector:@selector(count)];
//    if (changePageCount > 1) {
//        if (!_uiMayChange) {
//            // equal to viewWillDisappear
//            [self _doViewWillDisappear];
//        }
//        _uiMayChange = true;
//        _lastChangeDate = [NSDate date];
//    }
//    else if (_uiMayChange) {
//        NSDate *now = [NSDate date];
//        NSTimeInterval changeTimeInterval = [now timeIntervalSinceDate:_lastChangeDate];
//        if (changeTimeInterval > 1.0f) {
//            _uiMayChange = false;
//            // equal to viewDidLoad + viewWillAppear + viewDidAppear
//            [self _doViewDidLoad];
//            [self _doViewWillAppear];
//            [self _doViewDidAppear];
//        }
//    }
//}

@end

@implementation StreetHawkBaseCollectionViewController

- (id)init
{
    if (self = [super init])
    {
        self.excludeBehavior = NO;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        self.excludeBehavior = NO;
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.excludeBehavior = NO;
    }
    return self;
}

- (id)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
    if (self = [super initWithCollectionViewLayout:layout])
    {
        self.excludeBehavior = NO;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(displayDeepLinkingToUI)])
    {
        [self performSelector:@selector(displayDeepLinkingToUI)];
    }
    if (!self.excludeBehavior && !shIsSDKViewController(self)) //Not show tip and super tag for SDK vc
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ShowTip_Notification" object:nil userInfo:@{@"vc": self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_CustomFeed_Notification" object:nil userInfo:@{@"vc": self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_SuperTag_Notification" object:nil userInfo:@{@"vc": self}];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (!self.excludeBehavior && !shIsSDKViewController(self))
    {
        [[NSUserDefaults standardUserDefaults] setObject:self.class.description forKey:@"ENTERBAK_PAGE_HISTORY"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (!self.excludeBehavior && !shIsSDKViewController(self)) //several internal used vc not need log, such as SHFeedbackViewController, SHSlideWebViewController (it calls appear even not show).
    {
        [StreetHawk shNotifyPageEnter:[self.class.description refinePageName]];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_EnterVC_Notification" object:nil userInfo:@{@"vc": self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ShowAuthor_Notification" object:nil userInfo:@{@"vc": self}];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (!self.excludeBehavior && !shIsSDKViewController(self)) //several internal used vc not need log, such as SHFeedbackViewController, SHSlideWebViewController (it calls appear even not show).
    {
        [StreetHawk shNotifyPageExit:[self.class.description refinePageName]];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ForceDismissTip_Notification" object:nil userInfo:@{@"vc": self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PointziBridge_ExitVC_Notification" object:nil userInfo:@{@"vc": self}];
    }
}

@end

@interface UIViewController (SHViewExt_private)

@property (nonatomic, strong) SHCoverView *coverView; //if it has cover view required, assign to this property.

@end

@implementation UIViewController(SHViewExt)

- (SHCoverView *)coverView
{
    return objc_getAssociatedObject(self, @selector(coverView));
}

- (void)setCoverView:(SHCoverView *)coverView
{
    objc_setAssociatedObject(self, @selector(coverView), coverView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)presentOnTopWithCover:(BOOL)needCover
               withCoverColor:(UIColor *)coverColor
               withCoverAlpha:(CGFloat)coverAlpha
                    withDelay:(BOOL)needDelay
        withCoverTouchHandler:(void (^)(CGPoint touchPoint))coverTouchHandler
         withAnimationHandler:(void (^)(CGRect fullScreenRect))animationHandler
        withOrientationChangedHandler:(void (^)(CGRect))orientationChangedHandler
{
    double delayInMilliSeconds = needDelay ? 500 : 0; //delay, otherwise if previous is an alert view, the rootVC is UIAlertShimPresentingViewController. Test this is minimum time.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInMilliSeconds * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^(void)
    {
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        CGRect rootRect = rootVC.view.bounds; //this has orientation included. when rotate it can get the real CGRect accoriding to orientation.
        self.view.frame = CGRectOffset(self.view.frame, INT_MAX, INT_MAX); //make it out of screen, but not change size.
        if (needCover)
        {
            self.coverView = [[SHCoverView alloc] initWithFrame:rootVC.view.bounds];
            self.coverView.contentVC = self; //must have someone retain self as VC. Because it only added view and VC is dealloc, causing keyboard notification cannot trigger. Here has cover view to retain it. This only needed for keyboard input view controller, such as feedback input VC.
            self.coverView.overlayColor = coverColor;
            self.coverView.overlayAlpha = coverAlpha;
            self.coverView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; //make cover always full screen during rotation.
            UIViewController *presentedVC = rootVC;
            while (presentedVC.presentedViewController != nil)
            {
                presentedVC = presentedVC.presentedViewController;
            }
            [presentedVC.view addSubview:self.coverView];
            self.coverView.alpha = 0;
            [UIView animateWithDuration:0.1 animations:^{
                self.coverView.alpha = 1.0;
            }];
//            [[UIApplication sharedApplication].keyWindow addSubview:self.coverView]; //this also work but cannot rotate
            self.view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin; //content vc by default always in center, not affected by rotatation.
            [self.coverView addSubview:self.view];
            if (coverTouchHandler != nil)
            {
                self.coverView.touchedHandler = ^ (CGPoint touchPoint)
                {
                    coverTouchHandler(touchPoint);
                };
            }
            if (orientationChangedHandler != nil)
            {
                self.coverView.orientationChangedHandler = ^
                {
                    orientationChangedHandler(rootVC.view.bounds); //get root rect after orientation.
                };
            }
        }
        else
        {
            [rootVC.view addSubview:self.view];
        }
        if (animationHandler != nil)
        {
            animationHandler(rootRect); //allow customer code to animation show.
        }
        else
        {
            //directly add, not need animation. by default, put the content vc in middle of screen.
            self.view.frame = CGRectMake((rootRect.size.width - self.view.frame.size.width) / 2, (rootRect.size.height - self.view.frame.size.height) / 2, self.view.frame.size.width, self.view.frame.size.height);
        }
    });
}

- (void)dismissOnTop
{
    [self.view removeFromSuperview];
    if (self.coverView != nil)
    {
        [UIView animateWithDuration:0.1 animations:^{
            self.coverView.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self.coverView removeFromSuperview];
            self.coverView.contentVC = nil; //break loop retain to make self dealloc
        }];
    }
}

@end

