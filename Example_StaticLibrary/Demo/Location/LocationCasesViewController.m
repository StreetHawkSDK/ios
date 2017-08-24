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

#import "LocationCasesViewController.h"
#import "BeaconRegionInputViewController.h"
#import "FrequencyViewController.h"
#import "BeaconRangeViewController.h"

@interface LocationCasesViewController ()

@property (nonatomic, strong) NSArray *arrayCells; //cells for the table

//when this view open, not read whole file content from location log, but append last row to be efficient.
- (void)locationLogsUpdated:(NSNotification *)notification;

//update label and button status for geo location update.
- (void)updateGeoLocationStatus;
//stop monitor one iBeacon region.
- (void)buttonStopMonitorBeaconRegionClicked:(id)sender;

//notification handler
- (void)startStandardUpdateHandler:(NSNotification *)notification;
- (void)stopStandardUpdateHandler:(NSNotification *)notification;
- (void)startSignificantUpdateHandler:(NSNotification *)notification;
- (void)stopSignificantUpdateHandler:(NSNotification *)notification;
- (void)startMonitorRegionHandler:(NSNotification *)notification;
- (void)stopMonitorRegionHandler:(NSNotification *)notification;

@end

@implementation LocationCasesViewController

#pragma mark - life cycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationLogsUpdated:) name:LogMonitorUpdatedNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startStandardUpdateHandler:) name:SHLMStartStandardMonitorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopStandardUpdateHandler:) name:SHLMStopStandardMonitorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startSignificantUpdateHandler:) name:SHLMStartSignificantMonitorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopSignificantUpdateHandler:) name:SHLMStopSignificantMonitorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startMonitorRegionHandler:) name:SHLMStartMonitorRegionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopMonitorRegionHandler:) name:SHLMStopMonitorRegionNotification object:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //must init the arrays here because IBOutlet object is still nil when init.
    NSArray *arrayGeoConfigCells = @[self.cellLocationMonitorStatus, self.cellStartStandardUpdate, self.cellStartSignificantUpdate, self.cellStopUpdate, self.cellGeoConfig, self.cellCheckLocationPermission];
    NSArray *arrayiBeaconConfigCells = @[self.celliBeaconMonitor];
    self.arrayCells = @[arrayGeoConfigCells, arrayiBeaconConfigCells];
    //set control properties
    self.cellLocationMonitorStatus.textLabel.font = [UIFont systemFontOfSize:16];
    self.cellLocationMonitorStatus.textLabel.textColor = [UIColor redColor];
    self.cellLocationMonitorStatus.textLabel.textAlignment = NSTextAlignmentCenter;
    //start load some values to controls
    [self updateGeoLocationStatus];
    [BaseLogMonitor showLogToTextView:self.viewLogs fromMonitor:[LocationServiceMonitor shared]];
    //check location service is enabled
    [self.buttonEnableService setTitle:StreetHawk.isLocationServiceEnabled ? @"Now is Enabled" : @"Now is Disabled" forState:UIControlStateNormal];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.tableViewLocationConfig.dataSource = nil;
    self.tableViewLocationConfig.delegate = nil;
    self.tableViewBeaconRegions.dataSource = nil;
    self.tableViewBeaconRegions.delegate = nil;
}

- (void)viewDidUnload
{
    [self setTableViewLocationConfig:nil];
    [self setCellLocationMonitorStatus:nil];
    [self setCellStartStandardUpdate:nil];
    [self setCellStartSignificantUpdate:nil];
    [self setButtonStartStandardUpdate:nil];
    [self setButtonStartSignificantUpdate:nil];
    [self setCellStopUpdate:nil];
    [self setButtonStopUpdate:nil];
    [self setCellGeoConfig:nil];
    [self setViewLogs:nil];
    [self setButtonClearLogs:nil];
    [self setCellDisplayCalibration:nil];
    [self setSwitchDisplayCalibration:nil];
    [self setCelliBeaconMonitor:nil];
    [self setTableViewBeaconRegions:nil];
    [self setButtonAddBeaconRegion:nil];
    [self setButtonEnableService:nil];
    [super viewDidUnload];
}

#pragma mark - event handler

- (IBAction)buttonStartStandardUpdateClicked:(id)sender
{
    [StreetHawk.locationManager startMonitorGeoLocationStandard:YES];
}

- (IBAction)buttonStartSignificantUpdateClicked:(id)sender
{
    [StreetHawk.locationManager startMonitorGeoLocationStandard:NO];
}

- (IBAction)buttonStopUpdateClicked:(id)sender
{
    [StreetHawk.locationManager stopMonitorGeoLocation];
}

- (IBAction)buttonGeoConfigClicked:(id)sender
{
    FrequencyViewController *frequencyVC = [[FrequencyViewController alloc] initWithNibName:nil bundle:nil];
    [self.navigationController pushViewController:frequencyVC animated:YES];
}

- (IBAction)buttonCheckLocationPermissionClicked:(id)sender
{
    if (StreetHawk.systemPreferenceDisableLocation)
    {
        if (![StreetHawk launchSystemPreferenceSettings])
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Info" message:@"Pre-iOS 8 show self made instruction." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
        }
    }
    else
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Info" message:@"No need to show enable location preference." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
    }
}

- (IBAction)buttonAddBeaconRegionClicked:(id)sender
{
    BeaconRegionInputViewController *inputVC = [[BeaconRegionInputViewController alloc] initWithNibName:nil bundle:nil];
    inputVC.inputHandler = ^(CLBeaconRegion *region)
    {
        if (![StreetHawk.locationManager startMonitorRegion:region])
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"This beacon region is already monitored." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alertView show];
        }
    };
    [inputVC presentOnTopWithCover:YES withCoverColor:nil withCoverAlpha:0 withDelay:YES withCoverTouchHandler:nil withAnimationHandler:nil withOrientationChangedHandler:nil];
}

- (void)buttonStopMonitorBeaconRegionClicked:(id)sender
{
    UIButton *button = (UIButton *)sender;
    CLBeaconRegion *region = StreetHawk.locationManager.monitoredRegions[button.tag];
    [StreetHawk.locationManager stopMonitorRegion:region];
}

- (IBAction)buttonClearLogsClicked:(id)sender
{
    NSError *error;
    [[LocationServiceMonitor shared] clearLogHistory:&error];
    if (error)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Fail to clear log file" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
    }
}

- (IBAction)buttonEnableServiceClicked:(id)sender
{
    StreetHawk.isLocationServiceEnabled = !StreetHawk.isLocationServiceEnabled;
    [self.buttonEnableService setTitle:StreetHawk.isLocationServiceEnabled ? @"Now is Enabled" : @"Now is Disabled" forState:UIControlStateNormal];
}

#pragma mark - private functions

- (void)locationLogsUpdated:(NSNotification *)notification
{
    [BaseLogMonitor showLogToTextView:self.viewLogs fromMonitor:[LocationServiceMonitor shared]];
}

- (void)updateGeoLocationStatus
{
    if (StreetHawk.locationManager.geolocationMonitorState == SHGeoLocationMonitorState_MonitorStandard)
    {
        self.cellLocationMonitorStatus.textLabel.text = @"Status: Standard(GPS, Cellular)";
    }
    else if (StreetHawk.locationManager.geolocationMonitorState == SHGeoLocationMonitorState_MonitorSignificant)
    {
        self.cellLocationMonitorStatus.textLabel.text = @"Status: Significant";
    }
    else if (StreetHawk.locationManager.geolocationMonitorState == SHGeoLocationMonitorState_Stopped)
    {
        self.cellLocationMonitorStatus.textLabel.text = @"Status: Stop";
    }
    self.buttonStartStandardUpdate.enabled = (StreetHawk.locationManager.geolocationMonitorState != SHGeoLocationMonitorState_MonitorStandard);
    self.buttonStartSignificantUpdate.enabled = (StreetHawk.locationManager.geolocationMonitorState != SHGeoLocationMonitorState_MonitorSignificant);
    self.buttonStopUpdate.enabled = (StreetHawk.locationManager.geolocationMonitorState != SHGeoLocationMonitorState_Stopped);
}

- (void)startStandardUpdateHandler:(NSNotification *)notification
{
    [self updateGeoLocationStatus];
}

- (void)stopStandardUpdateHandler:(NSNotification *)notification
{
    [self updateGeoLocationStatus];
}

- (void)startSignificantUpdateHandler:(NSNotification *)notification
{
    [self updateGeoLocationStatus];
}

- (void)stopSignificantUpdateHandler:(NSNotification *)notification
{
    [self updateGeoLocationStatus];
}

- (void)startMonitorRegionHandler:(NSNotification *)notification
{
    [self.tableViewBeaconRegions reloadData];
}

- (void)stopMonitorRegionHandler:(NSNotification *)notification
{
    [self.tableViewBeaconRegions reloadData];
}

#pragma mark - UITableViewDelegate handler

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (tableView == self.tableViewLocationConfig)
    {
        return self.arrayCells.count;
    }
    else if (tableView == self.tableViewBeaconRegions)
    {
        return 1;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (tableView == self.tableViewLocationConfig)
    {
        if (section == 0)
        {
            return @"Geolocation config";
        }
        else if (section == 1)
        {
            return @"Monitor regions";
        }
    }
    else if (tableView == self.tableViewBeaconRegions)
    {
        return nil;
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.tableViewLocationConfig)
    {
        NSArray *array = self.arrayCells[section];
        return array.count;
    }
    else if (tableView == self.tableViewBeaconRegions)
    {
        return StreetHawk.locationManager.monitoredRegions.count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.tableViewLocationConfig)
    {
        NSArray *array = self.arrayCells[indexPath.section];
        return (UITableViewCell *)array[indexPath.row];
    }
    else if (tableView == self.tableViewBeaconRegions)
    {
        NSString *cellIdentifier = @"iBeaconRegionCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
            UIButton *buttonStop = [UIButton buttonWithType:UIButtonTypeRoundedRect];
            [buttonStop setTitle:@"Stop" forState:UIControlStateNormal];
            buttonStop.titleLabel.font = [UIFont systemFontOfSize:14];
            [buttonStop addTarget:self action:@selector(buttonStopMonitorBeaconRegionClicked:) forControlEvents:UIControlEventTouchUpInside];
            [cell.contentView addSubview:buttonStop];
            cell.textLabel.font = [UIFont systemFontOfSize:13];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
            cell.detailTextLabel.numberOfLines = 2;
            cell.detailTextLabel.lineBreakMode = 0; //word wrap
        }
        UIButton *buttonStop = cell.contentView.subviews[0];
        double buttonWidth = 33;
        double buttonHeight = 20;
        double rightMargin = 5;
        buttonStop.frame = CGRectMake(cell.bounds.size.width - rightMargin - buttonWidth, (cell.bounds.size.height - buttonHeight)/2, buttonWidth, buttonHeight); //do it here to deal with rotate
        buttonStop.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        buttonStop.tag = indexPath.row;
        cell.textLabel.frame = CGRectMake(cell.textLabel.frame.origin.x, cell.textLabel.frame.origin.y, cell.bounds.size.width - cell.textLabel.frame.origin.x - buttonWidth - rightMargin, cell.textLabel.frame.size.height);
        CLRegion *region = StreetHawk.locationManager.monitoredRegions[indexPath.row];
        if ([region isKindOfClass:[CLBeaconRegion class]])
        {
            CLBeaconRegion *beaconRegion = (CLBeaconRegion *)region;
            cell.textLabel.text = beaconRegion.proximityUUID.UUIDString;
            NSString *detail = nil;
            if (beaconRegion.minor != nil && beaconRegion.minor.intValue >= 0)
            {
                detail = [NSString stringWithFormat:@"(major: %d, minor: %d)", beaconRegion.major.intValue, beaconRegion.minor.intValue];
            }
            else if (beaconRegion.major != nil && beaconRegion.major.intValue >= 0)
            {
                detail = [NSString stringWithFormat:@"(major: %d, minor: null)", beaconRegion.major.intValue];
            }
            else
            {
                detail = @"(major: null, minor: null)";
            }
            detail = [NSString stringWithFormat:@"%@\nidentifier: %@", detail, beaconRegion.identifier];
            cell.detailTextLabel.text = detail;
        }
        else if ([region isKindOfClass:[CLCircularRegion class]])
        {
            CLCircularRegion *geoRegion = (CLCircularRegion *)region;
            cell.textLabel.text = [NSString stringWithFormat:@"(%f, %f)~%f", geoRegion.center.latitude, geoRegion.center.longitude, geoRegion.radius];
            cell.detailTextLabel.text = geoRegion.identifier;
        }
        return cell;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.tableViewLocationConfig)
    {
        NSArray *array = self.arrayCells[indexPath.section];
        UITableViewCell *cell = (UITableViewCell *)array[indexPath.row];
        return cell.bounds.size.height;
    }
    else if (tableView == self.tableViewBeaconRegions)
    {
        return 65;
    }
    return 0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.tableViewBeaconRegions)
    {
        CLRegion *region = StreetHawk.locationManager.monitoredRegions[indexPath.row];
        if ([region isKindOfClass:[CLBeaconRegion class]])
        {
            BeaconRangeViewController *rangeVC = [[BeaconRangeViewController alloc] initWithStyle:UITableViewStylePlain];
            rangeVC.iBeaconRegion = (CLBeaconRegion *)region;
            [self.navigationController pushViewController:rangeVC animated:YES];
        }
    }
}

@end
