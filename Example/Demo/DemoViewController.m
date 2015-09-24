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

#import "DemoViewController.h"
#import "TagViewController.h"
#import "LocationViewController.h"
#import "NotificationViewController.h"
#import "GrowthViewController.h"
#import "StreetHawkDemo-Swift.h" //Swift automatically generated header

@implementation DemoViewController

#pragma mark - life cycle

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self)
    {
        self.arraySampleCasesTitle = [NSMutableArray arrayWithArray:@[@"Tag Sample", @"Location Sample", @"Push Notification Sample", @"Growth", @"Swift"]];
        self.arraySampleCasesVC = [NSMutableArray arrayWithArray:@[@"TagViewController", @"LocationViewController", @"NotificationViewController", @"GrowthViewController", @"_TtC14StreetHawkDemo19SwiftViewController"/*Swift vc class name*/]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Sample Cases";
}

#pragma mark - UITableViewController delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.arraySampleCasesTitle.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"SampleCaseCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    cell.textLabel.text = self.arraySampleCasesTitle[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *className = self.arraySampleCasesVC[indexPath.row];
    Class vcClass = NSClassFromString(className);
    NSAssert(vcClass != nil, @"Fail to create view controller class.");
    UIViewController *vc = [[vcClass alloc] init];
    vc.title = self.arraySampleCasesTitle[indexPath.row];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
