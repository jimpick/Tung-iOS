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


@property (strong, nonatomic) NSMutableArray *profileArray;
@property (nonatomic, assign) BOOL requestingMore;
@property (nonatomic, assign) BOOL noMoreItemsToGet;
@property (nonatomic, assign) BOOL noResults;
@property (nonatomic, assign) BOOL queryExecuted;
@property (strong, nonatomic) UINavigationController *navController;

- (void) requestProfileListWithQuery:(NSString *)queryType
                           forTarget:(NSString *)target_id
                           newerThan:(NSNumber *)afterTime
                         orOlderThan:(NSNumber *)beforeTime;
- (void) preloadAvatars;

@end
