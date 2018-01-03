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

#import "FeedDetailViewController.h"

@interface FeedDetailViewController ()

@property (strong, nonatomic) IBOutlet UITextView *textviewFeed;
@property (strong, nonatomic) IBOutlet UISegmentedControl *segmentResult;

@property (strong, nonatomic) IBOutlet UISwitch *switchDeleted;
- (IBAction)buttonFeedackClicked:(id)sender;
- (IBAction)buttonFeedResultClicked:(id)sender;

@end

@implementation FeedDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSMutableString *str = [NSMutableString string];
    [str appendFormat:@"feed id: %@\n", self.feedObj.feed_id];
    [str appendFormat:@"title: %@\n", self.feedObj.title];
    [str appendFormat:@"message: %@\n", self.feedObj.message];
    [str appendFormat:@"campaign: %@\n", self.feedObj.campaign];
    [str appendFormat:@"json: %@\n", shSerializeObjToJson(self.feedObj.content)];
    [str appendFormat:@"activates: %@\n", shFormatStreetHawkDate(self.feedObj.activates)];
    [str appendFormat:@"expires: %@\n", shFormatStreetHawkDate(self.feedObj.expires)];
    [str appendFormat:@"created: %@\n", shFormatStreetHawkDate(self.feedObj.created)];
    [str appendFormat:@"modified: %@\n", shFormatStreetHawkDate(self.feedObj.modified)];
    [str appendFormat:@"deleted: %@\n", shFormatStreetHawkDate(self.feedObj.deleted)];
    self.textviewFeed.text = str;
}

- (IBAction)buttonFeedackClicked:(id)sender {
    [StreetHawk sendFeedAck:self.feedObj.feed_id];
}

- (IBAction)buttonFeedResultClicked:(id)sender {
    BOOL isDeleted = self.switchDeleted.on;
    SHResult feedResult = SHResult_Accept;
    switch (self.segmentResult.selectedSegmentIndex) {
        case 0:
            feedResult = SHResult_Accept;
            break;
        case 1:
            feedResult = SHResult_Postpone;
            break;
        case 2:
            feedResult = SHResult_Decline;
            break;
        default:
            feedResult = SHResult_Accept;
            break;
    }
    [StreetHawk notifyFeedResult:self.feedObj.feed_id
                      withResult:feedResult
                      withStepId:nil
                      deleteFeed:isDeleted
                       completed:NO];
    if (isDeleted)
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                           UIAlertController *alertCtrl
                           = [UIAlertController alertControllerWithTitle:@"This feed is deleted"
                                                                 message:nil
                                                          preferredStyle:UIAlertControllerStyleAlert];
                           UIAlertAction *action
                           = [UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        [self.navigationController popViewControllerAnimated:YES];
                                                    }];
                           [alertCtrl addAction:action];
                           [self presentViewController:alertCtrl
                                              animated:YES
                                            completion:nil];
                       });
    }
}
@end
