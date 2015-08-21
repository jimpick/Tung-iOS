//
//  ProfileSearchTableViewController.h
//  Tung
//
//  Created by Jamie Perkins on 11/12/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ProfileSearchTableViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, UIAlertViewDelegate, UISearchBarDelegate>

@property (strong, nonatomic) NSString *searchTerm;
@property (strong, nonatomic) UISearchBar *searchBar;

@end
