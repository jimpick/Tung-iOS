//
//  ProfileListTableViewController.h
//  Tung
//
//  Created by Jamie Perkins on 11/3/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ProfileHeaderView.h"

@interface ProfileListTableViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, UIAlertViewDelegate, UISearchBarDelegate, UISearchControllerDelegate>

@property (strong, nonatomic) NSString *queryType; // default is search 
@property (strong, nonatomic) NSString *target_id;

@property (strong, nonatomic) NSMutableDictionary *profileData; // used only for platform friends query
@property (strong, nonatomic) NSMutableArray *usersToFollow;

@property (strong, nonatomic) NSMutableArray *profileArray;
@property (nonatomic, assign) BOOL requestingMore;
@property (nonatomic, assign) BOOL noMoreItemsToGet;
@property (nonatomic, assign) BOOL noResults;
@property (nonatomic, assign) BOOL queryExecuted;
@property (strong, nonatomic) UINavigationController *navController;
@property (strong, nonatomic) ProfileHeaderView *profileHeader;

@property UISearchController *searchController;

- (void) requestProfileListWithQuery:(NSString *)queryType
                           forTarget:(NSString *)target_id
                           newerThan:(NSNumber *)afterTime
                         orOlderThan:(NSNumber *)beforeTime;
- (void) refreshFeed;
- (void) refetchFeed;
- (void) initSearchController;

@end
