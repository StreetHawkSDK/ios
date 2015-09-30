/*
 Erica Sadun, http://ericasadun.com
 iPhone Developer's Cookbook, 6.x Edition
 BSD License, Use at your own risk
 */

// Thanks to Emanuele Vulcano, Kevin Ballard/Eridius, Ryandjohnson, Matt Brown, etc.

#include <sys/sysctl.h>

#import "SHUIDevice-Hardware.h"

@implementation SHUIDevice

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

- (NSString *)platform
{
    return [self getSysInfoByName:"hw.machine"];
}

#pragma mark - public functions

- (NSString *)platformString
{
    NSString *platform = [self platform];
    //model list: http://theiphonewiki.com/wiki/Models

    // The ever mysterious iFPGA
    if ([platform isEqualToString:@"iFPGA"])
        return @"iFPGA";

    // iPhone
    if ([platform isEqualToString:@"iPhone1,1"])
        return @"iPhone 1G";
    if ([platform isEqualToString:@"iPhone1,2"])
        return @"iPhone 3G";
    if ([platform hasPrefix:@"iPhone2,1"])
        return @"iPhone 3GS";
    if ([platform hasPrefix:@"iPhone3"]) //3,1;3,2;3,3
        return @"iPhone 4";
    if ([platform hasPrefix:@"iPhone4,1"])
        return @"iPhone 4S";
    if ([platform hasPrefix:@"iPhone5,1"] || [platform hasPrefix:@"iPhone5,2"])
        return @"iPhone 5";
    if ([platform hasPrefix:@"iPhone5,3"] || [platform hasPrefix:@"iPhone5,4"])
        return @"iPhone 5c";
    if ([platform hasPrefix:@"iPhone6,1"] || [platform hasPrefix:@"iPhone6,2"])
        return @"iPhone 5s";
    if ([platform hasPrefix:@"iPhone7,2"])
        return @"iPhone 6";
    if ([platform hasPrefix:@"iPhone7,1"])
        return @"iPhone 6 Plus";
    if ([platform hasPrefix:@"iPhone8,1"])
        return @"iPhone 6s";
    if ([platform hasPrefix:@"iPhone8,2"])
        return @"iPhone 6s Plus";
    
    // iPod
    if ([platform hasPrefix:@"iPod1,1"])
        return @"iPod touch 1G";
    if ([platform hasPrefix:@"iPod2,1"])
        return @"iPod touch 2G";
    if ([platform hasPrefix:@"iPod3,1"])
        return @"iPod touch 3G";
    if ([platform hasPrefix:@"iPod4,1"])
        return @"iPod touch 4G";
    if ([platform hasPrefix:@"iPod5,1"])
        return @"iPod touch 5G";
    if ([platform hasPrefix:@"iPod7,1"])
        return @"iPod touch 6G";

    // iPad
    if ([platform hasPrefix:@"iPad1,1"])
        return @"iPad 1G";
    if ([platform hasPrefix:@"iPad2,1"] || [platform hasPrefix:@"2,2"] || [platform hasPrefix:@"2,3"] || [platform hasPrefix:@"2,4"])
        return @"iPad 2";
    if ([platform hasPrefix:@"iPad3,1"] || [platform hasPrefix:@"iPad3,2"] || [platform hasPrefix:@"iPad3,3"])
        return @"iPad 3";
    if ([platform hasPrefix:@"iPad3,4"] || [platform hasPrefix:@"iPad3,5"] || [platform hasPrefix:@"iPad3,6"])
        return @"iPad 4";
    if ([platform hasPrefix:@"iPad4,1"] || [platform hasPrefix:@"iPad4,2"] || [platform hasPrefix:@"iPad4,3"])
        return @"iPad Air";
    if ([platform hasPrefix:@"iPad5,3"] || [platform hasPrefix:@"iPad5,4"])
        return @"iPad Air 2";
    if ([platform hasPrefix:@"iPad2,5"] || [platform hasPrefix:@"2,6"] || [platform hasPrefix:@"2,7"])
        return @"iPad mini 1G";
    if ([platform hasPrefix:@"iPad4,4"] || [platform hasPrefix:@"iPad4,5"] || [platform hasPrefix:@"iPad4,6"])
        return @"iPad mini 2G";
    if ([platform hasPrefix:@"iPad4,7"] || [platform hasPrefix:@"iPad4,8"] || [platform hasPrefix:@"iPad4,9"])
        return @"iPad mini 3";
    if ([platform hasPrefix:@"iPad5,1"] || [platform hasPrefix:@"iPad5,2"])
        return @"iPad mini 4";
    
    // Apple TV
    if ([platform hasPrefix:@"AppleTV2,1"])
        return @"Apple TV 2G";
    if ([platform hasPrefix:@"AppleTV3,1"] || [platform hasPrefix:@"AppleTV3,2"])
        return @"Apple TV 3G";
    if ([platform hasPrefix:@"AppleTV5,3"])
        return @"Apple TV 4G";
    
    // Apple Watch
    if ([platform hasPrefix:@"Watch1,1"] || [platform hasPrefix:@"Watch1,2"])
        return @"Apple Watch";
    
    // Simulator
    if ([platform hasSuffix:@"86"] || [platform isEqual:@"x86_64"])
    {
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
            return @"iPhone Simulator";
        else
            return @"iPad Simulator";
    }
    
    // Unknown
    NSAssert(NO, @"Unknown device model: %@.", platform);
    return [NSString stringWithFormat:@"Unknown %@ from StreetHawk", platform];
}

@end