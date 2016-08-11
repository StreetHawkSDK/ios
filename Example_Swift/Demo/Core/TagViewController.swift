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

class TagViewController: StreetHawkBaseTableViewController, UITextFieldDelegate
{
    @IBOutlet var cellCuid: UITableViewCell!
    @IBOutlet var cellNumeric: UITableViewCell!
    @IBOutlet var cellString: UITableViewCell!
    @IBOutlet var cellDatetime: UITableViewCell!
    @IBOutlet var cellIncrement: UITableViewCell!
    @IBOutlet var cellDelete: UITableViewCell!
    
    @IBOutlet var textboxCuidValue: UITextField!
    @IBOutlet var textboxKeyNumeric: UITextField!
    @IBOutlet var textboxValueNumeric: UITextField!
    @IBOutlet var textboxKeyString: UITextField!
    @IBOutlet var textboxValueString: UITextField!
    @IBOutlet var textboxKeyDatetime: UITextField!
    @IBOutlet var textboxValueDatetime: UITextField!
    @IBOutlet var textboxKeyIncrement: UITextField!
    @IBOutlet var textboxKeyDelete: UITextField!
    
    var arrayCells : [UITableViewCell] = []
    
    //life cycle
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.arrayCells = [self.cellCuid, self.cellNumeric, self.cellString, self.cellDatetime, self.cellIncrement, self.cellDelete]
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
    
    @IBAction func buttonCuidClicked(sender: AnyObject)
    {
        let value = self.textboxCuidValue.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if !(value != nil && value?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)
        {
            let alertView = UIAlertView(title: "Please input value.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        let isSuccess = SHApp.sharedInstance().tagCuid(value)
        self.textboxCuidValue.resignFirstResponder()
        self.showDoneAlert(isSuccess)
    }    

    @IBAction func buttonNumericClicked(sender: AnyObject)
    {
        let key = self.textboxKeyNumeric.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        let value = self.textboxValueNumeric.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if !(key != nil && key?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)
        {
            let alertView = UIAlertView(title: "Please input key.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        if !(value != nil && value?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)
        {
            let alertView = UIAlertView(title: "Please input value.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        let valueNumeric = Double(value!)
        let isSuccess = SHApp.sharedInstance().tagNumeric(valueNumeric!, forKey: key)
        self.textboxKeyNumeric.resignFirstResponder()
        self.textboxValueNumeric.resignFirstResponder()
        self.showDoneAlert(isSuccess)
    }
    
    @IBAction func buttonStringClicked(sender: AnyObject)
    {
        let key = self.textboxKeyString.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        let value = self.textboxValueString.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if !(key != nil && key?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)
        {
            let alertView = UIAlertView(title: "Please input key.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        if !(value != nil && value?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)
        {
            let alertView = UIAlertView(title: "Please input value.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        let isSuccess = SHApp.sharedInstance().tagString(value, forKey: key)
        self.textboxKeyString.resignFirstResponder()
        self.textboxValueString.resignFirstResponder()
        self.showDoneAlert(isSuccess)
    }
    
    @IBAction func buttonDatetimeClicked(sender: AnyObject)
    {
        let key = self.textboxKeyDatetime.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        let value = self.textboxValueDatetime.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if !(key != nil && key?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)
        {
            let alertView = UIAlertView(title: "Please input key.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        var valueDate : NSDate?
        if !(value != nil && value?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)
        {
            valueDate = NSDate()
        }
        else
        {
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.timeZone = NSTimeZone(name: "UTC")
            dateFormatter.locale = NSLocale(localeIdentifier: "en_US")
            valueDate = dateFormatter.dateFromString(value!)
            if !(valueDate != nil)
            {
                
                let alertView = UIAlertView(title: "Please input date value as format, or leave nil to tag current time.", message: nil, delegate: nil, cancelButtonTitle: "OK")
                alertView.show()
                return
            }
        }
        let isSuccess = SHApp.sharedInstance().tagDatetime(valueDate, forKey: key)
        self.textboxKeyDatetime.resignFirstResponder()
        self.textboxValueDatetime.resignFirstResponder()
        self.showDoneAlert(isSuccess)
    }
    
    @IBAction func buttonIncrementClicked(sender: AnyObject)
    {
        let key = self.textboxKeyIncrement.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if !(key != nil && key?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)
        {
            let alertView = UIAlertView(title: "Please input key.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        let isSuccess = SHApp.sharedInstance().incrementTag(key)
        self.textboxKeyIncrement.resignFirstResponder()
        self.showDoneAlert(isSuccess)
    }
    
    @IBAction func buttonDeleteClicked(sender: AnyObject)
    {
        let key = self.textboxKeyDelete.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if !(key != nil && key?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0)
        {
            let alertView = UIAlertView(title: "Please input key.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        let isSuccess = SHApp.sharedInstance().removeTag(key)
        self.textboxKeyDelete.resignFirstResponder()
        self.showDoneAlert(isSuccess)
    }
    
    //private functions
    
    func showDoneAlert(isSuccess: Bool)
    {
        let info = isSuccess ? "Tag sent to server." : "Cannot send tag to server, please check console log."
        let alertView = UIAlertView(title: info, message: nil, delegate: nil, cancelButtonTitle: "OK")
        alertView.show()
    }
}
