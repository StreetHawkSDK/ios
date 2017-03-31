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

#import "SHViewController.h" //for inherit from SHBaseViewController
#import "SHSlideViewController.h" //for protocol SHSlideContentViewController

/**
 View controller for slide in web page for a url.
 */
@interface SHSlideWebViewController : SHBaseViewController <SHSlideContentViewController, UIWebViewDelegate>

@property (strong, nonatomic) IBOutlet UIWebView *webView;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

/**
 The url for opening on this web view.
 */
@property (nonatomic, strong) NSString *webpageUrl;

@end
