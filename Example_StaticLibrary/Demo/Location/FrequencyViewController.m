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

#import "FrequencyViewController.h"

@interface FrequencyViewController ()

@end

@implementation FrequencyViewController

#pragma mark - life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Frequency";
    if (StreetHawk.locationManager.fgMinTimeBetweenEvents == 0)
    {
        self.segmentFgTime.selectedSegmentIndex = 0;
    }
    if (StreetHawk.locationManager.fgMinTimeBetweenEvents == 1)
    {
        self.segmentFgTime.selectedSegmentIndex = 1;
    }
    if (StreetHawk.locationManager.fgMinTimeBetweenEvents == 2)
    {
        self.segmentFgTime.selectedSegmentIndex = 2;
    }
    if (StreetHawk.locationManager.fgMinDistanceBetweenEvents == 0)
    {
        self.segmentFgDistance.selectedSegmentIndex = 0;
    }
    if (StreetHawk.locationManager.fgMinDistanceBetweenEvents == 100)
    {
        self.segmentFgDistance.selectedSegmentIndex = 1;
    }
    if (StreetHawk.locationManager.fgMinDistanceBetweenEvents == 200)
    {
        self.segmentFgDistance.selectedSegmentIndex = 2;
    }
    if (StreetHawk.locationManager.bgMinTimeBetweenEvents == 0)
    {
        self.segmentBgTime.selectedSegmentIndex = 0;
    }
    if (StreetHawk.locationManager.bgMinTimeBetweenEvents == 5)
    {
        self.segmentBgTime.selectedSegmentIndex = 1;
    }
    if (StreetHawk.locationManager.bgMinTimeBetweenEvents == 10)
    {
        self.segmentBgTime.selectedSegmentIndex = 2;
    }
    if (StreetHawk.locationManager.bgMinDistanceBetweenEvents == 0)
    {
        self.segmentBgDistance.selectedSegmentIndex = 0;
    }
    if (StreetHawk.locationManager.bgMinDistanceBetweenEvents == 500)
    {
        self.segmentBgDistance.selectedSegmentIndex = 1;
    }
    if (StreetHawk.locationManager.bgMinDistanceBetweenEvents == 800)
    {
        self.segmentBgDistance.selectedSegmentIndex = 2;
    }
}

- (void)dealloc
{
    self.tableViewFrequency.dataSource = nil;
    self.tableViewFrequency.delegate = nil;
}

- (void)viewDidUnload
{
    [self setTableViewFrequency:nil];
    [self setCellFgTime:nil];
    [self setSegmentFgTime:nil];
    [self setCellBgTime:nil];
    [self setSegmentBgTime:nil];
    [self setCellFgDistance:nil];
    [self setSegmentFgDistance:nil];
    [self setCellBgDistance:nil];
    [self setSegmentBgDistance:nil];
    [super viewDidUnload];
}

#pragma mark - event handler

- (IBAction)segmentFgTimeValueChanged:(id)sender
{
    if (self.segmentFgTime.selectedSegmentIndex == 0)
    {
        StreetHawk.locationManager.fgMinTimeBetweenEvents = 0;
    }
    if (self.segmentFgTime.selectedSegmentIndex == 1)
    {
        StreetHawk.locationManager.fgMinTimeBetweenEvents = 1;
    }
    if (self.segmentFgTime.selectedSegmentIndex == 2)
    {
        StreetHawk.locationManager.fgMinTimeBetweenEvents = 2;
    }
}

- (IBAction)segmentFgDistanceValueChanged:(id)sender
{
    if (self.segmentFgDistance.selectedSegmentIndex == 0)
    {
        StreetHawk.locationManager.fgMinDistanceBetweenEvents = 0;
    }
    if (self.segmentFgDistance.selectedSegmentIndex == 1)
    {
        StreetHawk.locationManager.fgMinDistanceBetweenEvents = 100;
    }
    if (self.segmentFgDistance.selectedSegmentIndex == 2)
    {
        StreetHawk.locationManager.fgMinDistanceBetweenEvents = 200;
    }
}

- (IBAction)segmentBgTimeValueChanged:(id)sender
{
    if (self.segmentBgTime.selectedSegmentIndex == 0)
    {
        StreetHawk.locationManager.bgMinTimeBetweenEvents = 0;
    }
    if (self.segmentBgTime.selectedSegmentIndex == 1)
    {
        StreetHawk.locationManager.bgMinTimeBetweenEvents = 5;
    }
    if (self.segmentBgTime.selectedSegmentIndex == 2)
    {
        StreetHawk.locationManager.bgMinTimeBetweenEvents = 10;
    }
}

- (IBAction)segmentBgDistanceValueChanged:(id)sender
{
    if (self.segmentBgDistance.selectedSegmentIndex == 0)
    {
        StreetHawk.locationManager.bgMinDistanceBetweenEvents = 0;
    }
    if (self.segmentBgDistance.selectedSegmentIndex == 1)
    {
        StreetHawk.locationManager.bgMinDistanceBetweenEvents = 500;
    }
    if (self.segmentBgDistance.selectedSegmentIndex == 2)
    {
        StreetHawk.locationManager.bgMinDistanceBetweenEvents = 800;
    }
}

#pragma mark - UITableViewDelegate handler

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return @"Foreground update frequency";
    }
    else if (section == 1)
    {
        return @"Background update frequency";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
    {
        return @"When App in foreground, SHLMUpdateLocationSuccessNotification won't sent until both time and distance exceed the setting.";
    }
    else if (section == 1)
    {
        return @"When App in background, SHLMUpdateLocationSuccessNotification won't sent until both time and distance exceed the setting.";
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        if (indexPath.row == 0)
        {
            return self.cellFgTime;
        }
        else if (indexPath.row == 1)
        {
            return self.cellFgDistance;
        }
    }
    else if (indexPath.section == 1)
    {
        if (indexPath.row == 0)
        {
            return self.cellBgTime;
        }
        else if (indexPath.row == 1)
        {
            return self.cellBgDistance;
        }
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80;
}

@end
