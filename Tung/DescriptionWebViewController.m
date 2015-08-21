//
//  DescriptionWebViewController.m
//  Tung
//
//  Created by Jamie Perkins on 7/28/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "DescriptionWebViewController.h"

@interface DescriptionWebViewController ()

@end

@implementation DescriptionWebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _webView.opaque = NO;
    _webView.backgroundColor = [UIColor whiteColor];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
