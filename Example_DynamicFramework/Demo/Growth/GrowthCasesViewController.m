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

#import "GrowthCasesViewController.h"
#import "GenericShareViewController.h"
#import "ChannelShareViewController.h"

@interface GrowthCasesViewController ()

//Register sample cases.
@property (nonatomic, strong) NSArray *arraySampleCases;
@property (nonatomic, strong) NSArray *arrayDescription;
@property (nonatomic, strong) NSArray *arraySampleCasesVC;

@end

@implementation GrowthCasesViewController

#pragma mark - life cycle

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self)
    {
        self.arraySampleCases = @[@"Generic share", @"Predefined channel share"];
        self.arrayDescription = @[@"\"utm_source\" is free string, get callback for share_guid_url, and customer developer is responsible for take action to share.", @"StreetHawk internally predefine normal channel, use them to share."];
        self.arraySampleCasesVC = @[@"GenericShareViewController", @"ChannelShareViewController"];
    }
    return self;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.arraySampleCases.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 100;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"GrowthCaseCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.textLabel.textColor = [UIColor darkTextColor];
        cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
        cell.detailTextLabel.textAlignment = NSTextAlignmentLeft;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
        cell.detailTextLabel.textColor = [UIColor darkGrayColor];
        cell.detailTextLabel.numberOfLines = 0;
    }
    cell.textLabel.text = self.arraySampleCases[indexPath.row];
    cell.detailTextLabel.text = self.arrayDescription[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *className = self.arraySampleCasesVC[indexPath.row];
    Class vcClass = NSClassFromString(className);
    NSAssert(vcClass != nil, @"Fail to create view controller class.");
    UIViewController *vc = [[vcClass alloc] init];
    vc.title = self.arraySampleCases[indexPath.row];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
