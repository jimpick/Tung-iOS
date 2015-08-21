//
//  EditProfileNavigationController.m
//  Tung
//
//  Created by Jamie Perkins on 10/29/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "EditProfileNavigationController.h"

@interface EditProfileNavigationController ()

@end

@implementation EditProfileNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // Navigation bar
    UIColor *tungColor = [UIColor colorWithRed:87.0/255 green:90.0/255 blue:215.0/255 alpha:1];
    
    [[UINavigationBar appearance] setBarTintColor:[UIColor whiteColor]];
    [[UINavigationBar appearance] setTintColor:tungColor];
    self.navigationController.navigationBar.translucent = NO;
    
    [[UINavigationBar appearance] setBackgroundImage:[UIImage alloc] forBarMetrics:UIBarMetricsDefault];
    [[UINavigationBar appearance] setShadowImage:[UIImage imageNamed:@"navBarShadowWhite@2x.png"]];
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
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
