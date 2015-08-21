//
//  CustomSearchController.m
//  Tung
//
//  Created by Jamie Perkins on 6/17/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "CustomSearchController.h"

@interface CustomSearchController ()

@end

@implementation CustomSearchController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)setActive:(BOOL)active {
    [super setActive:active];
    [self.searchResultsController.navigationController setNavigationBarHidden: NO animated: NO];
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
