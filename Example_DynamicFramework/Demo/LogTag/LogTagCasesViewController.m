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

#import "LogTagCasesViewController.h"

@interface LogTagCasesViewController ()

@property (nonatomic, strong) NSArray *arrayCells;

- (void)showDoneAlert:(BOOL)isSuccess;

@end

@implementation LogTagCasesViewController

#pragma mark - life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.arrayCells = @[self.cellCuid, self.cellNumeric, self.cellString, self.cellDatetime, self.cellIncrement, self.cellIncrementValue, self.cellDelete, self.cellFeed];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.arrayCells.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger rowCuid = 0;
    NSInteger rowIncrease = 4;
    NSInteger rowDelete = 6;
    NSInteger rowButtonDelete = 7;
    NSInteger rowButtonFeed = 8;
    CGFloat oneLineHeight = 50;
    CGFloat twoLineHeight = 80;
    CGFloat threeLineHeight = 135;
    if (indexPath.row == rowCuid
        || indexPath.row == rowIncrease
        || indexPath.row == rowDelete)
    {
        return twoLineHeight;
    }
    else if (indexPath.row == rowButtonDelete
             || indexPath.row == rowButtonFeed)
    {
        return oneLineHeight;
    }
    else
    {
        return threeLineHeight;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.arrayCells[indexPath.row];
}

#pragma mark - UITextFieldDelegate handler

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - event handler

- (IBAction)buttonCuidClicked:(id)sender
{
    NSString *value = [self.textboxCuidValue.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (value == nil || value.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Please input value." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alertView show];
        return;
    }
    BOOL isSuccess = [StreetHawk tagCuid:value];
    [self.textboxCuidValue resignFirstResponder];
    [self showDoneAlert:isSuccess];
}

- (IBAction)buttonNumericClicked:(id)sender
{
    NSString *key = [self.textboxKeyNumeric.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *value = [self.textboxValueNumeric.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (key == nil || key.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Please input key." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alertView show];
        return;
    }
    if (value == nil || value.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Please input value." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alertView show];
        return;
    }
    double valueNumeric = [value doubleValue];
    BOOL isSuccess = [StreetHawk tagNumeric:valueNumeric forKey:key];
    [self.textboxKeyNumeric resignFirstResponder];
    [self.textboxValueNumeric resignFirstResponder];
    [self showDoneAlert:isSuccess];
}

- (IBAction)buttonSringClicked:(id)sender
{
    NSString *key = [self.textboxKeyString.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *value = [self.textboxValueString.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (key == nil || key.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Please input key." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alertView show];
        return;
    }
    if (value == nil || value.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Please input value." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alertView show];
        return;
    }
    BOOL isSuccess = [StreetHawk tagString:value forKey:key];
    [self.textboxKeyString resignFirstResponder];
    [self.textboxValueString resignFirstResponder];
    [self showDoneAlert:isSuccess];
}

- (IBAction)buttonDatetimeClicked:(id)sender
{
    NSString *key = [self.textboxKeyDatetime.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *value = [self.textboxValueDatetime.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (key == nil || key.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Please input key." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alertView show];
        return;
    }
    NSDate *valueDate = nil;
    if (value == nil || value.length == 0)
    {
        valueDate = [NSDate date];
    }
    else
    {
        valueDate = shParseDate(value, 0);
        if (valueDate == nil)
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Please input date value as format, or leave nil to tag current time." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alertView show];
            return;
        }
    }
    BOOL isSuccess = [StreetHawk tagDatetime:valueDate forKey:key];
    [self.textboxKeyDatetime resignFirstResponder];
    [self.textboxValueDatetime resignFirstResponder];
    [self showDoneAlert:isSuccess];
}

- (IBAction)buttonIncrementClicked:(id)sender
{
    NSString *key = [self.textboxKeyIncrement.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (key == nil || key.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Please input key." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alertView show];
        return;
    }
    BOOL isSuccess = [StreetHawk incrementTag:key];
    [self.textboxKeyIncrement resignFirstResponder];
    [self showDoneAlert:isSuccess];
}

- (IBAction)buttonIncrementValueClicked:(id)sender
{
    NSString *key = [self.textboxKeyIncrementValue.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *value = [self.textboxValueIncrementValue.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (key == nil || key.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Please input key." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alertView show];
        return;
    }
    if (value == nil || value.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Please input value." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alertView show];
        return;
    }
    double valueDouble = [value doubleValue];
    BOOL isSuccess = [StreetHawk incrementTag:valueDouble forKey:key];
    [self.textboxKeyIncrementValue resignFirstResponder];
    [self.textboxValueIncrementValue resignFirstResponder];
    [self showDoneAlert:isSuccess];
}

- (IBAction)buttonDeleteClicked:(id)sender
{
    NSString *key = [self.textboxKeyDelete.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (key == nil || key.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Please input key." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alertView show];
        return;
    }
    BOOL isSuccess = [StreetHawk removeTag:key];
    [self.textboxKeyDelete resignFirstResponder];
    [self showDoneAlert:isSuccess];
}

- (IBAction)buttonFeedClicked:(id)sender
{
    [StreetHawk feed:0 withHandler:^(NSArray<SHFeedObject *> *arrayFeeds, NSError *error)
     {
         dispatch_async(dispatch_get_main_queue(), ^
         {
             if (error)
             {
                 UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Fetch feed error:" message:error.localizedDescription delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                 [alertView show];
             }
             else
             {
                 NSMutableString *strFeeds = [NSMutableString string];
                 for (SHFeedObject *feedObj in arrayFeeds)
                 {
                     [strFeeds appendFormat:@"%@\r\n\r\n", feedObj];
                     [StreetHawk sendFeedAck:feedObj.feed_id];
                     [StreetHawk notifyFeedResult:feedObj.feed_id withResult:SHResult_Decline];
                 }
                 UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Fetch feed(s):" message:strFeeds delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                 [alertView show];
             }
         });
     }];
}

#pragma mark - private functions

- (void)showDoneAlert:(BOOL)isSuccess
{
    NSString *info = isSuccess ? @"Tag sent to server." :@"Cannot send tag to server, please check console log.";
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:info message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alertView show];
}

@end
