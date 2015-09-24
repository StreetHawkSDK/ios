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
 Normally one delegate can only set to one object, for example UITableView needs to setup one delegate, usually it's set to a UIViewController. However now some common object for handling UITableView is involved, such as StreetHawkInfinyTableViewDriver. The expected behavior is: StreetHawkInfinyTableViewDriver controls behavior of UITableView, and UIViewController can supplement some of the detail functions, for example create cell. It's like the delegate can have two choices, StreetHawkInfinyTableViewDriver is first choice, UIViewController is second choice. In this case, this SHInterceptor is needed. It has `firstResponder` for the first choice, `secondResponder` for the second choice. Create one instance of SHInterceptor, and set StreetHawkInfinyTableViewDriver as `firstResponder`, set UIViewController as `secondResponder`, make this instance as UITableView's delegate. More widely this can handle more than two choices by setup `firstResponder` or `secondResponder` to be SHInterceptor.
 
 A good quetion maybe: why use StreetHawkInfinyTableViewDriver as firstResponder, why not UIViewControlelr? This is because: StreetHawkInfinyTableViewDriver needs to control the UITableView for sure. If use UIViewController as firstResponder, some key function may get rid of StreetHawkInfinyTableViewDriver so that it cannot function well. If StreetHawkInfinyTableViewDriver needs to consider UIViewController at higher priority, it can call `secondResponder responseTo...` to let UIViewController do first. If some function not implement in StreetHawkInfinyTableViewDriver but implement in UIViewController, it still get called.
 */
@interface SHInterceptor : NSObject

/**
 Setup the first choice Responder.
 */
@property (nonatomic, weak) id firstResponder;

/**
 Setup the second choice Responder.
 */
@property (nonatomic, weak) id secondResponder;

@end
