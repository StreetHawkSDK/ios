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
        super.init(nibName: "TagViewController"/*must explict write name, use nil not load correct xib in iOS 7*/, bundle: nibBundleOrNil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.arrayCells = [self.cellCuid, self.cellNumeric, self.cellString, self.cellDatetime, self.cellIncrement, self.cellDelete]
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
    
    @IBAction func buttonCuidClicked(_ sender: AnyObject)
    {
        let value = self.textboxCuidValue.text?.trimmingCharacters(in: CharacterSet.whitespaces)
        if !(value != nil && value?.lengthOfBytes(using: String.Encoding.utf8) > 0)
        {
            let alertView = UIAlertView(title: "Please input value.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        let isSuccess = SHApp.sharedInstance().tagCuid(value)
        self.textboxCuidValue.resignFirstResponder()
        self.showDoneAlert(isSuccess)
    }    

    @IBAction func buttonNumericClicked(_ sender: AnyObject)
    {
        let key = self.textboxKeyNumeric.text?.trimmingCharacters(in: CharacterSet.whitespaces)
        let value = self.textboxValueNumeric.text?.trimmingCharacters(in: CharacterSet.whitespaces)
        if !(key != nil && key?.lengthOfBytes(using: String.Encoding.utf8) > 0)
        {
            let alertView = UIAlertView(title: "Please input key.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        if !(value != nil && value?.lengthOfBytes(using: String.Encoding.utf8) > 0)
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
    
    @IBAction func buttonStringClicked(_ sender: AnyObject)
    {
        let key = self.textboxKeyString.text?.trimmingCharacters(in: CharacterSet.whitespaces)
        let value = self.textboxValueString.text?.trimmingCharacters(in: CharacterSet.whitespaces)
        if !(key != nil && key?.lengthOfBytes(using: String.Encoding.utf8) > 0)
        {
            let alertView = UIAlertView(title: "Please input key.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        if !(value != nil && value?.lengthOfBytes(using: String.Encoding.utf8) > 0)
        {
            let alertView = UIAlertView(title: "Please input value.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        let isSuccess = SHApp.sharedInstance().tagString(value as NSObject!, forKey: key)
        self.textboxKeyString.resignFirstResponder()
        self.textboxValueString.resignFirstResponder()
        self.showDoneAlert(isSuccess)
    }
    
    @IBAction func buttonDatetimeClicked(_ sender: AnyObject)
    {
        let key = self.textboxKeyDatetime.text?.trimmingCharacters(in: CharacterSet.whitespaces)
        let value = self.textboxValueDatetime.text?.trimmingCharacters(in: CharacterSet.whitespaces)
        if !(key != nil && key?.lengthOfBytes(using: String.Encoding.utf8) > 0)
        {
            let alertView = UIAlertView(title: "Please input key.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        var valueDate : Date?
        if !(value != nil && value?.lengthOfBytes(using: String.Encoding.utf8) > 0)
        {
            valueDate = Date()
        }
        else
        {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            dateFormatter.locale = Locale(identifier: "en_US")
            valueDate = dateFormatter.date(from: value!)
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
    
    @IBAction func buttonIncrementClicked(_ sender: AnyObject)
    {
        let key = self.textboxKeyIncrement.text?.trimmingCharacters(in: CharacterSet.whitespaces)
        if !(key != nil && key?.lengthOfBytes(using: String.Encoding.utf8) > 0)
        {
            let alertView = UIAlertView(title: "Please input key.", message: nil, delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
            return
        }
        let isSuccess = SHApp.sharedInstance().incrementTag(key)
        self.textboxKeyIncrement.resignFirstResponder()
        self.showDoneAlert(isSuccess)
    }
    
    @IBAction func buttonDeleteClicked(_ sender: AnyObject)
    {
        let key = self.textboxKeyDelete.text?.trimmingCharacters(in: CharacterSet.whitespaces)
        if !(key != nil && key?.lengthOfBytes(using: String.Encoding.utf8) > 0)
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
    
    func showDoneAlert(_ isSuccess: Bool)
    {
        let info = isSuccess ? "Tag sent to server." : "Cannot send tag to server, please check console log."
        let alertView = UIAlertView(title: info, message: nil, delegate: nil, cancelButtonTitle: "OK")
        alertView.show()
    }
}
