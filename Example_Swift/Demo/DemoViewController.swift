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

class DemoViewController: StreetHawkBaseTableViewController
{
    //Register sample cases.
    let arraySampleCasesTitle = ["Current Install", "Tag Sample", "Location Sample", "Push Notification Sample", "Growth"]
    let arraySampleCasesVC = ["InstallViewController", "TagViewController"]
    
    //life cycle
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.title = "Sample Cases";
    }

    //UITableViewController delegate
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return self.arraySampleCasesTitle.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cellIdentifier = "SampleCaseCell"
        var cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier)
        if (cell == nil)
        {
            cell = UITableViewCell(style: .Default, reuseIdentifier: cellIdentifier)
        }
        cell?.textLabel?.text = self.arraySampleCasesTitle[indexPath.row]
        return cell!
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        let appName = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleName") as! String
        let className = self.arraySampleCasesVC[indexPath.row]
        let fullClassName = "\(appName).\(className)"
        let anyClass : AnyClass? = NSClassFromString(fullClassName)
        assert(anyClass != nil, "Unhandle test sample case")
        if (anyClass != nil)
        {
            let vcClass = anyClass as! UIViewController.Type
            let vc = vcClass.init()
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}
