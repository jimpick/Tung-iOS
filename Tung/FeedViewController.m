//
//  FeedTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 8/7/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "FeedViewController.h"
#import "StoriesTableViewController.h"
#import "IconButton.h"
#import "FindFriendsTableViewController.h"
#import "ProfileListTableViewController.h"

@interface FeedViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) TungPodcast *podcast;
@property (strong, nonatomic) StoriesTableViewController *storiesView;

@property BOOL hasPodcastData;
@property BOOL hasUserData;

@end

@implementation FeedViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tungNavBarLogo.png"]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiatePodcastSearch)];
    
    _tung = [TungCommonObjects establishTungObjects];
    if (!_tung.tungId || !_tung.tungToken) [_tung establishCred];
    
    // for search controller
    _podcast = [TungPodcast new];
    _podcast.navController = [self navigationController];
    _podcast.delegate = self;
    
    // find friends button
    IconButton *findFriendsInner = [[IconButton alloc] initWithFrame:CGRectMake(0, 0, 34, 34)];
    findFriendsInner.type = kIconButtonTypeFindFriends;
    findFriendsInner.color = [TungCommonObjects tungColor];
    [findFriendsInner addTarget:self action:@selector(pushFindFriendsView) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:findFriendsInner];
    
    // FEED
    _storiesView = [self.storyboard instantiateViewControllerWithIdentifier:@"storiesTableView"];
    
    //_storiesView.edgesForExtendedLayout = UIRectEdgeNone; // seems to not do anything
    [self addChildViewController:_storiesView];
    _storiesView.navController = [self navigationController];
    _storiesView.profiledUserId = @"";
    [self.view addSubview:_storiesView.view];
    
    
    CGFloat topConstraint = 0;
    /* There's some kind of bug in 9.0 that causes edgesForExtendedLayout to not behave properly.
     ONLY in 9.0 (not 8.4 or 9.1+) the top constraint needs to be 64 so stories feed isn't positioned behind nav bar.
     I tried every combination imaginable for edgesForExtendedLayout, automaticallyAdjustsScrollViewInsets, 
     and extendedLayoutIncludesOpaqueBars. Without the top constraint the status bar will be transparent or 
     feed will positioned wrong. The translucence of the nav bar also affects the layout. */
    NSInteger majorVersion = [[NSProcessInfo processInfo] operatingSystemVersion].majorVersion;
    NSInteger minorVersion = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
    NSString *version = [NSString stringWithFormat:@"%ld.%ld", (long)majorVersion, (long)minorVersion];
    if ([version isEqualToString:@"9.0"]) topConstraint = 64;
    
    _storiesView.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_storiesView.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:topConstraint]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_storiesView.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_storiesView.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_storiesView.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_storiesView.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_storiesView.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_storiesView.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
    //[TungCommonObjects clearTempDirectory]; // DEV only
    
    /* dev purposes - log out of fb
    if ([FBSDKAccessToken currentAccessToken]) {
        [[FBSDKLoginManager new] logOut];
    } */
    
    //[TungCommonObjects checkForUserData]; // for debugging
    //[TungCommonObjects checkForPodcastData]; // for debugging
    
    // first load
    _tung.feedNeedsRefresh = [NSNumber numberWithBool:YES];
    
    // notifs
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareView) name:UIApplicationDidBecomeActiveNotification object:nil];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) viewWillAppear:(BOOL)animated {
    self.navigationController.navigationBar.translucent = NO;
    
    _tung.viewController = self;
    self.definesPresentationContext = YES;
	
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self prepareView];
        
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    //self.navigationController.navigationBar.translucent = YES;
    [_podcast.feedPreloadQueue cancelAllOperations];
    self.definesPresentationContext = NO;
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    /* ppl want what was there to remain
    if (_podcast.searchController.active) {
        [_podcast.searchController setActive:NO];
        [self dismissPodcastSearch];
    }*/
}

- (void) prepareView {
    // if feed hasn't been fetched in the last 5 minutes
    [_tung checkFeedLastFetchedTime];
    
    
    if (_tung.feedNeedsRefetch.boolValue) {
        [_storiesView refetchFeed];
    }
    else if (_tung.feedNeedsRefresh.boolValue) {
        // let's get retarded in here
        [self refreshFeed];
    }
}

- (void) pushFindFriendsView {
    FindFriendsTableViewController *findFriendsView = [self.storyboard instantiateViewControllerWithIdentifier:@"findFriendsView"];
    [self.navigationController pushViewController:findFriendsView animated:YES];
}

#pragma mark - tungObjects/tungPodcasts delegate methods

- (void) initiatePodcastSearch {
    [_podcast.searchController setActive:YES];
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"revealSearch"];
    
    self.navigationItem.titleView = _podcast.searchController.searchBar;
    [self.navigationItem setRightBarButtonItem:nil animated:YES];
    
    [_podcast.searchController.searchBar becomeFirstResponder];
    
}

-(void) dismissPodcastSearch {
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"hideSearch"];
    
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tungNavBarLogo.png"]];
    UIBarButtonItem *searchBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiatePodcastSearch)];
    [self.navigationItem setRightBarButtonItem:searchBtn animated:YES];
    
}

#pragma mark - Feed

- (void) refreshFeed {
    
    [_tung checkReachabilityWithCallback:^(BOOL reachable) {
        if (reachable) {
            // refresh feed
            if (_tung.sessionId && _tung.sessionId.length > 0) {
                [_storiesView refreshFeed];
            }
            // get missing data or get session and feed
            else {
                [_storiesView getSessionAndFeed];
            }
        }
        // unreachable
        else {
            [TungCommonObjects showNoConnectionAlert];
            [_storiesView endRefreshing];
        }
    }];
}


@end
