//
//  tungPeople.h
//  Tung
//
//  Created by Jamie Perkins on 11/5/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TungCommonObjects.h"

@interface TungPeople : NSObject

@property (nonatomic, retain) TungCommonObjects *tungObjects;
@property (strong, nonatomic) NSMutableArray *itemArray;

@property (nonatomic, assign) CGFloat systemVersion;

@property (nonatomic, assign) BOOL requestingMore;
@property (nonatomic, assign) BOOL noMoreItemsToGet;
@property (nonatomic, assign) BOOL noResults;
@property (nonatomic, assign) BOOL queryExecuted;
@property (nonatomic, assign) NSInteger itemSection;
@property (nonatomic, assign) NSInteger buttonPressedAtIndex;
// references to objects owned by view controller using tungStereo
@property (strong, nonatomic) UITableViewController *viewController;
@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) UIRefreshControl *refreshControl;
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;
// references to query params 
@property (strong, nonatomic) NSString *queryType;
@property (strong, nonatomic) NSString *target_id;

- (void) requestProfileListWithQuery:(NSString *)queryType
                           forTarget:(NSString *)target_id
                        orSearchTerm:(NSString *)term
                           newerThan:(NSNumber *)afterTime
                         orOlderThan:(NSNumber *)beforeTime;
- (void) configureProfileListCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath;
- (void) tableCellButtonTapped:(id)sender;
- (void) pushProfileForUserAtIndex:(NSInteger)index;

@end
