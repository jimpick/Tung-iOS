//
//  TungNavController.m
//  Tung
//
//  Created by Jamie Perkins on 7/9/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "TungNavController.h"
#import "TungCommonObjects.h"

@interface TungNavController ()

@property TungCommonObjects *tung;

@end

@implementation TungNavController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    self.navigationBar.barTintColor = [UIColor whiteColor];
    self.navigationBar.backgroundColor = [UIColor whiteColor];
    self.navigationBar.tintColor = _tung.tungColor;
    //self.navigationBar.translucent = NO; // causes black gap at top - stackoverflow.com/q/31308766/591487
    self.navigationBar.titleTextAttributes = @{ NSForegroundColorAttributeName: _tung.tungColor };
    
    [[UINavigationBar appearance] setBackgroundImage:[UIImage imageNamed:@"navBarBkgd.png"] forBarMetrics:UIBarMetricsDefault]; // makes status bar white
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];// [UIImage imageNamed:@"navBarShadowWhite@2x.png"]
    
    //[self setNeedsStatusBarAppearanceUpdate];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resource`s that can be recreated.
}

//- (UIStatusBarStyle)preferredStatusBarStyle {
//    NSLog(@"set preferred status bar style");
//    //return UIStatusBarStyleLightContent;
//    return UIStatusBarStyleDefault;
//}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
