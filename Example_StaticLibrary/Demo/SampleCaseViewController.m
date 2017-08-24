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

#import "SampleCaseViewController.h"
#import "FeedbackCasesViewController.h"
#import "LogTagCasesViewController.h"
#import "FeedCasesController.h"
#import "LocationViewController.h"
#import "InstallCasesViewController.h"
#import "InstallServiceMonitor.h"
#import "PushNotificationCasesViewController.h"
#import "GrowthCasesViewController.h"
#import "StreetHawkDemo-Swift.h"

@implementation SampleCaseViewController

#pragma mark - life cycle

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self)
    {
        //use array instead of dictionary as NSDictionary.allKeys cannot keep order.
        self.arraySampleCasesTitle = [NSMutableArray arrayWithArray:@[@"Feedback Sample", @"Tag & Log Sample", @"Feeds Sample", @"Location Sample", @"Install Sample", @"Push Notification Sample", @"Growth", @"Swift Sample"]];
        self.arraySampleCasesVC = [NSMutableArray arrayWithArray:@[@"FeedbackCasesViewController", @"LogTagCasesViewController", @"FeedCasesController",  @"LocationViewController", @"InstallCasesViewController", @"PushNotificationCasesViewController", @"GrowthCasesViewController", @"SwiftViewController"]];
        //initialize long persistent objects
        [InstallServiceMonitor shared];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Sample Cases";
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appStatusChangedNotificationHandler:) name:@"SHAppStatusChangeNotification" object:nil];
}

- (void)appStatusChangedNotificationHandler:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [self.tableView reloadData]; //host url is changed, update UI
    });
}

#pragma mark - UITableViewController delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.arraySampleCasesTitle.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    if (indexPath.row == 0)
    {
        static NSString *cellIdentifier = @"SampleCaseHostCell";
        cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        }
        //SHAppStatus is private class, to get alive host and without affecting code structure.
        NSString *aliveHostUrl = nil;
        Class appstatusClass = NSClassFromString(@"SHAppStatus");
        if (appstatusClass)
        {
            SEL sharedInstanceSelector = NSSelectorFromString(@"sharedInstance");
            id sharedInstance = ((id (*)(id, SEL))[appstatusClass methodForSelector:sharedInstanceSelector])(appstatusClass, sharedInstanceSelector);
            SEL aliveHostSelector = NSSelectorFromString(@"aliveHostInner");
            aliveHostUrl = ((id (*)(id, SEL))[sharedInstance methodForSelector:aliveHostSelector])(sharedInstance, aliveHostSelector);
        }
        cell.textLabel.text = StreetHawk.appKey;
        cell.detailTextLabel.text = aliveHostUrl;
        cell.textLabel.textColor = [UIColor redColor];
        cell.detailTextLabel.textColor = [UIColor redColor];
    }
    else
    {
        static NSString *cellIdentifier = @"SampleCaseModuleCell";
        cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        }
        cell.textLabel.text = self.arraySampleCasesTitle[indexPath.row - 1];
        cell.textLabel.textColor = [UIColor darkTextColor];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0)
    {
        return; //host server
    }
    NSString *className = self.arraySampleCasesVC[indexPath.row - 1];
    Class vcClass = NSClassFromString(className);
    if (vcClass == nil)
    {
        //swift class name is formatted like "_TtC11SHSampleDev19SwiftViewController", check in SHSampleDev-Swift.h.
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
        className = [NSString stringWithFormat:@"_TtC%lu%@%lu%@", (unsigned long)appName.length, appName, (unsigned long)className.length, className];
        vcClass = NSClassFromString(className);
    }
    NSAssert(vcClass != nil, @"Fail to create view controller class.");
    UIViewController *vc = [[vcClass alloc] init];
    vc.title = self.arraySampleCasesTitle[indexPath.row - 1];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    NSString *inputToken = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [[NSUserDefaults standardUserDefaults] setObject:NONULL(inputToken) forKey:SH_INSTALL_TOKEN]; //this is not normally use. it must restart App to take effect as SHHttpSessionManager set "X-Install-Token" when sigleton init.
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
