//
//  ProfileNavigationController.m
//  Tung
//
//  Created by Jamie Perkins on 10/29/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "ProfileNavigationController.h"
#import "TungCommonObjects.h"

@interface ProfileNavigationController ()

@property (nonatomic, retain) TungCommonObjects *tungObjects;

@end

@implementation ProfileNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tungObjects = [TungCommonObjects establishTungObjects];
    
    // Navigation bar
    [[UINavigationBar appearance] setBarTintColor:[UIColor whiteColor]];
    [[UINavigationBar appearance] setTintColor:_tungObjects.tungColor];
    self.navigationController.navigationBar.translucent = NO;
    
    [[UINavigationBar appearance] setTitleTextAttributes: [NSDictionary dictionaryWithObjectsAndKeys:_tungObjects.tungColor, NSForegroundColorAttributeName, nil]];
    [[UINavigationBar appearance] setBackgroundImage:[UIImage alloc] forBarMetrics:UIBarMetricsDefault];
    [[UINavigationBar appearance] setShadowImage:[UIImage imageNamed:@"navBarShadowWhite@2x.png"]];
    [super viewDidLoad];
    
    // Currently used only for loading EditProfileTableViewController
    NSLog(@"show: %@", _rootView);
    UIViewController *root = [self.storyboard instantiateViewControllerWithIdentifier:_rootView];
    [self pushViewController:root animated:NO];
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
