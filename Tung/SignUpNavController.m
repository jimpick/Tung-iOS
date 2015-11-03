//
//  SignUpNavController.m
//  Tung
//
//  Created by Jamie Perkins on 5/15/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "SignUpNavController.h"
#import "TungCommonObjects.h"

@implementation SignUpNavController

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
    
    // Navigation bar
    [[UINavigationBar appearance] setBarTintColor: [UIColor whiteColor]];
    [[UINavigationBar appearance] setTintColor:[TungCommonObjects tungColor]];
    self.navigationController.navigationBar.translucent = NO;
    
    [[UINavigationBar appearance] setTitleTextAttributes: [NSDictionary dictionaryWithObjectsAndKeys:[TungCommonObjects tungColor], NSForegroundColorAttributeName, nil]];
    [[UINavigationBar appearance] setBackgroundImage:[UIImage alloc] forBarMetrics:UIBarMetricsDefault];
    [[UINavigationBar appearance] setShadowImage:[UIImage imageNamed:@"navBarShadowWhite@2x.png"]];
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
