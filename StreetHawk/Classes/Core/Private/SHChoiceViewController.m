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

#import "SHChoiceViewController.h"
//header from StreetHawk
#import "SHCoverWindow.h"

@interface SHChoiceViewController ()

@property (nonatomic, strong) UIWindow *windowCover;  //ARC: add this strong property to keep window, otherwise window is dealloc in `showSlide` and nothing show; Note: this property is set nil in `dismissSlide` to break retain.

//arrange control and dialog frame.
- (void)arrangeControls;

@end

@implementation SHChoiceViewController

@synthesize choiceHandler;

#pragma mark - life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableChoice.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero]; //remove extra separator
}

- (void)dealloc
{
    self.tableChoice.delegate = nil;
    self.tableChoice.dataSource = nil;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self arrangeControls];
}

#pragma mark - public functions

- (void)showChoiceList
{
    self.windowCover = [[SHCoverWindow alloc] initWithFrame:[UIScreen mainScreen].bounds]; //cannot release window otherwise nothing get show, this window will be manually release when closeChoiceList, so ARC add strong property to keep this window.
    self.windowCover.rootViewController = self;  //set rootViewController so that it can rotate
    [self.windowCover makeKeyAndVisible];  //must use [windowCover makeKeyAndVisible] self.view.window is nil until the window show, and now window.rootViewController is setup.
    [self arrangeControls];
}

- (void)closeChoiceList
{
    self.view.window.hidden = YES;
    self.windowCover = nil; //self's dealloc is called after this
}

#pragma mark - event handler

- (IBAction)buttonCancelClicked:(id)sender
{
    if (self.choiceHandler)
    {
        self.choiceHandler(YES, -1);
    }
    [self closeChoiceList];
}

#pragma mark - private functions

- (void)arrangeControls
{
    float horizontalMargin = 10;
    float verticalMargin = 10;
    float viewMargin = 30;
    CGRect screenRect = [self.view.window.rootViewController.view convertRect:[UIScreen mainScreen].bounds fromView:nil];
    float viewWidth = screenRect.size.width - 2 * viewMargin;
    CGSize constraintSize = CGSizeMake(viewWidth - 2 * horizontalMargin, 1000);
    float usedHeight = 0;
    CGRect frameTitle = CGRectZero;
    CGRect frameMessage = CGRectZero;
    CGRect frameTable = CGRectZero;
    CGRect frameCancel = CGRectZero;
    //title
    if (self.displayTitle != nil && self.displayTitle.length > 0)
    {
        self.labelTitle.hidden = NO;
        self.labelTitle.text = self.displayTitle;
        CGRect rectSize = [self.displayTitle boundingRectWithSize:constraintSize options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) attributes:@{NSFontAttributeName:self.labelTitle.font} context:nil];
        frameTitle = CGRectMake(horizontalMargin, verticalMargin, viewWidth - 2 * horizontalMargin, rectSize.size.height);
        usedHeight = frameTitle.origin.y + frameTitle.size.height;
    }
    else
    {
        self.labelTitle.hidden = YES;
    }
    //message
    if (self.displayMessage != nil && self.displayMessage.length > 0)
    {
        self.labelMessage.hidden = NO;
        self.labelMessage.text = self.displayMessage;
        CGRect rectSize = [self.displayMessage boundingRectWithSize:constraintSize options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) attributes:@{NSFontAttributeName:self.labelMessage.font} context:nil];
        frameMessage = CGRectMake(horizontalMargin, usedHeight + verticalMargin, viewWidth - 2 * horizontalMargin, rectSize.size.height);
        usedHeight = frameMessage.origin.y + frameMessage.size.height;
    }
    else
    {
        self.labelMessage.hidden = YES;
    }
    //table required height
    float tableContentHeight = [self tableView:self.tableChoice heightForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]] * [self tableView:self.tableChoice numberOfRowsInSection:0];
    float viewHeight = screenRect.size.height - 2 * viewMargin;
    if (usedHeight + verticalMargin + tableContentHeight + verticalMargin + self.buttonCancel.bounds.size.height + verticalMargin > viewHeight)
    {
        tableContentHeight = viewHeight - (usedHeight + verticalMargin + verticalMargin + self.buttonCancel.bounds.size.height + verticalMargin);
        self.tableChoice.scrollEnabled = YES;
    }
    else
    {
        viewHeight = usedHeight + verticalMargin + tableContentHeight + verticalMargin + self.buttonCancel.bounds.size.height + verticalMargin;
        self.tableChoice.scrollEnabled = NO;
    }
    frameTable = CGRectMake(horizontalMargin, usedHeight + verticalMargin, viewWidth - 2 * horizontalMargin, tableContentHeight);
    //cancel button
    if (self.displayCancelButton == nil || self.displayCancelButton.length == 0)
    {
        self.displayCancelButton = @"Cancel";
    }
    CGRect rectSize = [self.displayCancelButton boundingRectWithSize:constraintSize options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) attributes:@{NSFontAttributeName:self.buttonCancel.titleLabel.font} context:nil];
    [self.buttonCancel setTitle:self.displayCancelButton forState:UIControlStateNormal];
    frameCancel = CGRectMake((viewWidth - rectSize.size.width) / 2, frameTable.origin.y + frameTable.size.height + verticalMargin, rectSize.size.width, self.buttonCancel.frame.size.height);
    //whole view
    self.viewDialog.frame = CGRectMake(viewMargin, (screenRect.size.height - viewHeight) / 2, viewWidth, viewHeight);
    self.labelTitle.frame = frameTitle;
    self.labelMessage.frame = frameMessage;
    self.tableChoice.frame = frameTable;
    self.buttonCancel.frame = frameCancel;
}

#pragma mark - UITableView delegate and datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.arrayChoices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"SHChoiceCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.textLabel.font = self.buttonCancel.titleLabel.font;
        cell.textLabel.textColor = self.buttonCancel.titleLabel.textColor;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    cell.textLabel.text = self.arrayChoices[indexPath.row];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 35;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.choiceHandler)
    {
        self.choiceHandler(NO, indexPath.row);
    }
    [self closeChoiceList];
}

@end
