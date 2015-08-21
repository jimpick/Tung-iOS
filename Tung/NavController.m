//
//  NavController.m
//  Tung
//
//  Created by Jamie Perkins on 2/4/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "NavController.h"
#import "TungCommonObjects.h"

@interface NavController ()

@property (nonatomic, retain) TungCommonObjects *tungObjects;

@end

@implementation NavController

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
    
    _tungObjects = [TungCommonObjects establishTungObjects];
    self.navigationBar.barTintColor = [UIColor whiteColor];
	self.navigationBar.tintColor = _tungObjects.tungColor;
    self.navigationBar.translucent = NO;
    self.navigationBar.titleTextAttributes = @{ NSForegroundColorAttributeName: _tungObjects.tungColor };
    
    [[UINavigationBar appearance] setBackgroundImage:[UIImage imageNamed:@"navBarBkgd.png"] forBarMetrics:UIBarMetricsDefault];
    [[UINavigationBar appearance] setShadowImage:[UIImage imageNamed:@"navBarShadowWhite@2x.png"]];
    [super viewDidLoad];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
