# StreetHawk iOS SDK

[![Version](https://img.shields.io/cocoapods/v/streethawk.svg?style=flat)](http://cocoadocs.org/docsets/streethawk)
[![License](https://img.shields.io/cocoapods/l/streethawk.svg?style=flat)](http://cocoadocs.org/docsets/streethawk)
[![Platform](https://img.shields.io/cocoapods/p/streethawk.svg?style=flat)](http://cocoadocs.org/docsets/streethawk)

## Installation

1. Install [CocoaPods](http://cocoapods.org).
2. Add pod line into your Podfile. There are two ways:

1) add whole StreetHawk iOS SDK.

    pod "streethawk"
    
2) add sub-module as need. Available sub-modules include:

    pod "streethawk/Core"  #core component for register install, sending logs, tag, trace App status. Other sub-module depends on Core, it's automatically included in other sub-module, no need to specifically add. For example, use pod "streethawk/Growth" is enough, it will automatically sync pod "streethawk/Core".
    pod "streethawk/Growth"  #growth sharing.
    pod "streethawk/Push"  #push notification.
    pod "streethawk/Locations"  #trace latitude/longitude location.
    pod "streethawk/Geofence"  #trace user location by geofence, usually work together with push notification.
    pod "streethawk/Beacons"  #trace user location by enter iBeacon region, usually work together with push notification.
    pod "streethawk/Crash"  #submit crash report.
    pod "streethawk/Feed"  # handle feed.

Click [here](https://streethawk.freshdesk.com/support/solutions/articles/5000677092-introduction) for detailed documentation

## StreetHawk web console

Register App on [StreetHawk web console](https://console.streethawk.com). 

More documents on [StreetHawk freshdesk](https://streethawk.freshdesk.com/helpdesk). 

## Author

StreetHawk, support@streethawk.com

## License

The StreetHawk iOS SDK is available under the LGPL license. See the LICENSE file for more info.