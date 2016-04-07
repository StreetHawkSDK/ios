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

/**
 Object for hosting customized interactive push button pairs. Refer to `- (BOOL)setInteractivePushBtnPairs:(NSArray *)arrayPairs;`.
 */
@interface InteractivePush : NSObject

/**
 Title for given pair, it's the identifier of pairs, case sensitive. Note: customized pair identifier cannot same as pre-defined pairs, if overlap there is a warning message prints in console log when `- (BOOL)setInteractivePushBtnPairs:(NSArray *)arrayPairs;`, and this customized pair is ignored.
 */
@property (nonatomic, strong) NSString * pairTitle;

/**
 Title for button 1, whose result is 1. For customized button, the action is always foreground.
 */
@property (nonatomic, strong) NSString *b1Title;

/**
 Title for button 2, whose result is -1. For customized button, the action is always foreground.
 */
@property (nonatomic, strong) NSString *b2Title;

/**
 Creator with necessary parameters.
 @param pairTitle Title for given pair, it's the identifier of pairs.
 @param b1Title Title for button 1, whose result is 1.
 @param b2Title Title for button 2, whose result is -1.
 */
- (id)initWithPairTitle:(NSString *)pairTitle withButton1:(NSString *)b1Title withButton2:(NSString *)b2Title;

@end
