//
//  BrowserViewController.m
//  Tung
//
//  Created by Jamie Perkins on 8/14/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "BrowserViewController.h"
#import "TungCommonObjects.h"

@interface BrowserViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property UIBarButtonItem *backBtn;
@property UIBarButtonItem *forwardBtn;
@property (nonatomic, strong) UIDocumentInteractionController *documentController;

@end

@implementation BrowserViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    
    //JPLog(@"loaded browser view controller with url request: %@", _urlStringToNavigateTo);
    
    _tung = [TungCommonObjects establishTungObjects];
    
    _titleLabel.text = @"Loading...";
    
    [_spinner startAnimating];
    
    _blurView.opacity = .4;
    _blurView.tintColor = [UIColor whiteColor];
    
    NSURL *url = [TungCommonObjects addReferrerToUrlString:_urlStringToNavigateTo];
    
    // instantiate webview
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    self.webView.delegate = self;
    self.webView.scrollView.scrollsToTop = YES;
    self.webView.scalesPageToFit = YES;
    self.webView.scrollView.contentInset = UIEdgeInsetsMake(30, 0, 0, 0);

    [self.webView loadRequest:urlRequest];
    
    // bottom bar
    UIButton *backBtnInner = [UIButton buttonWithType:UIButtonTypeCustom];
    backBtnInner.frame = CGRectMake(0, 0, 42, 42);
    [backBtnInner addTarget:self.webView action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    [backBtnInner setContentMode:UIViewContentModeCenter];
    [backBtnInner setImage:[UIImage imageNamed:@"UIButtonBarArrowLeft.png"] forState:UIControlStateNormal];
    backBtnInner.tintColor = [TungCommonObjects tungColor];
    _backBtn = [[UIBarButtonItem alloc] initWithCustomView:backBtnInner];
    _backBtn.tintColor = [TungCommonObjects tungColor];
    UIButton *forwardBtnInner = [UIButton buttonWithType:UIButtonTypeCustom];
    forwardBtnInner.frame = CGRectMake(0, 0, 42, 42);
    [forwardBtnInner addTarget:self.webView action:@selector(goForward) forControlEvents:UIControlEventTouchUpInside];
    [forwardBtnInner setContentMode:UIViewContentModeCenter];
    [forwardBtnInner setImage:[UIImage imageNamed:@"UIButtonBarArrowRight.png"] forState:UIControlStateNormal];
    _forwardBtn.tintColor = [TungCommonObjects tungColor];
    _forwardBtn = [[UIBarButtonItem alloc] initWithCustomView:forwardBtnInner];
    _forwardBtn.tintColor = [TungCommonObjects tungColor];
    UIBarButtonItem *openInBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(openActionSheet)];
    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(dismissWebView)];
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    
    _toolbar.tintColor = [TungCommonObjects tungColor];
    _toolbar.items = @[_backBtn, flexSpace, _forwardBtn, flexSpace, openInBtn, flexSpace, doneBtn];
    
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) dismissWebView {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIWebView delegate methods

-(BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    return YES;
}
// set nav bar title to web page title
- (void) webViewDidFinishLoad:(UIWebView *)webView {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateToolbarButtons];
    NSString *title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    _titleLabel.text = title;
    [_spinner stopAnimating];
}
- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self updateToolbarButtons];
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateToolbarButtons];
}

#pragma mark - Misc

-(void) updateToolbarButtons {
    _backBtn.enabled = _webView.canGoBack;
    _forwardBtn.enabled = _webView.canGoForward;
}

- (void) openActionSheet {
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Open in Safari" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSURL *url = [TungCommonObjects addReferrerToUrlString:_urlStringToNavigateTo];
        [[UIApplication sharedApplication] openURL:url];
    }]];
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Copy URL" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *urlString = self.webView.request.URL.absoluteString;
        [[UIPasteboard generalPasteboard] setString:urlString];
    }]];
    [self presentViewController:actionSheet animated:YES completion:nil];
}


@end
