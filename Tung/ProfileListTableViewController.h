//
//  ProfileListTableViewController.h
//  Tung
//
//  Created by Jamie Perkins on 11/3/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ProfileListTableViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) NSString *queryType;
@property (strong, nonatomic) NSString *target_id;

@end
