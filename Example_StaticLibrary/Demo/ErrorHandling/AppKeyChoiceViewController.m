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

#import "AppKeyChoiceViewController.h"

@interface AppKeyChoiceViewController ()

//Host list.
@property (nonatomic, strong) NSArray *arrayAppKeys;

//The selected App key from choice list, not include input App key.
@property (nonatomic, strong) NSString *selectedAppKey;

@property (nonatomic, strong) UITextField *inputAppKey;

- (void)buttonDoneClick:(id)sender; //button done clicked

@end

@implementation AppKeyChoiceViewController

#pragma mark - life cycle

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self)
    {
        self.arrayAppKeys = @[@"SHStatic_bison", @"SHStatic_zebra"];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(buttonDoneClick:)];
}

#pragma mark - event handler

- (void)buttonDoneClick:(id)sender
{
    NSString *inputAppKey = [self.inputAppKey.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (shStrIsEmpty(self.selectedAppKey) && shStrIsEmpty(inputAppKey))
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Please select or input one app key." message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
        return;
    }
    if (self.selectedCallback != nil)
    {
        if (!shStrIsEmpty(inputAppKey))
        {
            self.selectedCallback(inputAppKey);
        }
        else
        {
            self.selectedCallback(self.selectedAppKey);
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.tableView.window.bounds.size.width, 100)];
    label.text = @"Choose App key when App first launch. If you would like to test another App key, please delete App and install again!";
    label.font = [UIFont boldSystemFontOfSize:18];
    label.textColor = [UIColor redColor];
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.numberOfLines = 0;
    return label;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 100;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.arrayAppKeys.count + 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 35;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row < self.arrayAppKeys.count)
    {
        static NSString *cellIdentifier = @"AppKeyChooseCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.textLabel.textAlignment = NSTextAlignmentLeft;
            cell.textLabel.font = [UIFont systemFontOfSize:17];
        }
        cell.textLabel.text = self.arrayAppKeys[indexPath.row];
        if ([cell.textLabel.text compare:self.selectedAppKey] == NSOrderedSame)
        {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        else
        {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        return cell;
    }
    else
    {
        static NSString *cellIdentifier = @"AppKeyInputCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            self.inputAppKey = [[UITextField alloc] initWithFrame:CGRectMake(10, 0, cell.bounds.size.width - 20, cell.bounds.size.height)];
            self.inputAppKey.placeholder = @"Please input App Key";
            self.inputAppKey.delegate = self;
            [cell.contentView addSubview:self.inputAppKey];
        }
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row < self.arrayAppKeys.count)
    {
        NSString *selectRow = self.arrayAppKeys[indexPath.row];
        if ([selectRow compare:self.selectedAppKey] != NSOrderedSame)
        {
            self.selectedAppKey = selectRow;
            [self.tableView reloadData];
        }
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

@end
