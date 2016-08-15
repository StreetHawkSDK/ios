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

class GrowthViewController: StreetHawkBaseTableViewController
{
    let arraySampleCases = ["Generic share", "Predefined channel share"]
    let arrayDescription = ["\"utm_source\" is free string, get callback for share_guid_url, and customer developer is responsible for take action to share.", "StreetHawk internally predefine normal channel, use them to share."]
    let arraySampleCasesVC = ["GenericShareViewController", "ChannelShareViewController"]
    
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
        //even this view controller does not have xib, and super.init call just use same nil as subclass, it still need to have this init. otherwise iOS 7 crash.
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    //Table view data source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return self.arraySampleCases.count
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {
        return 100
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cellIdentifier = "GrowthCaseCell"
        var cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier)
        if !(cell != nil)
        {
            cell = UITableViewCell(style: .Subtitle, reuseIdentifier: cellIdentifier)
            cell?.textLabel?.lineBreakMode = .ByWordWrapping
            cell?.textLabel?.numberOfLines = 0
            cell?.textLabel?.textAlignment = .Left
            cell?.textLabel?.font = UIFont.systemFontOfSize(16)
            cell?.textLabel?.textColor = UIColor.darkTextColor()
            cell?.detailTextLabel?.lineBreakMode = .ByWordWrapping
            cell?.detailTextLabel?.textAlignment = .Left
            cell?.detailTextLabel?.font = UIFont.systemFontOfSize(13)
            cell?.detailTextLabel?.textColor = UIColor.darkGrayColor()
            cell?.detailTextLabel?.numberOfLines = 0
        }
        cell?.textLabel?.text = self.arraySampleCases[indexPath.row]
        cell?.detailTextLabel?.text = self.arrayDescription[indexPath.row]
        return cell!
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        let appName = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleName") as! String
        let className = self.arraySampleCasesVC[indexPath.row]
        let fullClassName = "\(appName).\(className)"
        let anyClass : AnyClass? = NSClassFromString(fullClassName)
        assert(anyClass != nil, "Fail to create view controller class.")
        if (anyClass != nil)
        {
            let vcClass = anyClass as! UIViewController.Type
            let vc = vcClass.init()
            vc.title = self.arraySampleCases[indexPath.row]
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}
