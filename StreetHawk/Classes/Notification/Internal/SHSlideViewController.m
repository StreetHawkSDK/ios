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

#import "SHSlideViewController.h"
//header from StreetHawk
#import "SHCoverWindow.h" //for cover window
#import "SHAlertView.h" //for confirm dialog
#import "SHSlideWebViewController.h" //for content web view
#import "SHUtils.h" //for shLocalizedString
#import "SHApp+Notification.h" //for handlePushDataForAppCallback
//header from Third-party
#import "CBAutoScrollLabel.h"  //for scrolling title and message

@class SHSlideViewController;

//A container for hosting currently showing SHSlideViewController.
@interface SHSlideContainer : NSObject

@property (nonatomic, strong) NSMutableArray *arrayVCs;
@property (nonatomic) dispatch_semaphore_t semaphore;

//singleton creator.
+ (SHSlideContainer *)shared;
//add one slide vc.
- (void)addSlide:(SHSlideViewController *)vc;
//remove one slide vc.
- (void)removeSlide:(SHSlideViewController *)vc;
//check whether slide vc exist in container.
- (BOOL)containsSlide:(SHSlideViewController *)vc;
//remove all slide vc.
- (void)removeAllSlides;

@end

//Root view controller of the slide cover window. It hosts effect properties, and control show, hide, position of slide.
@interface SHSlideViewController : UIViewController

//The common properties for showing slide.
@property (nonatomic, strong) UIViewController<SHSlideContentViewController> *contentVC;
@property (nonatomic) SHSlideDirection direction;
@property (nonatomic) double speed;
@property (nonatomic) double percentage;
@property (nonatomic, strong) NSString *alertTitle;
@property (nonatomic, strong) NSString *alertMessage;
@property (nonatomic) BOOL needShowDialog;

@property (nonatomic, strong) UIWindow *windowCover;  //ARC: add this strong property to keep window, otherwise window is dealloc in `showSlide` and nothing show; Note: this property is set nil in `dismissSlide` to break retain. Test: window, slide vc and content vc are all dealloc.
@property (nonatomic, strong) UIView *viewContainer;  //a container view to host detail slide content. cannot use rootViewController.view because it covers whole screen, and there are other controls such as close button.
@property (nonatomic, strong) UIView *viewTitle;  //title banner, contains close button.

//Initialise and assign the properties.
- (id)initForContent:(UIViewController<SHSlideContentViewController> *)contentVC withDirection:(SHSlideDirection)direction withSpeed:(double)speed withCoverPercentage:(double)percentage withAlertTitle:(NSString *)alertTitle withAlertMessage:(NSString *)alertMessage withNeedShowDialog:(BOOL)needShowDialog;

//Create and layout content view, calculate proper position and show slide. Note: this can be called only once. If call it again another window will be created. Match to `dismissSlide`.
- (void)showSlide;
//Dismiss window and release self. Note: this can be called only once because self is dealloc. Second call cause crash. Match to `showSlide`.
- (void)dismissSlide;
//Calculate after rotate, adjust container view, title and close button.
- (void)rotateSlide;
//Call `dismissSlideView`.
- (void)buttonCloseClicked:(id)sender;

//Calculate rect position for a certain orientation.
- (CGFloat)statusBarHeight;
- (CGRect)calculateStartRect;
- (CGRect)calculateEndRect;

@end

@implementation SHSlideViewController

#pragma mark - life cycle

- (id)initForContent:(UIViewController<SHSlideContentViewController> *)contentVC_ withDirection:(SHSlideDirection)direction_ withSpeed:(double)speed_ withCoverPercentage:(double)percentage_ withAlertTitle:(NSString *)alertTitle_ withAlertMessage:(NSString *)alertMessage_ withNeedShowDialog:(BOOL)needShowDialog_
{
    if (self = [super initWithNibName:nil bundle:nil])
    {
        self.contentVC = contentVC_;
        self.contentVC.view.frame = CGRectZero;  //this is a tricky part: if contentVC is hide when loading, "showSlide" is not called till load content finish; however to trigger load content the contentVC's viewDidLoad should be called. Here use self.contentVC.view so that its viewDidLoad is called. Note: it cannot use [self calculateStartRect] because window is not ready yet, cannot know rotation.
        self.direction = direction_;
        if (speed_ > 0)
        {
            self.speed = speed_;
        }
        else
        {
            self.speed = 0.1;
        }
        if (percentage_ > 0 && percentage_ <= 1)
        {
            self.percentage = percentage_;
        }
        else if (percentage_ <= 0)
        {
            self.percentage = 0.1;
        }
        else
        {
            self.percentage = 1;
        }
        self.alertTitle = alertTitle_;
        self.alertMessage = alertMessage_;
        self.needShowDialog = needShowDialog_;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];  //The background VC is invisible, show light gray window.
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self rotateSlide];
}

#pragma mark - private functions

static const float SlideTitle_Height = 28;

- (void)showSlide
{
    if (![[SHSlideContainer shared] containsSlide:self])
    {
        return;  //if already remove all, stop showing.
    }
    //animate show slide
    dispatch_block_t actionShowSlide = ^{
        //Move add window to inside actionShowSlide, unless click Yes button not create cover window. This is to fix in case customer not implement clickHandler(SHResult).
        self.viewContainer = [[UIView alloc] initWithFrame:CGRectZero];  //not show it now, out of screen
        [self.view addSubview:self.viewContainer];
        //Add content VC so that content VC is loaded out of screen
        self.contentVC.view.frame = self.viewContainer.bounds;
        self.contentVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;;
        [self.viewContainer addSubview:self.contentVC.view];
        self.windowCover = [[SHCoverWindow alloc] initWithFrame:[UIScreen mainScreen].bounds]; //cannot release window otherwise nothing get show, this window will be manually release when dismissSlideView, so ARC add strong property to keep this window.
        self.windowCover.rootViewController = self;  //set rootViewController so that it can rotate
        [self.windowCover makeKeyAndVisible];  //must use [windowCover makeKeyAndVisible] self.view.window is nil until the window show, and now window.rootViewController is setup.
        self.viewContainer.frame = [self calculateStartRect];
        [self.contentVC contentViewAdjustUI];  //first time know view size.
        __block CGRect endRect = [self calculateEndRect];
        [UIView animateWithDuration:self.speed animations:^
         {
             self.viewContainer.frame = endRect;
             [self.contentVC contentViewAdjustUI];  //first time show and animation finished.
         } completion:^(BOOL finished)
         {
             endRect = [self calculateEndRect]; //after complete must calculate it again, because show slide can take a while, and device may rotate. If rotate the endRect is changed when finish.
             //create close button and title
             self.viewTitle = [[UIView alloc] initWithFrame:CGRectMake(endRect.origin.x, endRect.origin.y - SlideTitle_Height, endRect.size.width, SlideTitle_Height)];
             self.viewTitle.backgroundColor = [UIColor whiteColor];
             self.viewTitle.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
             [self.view addSubview:self.viewTitle];
             UIButton *buttonClose = [UIButton buttonWithType:UIButtonTypeCustom];
             [buttonClose setTitle:@"Close" forState:UIControlStateNormal];
             [buttonClose setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
             [buttonClose setBackgroundColor:[UIColor grayColor]];
             buttonClose.titleLabel.font = [UIFont boldSystemFontOfSize:18];
             [buttonClose addTarget:self action:@selector(buttonCloseClicked:) forControlEvents:UIControlEventTouchUpInside];
             buttonClose.frame = CGRectMake(endRect.size.width - 65, 3, 62, SlideTitle_Height-6);  //always keep in container view's right top cornor
             buttonClose.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin;
             [self.viewTitle addSubview:buttonClose];
             if ((self.alertTitle != nil && self.alertTitle.length > 0) || (self.alertMessage != nil && self.alertMessage.length > 0))
             {
                 NSString *displayText = nil;
                 if ((self.alertTitle != nil && self.alertTitle.length > 0) && (self.alertMessage != nil && self.alertMessage.length > 0))
                 {
                     displayText = [NSString stringWithFormat:@"%@ %@", self.alertTitle, self.alertMessage];
                 }
                 else if (self.alertTitle != nil && self.alertTitle.length > 0)
                 {
                     displayText = self.alertTitle;
                 }
                 else
                 {
                     displayText = self.alertMessage;
                 }
                 CBAutoScrollLabel *labelInfo = [[CBAutoScrollLabel alloc] initWithFrame:CGRectMake(0, 0, endRect.size.width-65, SlideTitle_Height)];
                 labelInfo.text = displayText;
                 labelInfo.textAlignment = NSTextAlignmentLeft;
                 labelInfo.backgroundColor = [UIColor clearColor];
                 labelInfo.font = [UIFont systemFontOfSize:15];
                 labelInfo.textColor = [UIColor darkTextColor];
                 labelInfo.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                 labelInfo.labelSpacing = 50; //distance between start and end labels
                 labelInfo.pauseInterval = 1; //seconds of pause before scrolling starts again
                 labelInfo.scrollSpeed = 39; //pixels per second
                 labelInfo.scrollDirection = CBAutoScrollDirectionLeft;
                 [labelInfo observeApplicationNotifications];
                 [self.viewTitle addSubview:labelInfo];
             }
             //Send push result log if this is from notification.
             if ([self.contentVC respondsToSelector:@selector(pushData)])
             {
                 PushDataForApplication *pushData = self.contentVC.pushData;
                 [pushData sendPushResult:SHResult_Accept withHandler:nil];
             }
         }];
    };
    dispatch_block_t actionDismissSlide = ^{
        //Send push result log if this is from notification.
        if ([self.contentVC respondsToSelector:@selector(pushData)])
        {
            PushDataForApplication *pushData = self.contentVC.pushData;
            [pushData sendPushResult:SHResult_Decline withHandler:nil];
        }
        //close it
        [self dismissSlide];
    };
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (![[SHSlideContainer shared] containsSlide:self])
        {
            return;  //if already remove all, stop showing. This is especially useful for continous show two slide. The order mismatch because this dispatch_to_main.
        }
        PushDataForApplication *pushData = nil;
        if ([self.contentVC respondsToSelector:@selector(pushData)])
        {
            pushData = self.contentVC.pushData;
        }
        if (pushData == nil) //not from notification
        {
            if (self.needShowDialog && ((self.alertTitle != nil && self.alertTitle.length > 0) || (self.alertMessage != nil && self.alertMessage.length > 0)))
            {
                SHAlertView *alertView = [[SHAlertView alloc] initWithTitle:self.alertTitle message:self.alertMessage withHandler:^(UIAlertView *view, NSInteger buttonIndex)
                  {
                      if (buttonIndex != view.cancelButtonIndex)
                      {
                          actionShowSlide();
                      }
                      else
                      {
                          actionDismissSlide();
                      }
                  } cancelButtonTitle:shLocalizedString(@"STREETHAWK_CANCEL", @"Cancel") otherButtonTitles:shLocalizedString(@"STREETHAWK_YES", @"Yes Please!"), nil];
                [alertView show];
            }
            else
            {
                actionShowSlide();
            }
        }
        else
        {
            if (self.needShowDialog && [pushData shouldShowConfirmDialog] /*consider title, message and supress dialog*/)
            {
                [StreetHawk handlePushDataForAppCallback:pushData clickButton:^(SHResult result)
                {
                    switch (result)
                    {
                        case SHResult_Accept:
                            actionShowSlide();
                            break;
                        case SHResult_Decline:
                            actionDismissSlide();
                            break;
                        default:
                            break;
                    }
                }];
            }
            else
            {
                actionShowSlide();
            }
        }
    });
}

- (void)dismissSlide
{
    if (self.contentVC.contentLoadFinishHandler != nil)
    {
        self.contentVC.contentLoadFinishHandler = nil;  //to avoid later show content after load successfully; although contentVC dealloc should set this, do it again here to avoid crash.
    }
    if (self.windowCover != nil)
    {
        self.view.window.hidden = YES;
        self.windowCover = nil; //self's dealloc is called after this
    }
    [[SHSlideContainer shared] removeSlide:self];  //keep this at end so above self.view not cause deallocated object.
}

- (void)rotateSlide
{
    if (!CGRectIsEmpty(self.viewContainer.frame)) //if alert view show and not adjust rotated position.
    {
        CGRect endRect = [self calculateEndRect];
        self.viewContainer.frame = endRect;
        self.viewTitle.frame = CGRectMake(endRect.origin.x, endRect.origin.y - SlideTitle_Height, endRect.size.width, SlideTitle_Height);
        [self.contentVC contentViewAdjustUI];  //adjust content view's subview after rotation.
    }
}

- (void)buttonCloseClicked:(id)sender
{
    [self dismissSlide];
}

- (CGFloat)statusBarHeight
{
    if ([[UIDevice currentDevice].systemVersion doubleValue] >= 8.0)
    {
        return [UIApplication sharedApplication].statusBarFrame.size.height;
    }
    else
    {
        return 20; //in iOS 7 landscape, iPhone 5s return 568, iPad 2 return 1024, not expected. Hard code to 20 as before.
    }
}

- (CGRect)calculateStartRect
{
    CGRect startRect = CGRectZero;
    CGRect fullScreenRect = [self.view.window.rootViewController.view convertRect:[UIScreen mainScreen].bounds fromView:nil]; //key
    switch (self.direction)
    {
        case SHSlideDirection_Up:
        {
            float height = self.percentage * (fullScreenRect.size.height - [self statusBarHeight] - SlideTitle_Height);
            startRect = CGRectMake(0, fullScreenRect.size.height, fullScreenRect.size.width, height);
        }
            break;
        case SHSlideDirection_Down:
        {
            float height = self.percentage * (fullScreenRect.size.height - [self statusBarHeight] - SlideTitle_Height);
            startRect = CGRectMake(0, 0 - height, fullScreenRect.size.width, height);
        }
            break;
        case SHSlideDirection_Left:
        {
            float width = self.percentage * fullScreenRect.size.width;
            startRect = CGRectMake(fullScreenRect.size.width, [self statusBarHeight] + SlideTitle_Height, width, fullScreenRect.size.height);
        }
            break;
        case SHSlideDirection_Right:
        {
            float width = self.percentage * fullScreenRect.size.width;
            startRect = CGRectMake(0 - width, [self statusBarHeight] + SlideTitle_Height, width, fullScreenRect.size.height);
        }
            break;
        default:
            NSAssert(NO, @"Should not reach here.");
            break;
    }
    return startRect;
}

- (CGRect)calculateEndRect
{
    CGRect endRect = CGRectZero;
    CGRect fullScreenRect = [self.view.window.rootViewController.view convertRect:[UIScreen mainScreen].bounds fromView:nil]; //key
    switch (self.direction)
    {
        case SHSlideDirection_Up:
        {
            float height = self.percentage * (fullScreenRect.size.height - [self statusBarHeight] - SlideTitle_Height);
            endRect = CGRectMake(0, fullScreenRect.size.height - height, fullScreenRect.size.width, height);
        }
            break;
        case SHSlideDirection_Down:
        {
            float height = self.percentage * (fullScreenRect.size.height - [self statusBarHeight] - SlideTitle_Height);
            endRect = CGRectMake(0, [self statusBarHeight] + SlideTitle_Height, fullScreenRect.size.width, height);
        }
            break;
        case SHSlideDirection_Left:
        {
            float width = self.percentage * fullScreenRect.size.width;
            endRect = CGRectMake(fullScreenRect.size.width - width, [self statusBarHeight] + SlideTitle_Height, width, fullScreenRect.size.height);
        }
            break;
        case SHSlideDirection_Right:
        {
            float width = self.percentage * fullScreenRect.size.width;
            endRect = CGRectMake(0, [self statusBarHeight] + SlideTitle_Height, width, fullScreenRect.size.height);
        }
            break;
        default:
            NSAssert(NO, @"Should not reach here.");
            break;
    }
    return endRect;
}

@end

@implementation SHSlideContainer

#pragma mark - life cycle

+ (SHSlideContainer *)shared
{
    static SHSlideContainer *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SHSlideContainer alloc] init];
    });
    return instance;
}

- (id)init
{
    if (self = [super init])
    {
        self.arrayVCs = [NSMutableArray array];
        self.semaphore = dispatch_semaphore_create(1);  //happen in sequence
    }
    return self;
}

#pragma mark - public functions

- (void)addSlide:(SHSlideViewController *)vc
{
    NSAssert(vc != nil, @"Try to add nil slide.");
    if (vc != nil)
    {
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        if (![self.arrayVCs containsObject:vc])
        {
            [self.arrayVCs addObject:vc];
        }
        dispatch_semaphore_signal(self.semaphore);
    }
}

- (void)removeSlide:(SHSlideViewController *)vc
{
    NSAssert(vc != nil, @"Try to remove nil slide.");
    if (vc != nil)
    {
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        if ([self.arrayVCs containsObject:vc])
        {
            [self.arrayVCs removeObject:vc];
        }
        dispatch_semaphore_signal(self.semaphore);
    }
}

- (BOOL)containsSlide:(SHSlideViewController *)vc
{
    if (vc == nil)
    {
        return NO;
    }
    else
    {
        return [self.arrayVCs containsObject:vc];
    }
}

- (void)removeAllSlides
{
    for (SHSlideViewController *vc in self.arrayVCs)
    {
        [vc dismissSlide];
    }
}

@end

@implementation SHApp (SlideExt)

#pragma mark - public functions

- (void)slideForUrl:(NSString *)url withDirection:(SHSlideDirection)direction withSpeed:(double)speed withCoverPercentage:(double)percentage withHideLoading:(BOOL)isHideLoading withAlertTitle:(NSString *)alertTitle withAlertMessage:(NSString *)alertMessage withNeedShowDialog:(BOOL)needShowDialog withPushData:(PushDataForApplication *)pushData
{
    SHSlideWebViewController *webVC = [[SHSlideWebViewController alloc] initWithNibName:nil bundle:nil];
    webVC.pushData = pushData;
    webVC.webpageUrl = url;
    [self slideForVC:webVC withDirection:direction withSpeed:speed withCoverPercentage:percentage withHideLoading:isHideLoading withAlertTitle:alertTitle withAlertMessage:alertMessage withNeedShowDialog:needShowDialog];
}

- (void)slideForVC:(UIViewController<SHSlideContentViewController> *)contentVC withDirection:(SHSlideDirection)direction withSpeed:(double)speed withCoverPercentage:(double)percentage withHideLoading:(BOOL)isHideLoading withAlertTitle:(NSString *)alertTitle withAlertMessage:(NSString *)alertMessage withNeedShowDialog:(BOOL)needShowDialog
{
    if (!streetHawkIsEnabled())
    {
        return;
    }
    [[SHSlideContainer shared] removeAllSlides]; //only keep last slide, remove previous slides.
    //__block /*not copy in contentLoadFinishHandler block, so that "removeAllSlides" can dealloc this slide*/ ARC: it was marked as __block to avoid copy when MRC, cause warning in ARC, but now by testing window, slide vc and content vc are all dealloc, no need __block.
    SHSlideViewController *slideVC = [[SHSlideViewController alloc] initForContent:contentVC withDirection:direction withSpeed:speed withCoverPercentage:percentage withAlertTitle:alertTitle withAlertMessage:alertMessage withNeedShowDialog:needShowDialog];
    [[SHSlideContainer shared] addSlide:slideVC];  //record this slide no matter it shows immediately or after loading. if another slide push right after this, this slide is removed, even it hide loading, "contentLoadFinishHandler" is cleaned to avoid later show.
    if (isHideLoading)
    {
        contentVC.contentLoadFinishHandler = ^(BOOL isSuccesss)
        {
            if (isSuccesss)
            {
                [slideVC showSlide];
            }
        };
    }
    else
    {
        [slideVC showSlide];
    }
}

@end
