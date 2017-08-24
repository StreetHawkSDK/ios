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

#import <UIKit/UIKit.h>
#import "LocationServiceMonitor.h"

@interface LocationCasesViewController : StreetHawkBaseViewController <UITableViewDataSource, UITableViewDelegate>

@property (retain, nonatomic) IBOutlet UITableView *tableViewLocationConfig;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellLocationMonitorStatus;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellStartStandardUpdate;
@property (retain, nonatomic) IBOutlet UIButton *buttonStartStandardUpdate;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellStartSignificantUpdate;
@property (retain, nonatomic) IBOutlet UIButton *buttonStartSignificantUpdate;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellStopUpdate;
@property (retain, nonatomic) IBOutlet UIButton *buttonStopUpdate;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellGeoConfig;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellCheckLocationPermission;
@property (retain, nonatomic) IBOutlet UITableViewCell *celliBeaconMonitor;
@property (retain, nonatomic) IBOutlet UIButton *buttonAddBeaconRegion;
@property (retain, nonatomic) IBOutlet UITableView *tableViewBeaconRegions;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellDisplayCalibration;
@property (retain, nonatomic) IBOutlet UISwitch *switchDisplayCalibration;
@property (retain, nonatomic) IBOutlet UIButton *buttonClearLogs;
@property (retain, nonatomic) IBOutlet UIButton *buttonEnableService;
@property (retain, nonatomic) IBOutlet UITextView *viewLogs;

- (IBAction)buttonStartStandardUpdateClicked:(id)sender;
- (IBAction)buttonStartSignificantUpdateClicked:(id)sender;
- (IBAction)buttonStopUpdateClicked:(id)sender;
- (IBAction)buttonGeoConfigClicked:(id)sender;
- (IBAction)buttonCheckLocationPermissionClicked:(id)sender;
- (IBAction)buttonAddBeaconRegionClicked:(id)sender;
- (IBAction)buttonClearLogsClicked:(id)sender;
- (IBAction)buttonEnableServiceClicked:(id)sender;

@end
