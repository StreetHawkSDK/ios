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

#import <Foundation/Foundation.h>
#import "SHTypes.h" //for SHCallbackHandler

@class PushDataForApplication;

/**
 It's possible to call API `-(void)shFeedback:(NSArray *)arrayChoice needInputDialog:(BOOL)needInput needConfirmDialog:(BOOL)needConfirm withTitle:(NSString *)infoTitle withMessage:(NSString *)infoMessage withPushData:(PushDataForApplication *)pushData` many times, if previous choice is not submitted yet, next choice should wait and not show till user finish previous one. This queue is to hold and handle it.
 */
@interface SHFeedbackQueue : NSObject

/**
 Singletone instance.
 */
+ (id)shared;

/**
 Add into queue, it will be handled automatically.
 */
- (void)addFeedback:(NSArray *)arrayChoice needInputDialog:(BOOL)needInput needConfirmDialog:(BOOL)needConfirm withTitle:(NSString *)infoTitle withMessage:(NSString *)infoMessage withPushData:(PushDataForApplication *)pushData;

/**
 Submit feedback to StreetHawk server.
 */
- (void)submitFeedbackForTitle:(NSString *)feedbackTitle withType:(NSInteger)feedbackType withContent:(NSString *)feedbackContent withPushData:(PushDataForApplication *)pushData withHandler:(SHCallbackHandler)handler;

@end
