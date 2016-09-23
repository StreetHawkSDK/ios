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

class NotificationViewController: StreetHawkBaseViewController
{
    @IBOutlet var buttonSetEnabled: UIButton!
    @IBOutlet var textboxAlertSettings: UITextField!
    
    //life cycle
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: "NotificationViewController"/*must explict write name, use nil not load correct xib in iOS 7*/, bundle: nibBundleOrNil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.buttonSetEnabled.setTitle(SHApp.sharedInstance().isNotificationEnabled ? "SDK API enables Notification now" : "SDK API disables Notification now", for: UIControlState())
    }
    
    //event handler
    
    @IBAction func buttonSetEnabledClicked(_ sender: AnyObject)
    {
        SHApp.sharedInstance().isNotificationEnabled = !SHApp.sharedInstance().isNotificationEnabled
        self.buttonSetEnabled.setTitle(SHApp.sharedInstance().isNotificationEnabled ? "SDK API enables Notification now" : "SDK API disables Notification now", for: UIControlState())
    }
    
    @IBAction func buttonCheckNotificationPermissionClicked(_ sender: AnyObject)
    {
        if (SHApp.sharedInstance().systemPreferenceDisableNotification)
        {
            if (!SHApp.sharedInstance().launchSystemPreferenceSettings())
            {
                let alertView = UIAlertView(title: "Info", message: "Pre-iOS 8 show self made instruction.", delegate: nil, cancelButtonTitle: "OK")
                alertView.show()
            }
        }
        else
        {
            let alertView = UIAlertView(title: "Info", message: "No need to show enable notification preference.", delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
        }
    }

    @IBAction func buttonSetAlertClicked(_ sender: AnyObject)
    {
        self.textboxAlertSettings.resignFirstResponder()
        var pauseMinutes = NSInteger(self.textboxAlertSettings.text!)
        if !(pauseMinutes != nil)
        {
            pauseMinutes = 0
        }
        //pauseMinutes <= 0 means not pause
        //pauseMinutes >= StreetHawk_AlertSettings_Forever means pause forever
        SHApp.sharedInstance().shSetAlertSetting(pauseMinutes!, finish: { (result, error) in
            DispatchQueue.main.async(execute: {
                if (error != nil)
                {
                    let alert = UIAlertView(title: "Fail to setup alert settings!", message: error?.localizedDescription, delegate: nil, cancelButtonTitle: "OK")
                    alert.show()
                }
                else
                {
                    let alert = UIAlertView(title: "Save alert settings successfully!", message: nil, delegate: nil, cancelButtonTitle: "OK")
                    alert.show()
                }
            })
        })
    }
    
    @IBAction func buttonGetAlertSettingsClicked(_ sender: AnyObject)
    {
        self.textboxAlertSettings.resignFirstResponder()
        let pauseMinutes = SHApp.sharedInstance().getAlertSettingMinutes()
        let alert = UIAlertView(title: "Pause \(pauseMinutes) minutes.", message: nil, delegate: nil, cancelButtonTitle: "OK")
        alert.show()
    }
}