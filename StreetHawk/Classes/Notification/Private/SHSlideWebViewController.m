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

#import "SHSlideWebViewController.h"
//header from StreetHawk
#import "SHUtils.h" //for SHLog

@interface SHSlideWebViewController ()

//load page and refresh UI.
- (void)displayUI;

@end

@implementation SHSlideWebViewController

@synthesize contentLoadFinishHandler;
@synthesize pushData;

#pragma mark - life cycle

- (void)dealloc
{
    self.webView.delegate = nil;
    self.webpageUrl = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //another chance to load web page
    [self displayUI];
}

#pragma mark - properties

- (void)setWebpageUrl:(NSString *)url
{
    if (url != nil && ![url isKindOfClass:[NSString class]])
    {
        return;
    }
    if (url != nil && [url rangeOfString:@"://"].location == NSNotFound)  //if not have protocal, prefix https://
    {
        url = [NSString stringWithFormat:@"https://%@", url];
    }
    if (url == nil || self.webpageUrl == nil || [self.webpageUrl compare:url options:NSCaseInsensitiveSearch] != NSOrderedSame)
    {
        _webpageUrl = url;
        [self displayUI];
    }
}

#pragma mark - protocol functions

- (void)contentViewAdjustUI
{
    self.activityIndicator.frame = CGRectMake((self.view.bounds.size.width - self.activityIndicator.bounds.size.width) / 2, (self.view.bounds.size.height - self.activityIndicator.bounds.size.height) / 2, self.activityIndicator.bounds.size.width, self.activityIndicator.bounds.size.height);
}

#pragma mark - private functions

- (void)displayUI
{
    if (self.isViewLoaded && self.webpageUrl != nil && self.webpageUrl.length > 0)
    {
        [self.activityIndicator startAnimating];
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.webpageUrl]]];
    }
    else
    {
        [self.activityIndicator stopAnimating];
        [self.webView loadHTMLString:@"" baseURL:nil];
    }
}

#pragma mark - UIWebView delegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self.activityIndicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    //This delegate may be called several time even load a single url, one case is the url contains iFrames. For example when loading www.streethawk.com, "Slide start to load." promotes 6 times. Fortunately webView.isLoading can tell you whether it's the last loading.
    if (!webView.isLoading)
    {
        [self.activityIndicator stopAnimating];
        if (self.contentLoadFinishHandler != nil)
        {
            self.contentLoadFinishHandler(YES);
        }
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (!webView.isLoading)
    {
        [self.activityIndicator stopAnimating];
        if (self.contentLoadFinishHandler != nil)
        {
            self.contentLoadFinishHandler(NO);
        }
    }
    SHLog(@"Fail to show slide due to error: %@", error.localizedDescription);
}

@end
