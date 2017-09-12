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

#import "TagViewController.h"

@interface TagViewController ()

@property (retain, nonatomic) IBOutlet UITableViewCell *cellCuid;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellNumeric;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellString;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellDatetime;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellIncrement;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellDelete;

@property (retain, nonatomic) IBOutlet UITextField *textboxCuidValue;
@property (retain, nonatomic) IBOutlet UITextField *textboxKeyNumeric;
@property (retain, nonatomic) IBOutlet UITextField *textboxValueNumeric;
@property (retain, nonatomic) IBOutlet UITextField *textboxKeyString;
@property (retain, nonatomic) IBOutlet UITextField *textboxValueString;
@property (retain, nonatomic) IBOutlet UITextField *textboxKeyDatetime;
@property (retain, nonatomic) IBOutlet UITextField *textboxValueDatetime;
@property (retain, nonatomic) IBOutlet UITextField *textboxKeyIncrement;
@property (retain, nonatomic) IBOutlet UITextField *textboxKeyDelete;

- (IBAction)buttonCuidClicked:(id)sender;
- (IBAction)buttonNumericClicked:(id)sender;
- (IBAction)buttonStringClicked:(id)sender;
- (IBAction)buttonDatetimeClicked:(id)sender;
- (IBAction)buttonIncrementClicked:(id)sender;
- (IBAction)buttonDeleteClicked:(id)sender;

@property (nonatomic, strong) NSArray *arrayCells;

- (void)showDoneAlert:(BOOL)isSuccess;

@end

@implementation TagViewController

#pragma mark - life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.arrayCells = @[self.cellCuid, self.cellNumeric, self.cellString, self.cellDatetime, self.cellIncrement, self.cellDelete];
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
    UITableViewCell *cell = self.arrayCells[indexPath.row];
    return cell.bounds.size.height;
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

- (IBAction)buttonStringClicked:(id)sender
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
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
        [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];
        valueDate = [dateFormatter dateFromString:value];
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

#pragma mark - private functions

- (void)showDoneAlert:(BOOL)isSuccess
{
    NSString *info = isSuccess ? @"Tag sent to server." :@"Cannot send tag to server, please check console log.";
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:info message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alertView show];
}

@end
