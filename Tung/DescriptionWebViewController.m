//
//  DescriptionWebViewController.m
//  Tung
//
//  Created by Jamie Perkins on 7/28/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "DescriptionWebViewController.h"
#import "BrowserViewController.h"
#import "JPLogRecorder.h"

@interface DescriptionWebViewController ()
@property NSURL *urlToPass;

@end

@implementation DescriptionWebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Podcast Description";
    self.view.backgroundColor = [UIColor whiteColor];
    
    _webView.opaque = NO;
    _webView.backgroundColor = [UIColor whiteColor];
    _webView.delegate = self;
    
    if (_stringToLoad) {
        [_webView loadHTMLString:_stringToLoad baseURL:[NSURL URLWithString:@"desc"]];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UIWebView delegate methods

-(BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    if ([request.URL.scheme isEqualToString:@"file"]) {
        return YES;
        
    } else {
        
        // open web browsing modal
        _urlToPass = request.URL;
        [self performSegueWithIdentifier:@"presentWebView" sender:self];
        
        return NO;
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    JPLog(@"description web view did fail with error: %@", error.localizedDescription);
    
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UINavigationController *destination = segue.destinationViewController;
    
    if ([[segue identifier] isEqualToString:@"presentWebView"]) {
        BrowserViewController *browserViewController = (BrowserViewController *)destination;
        [browserViewController setValue:_urlToPass forKey:@"urlToNavigateTo"];
    }
    
}


@end
