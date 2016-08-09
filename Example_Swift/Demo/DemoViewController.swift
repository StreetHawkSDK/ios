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
    var arraySampleCasesTitle : [String];
    
    //life cycle
    
    required init?(coder aDecoder: NSCoder)
    {
        self.arraySampleCasesTitle = ["Current Install", "Tag Sample", "Location Sample", "Push Notification Sample", "Growth"];
        super.init(coder: aDecoder);
    }

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
//        let className = self.arraySampleCasesVC[indexPath.row]
//        let vcClass : AnyClass? = NSClassFromString(className)
//        assert(vcClass != nil, "Fail to create view controller class.")
//        var vc = vcClass!()
        
        
    }
    
    
//    
//    - (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
//    {
//    NSString *className = self.arraySampleCasesVC[indexPath.row];
//    Class vcClass = NSClassFromString(className);
//    NSAssert(vcClass != nil, @"Fail to create view controller class.");
//    UIViewController *vc = [[vcClass alloc] init];
//    vc.title = self.arraySampleCasesTitle[indexPath.row];
//    [self.navigationController pushViewController:vc animated:YES];
//    }
}

