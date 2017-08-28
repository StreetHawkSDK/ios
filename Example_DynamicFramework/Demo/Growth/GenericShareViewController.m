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

#import "GenericShareViewController.h"
#import <MessageUI/MessageUI.h>

@interface GenericShareViewController () <MFMailComposeViewControllerDelegate>

@property (nonatomic, strong) NSArray *arrayCells;

@end

@implementation GenericShareViewController

#pragma mark - life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.arrayCells = @[self.cellID, self.cellSource, self.cellMedium, self.cellContent, self.cellTerm, self.cellUrl, self.cellDestinationUrl, self.cellEmailSubject, self.cellEmailBody, self.cellShare];
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
    return self.arrayCells[indexPath.row];;
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
    [StreetHawk originateShareWithCampaign:self.textboxID.text withSource:self.textboxSource.text withMedium:self.textboxMedium.text withContent:self.textboxContent.text withTerm:self.textboxTerm.text shareUrl:deeplinkingUrl withDefaultUrl:destinationUrl streetHawkGrowth_object:^(NSObject *result, NSError *error)
    {
        shPresentErrorAlertOrLog(error);
        if (error == nil)
        {
            dispatch_async(dispatch_get_main_queue(), ^
               {
                   NSString *shareUrl = (NSString *)result;
                   if ([MFMailComposeViewController canSendMail])
                   {
                       MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
                       mc.mailComposeDelegate = self;
                       [mc setMessageBody:[NSString stringWithFormat:@"%@\n\n%@", self.textboxEmailBody.text, shareUrl] isHTML:NO];
                       [mc setSubject:self.textboxEmailSubject.text];
                       [self presentViewController:mc animated:YES completion:nil];
                   }
                   else
                   {
                       UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"share_guid_url" message:shareUrl delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                       [alert show];
                   }
               });
        }
    }];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    if (!error)
    {
        [controller dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
