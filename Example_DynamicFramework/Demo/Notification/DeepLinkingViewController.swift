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

class DeepLinkingViewController: StreetHawkBaseViewController
{
    @IBOutlet var labelParam: UILabel!
    
    var dictParam : NSDictionary? = [:]
    
    //life cycle
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: "DeepLinkingViewController"/*must explict write name, use nil not load correct xib in iOS 7*/, bundle: nibBundleOrNil)
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.title = "Show Deeplinking Param"
    }

    //deeplinking handler
    
    override func receiveData(_ dictParam: [AnyHashable: Any]!)
    {
        self.dictParam = dictParam as NSDictionary?
        self.displayToUI()
    }
    
    override func displayToUI()
    {
        if (self.isViewLoaded)
        {
            if (self.dictParam != nil)
            {
                self.labelParam.text = "\(self.dictParam)"
            }
        }
    }
}
