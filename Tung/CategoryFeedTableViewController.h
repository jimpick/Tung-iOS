//
//  CategoryFeedTableViewController.h
//  Tung
//
//  Created by Jamie Perkins on 8/7/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface CategoryFeedTableViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) NSString *profiledUser;
@property (strong, nonatomic) NSNumber *profiledCategory;
@property (strong, nonatomic) NSDictionary *profiledUserData;
@property (strong, nonatomic) NSString *searchTerm;

@end
