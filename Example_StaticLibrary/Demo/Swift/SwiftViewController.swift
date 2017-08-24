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

class SwiftViewController: StreetHawkBaseViewController
{
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    //override init to make sure load nib "SwiftViewController", as class name is "SHSampleDev.SwiftViewController", if not override fail to find right nib and cause black screen.
    override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: Bundle!)
    {
        super.init(nibName: "SwiftViewController", bundle: nil)
    }
  
    @IBAction func buttonFeedbackClicked(_ sender: AnyObject)
    {
        let arrayChoice = ["Product not Available", "Wrong Address", "Description mismatch"]
        SHApp.sharedInstance().shFeedback(arrayChoice, needInputDialog: true, needConfirmDialog: false, withTitle: "What problem do you meet?", withMessage: "Your feedback will be very helpful!", withPushData: nil)
    }
    
    @IBAction func buttonTagClicked(_ sender: AnyObject)
    {
        SHApp.sharedInstance().tagString("a@a.com", forKey: "sh_email")
        SHApp.sharedInstance().removeTag("sh_email")
        SHApp.sharedInstance().tagDatetime(Date(), forKey: "visit_time")
        SHApp.sharedInstance().tagNumeric(100, forKey: "click_count")
        SHApp.sharedInstance().incrementTag("click_count")
        SHApp.sharedInstance().tagString("+0123456789", forKey: "sh_phone")
    }
    
    @IBAction func buttonFeedClicked(_ sender: AnyObject)
    {
        SHApp.sharedInstance().feed(0, withHandler: {arrayFeeds, error in
            if (error != nil)
            {
                print("Fetch feed meet error: \(String(describing: error)).")
            }
            else
            {
                for feedObj in arrayFeeds!
                {
                    print("Feed obj <\((feedObj as AnyObject).feed_id)>: \(feedObj).")
                    SHApp.sharedInstance().notifyFeedResult((feedObj as AnyObject).feed_id, with: SHResult_Accept)
                }
            }
        })
    }
}
