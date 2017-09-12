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

#import "FeedbackCasesViewController.h"

@interface FeedbackCasesViewController ()

//Register sample cases.
@property (nonatomic, strong) NSArray *arraySampleCases;
@property (nonatomic, strong) NSArray *arrayDescription;
@property (nonatomic, strong) NSArray *arrayDislayCases;

@end

@implementation FeedbackCasesViewController

#pragma mark - life cycle

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        self.arraySampleCases = @[@"Feedback with option choice list and need input is Yes", @"Feedback with option choice list and need input is No", @"Feedback without option choice list and need input is Yes", @"Feedback without option choice list and need input is No"];
        self.arrayDescription = @[@"\"arrayChoice\" is not empty, feedback show option list first then input text.", @"\"arrayChoice\" is not empty, feedback show option list and direct submit without input text.", @"\"arrayChoice\" is empty, directly show input text dialog regardless \"needInput\".", @"\"arrayChoice\" is empty, directly show input text dialog regardless \"needInput\"."];
        self.arrayDislayCases = @[@"Title, message, short choice.", @"Title, message, long choice.", @"Long title, long message, short choice.", @"No title, long message, long choice.", @"Long title, no message, short choice.", @"No title, no message, long choice.", @"No title, no message, short choice."];
    }
    return self;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return self.arraySampleCases.count;
    }
    else if (section == 1)
    {
        return self.arrayDislayCases.count;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return @"Choose and input function test";
    }
    else if (section == 1)
    {
        return @"Choose list display test";
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        return 100;
    }
    else if (indexPath.section == 1)
    {
        return 38;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        static NSString *cellIdentifier = @"FeedbackFunctionCaseCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
            cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.textAlignment = NSTextAlignmentLeft;
            cell.textLabel.font = [UIFont systemFontOfSize:16];
            cell.textLabel.textColor = [UIColor darkTextColor];
            cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
            cell.detailTextLabel.textAlignment = NSTextAlignmentLeft;
            cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
            cell.detailTextLabel.textColor = [UIColor darkGrayColor];
            cell.detailTextLabel.numberOfLines = 0;
        }
        cell.textLabel.text = self.arraySampleCases[indexPath.row];
        cell.detailTextLabel.text = self.arrayDescription[indexPath.row];
        return cell;
    }
    else if (indexPath.section == 1)
    {
        static NSString *cellIdentifier = @"FeedbackDisplayCaseCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            cell.textLabel.numberOfLines = 1;
            cell.textLabel.textAlignment = NSTextAlignmentLeft;
            cell.textLabel.font = [UIFont systemFontOfSize:16];
            cell.textLabel.textColor = [UIColor darkTextColor];
        }
        cell.textLabel.text = self.arrayDislayCases[indexPath.row];
        return cell;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        NSArray *arrayChoice = @[@"Product not Available", @"Wrong Address", @"Description mismatch"];
        if (indexPath.row == 0)  //Feedback with option choice list and need input is Yes
        {
            [StreetHawk shFeedback:arrayChoice needInputDialog:YES needConfirmDialog:NO withTitle:@"What problem do you meet?" withMessage:@"Your feedback will be very helpful!" withPushData:nil];
        }
        else if (indexPath.row == 1)  //Feedback with option choice list and need input is No
        {
            [StreetHawk shFeedback:arrayChoice needInputDialog:NO needConfirmDialog:NO withTitle:nil withMessage:nil withPushData:nil];
        }
        else if (indexPath.row == 2)  //Feedback without option choice list and need input is Yes
        {
            [StreetHawk shFeedback:nil needInputDialog:YES needConfirmDialog:NO withTitle:@"What problem do you meet?" withMessage:nil withPushData:nil];
        }
        else if (indexPath.row == 3)  //Feedback without option choice list and need input is No
        {
            [StreetHawk shFeedback:@[] needInputDialog:NO needConfirmDialog:NO withTitle:@"" withMessage:@"Your feedback will be very helpful!" withPushData:nil];
        }
    }
    else if (indexPath.section == 1)
    {
        if (indexPath.row == 0) //Title, message, short choice.
        {
            [StreetHawk shFeedback:@[@"1", @"2", @"3", @"4", @"5"] needInputDialog:YES needConfirmDialog:NO withTitle:@"This is title" withMessage:@"This is message." withPushData:nil];
        }
        else if (indexPath.row == 1) //Title, message, long choice.
        {
            [StreetHawk shFeedback:@[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"10", @"11", @"12", @"13", @"14", @"15", @"16"] needInputDialog:YES needConfirmDialog:NO withTitle:@"This is title" withMessage:@"This is message." withPushData:nil];
        }
        else if (indexPath.row == 2) //Long title, long message, short choice.
        {
            [StreetHawk shFeedback:@[@"1", @"2", @"3", @"4", @"5"] needInputDialog:YES needConfirmDialog:NO withTitle:@"This is a very long, long, long, long, long title, it should wrapper to several lines, and still display all." withMessage:@"This is a very long, long, long, long, long message, it should wrapper to several lines, and still display all." withPushData:nil];
        }
        else if (indexPath.row == 3) //No title, long message, long choice.
        {
            [StreetHawk shFeedback:@[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"10", @"11", @"12", @"13", @"14", @"15", @"16"] needInputDialog:YES needConfirmDialog:NO withTitle:nil withMessage:@"This is a very long, long, long, long, long message, it should wrapper to several lines, and still display all." withPushData:nil];
        }
        else if (indexPath.row == 4) //Long title, no message, short choice.
        {
            [StreetHawk shFeedback:@[@"1", @"2", @"3", @"4", @"5"] needInputDialog:YES needConfirmDialog:NO withTitle:@"This is a very long, long, long, long, long title, it should wrapper to several lines, and still display all." withMessage:@"" withPushData:nil];
        }
        else if (indexPath.row == 5) //No title, no message, long choice.
        {
            [StreetHawk shFeedback:@[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"10", @"11", @"12", @"13", @"14", @"15", @"16"] needInputDialog:YES needConfirmDialog:NO withTitle:nil withMessage:nil withPushData:nil];
        }
        else if (indexPath.row == 6) //No title, no message, short choice.
        {
            [StreetHawk shFeedback:@[@"1", @"2", @"3", @"4", @"5"] needInputDialog:YES needConfirmDialog:NO withTitle:@"" withMessage:@"" withPushData:nil];
        }
    }
}

@end
