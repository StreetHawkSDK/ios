//
//  SwiftySHApp.swift
//  StreetHawkCore
//
//  Created by Xingyuji on 22/3/18.
//  Copyright © 2018 StreetHawk. All rights reserved.
//

import UIKit

@objc public class SwiftySHApp: NSObject {
    @objc public static var streethawk = SHApp.sharedInstance()
    
    /**
     check push permission and set tag sh_push_denied to current datetime if permission is denied, or delete the tag if permission change from NO to YES
     */
    @objc public func checkPushPermission(){
        if(SwiftySHApp.streethawk.currentInstall?.suid == nil){
            return;
        }
        
        if(UserDefaults.standard.object(forKey: "registerForRemoteNotificationOccurred") == nil){
            return;
        }
        
        let currentPushPermissionDenied = UIApplication.shared.currentUserNotificationSettings?.types.isEmpty ?? false
        let isPushDenied = "is_push_denied"
        let preferences = UserDefaults.standard
        
        if(UserDefaults.standard.object(forKey: isPushDenied) == nil){
            if (currentPushPermissionDenied){
                SwiftySHApp.streethawk.tagDatetime(getCurrentLocalDateTime(), forKey: "sh_push_denied")
                preferences.set(true, forKey: isPushDenied)
            } else {
                preferences.set(false, forKey: isPushDenied)
            }
        } else if (preferences.bool(forKey: isPushDenied) != currentPushPermissionDenied){
            if (currentPushPermissionDenied){
                SwiftySHApp.streethawk.tagDatetime(getCurrentLocalDateTime(), forKey: "sh_push_denied")
            } else {
                SwiftySHApp.streethawk.removeTag("sh_push_denied")
            }
            preferences.set(currentPushPermissionDenied, forKey: isPushDenied)
        }

    }
    
    @objc public func getCurrentLocalDateTime() -> Date{
        let sourceDate:Date = Date.init()
        let sourceTimeZone:TimeZone = TimeZone.init(abbreviation: "GMT")!
        let destinationTimeZone:TimeZone = NSTimeZone.local//use `[NSTimeZone localTimeZone]` if your users will be changing time-zones.
        let sourceGMTOffset = sourceTimeZone.secondsFromGMT(for: sourceDate)
        let destinationGMTOffset = destinationTimeZone.secondsFromGMT(for: sourceDate)
        let interval = TimeInterval(destinationGMTOffset - sourceGMTOffset)
        return Date.init(timeInterval: interval, since: sourceDate)
    }
}
