//
//  NewRecordingNavController.m
//  Tung
//
//  Created by Jamie Perkins on 2/7/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "NewRecordingNavController.h"
#import "tungCommonObjects.h"

@interface NewRecordingNavController ()

@property (nonatomic, retain) tungCommonObjects *tungObjects;

@end

@implementation NewRecordingNavController

- (void)viewDidLoad
{
    _tungObjects = [tungCommonObjects establishTungObjects];
    // Navigation bar
    [[UINavigationBar appearance] setBarTintColor: [UIColor whiteColor]];
    [[UINavigationBar appearance] setTintColor:_tungObjects.tungColor];
    self.navigationController.navigationBar.translucent = NO;

    // title color
    [[UINavigationBar appearance] setTitleTextAttributes: [NSDictionary dictionaryWithObjectsAndKeys:_tungObjects.tungColor, NSForegroundColorAttributeName, nil]];
    [[UINavigationBar appearance] setBackgroundImage:[UIImage alloc] forBarMetrics:UIBarMetricsDefault];
    [[UINavigationBar appearance] setShadowImage:[[UIImage alloc] init]];
    [super viewDidLoad];
    
    NSLog(@"show: %@", _rootView);
    UIViewController *root = [self.storyboard instantiateViewControllerWithIdentifier:_rootView];
    [self pushViewController:root animated:NO];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

@end
