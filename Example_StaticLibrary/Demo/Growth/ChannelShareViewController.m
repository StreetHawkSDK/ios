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

#import "ChannelShareViewController.h"

@interface ChannelShareViewController ()

@property (strong, nonatomic) IBOutlet UITableViewCell *cellID;
@property (strong, nonatomic) IBOutlet UITextField *textboxID;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellMedium;
@property (retain, nonatomic) IBOutlet UITextField *textboxMedium;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellContent;
@property (retain, nonatomic) IBOutlet UITextField *textboxContent;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellTerm;
@property (retain, nonatomic) IBOutlet UITextField *textboxTerm;
@property (strong, nonatomic) IBOutlet UITableViewCell *cellUrl;
@property (strong, nonatomic) IBOutlet UITextField *textboxUrl;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellDestinationUrl;
@property (retain, nonatomic) IBOutlet UITextField *textboxDestinationUrl;
@property (strong, nonatomic) IBOutlet UITableViewCell *cellMessage;
@property (strong, nonatomic) IBOutlet UITextField *textboxMessage;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellShare;

- (IBAction)buttonShareClicked:(id)sender;

@property (nonatomic, strong) NSArray *arrayCells;

@end

@implementation ChannelShareViewController

#pragma mark - life cycle

- (void)viewDidLoad
{
    self.arrayCells = @[self.cellID, self.cellMedium, self.cellContent, self.cellTerm, self.cellUrl, self.cellDestinationUrl, self.cellMessage, self.cellShare];
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

- (IBAction)buttonShareClicked:(id)sender
{
    NSURL *deeplinkingUrl = nil;
    if (self.textboxUrl.text.length > 0)
    {
        deeplinkingUrl = [NSURL URLWithString:self.textboxUrl.text];
        if (deeplinkingUrl == nil)
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Deeplinking url format is invalid. Correct it or delete it." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alertView show];
            return;
        }
    }
    NSURL *destinationUrl = nil;
    if (self.textboxDestinationUrl.text.length > 0)
    {
        destinationUrl = [NSURL URLWithString:self.textboxDestinationUrl.text];
        if (destinationUrl == nil)
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Destination url format is invalid. Correct it or delete it." message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alertView show];
            return;
        }
    }
    [StreetHawk originateShareWithCampaign:self.textboxID.text withMedium:self.textboxMedium.text withContent:self.textboxContent.text withTerm:self.textboxTerm.text shareUrl:deeplinkingUrl withDefaultUrl:destinationUrl withMessage:self.textboxMessage.text];
}

@end
