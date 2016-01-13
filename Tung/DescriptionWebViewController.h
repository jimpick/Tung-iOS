//
//  DescriptionWebViewController.h
//  Tung
//
//  Created by Jamie Perkins on 7/28/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DescriptionWebViewController : UIViewController <UIWebViewDelegate>

@property (strong, nonatomic) IBOutlet UIWebView *webView;
@property (strong, nonatomic) NSString *stringToLoad;

@end
