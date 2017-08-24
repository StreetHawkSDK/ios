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

#import <StreetHawkCore/StreetHawkCore.h>

@interface FrequencyViewController : StreetHawkBaseViewController <UITableViewDataSource, UITableViewDelegate>

@property (retain, nonatomic) IBOutlet UITableView *tableViewFrequency;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellFgTime;
@property (retain, nonatomic) IBOutlet UISegmentedControl *segmentFgTime;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellFgDistance;
@property (retain, nonatomic) IBOutlet UISegmentedControl *segmentFgDistance;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellBgTime;
@property (retain, nonatomic) IBOutlet UISegmentedControl *segmentBgTime;
@property (retain, nonatomic) IBOutlet UITableViewCell *cellBgDistance;
@property (retain, nonatomic) IBOutlet UISegmentedControl *segmentBgDistance;

- (IBAction)segmentFgTimeValueChanged:(id)sender;
- (IBAction)segmentFgDistanceValueChanged:(id)sender;
- (IBAction)segmentBgTimeValueChanged:(id)sender;
- (IBAction)segmentBgDistanceValueChanged:(id)sender;
@end
