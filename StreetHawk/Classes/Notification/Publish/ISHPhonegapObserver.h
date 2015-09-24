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

#import <Foundation/Foundation.h>

/**
 Streethawk calls [ISHPhoneGapObserver shPGDisplayHtmlFileName] function when a friendly names is sent from Streethawk server. Customer App developer gets the name of HTML file and need to implemented in Phonegap App by themselves. This is observer model. 
 
 1. Customer App create class (assume named `SHPhonegapObserver`) inherit from `ISHPhonegapObserver` and implement function `shPGDisplayHtmlFileName`, which get html page name and implement how to load the html page on web view.
 2. Customer App call `[StreetHawk shPGHtmlReceiver:<instance_SHPhonegapObserver>` to register the observer. 
 3. When StreetHawk sends 8004, map friendly name to html page and call registered instance of `ISHPhoneGapObserver`.
 */
@protocol ISHPhonegapObserver <NSObject>

@required

/**
 Phonegap Only! Function returns name of the html file which needs to be displayed in application. 
 @param html_fileName
 */
- (void)shPGDisplayHtmlFileName:(NSString *)html_fileName;

@end
