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

class InstallViewController: StreetHawkBaseTableViewController
{
    var arrayValues : [NSArray] = [] //cells for value displaying on the table
    var arrayDescriptions : [NSArray] = [] //cells for description displaying on the table
    
    //life cycle
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    override init(style: UITableViewStyle)
    {
        super.init(style: .Grouped)
        
        let arrayGeneralDescription : NSMutableArray = []
        arrayGeneralDescription.addObject("The unique installation ID for the device. Generated by StreetHawk SDK automatically. If delete and re-install, install id changes.")
        arrayGeneralDescription.addObject("Customer developer register app_key in streethawk server. It's same as `StreetHawk.appKey`.")
        arrayGeneralDescription.addObject("Your unique identifier for this Client. Tagged by API `SHApp.sharedInstance().tagCuid(\"<unique_value>\")`")
        arrayGeneralDescription.addObject("The version of the client application.")
        arrayGeneralDescription.addObject("The version of StreetHawkCore framework SDK.")
        arrayGeneralDescription.addObject("Operate system and version.")
        arrayGeneralDescription.addObject("If this App is AppStore or Enterprise provisioning profile, it's true; otherwise it's false.")
        arrayGeneralDescription.addObject("Development platform, hardcoded in StreetHawk SDK.")
        arrayGeneralDescription.addObject("The UTC time this install was created in year-month-day hour:minute:second format.")
        arrayGeneralDescription.addObject("The UTC time this install was modified in year-month-day hour:minute:second format.")
        arrayGeneralDescription.addObject("If current App deleted and re-install again, install id changes. This property is the Install this Install has been replaced by.")
        arrayGeneralDescription.addObject("An estimated timestamp (UTC) when the Install has been uninstalled, nil otherwise.")
        let arrayGeneralValue = NSMutableArray(capacity: arrayGeneralDescription.count)
        let arrayCapabilityDescription : NSMutableArray = []
        arrayCapabilityDescription.addObject("Customer developer uses location related SDK functions, technically when his pod include `streethawk/Locations` or `streethawk/Geofence` or `streethawk/Beacons` and set `StreetHawk.isLocationServiceEnabled = YES` this is true; otherwise this is false.")
        arrayCapabilityDescription.addObject("Customer developer uses notification related SDK functions, technically when his pod include `streethawk/Push` and set `StreetHawk.isNotificationEnabled = YES` this is true; otherwise this is false.")
        arrayCapabilityDescription.addObject("Customer developer uses iBeacon related SDK functions, technically when his pod include `streethawk/Beacons` this is true; otherwise this is false.")
        arrayCapabilityDescription.addObject("When `featureiBeacons == YES` and end user's device supports iBeacon (iOS version >= 7.0, location service enabled and bluetooth enabled), it's true.")
        let arrayCapabilityValue = NSMutableArray(capacity: arrayCapabilityDescription.count)
        let arrayPushDescription : NSMutableArray = []
        arrayPushDescription.addObject("If iOS App use development provisioning, it's `dev`; if use simulator, it's `simulator`; if use ad-hoc or AppStore or Enterprise distribution provisioning, it's `prod`.")
        arrayPushDescription.addObject("The access data for remote notification.")
        arrayPushDescription.addObject("It set to time stamp once get error from Apple's push notification server. If empty means Apple not reply error.")
        arrayPushDescription.addObject("Timestamp when end user refuse to receive notification. If notification is approved it's empty.")
        arrayPushDescription.addObject("Whether use \"smart push\".")
        arrayPushDescription.addObject("Timestamp for feed. If not nil and local fetch time is older than this, SDK will fetch feed.")
        let arrayPushValue = NSMutableArray(capacity: arrayPushDescription.count)
        let arrayDeviceDescription : NSMutableArray = []
        arrayDeviceDescription.addObject("Device's location. StreetHawk server try to guess location by ip even when device disable location, thus it may not be nil even device disable location.")
        arrayDeviceDescription.addObject("UTC offset in minutes.")
        arrayDeviceDescription.addObject("Raw text for the device model, e.g. `iPhone 8.1`.")
        arrayDeviceDescription.addObject("Ip address of current device. It's known by server, not sent from client.")
        arrayDeviceDescription.addObject("Mac address sent to server by client. It's not available since iOS 7 device, which always returns 02:00:00:00:00:00.")
        arrayDeviceDescription.addObject("[UIDevice device].identifierForVendor, a way to identifier vendor.")
        arrayDeviceDescription.addObject("If customer developer pass in advertise identifier, submit to StreetHawk server. It requires App to approve IDFA when submitting to AppStore, thus StreetHawk SDK cannot positively read this property. Set up by `StreetHawk.advertisingIdentifier = ...`.")
        arrayDeviceDescription.addObject("Carrier of current device.")
        arrayDeviceDescription.addObject("Screen resolution of current device.")
        let arrayDeviceValue = NSMutableArray(capacity: arrayDeviceDescription.count)
        self.arrayValues = [arrayGeneralValue, arrayCapabilityValue, arrayPushValue, arrayDeviceValue];
        self.arrayDescriptions = [arrayGeneralDescription, arrayCapabilityDescription, arrayPushDescription, arrayDeviceDescription];
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.installNotificationHandler(_:)), name: SHInstallRegistrationSuccessNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.installNotificationHandler(_:)), name: SHInstallUpdateSuccessNotification, object: nil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.displayInstallData()
        //add update install button
        let buttonUpdate = UIButton(type: .System)
        buttonUpdate.addTarget(self, action: #selector(self.buttonUpdateClicked(_:)), forControlEvents: .TouchUpInside)
        buttonUpdate.setTitle("Update Install", forState: .Normal)
        buttonUpdate.frame = CGRectMake((self.tableView.bounds.size.width-200)/2, 0, 200, 50)
        let viewHeader = UIView(frame: CGRectMake(0, 0, self.tableView.bounds.size.width, 50))
        viewHeader.backgroundColor = UIColor.lightGrayColor()
        viewHeader.addSubview(buttonUpdate)
        self.tableView.tableHeaderView = viewHeader
    }
    
    deinit
    {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        self.tableView.dataSource = nil;
        self.tableView.delegate = nil;
    }
    
    //event handler
    
    func buttonUpdateClicked(sender : AnyObject)
    {
        SHApp.sharedInstance().registerOrUpdateInstallWithHandler(nil)
    }
    
    //private functions
    
    func displayInstallData() //format install data to fill table cell data and refresh table to display.
    {
        dispatch_async(dispatch_get_main_queue())
        {
            if (SHApp.sharedInstance().currentInstall == nil)
            {
                let alertView = UIAlertView(title: "Not install successfully.", message: nil, delegate: nil, cancelButtonTitle: "OK")
                alertView.show()
                return;
            }
            let arrayGeneralValue = self.arrayValues[0] as! NSMutableArray
            arrayGeneralValue[0] = "install id: \(SHApp.sharedInstance().currentInstall.suid)"
            arrayGeneralValue[1] = "app key: \(SHApp.sharedInstance().currentInstall.appKey)"
            arrayGeneralValue[2] = "sh_cuid: \(SHApp.sharedInstance().currentInstall.sh_cuid)"
            arrayGeneralValue[3] = "client App version: \(SHApp.sharedInstance().currentInstall.clientVersion)"
            arrayGeneralValue[4] = "StreetHawk SDK version: \(SHApp.sharedInstance().currentInstall.shVersion)"
            arrayGeneralValue[5] = "OS: \(SHApp.sharedInstance().currentInstall.operatingSystem) \(SHApp.sharedInstance().currentInstall.osVersion)"
            arrayGeneralValue[6] = "AppStore or Enterprise release: \(SHApp.sharedInstance().currentInstall.live ? "true" : "false")"
            arrayGeneralValue[7] = "development platform: \(SHApp.sharedInstance().currentInstall.developmentPlatform)"
            arrayGeneralValue[8] = "created date: \(SHApp.sharedInstance().currentInstall.created)"
            arrayGeneralValue[9] = "modifid date: \(SHApp.sharedInstance().currentInstall.modified)"
            arrayGeneralValue[10] = "replaced by: \(SHApp.sharedInstance().currentInstall.replaced)"
            arrayGeneralValue[11] = "uninstalled date: \(SHApp.sharedInstance().currentInstall.uninstalled)"
            let arrayCapabilityValue = self.arrayValues[1] as! NSMutableArray
            arrayCapabilityValue[0] = "use location feature: \(SHApp.sharedInstance().currentInstall.featureLocation ? "true" : "false")"
            arrayCapabilityValue[1] = "use push feature: \(SHApp.sharedInstance().currentInstall.featurePush ? "true" : "false")"
            arrayCapabilityValue[2] = "use iBeacon feature: \(SHApp.sharedInstance().currentInstall.featureiBeacons ? "true" : "false")"
            arrayCapabilityValue[3] = "support iBeacon: \(SHApp.sharedInstance().currentInstall.supportiBeacons ? "true" : "false")"
            let arrayPushValue = self.arrayValues[2] as! NSMutableArray
            arrayPushValue[0] = "push service mode: \(SHApp.sharedInstance().currentInstall.mode)"
            arrayPushValue[1] = "token: \(SHApp.sharedInstance().currentInstall.pushNotificationToken)"
            arrayPushValue[2] = "negative feedback: \(SHApp.sharedInstance().currentInstall.negativeFeedback)"
            arrayPushValue[3] = "revoked: \(SHApp.sharedInstance().currentInstall.revoked)"
            arrayPushValue[4] = "use smart push: \(SHApp.sharedInstance().currentInstall.smart ? "true" : "false")"
            arrayPushValue[5] = "feed timestamp: \(SHApp.sharedInstance().currentInstall.feed)"
            let arrayDeviceValue = self.arrayValues[3] as! NSMutableArray
            if (SHApp.sharedInstance().currentInstall.latitude != nil && SHApp.sharedInstance().currentInstall.longitude != nil)
            {
                arrayDeviceValue[0] = "location: (\(SHApp.sharedInstance().currentInstall.latitude.doubleValue), \(SHApp.sharedInstance().currentInstall.longitude.doubleValue))"
            }
            else
            {
                arrayDeviceValue[0] = "location not available.";
            }
            arrayDeviceValue[1] = "timezone offset in mins: \(SHApp.sharedInstance().currentInstall.utcOffset)"
            arrayDeviceValue[2] = "model: \(SHApp.sharedInstance().currentInstall.model)"
            arrayDeviceValue[3] = "ip address: \(SHApp.sharedInstance().currentInstall.ipAddress)"
            arrayDeviceValue[4] = "mac address: \(SHApp.sharedInstance().currentInstall.macAddress)"
            arrayDeviceValue[5] = "vendor identifier: \(SHApp.sharedInstance().currentInstall.identifierForVendor)"
            arrayDeviceValue[6] = "advertising identifier: \(SHApp.sharedInstance().currentInstall.advertisingIdentifier)"
            arrayDeviceValue[7] = "carrier: \(SHApp.sharedInstance().currentInstall.carrierName)"
            arrayDeviceValue[8] = "resolution: \(SHApp.sharedInstance().currentInstall.resolution)"
                
            self.tableView.reloadData()
        }
    }
    
    func installNotificationHandler(notification: NSNotification)
    {
        self.displayInstallData()
    }
    
    //UITableViewDelegate handler
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return self.arrayValues.count
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        if (section == 0)
        {
            return "General"
        }
        else if (section == 1)
        {
            return "Capability"
        }
        else if (section == 2)
        {
            return "Push Notification"
        }
        else if (section == 3)
        {
            return "Device"
        }
        return nil
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let array = self.arrayValues[section] as! NSMutableArray
        return array.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cellIdentifier = "installCell"
        var cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier)
        if (cell == nil)
        {
            cell = UITableViewCell(style: .Subtitle, reuseIdentifier: cellIdentifier)
            cell?.textLabel?.font = UIFont.systemFontOfSize(13)
            cell?.textLabel?.lineBreakMode = .ByWordWrapping
            cell?.textLabel?.numberOfLines = 0
            cell?.detailTextLabel?.font = UIFont.systemFontOfSize(10)
            cell?.detailTextLabel?.lineBreakMode = .ByWordWrapping
            cell?.detailTextLabel?.numberOfLines = 0
        }
        let arrayValues = self.arrayValues[indexPath.section] as! NSMutableArray
        cell?.textLabel?.text = arrayValues[indexPath.row] as? String
        let arrayDescriptions = self.arrayDescriptions[indexPath.section] as! NSMutableArray
        cell?.detailTextLabel?.text = arrayDescriptions[indexPath.row] as? String
        return cell!
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {
        let arrayValue = self.arrayValues[indexPath.section] as! NSMutableArray
        let content = arrayValue[indexPath.row] as! String
        let arrayDescription = self.arrayDescriptions[indexPath.section] as! NSMutableArray
        let description = arrayDescription[indexPath.row] as! String
        let constrainSize = CGSizeMake(self.tableView.bounds.size.width - 10, 100)
        let rectValue = NSString(string: content).boundingRectWithSize(constrainSize, options: [.UsesLineFragmentOrigin, .UsesFontLeading], attributes: [NSFontAttributeName : UIFont.systemFontOfSize(13)], context: nil)
        let rectDescription = NSString(string: description).boundingRectWithSize(constrainSize, options: [.UsesLineFragmentOrigin, .UsesFontLeading], attributes: [NSFontAttributeName: UIFont.systemFontOfSize(10)], context: nil)
        return rectValue.size.height + rectDescription.size.height + 10
    }
}