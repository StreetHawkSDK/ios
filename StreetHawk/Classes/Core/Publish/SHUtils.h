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

#ifndef SH__UTILS__H
#define SH__UTILS__H

#import <UIKit/UIKit.h>

#ifndef SH_LOG_H
#define SH_LOG_H

FOUNDATION_EXPORT void SHLog(NSString *format, ...);

#endif

/** @name Data Format Convert Utility */

/**
 Convert an ASCII encoded c-string to NSString, for example `shCstringToNSString(__FILE__)` to get NSString of current file.
 */
extern NSString *shCstringToNSString(const char *input);

/**
 Converts a byte array into an hex string.
 @param data Byte data.
 @return Hex string.
 */
extern NSString *shDataToHexString(NSData *data);

/**
 Convert a bool to string. 
 @param boolVal Boolean value.
 @return String value "true" or "false".
 */
extern NSString *shBoolToString(BOOL boolVal);

/**
 Get a new instance of NSDateFormatter for the supported date format, timezone and locale. It's auto-release, caller should not release it again.
 @param dateFormat The format string of date, by default (nil) it's yyyy-MM-dd HH:mm:ss, this is also the recognizable date format of server.
 @param timeZone The time zone of format, by default (nil) it's UTC.
 @param locale The locale of format, by default (nil) it's en-US.
 @return A new instance of date formatter.
 */
extern NSDateFormatter *shGetDateFormatter(NSString *dateFormat, NSTimeZone *timeZone, NSLocale *locale);

/**
 Formats a date into a string in StreetHawk-wide format. Must use this format to be recognizable by server. Format is yyyy-MM-dd HH:mm:ss in UTC timezone.
 @param date The date value to be formatted.
 @return The return string.
 */
extern NSString *shFormatStreetHawkDate(NSDate *date);

/**
 Formats a date into a string in ISO format.
 Format is yyyy-MM-dd'T'HH:mm:ssZ in UTC timezone, for example 2017-03-03T05:27:59+0000.
 @param date The date value to be formatted.
 @return The return string.
 */
extern NSString *shFormatISODate(NSDate *date);

/**
 Parses date string into NSDate format. It tries to support as much format as possible. Refer to `input` parameters for the supported date time format.
 @param input Date time string. It supports this kinds of strings:
 
 * yyyy-MM-dd'T'HH:mm:ssZ, for example 2017-03-03T05:27:59+0000
 * yyyy-MM-dd HH:mm:ss, for example 2012-12-20 18:20:50
 * yyyy-MM-dd, for example 2012-12-20
 * dd/MM/yyyy HH:mm:ss, for example 20/12/2012 18:20:50
 * dd/MM/yyyy, for example 20/12/2012
 * MM/dd/yyyy HH:mm:ss, for example 12/20/2012 18:20:50
 * MM/dd/yyyy, for example 12/20/2012
 
 @param offsetSeconds The offsetSeconds parameter tells how many seconds the parsed date is to be offset by.
 */
extern NSDate *shParseDate(NSString *input, int offsetSeconds);

/**
 Parse the string or json object to a dictionary. It handles as much situation as possible, for example, the obj is a right dictionary, or the obj is a string, or the string obj contains wrong "\"" etc.
 @param obj The possible object to be parsed to dictionary.
 @return Try all possible way to parse it to dictionary. If fail return nil.
 */
extern NSDictionary *shParseObjectToDict(NSObject *obj);

/**
 Serialize the NSObject to json string. 
 @param obj The object to be serialized.
 @return The json string if serialize successfully. If fail return nil.
 */
extern NSString *shSerializeObjToJson(NSObject *obj);

/** @name URL Process Utility */

/**
 /If need to set a string as paramter to URL, it needs to check some spefical characters 
 (such as !*'();:@&=+$,/?%#[]) and convert them to URL encoding, for example "#" is encoded as "%23".
 @param input The input raw string, such as "#".
 @return The url encoded string, such as "%23".
 */
extern NSString *shUrlEncodeFull(NSString *input);

/**
 Parse get request string's parameter string to NSDictionary. For example, param1=value1&param2=value2&param3=value3 is parsed to {param1:value1, param2:value2, param3=value3}.
 @param str Parameter string of a get request, formatted as: param1=value1&param2=value2&param3=value3...
 @return Dictionary parsed from the parameter string.
 */
extern NSDictionary *shParseGetParamStringToDict(NSString *str);

/**
 Append two string together into one string, ignore if empty. For example "abc" and "efg" to be "abc efg"; "abc" and nil to be "abc".
 */
extern NSString *shAppendString(NSString *str1, NSString *str2);

/** @name UI Utility */

/**
 A common way to present error by showing details in an alert view or XCode console log. It's only used in SHSampleDev and SHSampleProd to show alert, others show logline.
 @param error The error to present. If error is nil nothing happen.
 */
extern void shPresentErrorAlertOrLog(NSError *error);

/**
 Get corresponding view controller for a view.
 */
extern UIViewController *shGetViewController(UIView *view);

/**
 Get real display name for some controls such as UILabel.
 */
extern CGSize shrinkControlSize(UIView *control);

/**
 Dismiss all message views, including UIAlertView, UIActionSheet, UIModalView.
 */
extern void shDismissAllMessageView(void);

/**
 Get a suitable window to present other views, such as `MBProgressHUD`, `UIActionSheet` etc. It's not hidden, and not confirm dialog window.
 */
extern UIWindow *shGetPresentWindow(void);

/** @name Resources and Bundles Utility */

/**
 Find the bundle contains the resource with type. StreetHawk library has its own resource bundle `StreetHawkCoreRes.bundle` for images, xibs, strings etc, these resources are not in main bundle. To find them properly, need to give the correct bundle. This utility function is to get properly bundle.
 @param resourceName The resource name required, for example @"InputiBeaconViewController" or @"loginfo".
 @param type The resource type required, for example @"nib" or @"png".
 @param mandatory Whether this resource is mandatory. If not find suitable bundle, trigger assert when `mandatory` = YES.
 @return Return find bundle, it may be main bundle, or sub-bundle, or even nil.
 */
extern NSBundle *shFindBundleForResource(NSString *resourceName, NSString *type, BOOL mandatory);

/**
 Search for localized string for a `key`, first search in App's bundle, then search StreetHawkCoreRes.bundle. If nothing match return `defaultStr`. This provides a mechanism for customer App to override resource strings inside StreetHawk library. Customer should add Localizable.strings file and override the resource strings with same key defined in StreetHawkRes.bundle's Localizable.strings.
 @param key Key registered in Localizable.strings.
 @param defaultStr If nothing matching in Localizable.strings (both customer's and StreetHawkCoreRes.bundle's), use this `defaultStr`.
 */
extern NSString *shLocalizedString(NSString *key, NSString *defaultStr);

/** @name Other Utility */

/**
 Call phone number. If success return YES else return NO.
 @param phone The string for phone number to call.
 @return If pass in phone string can call, return YES; else return NO.
 */
extern BOOL shCallPhoneNumber(NSString *phone);

/**
 Get mac address of current device, the output is for example: 00:23:32:CB:AB:80. However since iOS 7 this function cannot work on device anymore, always return fake address.
 */
extern NSString *shGetMacAddress(void);

/**
 Get carrier's name from current device, for example "AT&T", "China Mobile" etc. If current device does not connect to carrier, for example iPad Wifi, return "Other".
 */
extern NSString *shGetCarrierName(void);

/**
 Enum for this App's mode.
 */
enum SHAppMode
{
    /**
     Cannot detect which mode is. This should never happen, in debug SDK trigger assert.
     */
    SHAppMode_Unknown,
    /**
     The App is running on simulator. Against it all below is running on device.
     */
    SHAppMode_Simulator,
    /**
     The App is built with development provisioning, will use sandbox remote notification.
     */
    SHAppMode_DevProvisioning,
    /**
     The App is built with ad-hoc provisioning, will use production remote notification.
     */
    SHAppMode_AdhocProvisioning,
    /**
     The App is downloaded from AppStore. will use production remote notification.
     */
    SHAppMode_AppStore,
    /**
     The App is downloaded from enterprise distribution way. will use production remote notification.
     */
    SHAppMode_Enterprise,
};
typedef enum SHAppMode SHAppMode;

/**
 Return the mode of current App.
 */
extern SHAppMode shAppMode(void);

/**
 Return the string to describe current mode. 
 */
extern NSString *shAppModeString(SHAppMode mode);

/**
 Return string describing which development platform current App is.
 */
extern NSString *shDevelopmentPlatformString(void);

/**
 Return app/status result of streethawk function should be enabled. 
 */
extern BOOL streetHawkIsEnabled(void);

/**
 Check whether it's SDK's view controller.
 */
extern BOOL shIsSDKViewController(UIViewController * vc);

/**
 Some view such as react-native use RCTView for all views, so that only vc cannot work, it needs an
 additional id. This function appends additional id.
 */
extern NSString *shAppendUniqueSuffix(UIViewController *vc);

/**
 Utility function to check string is nil or empty.
 @param str Check the string.
 @return Return YES if `str` is nil or length = 0; Otherwise return NO.
 */
extern BOOL shStrIsEmpty(NSString *str);

/**
 Utility function to check two array content is same.
 @param array1 Array to compare 1.
 @param array2 Array to compare 2.
 @return If content is same return YES; otherwise return NO.
 */
extern BOOL shArrayIsSame(NSArray *array1, NSArray *array2);

/**
 Check whether an open url is from universal linking. Universal linking works on iOS 9+, starting with "http" or "https". If the url is universal linking, it needs to convert to real deeplinking url such as "hawk://...".
 @param url The pass in url string. 
 @return If the url is universal linking return YES; otherwise return NO.
 */
extern BOOL shIsUniversalLinking(NSString *url);

/**
 Automatically capture advertising identifier if customer's App add AdSupport.framework. If not return nil.
 */
extern NSString *shCaptureAdvertisingIdentifier(void);

/**
 Extension to system UIDevice class.
 */
@interface UIDevice (SHExt)

/**
 Get platform string such as "iPhone 9.1". It will be mapping in server side to be readable model "iPhone 7".
 @return Raw model string.
 */
- (NSString *)platformString;

@end

/**
 Extension to system UIColor class.
 */
@interface UIColor (SHExt)

#define RGB_COLOUR_CODE_LEN         3
#define ARGB_COLOUR_CODE_LEN        4
#define RRGGBB_COLOUR_CODE_LEN      6
#define AARRGGBB_COLOUR_CODE_LEN    8

/**
 Support two types:
 1. Convert hex string formatted as #RGB or #RRGGBB or #AARRGGBB to UIColor.
    It must prefix "#" and only contains (A), R, G, B. If not in this format, return nil.
 2. Convert RGB string formatted as rgb(255,255,255,1).
 */
+ (UIColor *)colorFromString:(NSString *)str;

/**
 Convert color to hex string formatted as #AARRGGBB. If color is nil return nil.
 */
+ (NSString *)hexStringFromColor:(UIColor *)color;

@end

/**
 Extension for prints auto-layout constraint description.
 */
@interface NSLayoutConstraint (SHExt)

@end

/**
 Extension for NSObject.
 */
@interface NSObject (SHExt)

/**
 Get direct properties inside this class definition. Not include super class's properties.
 */
- (NSDictionary<NSString *, NSString *> *)getPropertyNameTypes;

@end

@interface NSString (SHExt)

/**
 Get md5 of a string.
 */
- (NSString *)md5;

@end

#endif //SH__UTILS__H
