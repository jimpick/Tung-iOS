//
//  TungActivity.h
//  Tung
//
//  Created by Jamie Perkins on 6/22/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TungCommonObjects;

@interface TungStories : NSObject

@property (nonatomic, retain) TungCommonObjects *tung;

@property (strong, nonatomic) NSMutableArray *storiesArray;

// request flags
@property (nonatomic, assign) BOOL requestingMore;
@property (nonatomic, assign) BOOL noMoreItemsToGet;
@property (nonatomic, assign) BOOL noResults;
@property (nonatomic, assign) BOOL queryExecuted;

// indexes
@property (nonatomic, assign) NSInteger feedSection;
@property (nonatomic, assign) NSInteger activeCellIndex;
@property (nonatomic, assign) NSInteger activeClipIndex;

// references to host viewcontroller's properties
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;
@property (strong, nonatomic) UIRefreshControl *refreshControl;
@property (strong, nonatomic) UITableView *tableView;

// methods
- (void) configureHeaderCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath;
- (void) configureEventCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath;
- (void) configureFooterCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath;
- (void) requestPostsNewerThan:(NSNumber *)afterTime orOlderThan:(NSNumber *)beforeTime fromUser:(NSString *)user_id;

@end
