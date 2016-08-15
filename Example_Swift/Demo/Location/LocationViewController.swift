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

import UIKit
import CoreLocation

class LocationViewController: StreetHawkBaseViewController
{
    @IBOutlet var buttonEnable: UIButton!
    
    //life cycle
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?)
    {
        super.init(nibName: "LocationViewController"/*must explict write name, use nil not load correct xib in iOS 7*/, bundle: nibBundleOrNil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.updateLocationSuccessNotificationHandler(_:)), name: SHLMUpdateLocationSuccessNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.updateFailNotificationHandler(_:)), name: SHLMUpdateFailNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.enterRegionNotificationHandler(_:)), name: SHLMEnterRegionNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.exitRegionNotificationHandler(_:)), name: SHLMExitRegionNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.regionStateChangeNotificationHandler(_:)), name: SHLMRegionStateChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.monitorRegionSuccessNotificationHandler(_:)), name: SHLMMonitorRegionSuccessNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.monitorRegionFailNotificationHandler(_:)), name: SHLMMonitorRegionFailNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.rangeiBeaconNotificationHandler(_:)), name: SHLMRangeiBeaconChangedNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.rangeiBeaconFailNotificationHandler(_:)), name: SHLMRangeiBeaconFailNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.authorizationStatusChangeNotificationHandler(_:)), name: SHLMChangeAuthorizationStatusNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.startStandardLocationMonitorNotificationHandler(_:)), name: SHLMStartStandardMonitorNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.stopStandardLocationMonitorNotificationHandler(_:)), name: SHLMStopStandardMonitorNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.startSignificantLocationMonitorNotificationHandler(_:)), name: SHLMStartSignificantMonitorNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.stopSignificantLocationMonitorNotificationHandler(_:)), name: SHLMStopSignificantMonitorNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.startMonitorRegionNotificationHandler(_:)), name: SHLMStartMonitorRegionNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.stopMonitorRegionNotificationHandler(_:)), name: SHLMStopMonitorRegionNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.startRangeiBeaconRegionNotificationHandler(_:)), name: SHLMStartRangeiBeaconRegionNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.stopRangeiBeaconRegionNotificationHandler(_:)), name: SHLMStopRangeiBeaconRegionNotification, object: nil)
    }
    
    deinit
    {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.buttonEnable.setTitle(SHApp.sharedInstance().isLocationServiceEnabled ? "SDK API enables Location now" : "SDK API disables Location now", forState:.Normal)
    }
    
    //event handler

    @IBAction func buttonOpenSettingsClicked(sender: AnyObject)
    {
        if (SHApp.sharedInstance().systemPreferenceDisableLocation)
        {
            if (!SHApp.sharedInstance().launchSystemPreferenceSettings())
            {
                let alertView = UIAlertView(title: "Info", message: "Pre-iOS 8 show self made instruction.", delegate: nil, cancelButtonTitle: "OK")
                alertView.show()
            }
        }
        else
        {
            let alertView = UIAlertView(title: "Info", message: "System preference enables location now. No need to show location preference.", delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
        }
    }
    
    @IBAction func buttonEnableClicked(sender: AnyObject)
    {
        SHApp.sharedInstance().isLocationServiceEnabled = !SHApp.sharedInstance().isLocationServiceEnabled
        self.buttonEnable.setTitle(SHApp.sharedInstance().isLocationServiceEnabled ? "SDK API enables Location now" : "SDK API disables Location now", forState:.Normal)
    }
    
    //notification handler
    
    func updateLocationSuccessNotificationHandler(notification : NSNotification)
    {
        let newLocation = (notification.userInfo)![SHLMNotification_kNewLocation] as! CLLocation
        let oldLocation = (notification.userInfo)![SHLMNotification_kOldLocation] as! CLLocation
        NSLog("Update success from (\(oldLocation.coordinate.latitude), \(oldLocation.coordinate.longitude)) to (\(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)).")
    }
    
    func updateFailNotificationHandler(notification : NSNotification)
    {
        let error = (notification.userInfo)![SHLMNotification_kError] as! NSError
        NSLog("Update fail: \(error.localizedDescription).")
    }
    
    func enterRegionNotificationHandler(notification : NSNotification)
    {
        let region = (notification.userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Enter region: \(region.description).");
    }
    
    func exitRegionNotificationHandler(notification : NSNotification)
    {
        let region = (notification.userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Exit region: \(region.description).")
    }
    
    func regionStateChangeNotificationHandler(notification : NSNotification)
    {
        let region = (notification.userInfo)![SHLMNotification_kRegion] as! CLRegion
        let regionStateRaw = (notification.userInfo)![SHLMNotification_kRegionState]?.integerValue
        let regionState = CLRegionState(rawValue: regionStateRaw!)
        var strState : String
        switch regionState!
        {
        case .Unknown:
            strState = "\"unknown\""
        case .Inside:
            strState = "\"inside\""
        case .Outside:
            strState = "\"outside\""
        }
        NSLog("State change to \(strState) for region: \(region.description).")
    }
    
    func monitorRegionSuccessNotificationHandler(notification : NSNotification)
    {
        let region = (notification.userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Successfully start monitoring region: \(region.description).")
    }
    
    func monitorRegionFailNotificationHandler(notification : NSNotification)
    {
        let region = (notification.userInfo)![SHLMNotification_kRegion] as! CLRegion
        let error = (notification.userInfo)![SHLMNotification_kError] as! NSError
        NSLog("Fail to monitor region \(region.description) due to error: \(error.localizedDescription).")
    }
    
    func rangeiBeaconNotificationHandler(notification : NSNotification)
    {
        let region = (notification.userInfo)![SHLMNotification_kRegion] as! CLRegion
        let arrayBeacons = (notification.userInfo)![SHLMNotification_kBeacons] as! NSArray
        NSLog("Found beacons in region \(region.description): \(arrayBeacons).")
    }
    
    func rangeiBeaconFailNotificationHandler(notification : NSNotification)
    {
        let region = (notification.userInfo)![SHLMNotification_kRegion] as! CLRegion
        let error = (notification.userInfo)![SHLMNotification_kError] as! NSError
        NSLog("Fail to range iBeacon region \(region.description) due to error: \(error.localizedDescription).")
    }
    
    func authorizationStatusChangeNotificationHandler(notification : NSNotification)
    {
        let statusRaw = (notification.userInfo)![SHLMNotification_kAuthStatus]?.intValue
        let status = CLAuthorizationStatus(rawValue: statusRaw!)
        var authStatus : String
        switch (status!)
        {
        case .NotDetermined:
            authStatus = "Not determinded"
        case .Restricted:
            authStatus = "Restricted"
        case .Denied:
            authStatus = "Denied"
        case .AuthorizedAlways: //equal kCLAuthorizationStatusAuthorized (3)
            authStatus = "Always Authorized"
        case .AuthorizedWhenInUse:
            authStatus = "When in Use"
        }
        NSLog("Authorization status change to: \(authStatus).")
    }
    
    func startStandardLocationMonitorNotificationHandler(notification : NSNotification)
    {
        NSLog("Start monitoring standard geolocation change.")
    }
    
    func stopStandardLocationMonitorNotificationHandler(notification : NSNotification)
    {
        NSLog("Stop monitoring standard geolocation change.")
    }
    
    func startSignificantLocationMonitorNotificationHandler(notification : NSNotification)
    {
        NSLog("Start monitoring significant geolocation change.")
    }
    
    func stopSignificantLocationMonitorNotificationHandler(notification : NSNotification)
    {
        NSLog("Stop monitoring significant geolocation change.")
    }
    
    func startMonitorRegionNotificationHandler(notification : NSNotification)
    {
        let region = (notification.userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Start to monitor region: \(region.description).")
    }
    
    func stopMonitorRegionNotificationHandler(notification : NSNotification)
    {
        let region = (notification.userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Stop monitoring region: \(region.description).")
    }
    
    func startRangeiBeaconRegionNotificationHandler(notification : NSNotification)
    {
        let region = (notification.userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Start to range one iBeacon region: \(region.description).", region.description)
    }
    
    func stopRangeiBeaconRegionNotificationHandler(notification : NSNotification)
    {
        let region = (notification.userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Stop ranging one iBeacon region: \(region.description).")
    }
}
