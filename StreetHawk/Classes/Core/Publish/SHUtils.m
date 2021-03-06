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

#import "SHUtils.h"
//header from StreetHawk
#import "SHApp.h" //for `StreetHawk.isDebugMode`
#import "SHAppStatus.h" //for check streetHawkIsEnabled
#import "SHViewController.h" //for SHBase(Table)ViewController

void SHLog(NSString *format, ...)
{
    if (StreetHawk.isDebugMode)
    {
        va_list args;
        va_start(args, format);
        NSString * msg = [[NSString alloc] initWithFormat:format arguments:args];
        NSLog(@"(StreetHawk Log): %@", msg);
        va_end(args);
    }
}

#pragma mark - Data Format Convert Utility

NSString *shCstringToNSString(const char *input)
{
    if (input)
        return @(input);
    else
        return @"";  //if not check this NSString get wild pointer.
}

NSString *shDataToHexString(NSData *data)
{
    NSMutableString *str = [NSMutableString string];
    char *hexChars = "0123456789ABCDEF";
    const char *bytes = [data bytes];
    if (bytes)
    {
        for (NSInteger i = 0, count = [data length];i < count;i++)
        {
            unsigned currChar = ((unsigned char *)bytes)[i];
            [str appendFormat:@"%c%c", hexChars[currChar / 16], hexChars[currChar % 16]];
        }
    }
    return str;
}

NSString *shBoolToString(BOOL boolVal)
{
    return boolVal ? @"true" : @"false";
}

NSDateFormatter *shGetDateFormatter(NSString *dateFormat, NSTimeZone *timeZone, NSLocale *locale)
{
    //Not use singleton because NSDateFormatter is not thread-safe, ticket https://bitbucket.org/shawk/streethawk/issue/319/asku-date-formatting-crashes
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    if (dateFormat == nil)
    {
        dateFormat = @"yyyy-MM-dd HH:mm:ss";
    }
    [dateFormatter setDateFormat:dateFormat];
    if (timeZone == nil)
    {
        timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    }
    [dateFormatter setTimeZone:timeZone];
    if (locale == nil)
    {
        locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    }
    [dateFormatter setLocale:locale];
    return dateFormatter;  //as this file is ARC, this return value is auto-released.
}

NSString *shFormatStreetHawkDate(NSDate *date)
{
    return [shGetDateFormatter(nil, nil, nil) stringFromDate:date];
}

NSString *shFormatISODate(NSDate *date)
{
    return [shGetDateFormatter(@"yyyy-MM-dd'T'HH:mm:ssZ", nil, nil) stringFromDate:date];
}

NSDate *shParseDate(NSString *input, int offsetSeconds)
{
    static dispatch_semaphore_t formatter_semaphore;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter_semaphore = dispatch_semaphore_create(1);
    });
    NSDate *out = nil;
    if ([input isKindOfClass:[NSString class]] && !shStrIsEmpty(input) && input != (id)[NSNull null])
    {
        dispatch_semaphore_wait(formatter_semaphore, DISPATCH_TIME_FOREVER);
        NSDateFormatter *dateFormatter = shGetDateFormatter(nil, nil, nil);
        out = [dateFormatter dateFromString:input];
        NSArray *arrayTimeformat = @[@"yyyy-MM-dd'T'HH:mm:ss.SSS",
                                     @"yyyy-MM-dd'T'HH:mm:ssZ",
                                     @"yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                                     @"yyyy-MM-dd'T'HH:mm:ss",
                                     @"yyyy-MM-dd",
                                     @"dd/MM/yyyy HH:mm:ss",
                                     @"dd/MM/yyyy",
                                     @"MM/dd/yyyy HH:mm:ss",
                                     @"MM/dd/yyyy"];
        if (out == nil)
        {
            for (NSString *strTimeFormat in arrayTimeformat)
            {
                [dateFormatter setDateFormat:strTimeFormat];
                out = [dateFormatter dateFromString:input];
                if (out != nil)
                {
                    break;
                }
            }
        }
        dispatch_semaphore_signal(formatter_semaphore);
        if (offsetSeconds != 0)
        {
            out = [NSDate dateWithTimeInterval:offsetSeconds sinceDate:out];
        }
    }
    return out;
}

NSDictionary *shParseObjectToDict(NSObject *obj)
{
    if (obj == nil || [obj isKindOfClass:[NSDictionary class]])  //no parse needed
    {
        return (NSDictionary *)obj;
    }
    if ([obj isKindOfClass:[NSString class]] && ((NSString *)obj).length > 0)  //sometimes server send dictionary in json string, parse it.
    {
        NSString *str = (NSString *)obj;
        //if returned json contains <null>, replace it to be empty string, otherwise it will cause NSNull value.
        if ([str rangeOfString:@": null," options:NSCaseInsensitiveSearch].location != NSNotFound)
        {
            str = [str stringByReplacingOccurrencesOfString:@": null," withString:@": \"\","];
        }
        if ([str rangeOfString:@": null}" options:NSCaseInsensitiveSearch].location != NSNotFound)
        {
            str = [str stringByReplacingOccurrencesOfString:@": null}" withString:@": \"\"}"];
        }
        NSError *error;
        NSObject *dictObj = [NSJSONSerialization JSONObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding] options:0/*no special option*/ error:&error];
        if (dictObj != nil && [dictObj isKindOfClass:[NSDictionary class]])
        {
            return (NSDictionary *)dictObj;
        }
        else
        {
            SHLog(@"Fail to parse object (%@) to dict, error: %@.", obj, error.localizedDescription);
        }
    }
    return nil;
}

NSString *shSerializeObjToJson(NSObject *obj)
{
    if (obj == nil)
    {
        return @"";
    }
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:obj options:0/*no special option*/ error:&error];
    assert((error == nil) && "Fail to serialize object.");
    if (error == nil)
    {
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    else
    {
        return nil;
    }
}

NSString *shAppendString(NSString *str1, NSString *str2)
{
    NSString *ret = nil;
    if (str1 != nil && str1.length > 0 && str2 != nil && str2.length > 0)
    {
        ret = [NSString stringWithFormat:@"%@ %@", str1, str2];
    }
    else if (str1 != nil && str1.length > 0)
    {
        ret = str1;
    }
    else if (str2 != nil && str2.length > 0)
    {
        ret = str2;
    }
    return ret;
}

#pragma mark - URL Process Utility

//If need to set a string as paramter to URL, it needs to check some spefical characters (such as !*'();:@&=+$,/?%#[]) and convert them to URL encoding, for example "#" is encoded as "%23".
NSString *shUrlEncodeFull(NSString *input)
{
    NSString *encoded = (__bridge_transfer/*ARC: create CF and memory managed by NS*/ NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)input, NULL, (CFStringRef)@"!*'();:@&=+$,/?%#[]_", kCFStringEncodingUTF8);
    return encoded;
}

NSDictionary *shParseGetParamStringToDict(NSString *str)
{
    NSMutableDictionary *queryComponents = [NSMutableDictionary dictionary];
    for(NSString *keyValuePairString in [str componentsSeparatedByString:@"&"])
    {
        NSArray *keyValuePairArray = [keyValuePairString componentsSeparatedByString:@"="];
        if ([keyValuePairArray count] < 2) continue; // Verify that there is at least one key, and at least one value.  Ignore extra = signs
        NSString *key = [[[keyValuePairArray objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *value = [[[keyValuePairArray objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (key != nil && key.length > 0 && value != nil && value.length > 0)
        {
            [queryComponents setObject:value forKey:key];
        }
    }
    return queryComponents;
}

#pragma mark - UI Utility

void shPresentErrorAlertOrLog(NSError *error)
{
    if (error == nil)  //this checks error inside, so the caller can safely call it directly without checking error.
    {
        return;
    }
    NSString *bundleId = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
    if ([bundleId rangeOfString:@"co.streethawk.SHSample"].location != NSNotFound)
    {
        //show error alert for StreetHawk SHSampleDev/Prod
        dispatch_async(dispatch_get_main_queue(), ^
           {
               NSString *errorTitle = error.localizedFailureReason;
               if (shStrIsEmpty(errorTitle))
               {
                   NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
                   errorTitle = [NSString stringWithFormat:@"%@ reports error", appName];
               }
               NSString *errorMsg = !shStrIsEmpty(error.localizedDescription) ? error.localizedDescription : @"No detail error message. Please contact App administrator.";
               UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:errorTitle message:errorMsg delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
               [alertView show];
           });
    }
    else
    {
        NSLog(@"StreetHawk report error: %@.", error);
    }
}

//Go traverse to UIView's responder till get a UIViewController.
id shTraverseResponderChainForUIViewController(UIView *view)
{
    if ([view respondsToSelector:@selector(nextResponder)])
    {
        id nextResponder = [view nextResponder];
        if ([nextResponder isKindOfClass:[UIViewController class]])
        {
            return nextResponder;
        }
        else if ([nextResponder isKindOfClass:[UIView class]])
        {
            return shTraverseResponderChainForUIViewController((UIView *)nextResponder);
        }
    }
    
    return nil;
}

UIViewController *shGetViewController(UIView *view)
{
    return (UIViewController *)shTraverseResponderChainForUIViewController(view);
}

CGSize shrinkControlSize(UIView *control)
{
    //for tip display at correct position, some control needs to get real size.
    if ([control isKindOfClass:[UILabel class]])
    {
        //a label can be large, but the real display size is small.
        UILabel *label = (UILabel *)control;
        if (shStrIsEmpty(label.text))
        {
            return CGSizeMake(1.0, 1.0);
        }
        BOOL isOneLine = NO;
        CGSize maximumLabelSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
        if (label.lineBreakMode == NSLineBreakByClipping
            || label.lineBreakMode == NSLineBreakByTruncatingHead
            || label.lineBreakMode == NSLineBreakByTruncatingTail
            || label.lineBreakMode == NSLineBreakByTruncatingMiddle)
        {
            //one line mode
            maximumLabelSize = CGSizeMake(CGFLOAT_MAX, label.bounds.size.height);
            isOneLine = YES;
        }
        else if (label.lineBreakMode == NSLineBreakByCharWrapping
                 || label.lineBreakMode == NSLineBreakByWordWrapping)
        {
            //multiple line mode
            maximumLabelSize = CGSizeMake(label.bounds.size.width, CGFLOAT_MAX);
        }
        else
        {
            assert(NO && "Meet unexpected line break mode.");
        }
        NSMutableParagraphStyle *textParagraphStyle = [[NSMutableParagraphStyle alloc] init];
        textParagraphStyle.alignment = label.textAlignment;
        textParagraphStyle.lineBreakMode = label.lineBreakMode;
        CGRect rect = [label.text boundingRectWithSize:maximumLabelSize options:NSStringDrawingUsesLineFragmentOrigin| NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:label.font, NSParagraphStyleAttributeName:textParagraphStyle} context:nil];
        CGFloat width = rect.size.width <= label.bounds.size.width ? rect.size.width : label.bounds.size.width;
        CGFloat height = rect.size.height <= label.bounds.size.height ? rect.size.height : label.bounds.size.height;
        if (isOneLine)
        {
            return CGSizeMake(width, label.bounds.size.height); //still keep label's height, otherwise pointer move a little bit upper.
        }
        else
        {
            return CGSizeMake(label.bounds.size.width, height);
        }
    }
    return control.bounds.size;
}

//Recrusively close views.
void shDismissMessageViewForSubviews(NSArray *subViews)
{
    for (UIView *subView in subViews)
    {
        if ([subView isKindOfClass:[UIAlertView class]])
        {
            UIAlertView *alertView = (UIAlertView *)subView;
            [alertView dismissWithClickedButtonIndex:alertView.cancelButtonIndex animated:NO];
        }
        if ([subView isKindOfClass:[UIActionSheet class]])
        {
            UIActionSheet *actionSheet = (UIActionSheet *)subView;
            [actionSheet dismissWithClickedButtonIndex:actionSheet.cancelButtonIndex animated:NO];
        }
        UIViewController *viewController = shGetViewController(subView);
        [viewController dismissViewControllerAnimated:YES completion:^{
            shDismissMessageViewForSubviews(subView.subviews);
        }];
    }
}

void shDismissAllMessageView()
{
    for (UIWindow *window in [UIApplication sharedApplication].windows)
    {
        shDismissMessageViewForSubviews(window.subviews);
    }
}

UIWindow *shGetPresentWindow()
{
    UIWindow *presentWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows)
    {
        if (!window.isHidden/*hidden window covers in demo App*/ && [NSStringFromClass(window.class) isEqual:@"UIWindow"]/*when confirm dialog promote there is a `UITextEffectsWindow` window*/)
        {
            presentWindow = window;
            break;
        }
    }
    assert(presentWindow != nil && "Cannot find suitable window to present other view.");
    if (presentWindow == nil && [UIApplication sharedApplication].windows.count > 0)
    {
        presentWindow = [UIApplication sharedApplication].windows.lastObject;
    }
    return presentWindow;
}

#pragma mark - Resources and Bundles Utility

#define StreetHawk_BUNDLE ([[NSBundle mainBundle] URLForResource:@"streethawk" withExtension:@"bundle"] != nil ? [NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"streethawk" withExtension:@"bundle"]] : nil)
#define Pointzi_BUNDLE ([[NSBundle mainBundle] URLForResource:@"Pointzi" withExtension:@"bundle"] != nil ? [NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"Pointzi" withExtension:@"bundle"]] : nil)
#define StreetHawkCoreRES_BUNDLE ([[NSBundle mainBundle] URLForResource:@"StreetHawkCoreRes" withExtension:@"bundle"] != nil ? [NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"StreetHawkCoreRes" withExtension:@"bundle"]] : nil)
#define StreetHawkCoreRES_Titanium_BUNDLE ([[NSBundle mainBundle] URLForResource:@"StreetHawkCoreRes" withExtension:@"bundle" subdirectory:@"modules/com.streethawk.shanalytics"] != nil ? [NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"StreetHawkCoreRes" withExtension:@"bundle" subdirectory:@"modules/com.streethawk.shanalytics"]] : nil)
#define StreetHawkCoreRES_EmbeddedFull_BUNDLE ([[NSBundle mainBundle] URLForResource:@"StreetHawkCoreRes" withExtension:@"bundle" subdirectory:@"Frameworks/StreetHawkCore.framework"] != nil ? [NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"StreetHawkCoreRes" withExtension:@"bundle" subdirectory:@"Frameworks/StreetHawkCore.framework"]] : nil)

NSBundle *shFindBundleForResource(NSString *resourceName, NSString *type, BOOL mandatory)
{
    NSBundle *bundle = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[NSBundle mainBundle] pathForResource:resourceName ofType:type]]) //first check main bundle
    {
        bundle = [NSBundle mainBundle];
    }
    else if (StreetHawk_BUNDLE != nil && [[NSFileManager defaultManager] fileExistsAtPath:[StreetHawk_BUNDLE pathForResource:resourceName ofType:type]]) //check streethawk.bundle
    {
        bundle = StreetHawk_BUNDLE;
    }
    else if (Pointzi_BUNDLE != nil && [[NSFileManager defaultManager] fileExistsAtPath:[Pointzi_BUNDLE pathForResource:resourceName ofType:type]]) //check Pointzi.bundle
    {
        bundle = Pointzi_BUNDLE;
    }
    else if (StreetHawkCoreRES_BUNDLE != nil && [[NSFileManager defaultManager] fileExistsAtPath:[StreetHawkCoreRES_BUNDLE pathForResource:resourceName ofType:type]])  //check StreetHawkCoreRes.bundle
    {
        bundle = StreetHawkCoreRES_BUNDLE;
    }
    else if (StreetHawkCoreRES_Titanium_BUNDLE != nil && [[NSFileManager defaultManager] fileExistsAtPath:[StreetHawkCoreRES_Titanium_BUNDLE pathForResource:resourceName ofType:type]])  //check Titanium assets path
    {
        bundle = StreetHawkCoreRES_Titanium_BUNDLE;
    }
    else if (StreetHawkCoreRES_EmbeddedFull_BUNDLE != nil && [[NSFileManager defaultManager] fileExistsAtPath:[StreetHawkCoreRES_EmbeddedFull_BUNDLE pathForResource:resourceName ofType:type]])  //check Embedded binary framework
    {
        bundle = StreetHawkCoreRES_EmbeddedFull_BUNDLE;
    }
    //For png image, it might append @3x or @2x in file name. Try in case not find suitable.
    if (bundle == nil && [type compare:@"png" options:NSCaseInsensitiveSearch] == NSOrderedSame && ![resourceName containsString:@"@"])
    {
        if (![resourceName hasSuffix:@"@3x"])
        {
            bundle  = shFindBundleForResource([resourceName stringByAppendingString:@"@3x"], type, mandatory);
        }
        if (bundle == nil && ![resourceName hasSuffix:@"@2x"])
        {
            bundle  = shFindBundleForResource([resourceName stringByAppendingString:@"@2x"], type, mandatory);
        }
    }
    if (mandatory)
    {
        assert(bundle != nil && "Cannot find suitable bundle");
    }
    return bundle;
}

NSString *shLocalizedString(NSString *key, NSString *defaultStr)
{
    NSString *retStr = NSLocalizedString(key, nil);  //search in App's bundle Localizable.strings
    if (shStrIsEmpty(retStr) || [retStr isEqualToString:key])
    {
        if (StreetHawk_BUNDLE != nil)
        {
            retStr = NSLocalizedStringWithDefaultValue(key, nil, StreetHawk_BUNDLE, defaultStr, nil);
        }
        if (Pointzi_BUNDLE != nil)
        {
            retStr = NSLocalizedStringWithDefaultValue(key, nil, Pointzi_BUNDLE, defaultStr, nil);
        }
        if (StreetHawkCoreRES_BUNDLE != nil && (shStrIsEmpty(retStr) || [retStr isEqualToString:key]))
        {
            retStr = NSLocalizedStringWithDefaultValue(key, nil, StreetHawkCoreRES_BUNDLE, defaultStr, nil);
        }
        if (StreetHawkCoreRES_Titanium_BUNDLE != nil && (shStrIsEmpty(retStr) || [retStr isEqualToString:key]))
        {
            retStr = NSLocalizedStringWithDefaultValue(key, nil, StreetHawkCoreRES_Titanium_BUNDLE, defaultStr, nil);
        }
        if (StreetHawkCoreRES_EmbeddedFull_BUNDLE != nil && (shStrIsEmpty(retStr) || [retStr isEqualToString:key]))
        {
            retStr = NSLocalizedStringWithDefaultValue(key, nil, StreetHawkCoreRES_EmbeddedFull_BUNDLE, defaultStr, nil);
        }        
        if (defaultStr != nil && defaultStr.length > 0 && (shStrIsEmpty(retStr) || [retStr isEqualToString:key]))
        {
            retStr = defaultStr;
        }
    }
    return retStr;
}

#pragma mark - Other Utility

BOOL shCallPhoneNumber(NSString *phone)
{
    phone = [phone stringByReplacingOccurrencesOfString:@"(" withString:@""];
    phone = [phone stringByReplacingOccurrencesOfString:@")" withString:@""];
    phone = [phone stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (phone != nil && phone.length > 0)
    {
        NSURL *phone_url = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", phone]];
        [[UIApplication sharedApplication] openURL:phone_url];
        return YES;
    }
    else
    {
        return NO;
    }
}

#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

NSString *shGetMacAddress()
{
    int                 mgmtInfoBase[6];
    char                *msgBuffer = NULL;
    size_t              length;
    unsigned char       macAddress[6];
    struct if_msghdr    *interfaceMsgStruct;
    struct sockaddr_dl  *socketStruct;
    NSString            *errorFlag = nil;
    
    // Setup the management Information Base (mib)
    mgmtInfoBase[0] = CTL_NET;        // Request network subsystem
    mgmtInfoBase[1] = AF_ROUTE;       // Routing table info
    mgmtInfoBase[2] = 0;
    mgmtInfoBase[3] = AF_LINK;        // Request link layer information
    mgmtInfoBase[4] = NET_RT_IFLIST;  // Request all configured interfaces
    
    // With all configured interfaces requested, get handle index
    if ((mgmtInfoBase[5] = if_nametoindex("en0")) == 0)
        errorFlag = @"if_nametoindex failure";
    else
    {
        // Get the size of the data available (store in len)
        if (sysctl(mgmtInfoBase, 6, NULL, &length, NULL, 0) < 0)
            errorFlag = @"sysctl mgmtInfoBase failure";
        else
        {
            // Alloc memory based on above call
            if ((msgBuffer = (char *)malloc(length)) == NULL)
                errorFlag = @"buffer allocation failure";
            else
            {
                // Get system information, store in buffer
                if (sysctl(mgmtInfoBase, 6, msgBuffer, &length, NULL, 0) < 0)
                    errorFlag = @"sysctl msgBuffer failure";
            }
        }
    }    
    // Befor going any further...
    if (errorFlag != nil)
    {
        SHLog(@"Error: %@", errorFlag);
        return nil;
    }    
    // Map msgbuffer to interface message structure
    interfaceMsgStruct = (struct if_msghdr *) msgBuffer;
    // Map to link-level socket structure
    socketStruct = (struct sockaddr_dl *) (interfaceMsgStruct + 1);
    // Copy link layer address data in socket structure to an array
    memcpy(&macAddress, socketStruct->sdl_data + socketStruct->sdl_nlen, 6);    
    // Read from char array into a string object, into traditional Mac address format
    NSString *macAddressString = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", macAddress[0], macAddress[1], macAddress[2], macAddress[3], macAddress[4], macAddress[5]];
    SHLog(@"Mac Address: %@", macAddressString);    
    // Release the buffer memory
    free(msgBuffer);
    return macAddressString;
}

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>

NSString *shGetCarrierName()
{
    CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [netinfo subscriberCellularProvider];
    NSString *carrierName = [carrier carrierName];
    return !shStrIsEmpty(carrierName) ? carrierName : @"Other";
}

SHAppMode shAppMode()
{
    //https://bitbucket.org/shawk/streethawk/issue/495/get-rid-of-apnsmode_dev-prod-by-detecting
#if TARGET_IPHONE_SIMULATOR
    return SHAppMode_Simulator;
#else
    static SHAppMode mode = SHAppMode_Unknown;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSString *provisionPath = [[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:provisionPath])
        {
            mode = SHAppMode_AppStore; //AppStore not contain embedded.mobileprovision
        }
        else
        {
            NSError *error;
            NSString *binaryString = [NSString stringWithContentsOfFile:provisionPath encoding:NSISOLatin1StringEncoding/*NSCocoaErrorDomain Code=261 if use UTF8*/ error:&error];
            if (binaryString == nil || binaryString.length == 0)
            {
                assert(NO && "Meet error when parse embedded.mobileprovision.");
            }
            else
            {
                NSScanner *scanner = [NSScanner scannerWithString:binaryString];
                Boolean ok = [scanner scanUpToString:@"<plist" intoString:nil];
                if (!ok)
                {
                    assert(NO && "Fail to start plist tag.");
                }
                else
                {
                    NSString *plistString;
                    ok = [scanner scanUpToString:@"</plist>" intoString:&plistString];
                    if (!ok)
                    {
                        assert(NO && "Fail to end plist tag.");
                    }
                    else
                    {
                        plistString = [NSString stringWithFormat:@"%@</plist>", plistString];
                        NSData *plistData = [plistString dataUsingEncoding:NSISOLatin1StringEncoding];
                        NSDictionary *mobileProvision = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:NULL error:&error];
                        if (mobileProvision == nil)
                        {
                            assert(NO && "Meet error when parse embedded.mobileprovision into plist dictionary.");
                        }
                        else
                        {
                            if ([mobileProvision.allKeys containsObject:@"ProvisionsAllDevices"] && [mobileProvision[@"ProvisionsAllDevices"] isKindOfClass:[NSNumber class]] && [(NSNumber *)mobileProvision[@"ProvisionsAllDevices"] boolValue] == YES)
                            {
                                mode = SHAppMode_Enterprise;
                            }
                            else if ([mobileProvision.allKeys containsObject:@"ProvisionedDevices"] && [mobileProvision[@"ProvisionedDevices"] isKindOfClass:[NSArray class]] && ((NSArray *)mobileProvision[@"ProvisionedDevices"]).count > 0)
                            {
                                if ([mobileProvision.allKeys containsObject:@"Entitlements"] && [mobileProvision[@"Entitlements"] isKindOfClass:[NSDictionary class]])
                                {
                                    NSDictionary *entitlements = mobileProvision[@"Entitlements"];
                                    if ([entitlements.allKeys containsObject:@"get-task-allow"] && [entitlements[@"get-task-allow"] isKindOfClass:[NSNumber class]])
                                    {
                                        if ([(NSNumber *)entitlements[@"get-task-allow"] boolValue])
                                        {
                                            mode = SHAppMode_DevProvisioning;
                                        }
                                        else
                                        {
                                            mode = SHAppMode_AdhocProvisioning;
                                        }
                                    }
                                    else
                                    {
                                        assert(NO && "Not find get-task-allow in Entitlements.");
                                    }
                                }
                                else
                                {
                                    assert(NO && "Not find Entitlements in mobileProvision");
                                }
                            }
                            else
                            {
                                assert(NO && "AppStore contains embedded.mobileprovision but without device list.");
                                mode = SHAppMode_AppStore;
                            }
                        }
                    }
                }
            }
        }
        //SHLog(@"App mode: %@.", shAppModeString(mode)); //Cannot do SHLog as it's used in SHApp's init, cause self loop.
    });
    return mode;
#endif
}

NSString *shAppModeString(SHAppMode mode)
{
    NSString *describeStr = nil;
    switch (mode)
    {
        case SHAppMode_AdhocProvisioning:
            describeStr = @"Internal Adhoc";
            break;
        case SHAppMode_AppStore:
            describeStr = @"AppStore";
            break;
        case SHAppMode_DevProvisioning:
            describeStr = @"Internal Development";
            break;
        case SHAppMode_Enterprise:
            describeStr = @"Enterprise";
            break;
        case SHAppMode_Simulator:
            describeStr = @"Simulator";
            break;
        case SHAppMode_Unknown:
            describeStr = @"Other";
            break;
        default:
            describeStr = @"";
            break;
    }
    return describeStr;
}

NSString *shDevelopmentPlatformString()
{
    NSString *platformStr = nil;
    switch (StreetHawk.developmentPlatform)
    {
        case SHDevelopmentPlatform_Native:
            platformStr = @"native";
            break;
        case SHDevelopmentPlatform_Phonegap:
            platformStr = @"phonegap";
            break;
        case SHDevelopmentPlatform_Titanium:
            platformStr = @"titanium";
            break;
        case SHDevelopmentPlatform_Xamarin:
            platformStr = @"xamarin";
            break;
        case SHDevelopmentPlatform_Unity:
            platformStr = @"unity";
            break;
        case SHDevelopmentPlatform_ReactNative:
            platformStr = @"reactnative";
            break;
        default:
            assert(NO && "Meet unknown development platform.");
            platformStr = @"unknown";
            break;
    }
    return platformStr;
}

BOOL streetHawkIsEnabled()
{
    if (![SHAppStatus sharedInstance].streethawkEnabled)
    {
        NSLog(@"This App is disabled, please contact Administrator to enable it.");
        return NO;
    }
    else if (shStrIsEmpty([[SHAppStatus sharedInstance] aliveHostForVersion:SHHostVersion_Unknown]))
    {
        NSLog(@"Route to host server.");
        return NO;
    }
    else
    {
        return YES;
    }
}

BOOL shIsSDKViewController(UIViewController * vc)
{
    return ([vc isKindOfClass:[SHBaseViewController class]]
            || [vc isKindOfClass:[SHBaseTableViewController class]]
            || [vc isKindOfClass:[SHBaseCollectionViewController class]]);
}

NSString* findNativeID(UIView *view)
{
    __block NSString *nativeid = nil;
    [view.subviews enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id nid = [obj valueForKey:@"nativeID"];
        if (nid && [nid isKindOfClass:NSString.class]) {
            nativeid = (NSString*)nid;
        }
        if (nativeid.length <= 0) {
            nativeid = findNativeID(obj);
        }
        if (nativeid.length > 0) {
            *stop = YES;
        }
    }];
    return nativeid;
}

NSString *shAppendUniqueSuffix(UIViewController *vc)
{
    NSString *ret = [vc.class description];
    //check react-native
    if ([vc.view isKindOfClass:NSClassFromString(@"RCTRootView")]) {
        id cview = [vc.view valueForKey:@"contentView"];
        if (cview) {
            UIView *view = (UIView*)cview;
            NSString *nativeid = findNativeID(view);
            if (nativeid.length > 0) {
                ret = nativeid;
            }
        }
    }
    return ret;
}

BOOL shStrIsEmpty(NSString *str)
{
    return (str == nil || str.length == 0);
}

BOOL shArrayIsSame(NSArray *array1, NSArray *array2)
{
    if (array1 == nil && array2 == nil)
    {
        return YES;
    }
    if (array1 == nil && array2 != nil)
    {
        return NO;
    }
    if (array1 != nil && array2 == nil)
    {
        return NO;
    }
    if (array1.count != array2.count)
    {
        return NO;
    }
    for (id item1 in array1)
    {
        BOOL isFound = NO;
        for (id item2 in array2)
        {
            NSString *value1 = [NSString stringWithFormat:@"%@", item1];
            NSString *value2 = [NSString stringWithFormat:@"%@", item2];
            if ([value1 compare:value2] == NSOrderedSame)
            {
                isFound = YES;
                break;
            }
        }
        if (!isFound)
        {
            return NO;
        }
    }
    return YES;
}

BOOL shIsUniversalLinking(NSString *url)
{
    if (shStrIsEmpty(url))
    {
        return NO;
    }
    if ([[UIDevice currentDevice].systemVersion doubleValue] < 9.0)
    {
        return NO; //universal linking only works on iOS 9.0+.
    }
    NSURL *parseUrl = [NSURL URLWithString:url];
    if (!shStrIsEmpty(parseUrl.scheme) && ([parseUrl.scheme compare:@"http" options:NSCaseInsensitiveSearch] == NSOrderedSame || [parseUrl.scheme compare:@"https" options:NSCaseInsensitiveSearch] == NSOrderedSame))
    {
        return YES; //universal linking is normal http(s) scheme. not limited to hwk.io host.
    }
    return NO;
}

NSString *shCaptureAdvertisingIdentifier()
{
#ifndef DISABLE_ADVERTISING_IDENTIFIER
    Class ASIdentifierManagerClass = NSClassFromString(@"ASIdentifierManager");
    if (ASIdentifierManagerClass) //get nil until customer add AdSupport.framework.
    {
        SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
        id sharedManager = ((id (*)(id, SEL))[ASIdentifierManagerClass methodForSelector:sharedManagerSelector])(ASIdentifierManagerClass, sharedManagerSelector);
        SEL isAdvertisingTrackingEnabledSelector = NSSelectorFromString(@"isAdvertisingTrackingEnabled");
        BOOL isEnabled = ((BOOL (*)(id, SEL))[sharedManager methodForSelector:isAdvertisingTrackingEnabledSelector])(sharedManager, isAdvertisingTrackingEnabledSelector);
        if (isEnabled)
        {
            SEL advertisingIdentifierSelector = NSSelectorFromString(@"advertisingIdentifier");
            NSUUID *uuid = ((NSUUID* (*)(id, SEL))[sharedManager methodForSelector:advertisingIdentifierSelector])(sharedManager, advertisingIdentifierSelector);
            return [uuid UUIDString];
        }
    }
#endif
    return nil;
}

#include <sys/sysctl.h>

@implementation UIDevice (SHExt)

#pragma mark - sysctlbyname utils

- (NSString *)getSysInfoByName:(char *)typeSpecifier
{
    size_t size;
    sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);
    
    char *answer = malloc(size);
    sysctlbyname(typeSpecifier, answer, &size, NULL, 0);
    
    NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
    
    free(answer);
    return results;
}

#pragma mark - public functions

- (NSString *)platformString
{
    //model list: http://theiphonewiki.com/wiki/Models.
    //It's up to server to show read friendly name.
    return [self getSysInfoByName:"hw.machine"];
}

@end

@implementation UIColor (SHExt)

+ (BOOL)isRGB:(NSArray *)arrayComponents
{
    return arrayComponents.count >= RGB_COLOUR_CODE_LEN;
}

+ (BOOL)isRGBA:(NSArray *)arrayComponents
{
    return arrayComponents.count == ARGB_COLOUR_CODE_LEN;
}

+ (UIColor *)colorFromHexString:(NSString *)hexString
{
    if (![hexString hasPrefix:@"#"])
    {
        return nil;
    }
    CGFloat red = -1;
    CGFloat green = -1;
    CGFloat blue = -1;
    CGFloat alpha = -1;
    if (hexString.length == RGB_COLOUR_CODE_LEN + 1)
    {
        NSString *red = [hexString substringWithRange:NSMakeRange(1, 1)];
        NSString *green = [hexString substringWithRange:NSMakeRange(2, 1)];
        NSString *blue = [hexString substringWithRange:NSMakeRange(3, 1)];
        hexString = [NSString stringWithFormat:@"#%@%@%@%@%@%@", red, red, green, green, blue, blue];
    }
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    unsigned rgbValue = 0;
    [scanner scanHexInt:&rgbValue];
    red = ((rgbValue & 0xFF0000) >> 16)/255.0;
    green = ((rgbValue & 0xFF00) >> 8)/255.0;
    blue = (rgbValue & 0xFF)/255.0;
    if (hexString.length == RRGGBB_COLOUR_CODE_LEN + 1)
    {
        alpha = 1.0;
    }
    else
    {
        alpha = ((rgbValue & 0xFF000000) >> 24)/255.0;
    }
    if (red >= 0 && red <= 1
        && green >= 0 && green <= 1
        && blue >= 0 && blue <= 1
        && alpha >= 0 && alpha <= 1)
    {
        return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
    }
    else
    {
        return nil;
    }
}

+ (UIColor *)colorFromRGBString:(NSString *)rgbString
{
    CGFloat red = -1;
    CGFloat green = -1;
    CGFloat blue = -1;
    CGFloat alpha = -1;
    if ([rgbString.lowercaseString hasPrefix:@"rgb("]
        && [rgbString.lowercaseString hasSuffix:@")"])
    {
        rgbString = [rgbString.lowercaseString stringByReplacingOccurrencesOfString:@"rgb(" withString:@""];
        rgbString = [rgbString stringByReplacingOccurrencesOfString:@")" withString:@""];
        NSArray *arrayComponents = [rgbString componentsSeparatedByString:@","];
        NSCharacterSet *whiteChar = [NSCharacterSet whitespaceCharacterSet];
        if ([self isRGB:arrayComponents])
        {
            red = [[arrayComponents[0] stringByTrimmingCharactersInSet:whiteChar] floatValue]/255.0;
            green = [[arrayComponents[1] stringByTrimmingCharactersInSet:whiteChar] floatValue]/255.0;
            blue = [[arrayComponents[2] stringByTrimmingCharactersInSet:whiteChar] floatValue]/255.0;
        }
        if ([self isRGBA:arrayComponents])
        {
            alpha = [[arrayComponents[3] stringByTrimmingCharactersInSet:whiteChar] floatValue];
            if (alpha > 1)
            {
                alpha = alpha/255.0;
            }
        }
        else
        {
            alpha = 1.0;
        }
    }
    if (red >= 0 && red <= 1
        && green >= 0 && green <= 1
        && blue >= 0 && blue <= 1
        && alpha >= 0 && alpha <= 1)
    {
        return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
    }
    else
    {
        return nil;
    }
}

+ (UIColor *)colorFromString:(NSString *)str
{
    if (![str isKindOfClass:[NSString class]])
    {
        return nil;
    }
    if (str.length == RGB_COLOUR_CODE_LEN + 1 //#RGB
        || str.length == RRGGBB_COLOUR_CODE_LEN + 1 //#RRGGBB
        || str.length == AARRGGBB_COLOUR_CODE_LEN + 1) //#AARRGGBB
    {
        return [self colorFromHexString:str];
    }
    else //rgb(255,255,255,1)
    {
        return [self colorFromRGBString:str];
    }
    return nil;
}

+ (NSString *)hexStringFromColor:(UIColor *)color
{
    if (color == nil)
    {
        return nil;
    }
    CGFloat red, green, blue, alpha;
    if ([color getRed:&red green:&green blue:&blue alpha:&alpha])
    {
        return [NSString stringWithFormat:@"#%02X%02X%02X%02X",
                (int)([self validateColorRange:alpha] * 255),
                (int)([self validateColorRange:red] * 255),
                (int)([self validateColorRange:green] * 255),
                (int)([self validateColorRange:blue] * 255)];
    }
    else
    {
        return nil;
    }
}

+ (CGFloat)validateColorRange:(CGFloat)colorComponent
{
    //getRed..green..blue..alpha function may return -0.001, maybe due
    //to float accuracy. Check the validate range is 0~1.
    if (colorComponent < 0)
    {
        return 0;
    }
    if (colorComponent > 1)
    {
        return 1;
    }
    return colorComponent;
}

@end

@implementation NSLayoutConstraint (SHExt)

-(NSString *)description
{
    return [NSString stringWithFormat:@"id: %@, constant: %f", self.identifier, self.constant];
}

@end

#import "objc/runtime.h"

@implementation NSObject (SHExt)

static NSString *getPropertyType(objc_property_t property)
{
    const char *attributes = property_getAttributes(property);
    char buffer[1 + strlen(attributes)];
    strcpy(buffer, attributes);
    char *state = buffer, *attribute;
    while ((attribute = strsep(&state, ",")) != NULL)
    {
        if (attribute[0] == 'T')
        {
            NSString *attributeStr = [NSString stringWithUTF8String:attribute];
            if ([attributeStr containsString:@"FourSide"]) //get "T{FourSide=dddd}"
            {
                return @"FourSide";
            }
            else if ([attributeStr isEqualToString:@"Ti"])
            {
                return @"int"; //not exactly the property definition. enum, NSInteger etc all end this.
            }
            else if ([attributeStr isEqualToString:@"Td"] ||
                     [attributeStr isEqualToString:@"Tf"])
            {
                return @"double"; //double, float, CGFloat etc.
            }
            if ([attributeStr isEqualToString:@"Tq"])
            {
                return @"NSTextAlignment";
            }
            if ([attributeStr isEqualToString:@"TB"] ||
                [attributeStr isEqualToString:@"Tc"])
            {
                return @"bool";
            }
            if ([attributeStr isEqualToString:@"T@"])
            {
                return @"id";
            }
            if (attributeStr.length > 4)
            {
                return [attributeStr substringWithRange:NSMakeRange(3, attributeStr.length - 4)];
            }
        }
    }
    return @"";
}

- (NSDictionary<NSString *, NSString *> *)getPropertyNameTypes
{
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    NSMutableDictionary<NSString *, NSString *> *dictProperties = [NSMutableDictionary dictionaryWithCapacity:outCount];
    for(i = 0; i < outCount; i++)
    {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if(propName)
        {
            NSString *propertyName = [NSString stringWithUTF8String:propName];
            NSString *propertyType = getPropertyType(property);
            dictProperties[propertyName] = NONULL(propertyType);
        }
    }
    free(properties);
    return dictProperties;
}

@end

#import <CommonCrypto/CommonDigest.h>

@implementation NSString (SHExt)

- (NSString *)md5
{
    const char *cStr = [self cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    NSInteger length = strlen(cStr);
    CC_MD5(cStr, (int)length, result);
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3], result[4], result[5],
            result[6], result[7], result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]];
}

@end
