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

#pragma mark - public functions

- (NSString *)platformString
{
    //model list: http://theiphonewiki.com/wiki/Models.
    //It's up to server to show read friendly name.
    return [self getSysInfoByName:"hw.machine"];
}

@end