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

#import "SHFeedbackViewController.h"
//header from StreetHawk
#import "SHPresentDialog.h" //for present modal dialog

@implementation SHFeedbackViewController

@synthesize inputHandler;

#pragma mark - life cycle

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.isViewAdjustForKeyboard = YES;
    }
    return self;
}

-(void)dealloc
{
    self.textboxTitle.delegate = nil;
    self.textboxContent.delegate = nil;
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor lightGrayColor];
    if (self.feedbackTitle == nil || self.feedbackTitle.length == 0)
    {
        [self.textboxTitle becomeFirstResponder];
    }
    else
    {
        self.textboxTitle.text = self.feedbackTitle;
        [self.textboxContent becomeFirstResponder];
    }
}

#pragma mark - event handle

- (IBAction)buttonSubmitClicked:(id)sender
{
    self.feedbackTitle = [self.textboxTitle.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (self.feedbackTitle == nil || self.feedbackTitle.length == 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Please input title" message:@"Title is mandatory for feedback." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
        [alertView show];
        return;
    }
    if (self.inputHandler)
    {
        self.inputHandler(YES, self.feedbackTitle, self.textboxContent.text);
    }
    [self dismissModalDialogViewController];
}

- (IBAction)buttonCancelClicked:(id)sender
{
    if (self.inputHandler)
    {
        self.inputHandler(NO, nil, nil);
    }
    [self dismissModalDialogViewController];
}

#pragma mark - UITextFieldDelegate and UITextViewDelegate handler

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.textboxTitle)
    {
        [self.textboxContent becomeFirstResponder];
    }
    return YES;
}

@end
