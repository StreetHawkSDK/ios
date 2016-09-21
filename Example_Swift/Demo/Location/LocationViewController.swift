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
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: "LocationViewController"/*must explict write name, use nil not load correct xib in iOS 7*/, bundle: nibBundleOrNil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateLocationSuccessNotificationHandler(_:)), name: NSNotification.Name.SHLMUpdateLocationSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateFailNotificationHandler(_:)), name: NSNotification.Name.SHLMUpdateFail, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.enterRegionNotificationHandler(_:)), name: NSNotification.Name.SHLMEnterRegion, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.exitRegionNotificationHandler(_:)), name: NSNotification.Name.SHLMExitRegion, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.regionStateChangeNotificationHandler(_:)), name: NSNotification.Name.SHLMRegionStateChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.monitorRegionSuccessNotificationHandler(_:)), name: NSNotification.Name.SHLMMonitorRegionSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.monitorRegionFailNotificationHandler(_:)), name: NSNotification.Name.SHLMMonitorRegionFail, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.rangeiBeaconNotificationHandler(_:)), name: NSNotification.Name.SHLMRangeiBeaconChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.rangeiBeaconFailNotificationHandler(_:)), name: NSNotification.Name.SHLMRangeiBeaconFail, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.authorizationStatusChangeNotificationHandler(_:)), name: NSNotification.Name.SHLMChangeAuthorizationStatus, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.startStandardLocationMonitorNotificationHandler(_:)), name: NSNotification.Name.SHLMStartStandardMonitor, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.stopStandardLocationMonitorNotificationHandler(_:)), name: NSNotification.Name.SHLMStopStandardMonitor, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.startSignificantLocationMonitorNotificationHandler(_:)), name: NSNotification.Name.SHLMStartSignificantMonitor, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.stopSignificantLocationMonitorNotificationHandler(_:)), name: NSNotification.Name.SHLMStopSignificantMonitor, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.startMonitorRegionNotificationHandler(_:)), name: NSNotification.Name.SHLMStartMonitorRegion, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.stopMonitorRegionNotificationHandler(_:)), name: NSNotification.Name.SHLMStopMonitorRegion, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.startRangeiBeaconRegionNotificationHandler(_:)), name: NSNotification.Name.SHLMStartRangeiBeaconRegion, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.stopRangeiBeaconRegionNotificationHandler(_:)), name: NSNotification.Name.SHLMStopRangeiBeaconRegion, object: nil)
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.buttonEnable.setTitle(SHApp.sharedInstance().isLocationServiceEnabled ? "SDK API enables Location now" : "SDK API disables Location now", for:UIControlState())
    }
    
    //event handler

    @IBAction func buttonOpenSettingsClicked(_ sender: AnyObject)
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
    
    @IBAction func buttonEnableClicked(_ sender: AnyObject)
    {
        SHApp.sharedInstance().isLocationServiceEnabled = !SHApp.sharedInstance().isLocationServiceEnabled
        self.buttonEnable.setTitle(SHApp.sharedInstance().isLocationServiceEnabled ? "SDK API enables Location now" : "SDK API disables Location now", for:UIControlState())
    }
    
    //notification handler
    
    func updateLocationSuccessNotificationHandler(_ notification : Notification)
    {
        let newLocation = ((notification as NSNotification).userInfo)![SHLMNotification_kNewLocation] as! CLLocation
        let oldLocation = ((notification as NSNotification).userInfo)![SHLMNotification_kOldLocation] as! CLLocation
        NSLog("Update success from (\(oldLocation.coordinate.latitude), \(oldLocation.coordinate.longitude)) to (\(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)).")
    }
    
    func updateFailNotificationHandler(_ notification : Notification)
    {
        let error = ((notification as NSNotification).userInfo)![SHLMNotification_kError] as! NSError
        NSLog("Update fail: \(error.localizedDescription).")
    }
    
    func enterRegionNotificationHandler(_ notification : Notification)
    {
        let region = ((notification as NSNotification).userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Enter region: \(region.description).");
    }
    
    func exitRegionNotificationHandler(_ notification : Notification)
    {
        let region = ((notification as NSNotification).userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Exit region: \(region.description).")
    }
    
    func regionStateChangeNotificationHandler(_ notification : Notification)
    {
        let region = ((notification as NSNotification).userInfo)![SHLMNotification_kRegion] as! CLRegion
        let regionStateRaw = (((notification as NSNotification).userInfo)![SHLMNotification_kRegionState] as! NSNumber).intValue
        let regionState = CLRegionState(rawValue: regionStateRaw)
        var strState : String
        switch regionState!
        {
        case .unknown:
            strState = "\"unknown\""
        case .inside:
            strState = "\"inside\""
        case .outside:
            strState = "\"outside\""
        }
        NSLog("State change to \(strState) for region: \(region.description).")
    }
    
    func monitorRegionSuccessNotificationHandler(_ notification : Notification)
    {
        let region = ((notification as NSNotification).userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Successfully start monitoring region: \(region.description).")
    }
    
    func monitorRegionFailNotificationHandler(_ notification : Notification)
    {
        let region = ((notification as NSNotification).userInfo)![SHLMNotification_kRegion] as! CLRegion
        let error = ((notification as NSNotification).userInfo)![SHLMNotification_kError] as! NSError
        NSLog("Fail to monitor region \(region.description) due to error: \(error.localizedDescription).")
    }
    
    func rangeiBeaconNotificationHandler(_ notification : Notification)
    {
        let region = ((notification as NSNotification).userInfo)![SHLMNotification_kRegion] as! CLRegion
        let arrayBeacons = ((notification as NSNotification).userInfo)![SHLMNotification_kBeacons] as! NSArray
        NSLog("Found beacons in region \(region.description): \(arrayBeacons).")
    }
    
    func rangeiBeaconFailNotificationHandler(_ notification : Notification)
    {
        let region = ((notification as NSNotification).userInfo)![SHLMNotification_kRegion] as! CLRegion
        let error = ((notification as NSNotification).userInfo)![SHLMNotification_kError] as! NSError
        NSLog("Fail to range iBeacon region \(region.description) due to error: \(error.localizedDescription).")
    }
    
    func authorizationStatusChangeNotificationHandler(_ notification : Notification)
    {
        let statusRaw = (((notification as NSNotification).userInfo)![SHLMNotification_kAuthStatus] as AnyObject).int32Value
        let status = CLAuthorizationStatus(rawValue: statusRaw!)
        var authStatus : String
        switch (status!)
        {
        case .notDetermined:
            authStatus = "Not determinded"
        case .restricted:
            authStatus = "Restricted"
        case .denied:
            authStatus = "Denied"
        case .authorizedAlways: //equal kCLAuthorizationStatusAuthorized (3)
            authStatus = "Always Authorized"
        case .authorizedWhenInUse:
            authStatus = "When in Use"
        }
        NSLog("Authorization status change to: \(authStatus).")
    }
    
    func startStandardLocationMonitorNotificationHandler(_ notification : Notification)
    {
        NSLog("Start monitoring standard geolocation change.")
    }
    
    func stopStandardLocationMonitorNotificationHandler(_ notification : Notification)
    {
        NSLog("Stop monitoring standard geolocation change.")
    }
    
    func startSignificantLocationMonitorNotificationHandler(_ notification : Notification)
    {
        NSLog("Start monitoring significant geolocation change.")
    }
    
    func stopSignificantLocationMonitorNotificationHandler(_ notification : Notification)
    {
        NSLog("Stop monitoring significant geolocation change.")
    }
    
    func startMonitorRegionNotificationHandler(_ notification : Notification)
    {
        let region = ((notification as NSNotification).userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Start to monitor region: \(region.description).")
    }
    
    func stopMonitorRegionNotificationHandler(_ notification : Notification)
    {
        let region = ((notification as NSNotification).userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Stop monitoring region: \(region.description).")
    }
    
    func startRangeiBeaconRegionNotificationHandler(_ notification : Notification)
    {
        let region = ((notification as NSNotification).userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Start to range one iBeacon region: \(region.description).", region.description)
    }
    
    func stopRangeiBeaconRegionNotificationHandler(_ notification : Notification)
    {
        let region = ((notification as NSNotification).userInfo)![SHLMNotification_kRegion] as! CLRegion
        NSLog("Stop ranging one iBeacon region: \(region.description).")
    }
}
