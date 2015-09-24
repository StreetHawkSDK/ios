/*
 Erica Sadun, http://ericasadun.com
 iPhone Developer's Cookbook, 6.x Edition
 BSD License, Use at your own risk
 */

#import <UIKit/UIKit.h>

/**
 UIDevice extension to get device real model. Refined by Christine to add latest devices. 
 */
@interface SHUIDevice : NSObject

- (NSString *)platformString;

@end