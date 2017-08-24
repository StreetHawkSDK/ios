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

#import "BeaconRangeViewController.h"

@interface BeaconRangeViewController ()

@property (nonatomic, strong) UIActivityIndicatorView *activityView;
@property (nonatomic, strong) NSArray *arrayBeacons;

- (void)rangeChangedHandler:(NSNotification *)notification; //notification handler for range changed
- (void)rangeFailHandler:(NSNotification *)notification; //notification handler for fail range

@end

@implementation BeaconRangeViewController

#pragma mark - life cycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rangeChangedHandler:) name:SHLMRangeiBeaconChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rangeFailHandler:) name:SHLMRangeiBeaconFailNotification object:self];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.activityView.frame = CGRectMake((self.tableView.frame.size.width-self.activityView.frame.size.width)/2, (self.tableView.frame.size.height-self.activityView.frame.size.height)/2, self.activityView.frame.size.width, self.activityView.frame.size.height);
    [self.tableView addSubview:self.activityView];
    self.activityView.hidesWhenStopped = YES;
    [self.activityView startAnimating];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [StreetHawk.locationManager startRangeiBeaconRegion:self.iBeaconRegion];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [StreetHawk.locationManager stopRangeiBeaconRegion:self.iBeaconRegion];
}

#pragma mark - location manager notification handler

- (void)rangeChangedHandler:(NSNotification *)notification
{
    [self.activityView stopAnimating];
    self.arrayBeacons = notification.userInfo[SHLMNotification_kBeacons];
    [self.tableView reloadData];
}

- (void)rangeFailHandler:(NSNotification *)notification
{
    self.arrayBeacons = nil;
    [self.tableView reloadData];
    NSError *error = notification.userInfo[SHLMNotification_kError];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Fail to range" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
}

#pragma mark - UITableView delegate and handler

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.arrayBeacons.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"iBeaconCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    CLBeacon *iBeacon = self.arrayBeacons[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"major: %d, minor: %d", iBeacon.major.intValue, iBeacon.minor.intValue];
    NSString *detail = nil;
    switch (iBeacon.proximity)
    {
        case CLProximityFar:
            detail = @"Far";
            break;
        case CLProximityNear:
            detail = @"Near";
            break;
        case CLProximityImmediate:
            detail = @"Immediate";
            break;
        case CLProximityUnknown:
            detail = @"Unknown";
            break;
        default:
            break;
    }
    detail = [NSString stringWithFormat:@"%@: %.6f m, rssi: %ld", detail, iBeacon.accuracy, (long)iBeacon.rssi];
    cell.detailTextLabel.text = detail;
    return cell;
}

@end
