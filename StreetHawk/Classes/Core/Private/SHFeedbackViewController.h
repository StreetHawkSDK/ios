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
 The callback for feedback input dialog.
 @param isSubmit If user want to continue submit, set YES; otherwise cancel submit.
 @param title The title of this feedback, mandatory.
 @param content The text input in the feedback dialog, optional.
 */
typedef void (^SHFeedbackInputHandler)(BOOL isSubmit, NSString *title, NSString *content);

/**
 Protocol for all feedback input view controller must implement.
 */
@protocol SHFeedbackInput <NSObject>

@required

/**
 The handler to notice input result of feedback dialog.
 */
@property (nonatomic, copy) SHFeedbackInputHandler inputHandler;

@end

//The default input user feedback dialog.
@interface SHFeedbackViewController : SHBaseViewController <SHFeedbackInput, UITextFieldDelegate, UITextViewDelegate>

@property (strong, nonatomic) IBOutlet UITextField *textboxTitle;
@property (strong, nonatomic) IBOutlet UITextView *textboxContent;
@property (strong, nonatomic) IBOutlet UIButton *buttonSubmit;
@property (strong, nonatomic) IBOutlet UIButton *buttonCancel;

//The pass in feedback title and content.
@property (nonatomic, strong) NSString *feedbackTitle;

- (IBAction)buttonSubmitClicked:(id)sender;
- (IBAction)buttonCancelClicked:(id)sender;

@end
