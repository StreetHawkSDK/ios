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

#import "FeedCasesController.h"
#import "FeedDetailViewController.h"

@interface FeedCasesController ()

@property (nonatomic, strong) NSArray<SHFeedObject *> *arrayFeeds;

- (void)buttonFetchFeedClicked:(id)sender;

@end

@implementation FeedCasesController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *fetchFeedButton = [UIButton buttonWithType:UIButtonTypeCustom];
    fetchFeedButton.frame = CGRectMake(0, 0, 100, 30);
    [fetchFeedButton setTitle:@"Fetch Feeds" forState:UIControlStateNormal];
    [fetchFeedButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [fetchFeedButton addTarget:self action:@selector(buttonFetchFeedClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    self.tableView.tableHeaderView = fetchFeedButton;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self buttonFetchFeedClicked:nil]; //when open this page, automatically load feeds.
}

- (void)buttonFetchFeedClicked:(id)sender
{
    [StreetHawk feed:0 withHandler:^(NSArray<SHFeedObject *> *arrayFeeds, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error == nil)
            {
                self.arrayFeeds = arrayFeeds;
                [self.tableView reloadData];
            }
            else
            {
                UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:@"Fetch feed error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [alertCtrl addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alertCtrl animated:YES completion:nil];
            }
        });
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.arrayFeeds.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"FeedsCell";
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
    cell.textLabel.text = [NSString stringWithFormat:@"%@", self.arrayFeeds[indexPath.row].title];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", self.arrayFeeds[indexPath.row].message];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    FeedDetailViewController *feedDetailCtrl = [[FeedDetailViewController alloc] initWithNibName:nil bundle:nil];
    feedDetailCtrl.feedObj = self.arrayFeeds[indexPath.row];
    [self.navigationController pushViewController:feedDetailCtrl animated:YES];
}

@end
