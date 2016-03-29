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

void SHLog(NSString *format, ...)
{
    if (StreetHawk.isDebugMode)
    {
        va_list args;
        va_start(args, format);
        NSString * msg = [[NSString alloc] initWithFormat:format arguments:args];
        NSLog(@"%@", msg);
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
    NSDateFormatter *date_formatter = shGetDateFormatter(nil, nil, nil);
    return [date_formatter stringFromDate:date];
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
        if (out == nil)
        {
            [dateFormatter setDateFormat:@"yyyy-MM-dd"];
            out = [dateFormatter dateFromString:input];
        }
        if (out == nil)
        {
            [dateFormatter setDateFormat:@"dd/MM/yyyy HH:mm:ss"];
            out = [dateFormatter dateFromString:input];
        }
        if (out == nil)
        {
            [dateFormatter setDateFormat:@"dd/MM/yyyy"];
            out = [dateFormatter dateFromString:input];
        }
        if (out == nil)
        {
            [dateFormatter setDateFormat:@"MM/dd/yyyy HH:mm:ss"];
            out = [dateFormatter dateFromString:input];
        }
        if (out == nil)
        {
            [dateFormatter setDateFormat:@"MM/dd/yyyy"];
            out = [dateFormatter dateFromString:input];
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
    NSString *encoded = (__bridge_transfer/*ARC: create CF and memory managed by NS*/ NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)input, NULL, (CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8);
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

//Tells if the error is one that describes a no-connection to the internet and/or host.
BOOL shIsNetworkError(NSError *error)
{
    return (error.domain == NSURLErrorDomain && (error.code == NSURLErrorNotConnectedToInternet || error.code == kCFURLErrorCannotConnectToHost || error.code == kCFURLErrorNetworkConnectionLost));
}

void shPresentErrorAlert(NSError *error, BOOL announceNetworkError)
{
    if (error == nil)  //this checks error inside, so the caller can safely call it directly without checking error.
        return;
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (shIsNetworkError(error))
        {
            if (announceNetworkError)
            {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Network error" message:@"You are not currently connected to the internet. Please try again later." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                [alertView show];
            }
        }
        else
        {
            NSString *errorTitle = error.localizedFailureReason;
            if (errorTitle == nil || errorTitle.length == 0)
            {
                errorTitle = [error.domain isEqualToString:SHErrorDomain] ? @"Error" : error.domain;
            }
            NSString *errorMsg = (error.localizedDescription != nil && error.localizedDescription.length > 0) ? error.localizedDescription : @"No detail error message. Please contact App administrator.";
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:errorTitle message:errorMsg delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alertView show];
        }
    });
}

//Go traverse to UIView's responder till get a UIViewController.
id shTraverseResponderChainForUIViewController(UIView *view)
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
    else
    {
        return nil;
    }
}

UIViewController *shGetViewController(UIView *view)
{
    return (UIViewController *)shTraverseResponderChainForUIViewController(view);
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
    else
    {
        return YES;
    }
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
