//
//  TungActivity.h
//  Tung
//
//  Created by Jamie Perkins on 6/22/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ProfileHeaderView.h"
#import <AVFoundation/AVFoundation.h>
#import "ClipProgressView.h"

@class TungCommonObjects;

@interface TungStories : NSObject <UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, AVAudioPlayerDelegate, UIGestureRecognizerDelegate, UIActionSheetDelegate>

@property (nonatomic, retain) TungCommonObjects *tung;

@property (strong, nonatomic) NSMutableArray *storiesArray;
@property UITableViewController *feedTableViewController;
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;

@property (strong, nonatomic) NSString *profiledUserId;

// request flags
@property (nonatomic, assign) BOOL requestingMore;
@property (nonatomic, assign) BOOL reachedEndOfPosts;
@property (nonatomic, assign) BOOL noResults;
@property (strong, nonatomic) NSString *requestStatus;

// indexes
@property (nonatomic, assign) NSInteger activeRowIndex;
@property (nonatomic, assign) NSInteger selectedRowIndex;
@property (nonatomic, assign) NSInteger activeSectionIndex;
@property (nonatomic, assign) NSInteger selectedSectionIndex;

// references to host viewcontroller's properties
@property (strong, nonatomic) UINavigationController *navController;
@property (strong, nonatomic) UIViewController *viewController;
@property ProfileHeaderView *profileHeader;
@property NSLayoutConstraint *profileHeaderHeight;

@property CGFloat screenWidth;

// playing clips
@property (strong, nonatomic) CADisplayLink *onEnterFrame;
@property (strong, nonatomic) ClipProgressView *activeClipProgressView;
- (void) playPause;
- (void) playbackClip;
- (void) pauseClipPlayback;
- (void) stopClipPlayback;
- (void) setActiveClipCellReference;

// feed related methods
- (void) refreshFeed:(BOOL)fullRefresh;
- (void) configureHeaderCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath;
- (void) configureEventCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath;
- (void) configureFooterCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath;
- (void) requestPostsNewerThan:(NSNumber *)afterTime orOlderThan:(NSNumber *)beforeTime fromUser:(NSString *)user_id;

@end
