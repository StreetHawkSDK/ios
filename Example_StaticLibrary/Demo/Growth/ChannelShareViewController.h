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

#import <StreetHawkCore/StreetHawkCore.h>

@interface ChannelShareViewController : StreetHawkBaseTableViewController <UITextFieldDelegate>

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

@end
