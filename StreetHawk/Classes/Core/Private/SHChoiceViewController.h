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

#import "SHViewController.h"

/**
 The callback for choice selection.
 @param isCancel If user click "cancel" button, set YES and `choiceIndex` is -1; Otherwise return NO with corresponding `choiceIndex`.
 @param choiceIndex The choice selected, match to property `arrayChoices`.
 */
typedef void (^SHChoiceHandler)(BOOL isCancel, NSInteger choiceIndex);

/**
 Protocol for all choice view controller must implement.
 */
@protocol SHChoiceHandler <NSObject>

@required

/**
 The handler to notice choice result.
 */
@property (nonatomic, copy) SHChoiceHandler choiceHandler;

@end

@interface SHChoiceViewController : SHBaseViewController <SHChoiceHandler, UITableViewDelegate, UITableViewDataSource>

@property (strong, nonatomic) IBOutlet UILabel *labelTitle;
@property (strong, nonatomic) IBOutlet UILabel *labelMessage;
@property (strong, nonatomic) IBOutlet UIButton *buttonCancel;
@property (strong, nonatomic) IBOutlet UITableView *tableChoice;
@property (strong, nonatomic) IBOutlet UIView *viewDialog;

- (IBAction)buttonCancelClicked:(id)sender;

/**
 The array string for choice options.
 */
@property (nonatomic, strong) NSArray *arrayChoices;

/**
 The text display as title.
 */
@property (nonatomic, strong) NSString *displayTitle;

/**
 The text display as message.
 */
@property (nonatomic, strong) NSString *displayMessage;

/**
 The text display in cancel button. If not set display "Cancel" by default.
 */
@property (nonatomic, strong) NSString *displayCancelButton;

/**
 Show this choice list in a window. Must use a special function instead of `presentModalDialogViewController:`, because need to set this view controller as rootViewController for rotating. 
 */
- (void)showChoiceList;

/**
 Close choice list from window.
 */
- (void)closeChoiceList;

@end
