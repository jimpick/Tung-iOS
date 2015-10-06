//
//  TungActivity.h
//  Tung
//
//  Created by Jamie Perkins on 6/22/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TungCommonObjects;

@interface TungStories : NSObject <UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate>

@property (nonatomic, retain) TungCommonObjects *tung;

@property (strong, nonatomic) NSMutableArray *storiesArray;
@property UITableViewController *feedTableViewController;
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;

@property (strong, nonatomic) NSString *profiledUserId;
@property UIBarButtonItem *headerLabel;

// request flags
@property (nonatomic, assign) BOOL requestingMore;
@property (nonatomic, assign) BOOL reachedEndOfPosts;
@property (nonatomic, assign) BOOL noResults;
@property (strong, nonatomic) NSString *requestStatus;

// indexes
@property (nonatomic, assign) NSInteger activeCellIndex;
@property (nonatomic, assign) NSInteger activeSectionIndex;

// references to host viewcontroller's properties
@property (strong, nonatomic) UINavigationController *navController;

// methods
- (void) refreshFeed;
- (void) determineProfileTableHeaderTextFromDict:(NSDictionary *)profiledUserData;
- (void) configureHeaderCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath;
- (void) configureEventCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath;
- (void) configureFooterCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath;
- (void) requestPostsNewerThan:(NSNumber *)afterTime orOlderThan:(NSNumber *)beforeTime fromUser:(NSString *)user_id;

@end
