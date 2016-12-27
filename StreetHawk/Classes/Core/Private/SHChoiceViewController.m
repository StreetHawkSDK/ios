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

#pragma mark - public functions

- (void)arrangeControls:(CGRect)fullScreenRect
{
    float horizontalMargin = 10;
    float verticalMargin = 10;
    float viewMargin = 30;
    float viewWidth = fullScreenRect.size.width - 2 * viewMargin;
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
    float viewHeight = fullScreenRect.size.height - 2 * viewMargin;
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
    [self.buttonCancel setTitle:self.displayCancelButton forState:UIControlStateNormal];
    frameCancel = CGRectMake(0, frameTable.origin.y + frameTable.size.height + verticalMargin, viewWidth, self.buttonCancel.frame.size.height);
    //whole view
    self.view.frame = CGRectMake(viewMargin, (fullScreenRect.size.height - viewHeight) / 2, viewWidth, viewHeight);
    self.labelTitle.frame = frameTitle;
    self.labelMessage.frame = frameMessage;
    self.tableChoice.frame = frameTable;
    self.buttonCancel.frame = frameCancel;
}

#pragma mark - event handler

- (IBAction)buttonCancelClicked:(id)sender
{
    if (self.choiceHandler)
    {
        self.choiceHandler(YES, -1);
    }
    [self dismissOnTop];
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
    [self dismissOnTop];
}

@end
