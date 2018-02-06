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

@interface LogTagCasesViewController : StreetHawkBaseTableViewController <UITextFieldDelegate>

@property (retain, nonatomic) IBOutlet UITableViewCell *cellCuid;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellNumeric;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellString;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellDatetime;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellIncrement;
@property (strong, nonatomic) IBOutlet UITableViewCell *cellIncrementValue;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellDelete;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellFeed;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellError;

@property (retain, nonatomic) IBOutlet UITextField *textboxCuidValue;
@property (retain, nonatomic) IBOutlet UITextField *textboxKeyNumeric;
@property (retain, nonatomic) IBOutlet UITextField *textboxValueNumeric;
@property (retain, nonatomic) IBOutlet UITextField *textboxKeyString;
@property (retain, nonatomic) IBOutlet UITextField *textboxValueString;
@property (retain, nonatomic) IBOutlet UITextField *textboxKeyDatetime;
@property (retain, nonatomic) IBOutlet UITextField *textboxValueDatetime;
@property (retain, nonatomic) IBOutlet UITextField *textboxKeyIncrement;
@property (strong, nonatomic) IBOutlet UITextField *textboxKeyIncrementValue;
@property (strong, nonatomic) IBOutlet UITextField *textboxValueIncrementValue;
@property (retain, nonatomic) IBOutlet UITextField *textboxKeyDelete;

- (IBAction)buttonCuidClicked:(id)sender;
- (IBAction)buttonNumericClicked:(id)sender;
- (IBAction)buttonSringClicked:(id)sender;
- (IBAction)buttonDatetimeClicked:(id)sender;
- (IBAction)buttonIncrementClicked:(id)sender;
- (IBAction)buttonIncrementValueClicked:(id)sender;
- (IBAction)buttonDeleteClicked:(id)sender;
- (IBAction)buttonFeedClicked:(id)sender;
- (IBAction)buttonErrorClicked:(id)sender;

@end
