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
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


class GenericShareViewController: StreetHawkBaseTableViewController, UITextFieldDelegate
{
    @IBOutlet var cellID: UITableViewCell!
    @IBOutlet var textboxID: UITextField!
    @IBOutlet var cellSource: UITableViewCell!
    @IBOutlet var textboxSource: UITextField!
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
    @IBOutlet var cellEmailSubject: UITableViewCell!
    @IBOutlet var textboxEmailSubject: UITextField!
    @IBOutlet var cellEmailBody: UITableViewCell!
    @IBOutlet var textboxEmailBody: UITextField!
    @IBOutlet var cellShare: UITableViewCell!
    
    var arrayCells : [UITableViewCell] = []
    
    //life cycle
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    override init(style: UITableViewStyle)
    {
        super.init(style: .plain)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: "GenericShareViewController"/*must explict write name, use nil not load correct xib in iOS 7*/, bundle: nibBundleOrNil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.arrayCells = [self.cellID, self.cellSource, self.cellMedium, self.cellContent, self.cellTerm, self.cellUrl, self.cellDestinationUrl, self.cellEmailSubject, self.cellEmailBody, self.cellShare]
    }
    
    //Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return self.arrayCells.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        let cell = self.arrayCells[(indexPath as NSIndexPath).row]
        return cell.bounds.size.height
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        return self.arrayCells[(indexPath as NSIndexPath).row]
    }
    
    //UITextFieldDelegate handler
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        textField.resignFirstResponder()
        return true
    }
    
    //event handler
    
    @IBAction func buttonShareClicked(_ sender: AnyObject)
    {
        var deeplinkingUrl : URL?
        if (self.textboxUrl.text?.lengthOfBytes(using: String.Encoding.utf8) > 0)
        {
            deeplinkingUrl = URL(string: self.textboxUrl.text!)
            if !(deeplinkingUrl != nil)
            {
                let alertView = UIAlertView(title: "Deeplinking url format is invalid. Correct it or delete it.", message: nil, delegate: nil, cancelButtonTitle: "OK")
                alertView.show()
                return
            }
        }
        var destinationUrl : URL?
        if (self.textboxDestinationUrl.text?.lengthOfBytes(using: String.Encoding.utf8) > 0)
        {
            destinationUrl = URL(string: self.textboxDestinationUrl.text!)
            if !(destinationUrl != nil)
            {
                let alertView = UIAlertView(title: "Destination url format is invalid. Correct it or delete it.", message: nil, delegate: nil, cancelButtonTitle: "OK")
                alertView.show()
                return
            }
        }
        SHApp.sharedInstance().originateShare(withCampaign: self.textboxID.text, withSource: self.textboxSource.text, withMedium: self.textboxMedium.text, withContent: self.textboxContent.text, withTerm: self.textboxTerm.text, share: deeplinkingUrl, withDefaultUrl: destinationUrl, streetHawkGrowth_object: { (result, error) in
            DispatchQueue.main.async(execute: {
                if !(error != nil)
                {
                    let shareUrl = result as! String
                    let alert = UIAlertView(title: "share_guid_url", message: shareUrl, delegate: nil, cancelButtonTitle: "OK")
                    alert.show()
                }
                else
                {
                    let alert = UIAlertView(title: "Error", message: error?.localizedDescription, delegate: nil, cancelButtonTitle: "OK")
                    alert.show()
                }
            })
        })
    }
}
