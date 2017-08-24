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
        super.init(style: .plain)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
    {
        //even this view controller does not have xib, and super.init call just use same nil as subclass, it still need to have this init. otherwise iOS 7 crash.
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    //Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return self.arraySampleCases.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 100
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cellIdentifier = "GrowthCaseCell"
        var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
        if !(cell != nil)
        {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)
            cell?.textLabel?.lineBreakMode = .byWordWrapping
            cell?.textLabel?.numberOfLines = 0
            cell?.textLabel?.textAlignment = .left
            cell?.textLabel?.font = UIFont.systemFont(ofSize: 16)
            cell?.textLabel?.textColor = UIColor.darkText
            cell?.detailTextLabel?.lineBreakMode = .byWordWrapping
            cell?.detailTextLabel?.textAlignment = .left
            cell?.detailTextLabel?.font = UIFont.systemFont(ofSize: 13)
            cell?.detailTextLabel?.textColor = UIColor.darkGray
            cell?.detailTextLabel?.numberOfLines = 0
        }
        cell?.textLabel?.text = self.arraySampleCases[(indexPath as NSIndexPath).row]
        cell?.detailTextLabel?.text = self.arrayDescription[(indexPath as NSIndexPath).row]
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
        let className = self.arraySampleCasesVC[(indexPath as NSIndexPath).row]
        let fullClassName = "\(appName).\(className)"
        let anyClass : AnyClass? = NSClassFromString(fullClassName)
        assert(anyClass != nil, "Fail to create view controller class.")
        if (anyClass != nil)
        {
            let vcClass = anyClass as! UIViewController.Type
            let vc = vcClass.init()
            vc.title = self.arraySampleCases[(indexPath as NSIndexPath).row]
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}
