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

class ChannelShareViewController: StreetHawkBaseTableViewController, UITextFieldDelegate
{
    @IBOutlet var cellID: UITableViewCell!
    @IBOutlet var textboxID: UITextField!
    @IBOutlet var cellMedium: UITableViewCell!
    @IBOutlet var textboxMedium: UITextField!
    @IBOutlet var cellContent: UITableViewCell!
    @IBOutlet var textboxContent: UITextField!
    @IBOutlet var cellTerm: UITableViewCell!
    @IBOutlet var textboxTerm: UITextField!
    @IBOutlet var cellUrl: UITableViewCell!
    @IBOutlet var textboxUrl: UITextField!
    @IBOutlet var cellDestinationUrl: UITableViewCell!
    @IBOutlet var textboxDestinationUrl: UITextField!
    @IBOutlet var cellMessage: UITableViewCell!
    @IBOutlet var textboxMessage: UITextField!
    @IBOutlet var cellShare: UITableViewCell!
    
    var arrayCells : [UITableViewCell] = []
        
    //life cycle
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    override init(style: UITableViewStyle)
    {
        super.init(style: .Plain)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?)
    {
        super.init(nibName: "ChannelShareViewController"/*must explict write name, use nil not load correct xib in iOS 7*/, bundle: nibBundleOrNil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.arrayCells = [self.cellID, self.cellMedium, self.cellContent, self.cellTerm, self.cellUrl, self.cellDestinationUrl, self.cellMessage, self.cellShare]
    }
    
    //Table view data source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return self.arrayCells.count
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {
        let cell = self.arrayCells[indexPath.row]
        return cell.bounds.size.height
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        return self.arrayCells[indexPath.row]
    }
    
    //UITextFieldDelegate handler
    
    func textFieldShouldReturn(textField: UITextField) -> Bool
    {
        textField.resignFirstResponder()
        return true
    }
    
    //event handler
    
    @IBAction func buttonShareClicked(sender: AnyObject)
    {
        var deeplinkingUrl : NSURL?
        if (self.textboxUrl.text?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)
        {
            deeplinkingUrl = NSURL(string: self.textboxUrl.text!)
            if !(deeplinkingUrl != nil)
            {
                let alertView = UIAlertView(title: "Deeplinking url format is invalid. Correct it or delete it.", message: nil, delegate: nil, cancelButtonTitle: "OK")
                alertView.show()
                return
            }
        }
        var destinationUrl : NSURL?
        if (self.textboxDestinationUrl.text?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)
        {
            destinationUrl = NSURL(string: self.textboxDestinationUrl.text!)
            if !(destinationUrl != nil)
            {
                let alertView = UIAlertView(title: "Destination url format is invalid. Correct it or delete it.", message: nil, delegate: nil, cancelButtonTitle: "OK")
                alertView.show()
                return
            }
        }
        SHApp.sharedInstance().originateShareWithCampaign(self.textboxID.text, withMedium: self.textboxMedium.text, withContent: self.textboxContent.text, withTerm: self.textboxTerm.text, shareUrl: deeplinkingUrl, withDefaultUrl: destinationUrl, withMessage: self.textboxMessage.text)
    }
}
