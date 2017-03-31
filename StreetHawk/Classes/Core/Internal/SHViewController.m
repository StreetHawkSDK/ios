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

#import "SHViewController.h"
//header from StreetHawk
#import "SHUtils.h" //for shFindBundleForResource

//Due to class inheritance, SHBaseViewController and SHBaseTableViewController has many duplicated code. Create an imp obj inside them to avoid duplicated code.
@interface SHBaseVCImp : NSObject

//The container vc for this imp. It must be weak reference to avoid loop reference.
@property (nonatomic, assign) UIViewController<SHBaseVC> *vc;

- (id)initForVC:(UIViewController<SHBaseVC> *)vc;

//Find xib from possible bundles.
+ (NSBundle *)prepareInitForClass:(Class)vcClass withNibName:(NSString *)nibNameOrNil withbundle:(NSBundle *)nibBundleOrNil;
//For common code of viewDidLoad.
- (void)viewDidLoad;

//keyboard notification handler
- (void)keyboardDidShowHandler:(NSNotification *)notification;
- (void)keyboardDidHideHandler:(NSNotification *)notification;
- (void)keyboardDidShowFrom:(CGRect)frameBegin to:(CGRect)frameEnd duration:(double)second;
- (void)keyboardDidHideFrom:(CGRect)frameBegin to:(CGRect)frameEnd duration:(double)second;
@property (nonatomic) CGRect frameBeforekeyboardShow;  //the original frame to restore when keyboard hide.

@end

@implementation SHBaseVCImp

+ (NSBundle *)prepareInitForClass:(Class)vcClass withNibName:(NSString *)nibNameOrNil withbundle:(NSBundle *)nibBundleOrNil
{
    Class nibClass = vcClass;
    //Detect bundle for nib file in this way:
    //If nibBundleOrNil is nil, search in the order of MainBundle->SHAppRes->StreetHawkRes->StreetHawkCoreRes
    //If nibBundleOrNil is not nil, use the one user specified
    //If nibNameOrNil is nil, try to search for super class if current class cannot find match xib.
    if (nibBundleOrNil == nil)
    {
        if (nibNameOrNil == nil)
        {
            nibBundleOrNil = shFindBundleForResource([nibClass description], @"nib", NO);
            while (nibBundleOrNil == nil && [nibClass superclass] != [NSObject class])
            {
                nibClass = [nibClass superclass];
                nibBundleOrNil = shFindBundleForResource([nibClass description], @"nib", NO);
            }
        }
        else
        {
            nibBundleOrNil = shFindBundleForResource(nibNameOrNil, @"nib", YES);
        }
    }
    return nibBundleOrNil;
}

- (id)initForVC:(UIViewController<SHBaseVC> *)vc
{
    if (self = [super init])
    {
        self.vc = vc;
        //use "did" instead of "will", because when rotate, "will" is in pre-coordinate system, "did" is in post-coordinate system, and view's position should be adjusted according to post-coordinate system.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShowHandler:) name:UIKeyboardDidShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHideHandler:) name:UIKeyboardDidHideNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.vc = nil;  //not hold reference
}

- (void)viewDidLoad
{
    //If current VC is under navigation controller, must set edgesForExtendedLayout = UIRectEdgeNone otherwise navigation bar will cover on the view. By setting edgesForExtendedLayout = UIRectEdgeNone so that view is under navigation bar.
    //But one thing need notice: navigation bar may automatically add 20 pixels for status bar if navigation bar is up to windows top, making the xib design not need move down 20 pixels.
    if([UIViewController instancesRespondToSelector:@selector(edgesForExtendedLayout)])
    {
        self.vc.edgesForExtendedLayout = UIRectEdgeNone;  //edgesForExtendedLayout is available since iOS 7.0
    }
}

- (void)keyboardDidShowHandler:(NSNotification *)notification
{
    NSValue *frameBeginValue = (notification.userInfo)[UIKeyboardFrameBeginUserInfoKey];
    NSValue *frameEndValue = (notification.userInfo)[UIKeyboardFrameEndUserInfoKey];
    NSNumber *durationValue = (notification.userInfo)[UIKeyboardAnimationDurationUserInfoKey];
    //--------------------------------- Before iOS 8 --------------------------------------
    //coordinate system in rotation is tricky, because there are many coordinate systems in one Application.
    //Two important concepts are:
    //frame: a view's frame is the location in its super view's coordinate system.
    //bounds: a view's bounds is the location in its own coordinate system.
    //window's coordinate system is ALWAYS portrait!!! No matter device is portrait, landscape, its frame and bounds always (0, 0, 320, 568). Same as [UIScreen mainScreen].bounds. Because window does not rotate, so in landscape mode, if make x from left to right and y from top to bottom, read window/screen width and height are reversed.
    //keyboard's coordinate system is window/screen coordinate system, meaning it's always portrait!!!
    //window does not rotate, but its rootViewController can rotate (depends on vc's delegate), thus when rotate, window.rootViewController.view has the expected width/height in landscape coordinate system (device landscape, x from left to right, y from top to bottom).
    //Example: device is landscape (no matter left or right)
    //self.view.window.frame = (0, 0, 320, 568), self.view.window.bounds = (0, 0, 320, 568), [UIScreen mainScreen].bounds = (0, 0, 320, 568). //because they don't rotate
    //self.view.window.rootViewController.view.frame = (0, 0, 320, 568) because frame is in super view (window) coordinate system, self.view.window.rootViewController.view.bounds = (0, 0, 568, 320) because rootViewController can rotate, and its coordinate system is landscape now.
    //self.view.frame and self.view.bounds are in landscape coordinate system.
    //To calculate position, first thing is converting to same coordinate system. Best one is always have x from left to right, y from top to bottom, that is convert to self.view.window.rootViewController.view's coordinate system.
    //---------------------------------- Since iOS 8 ----------------------------------------------------
    //Since iOS 8 window frame, keyboard, bounds ALL rotate.
    //Example: device is landscape (no matter left or right)
    //self.view.window.frame = (0, 0, 568, 320), self.view.window.bounds = (0, 0, 568, 320), [UIScreen mainScreen].bounds = (0, 0, 568, 320). //because they rotate since iOS 8.
    //self.view.window.rootViewController.view.frame = (0, 0, 568, 320) because frame is in super view (window) coordinate system, self.view.window.rootViewController.view.bounds = (0, 0, 568, 320) because rootViewController can rotate, and its coordinate system is landscape now.
    //self.view.frame and self.view.bounds are in landscape coordinate system.
    //--------------------------------------------------------------------------------------
    if ([[UIDevice currentDevice].systemVersion doubleValue] >= 8.0)
    {
        [self.vc keyboardDidShowFrom:frameBeginValue.CGRectValue to:frameEndValue.CGRectValue duration:durationValue.doubleValue];  //in same coordiate system, no need to convert.
    }
    else
    {
        [self.vc keyboardDidShowFrom:[self.vc.view.window.rootViewController.view convertRect:frameBeginValue.CGRectValue fromView:nil] to:[self.vc.view.window.rootViewController.view convertRect:frameEndValue.CGRectValue fromView:nil] duration:durationValue.doubleValue];
    }
}

- (void)keyboardDidHideHandler:(NSNotification *)notification
{
    NSValue *frameBeginValue = (notification.userInfo)[UIKeyboardFrameBeginUserInfoKey];
    NSValue *frameEndValue = (notification.userInfo)[UIKeyboardFrameEndUserInfoKey];
    NSNumber *durationValue = (notification.userInfo)[UIKeyboardAnimationDurationUserInfoKey];
    if ([[UIDevice currentDevice].systemVersion doubleValue] >= 8.0)
    {
        [self.vc keyboardDidHideFrom:frameBeginValue.CGRectValue to:frameEndValue.CGRectValue duration:durationValue.doubleValue];
    }
    else
    {
        [self.vc keyboardDidHideFrom:[self.vc.view.window.rootViewController.view convertRect:frameBeginValue.CGRectValue fromView:nil] to:[self.vc.view.window.rootViewController.view convertRect:frameEndValue.CGRectValue fromView:nil] duration:durationValue.doubleValue];
    }
}

- (void)keyboardDidShowFrom:(CGRect)frameBegin to:(CGRect)frameEnd duration:(double)second
{
    if (self.vc.isViewAdjustForKeyboard)
    {
        //Not consider frameBegin and frameEnd not same, because if there are two textbox, one click "Next" to move quickly to another, hide notification is called with frameBegin and frameEnd not same, however show notification is called with frameBegin and frameEnd same! A bug? Anyway, avoid check they are not same, and always use frameEnd.
        //By testing, when switch language this is also called, so it can handled.
        CGRect frameView = CGRectZero;
        if ([[UIDevice currentDevice].systemVersion doubleValue] >= 8.0)
        {
            //in iOS 8 all rotate, calculate the position to be center again.
            CGRect fullScreenRect = [UIScreen mainScreen].bounds;
            CGRect contentSize = self.vc.view.bounds;  //The xib of contentViewController's view should set Freedom and set the size.
            frameView = CGRectMake(fullScreenRect.origin.x + contentSize.origin.x + (fullScreenRect.size.width - contentSize.size.width)/2, fullScreenRect.origin.y + contentSize.origin.y + (fullScreenRect.size.height - contentSize.size.height)/2, contentSize.size.width, contentSize.size.height);
            self.frameBeforekeyboardShow = frameView;  //without keyboard should use this frame
        }
        else
        {
            self.frameBeforekeyboardShow = self.vc.view.frame;
            //Because keyboard's frame is also in rootViewController's coordinate system, same as current view, only need one calculation.
            frameView = [self.vc.view.window.rootViewController.view convertRect:self.vc.view.frame fromView:self.vc.view.superview];
        }
        if (frameView.origin.y + frameView.size.height > frameEnd.origin.y)  //overlap by keyboard
        {
            if (frameView.size.height <= frameEnd.origin.y)  //above keyboard has enough space for this view, just move, no shrink
            {
                frameView = CGRectMake(frameView.origin.x, frameEnd.origin.y - frameView.size.height, frameView.size.width, frameView.size.height);
            }
            else  //view need resize to meet top till keyboard
            {
                frameView = CGRectMake(frameView.origin.x, 0, frameView.size.width, frameEnd.origin.y);
            }
            [UIView animateWithDuration:second animations:^{
                if ([[UIDevice currentDevice].systemVersion doubleValue] >= 8.0)
                {
                    self.vc.view.frame = frameView;
                }
                else
                {
                    self.vc.view.frame = [self.vc.view.superview convertRect:frameView fromView:self.vc.view.window.rootViewController.view];
                }
            }];
        }
    }
}

- (void)keyboardDidHideFrom:(CGRect)frameBegin to:(CGRect)frameEnd duration:(double)second
{
    if (self.vc.isViewAdjustForKeyboard)
    {
        if (!CGRectEqualToRect(self.vc.view.frame, self.frameBeforekeyboardShow))
        {
            [UIView animateWithDuration:second animations:^{
                self.vc.view.frame = self.frameBeforekeyboardShow;  //hide keyboard and restore original frame
            }];
        }
    }
}

@end

@interface SHBaseViewController ()

//The implementation object to do common code.
@property (nonatomic, strong) SHBaseVCImp *imp;

@end

@implementation SHBaseViewController

@synthesize isViewAdjustForKeyboard;

#pragma mark - life cycle

- (id)init
{
    if (self = [super init])
    {
        self.isViewAdjustForKeyboard = NO;
        self.imp = [[SHBaseVCImp alloc] initForVC:self];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        self.isViewAdjustForKeyboard = NO;
        self.imp = [[SHBaseVCImp alloc] initForVC:self];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:[SHBaseVCImp prepareInitForClass:self.class withNibName:nibNameOrNil withbundle:nibBundleOrNil]])
    {
        self.isViewAdjustForKeyboard = NO;
        self.imp = [[SHBaseVCImp alloc] initForVC:self];
    }
    return self;
}

- (void)dealloc
{
    self.imp = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.imp viewDidLoad];
}

#pragma mark - keyboard functions

- (void)keyboardDidShowFrom:(CGRect)frameBegin to:(CGRect)frameEnd duration:(double)second
{
    [self.imp keyboardDidShowFrom:frameBegin to:frameEnd duration:second];
}

- (void)keyboardDidHideFrom:(CGRect)frameBegin to:(CGRect)frameEnd duration:(double)second
{
    [self.imp keyboardDidHideFrom:frameBegin to:frameEnd duration:second];
}

@end

@interface SHBaseTableViewController ()

//The implementation object to do common code.
@property (nonatomic, strong) SHBaseVCImp *imp;

@end

@implementation SHBaseTableViewController

@synthesize isViewAdjustForKeyboard;

#pragma mark - life cycle

- (id)init
{
    if (self = [super init])
    {
        self.isViewAdjustForKeyboard = NO;
        self.imp = [[SHBaseVCImp alloc] initForVC:self];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        self.isViewAdjustForKeyboard = NO;
        self.imp = [[SHBaseVCImp alloc] initForVC:self];
    }
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    if (self = [super initWithStyle:style])
    {
        self.isViewAdjustForKeyboard = NO;
        self.imp = [[SHBaseVCImp alloc] initForVC:self];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:[SHBaseVCImp prepareInitForClass:self.class withNibName:nibNameOrNil withbundle:nibBundleOrNil]])
    {
        self.isViewAdjustForKeyboard = NO;
        self.imp = [[SHBaseVCImp alloc] initForVC:self];
    }
    return self;
}

- (void)dealloc
{
    self.imp = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.imp viewDidLoad];
}

#pragma mark - keyboard functions

- (void)keyboardDidShowFrom:(CGRect)frameBegin to:(CGRect)frameEnd duration:(double)second
{
    [self.imp keyboardDidShowFrom:frameBegin to:frameEnd duration:second];
}

- (void)keyboardDidHideFrom:(CGRect)frameBegin to:(CGRect)frameEnd duration:(double)second
{
    [self.imp keyboardDidHideFrom:frameBegin to:frameEnd duration:second];
}

@end
