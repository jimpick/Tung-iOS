//
//  FeedTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 8/7/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "FeedViewController.h"
#import "StoriesTableViewController.h"
#import "EpisodeViewController.h"
#import "PodcastViewController.h"
#import "ProfileViewController.h"
#import "IconButton.h"
#import "FindFriendsTableViewController.h"
#import "ProfileListTableViewController.h"

@interface FeedViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) TungPodcast *tungPodcast;
@property (strong, nonatomic) UISegmentedControl *switcher;
@property (strong, nonatomic) StoriesTableViewController *followingFeed;
@property (strong, nonatomic) StoriesTableViewController *trendingFeed;
@property NSInteger activeFeedIndex;
@property UIBarButtonItem *findFriendsBarButtonItem;

@end

@implementation FeedViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    _switcher = [[UISegmentedControl alloc] initWithItems:@[@"Trending", @"Following"]];
    _switcher.tintColor = [TungCommonObjects tungColor];
    _switcher.frame = CGRectMake(0, 0, 200, 28);
    _switcher.selectedSegmentIndex = 0;
    [_switcher addTarget:self action:@selector(switchFeeds:) forControlEvents:UIControlEventValueChanged];
    //UIBarButtonItem *switcherBarItem = [[UIBarButtonItem alloc] initWithCustomView:(UIView *)_switcher];
    //UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    self.navigationItem.titleView = _switcher;
    //self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tungNavBarLogo.png"]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiatePodcastSearch)];
    
    _tung = [TungCommonObjects establishTungObjects];
    
    // for search controller
    _tungPodcast = [TungPodcast new];
    _tungPodcast.navController = [self navigationController];
    _tungPodcast.delegate = self;
    
    // find friends button
    IconButton *findFriendsInner = [[IconButton alloc] initWithFrame:CGRectMake(0, 0, 34, 34)];
    findFriendsInner.type = kIconButtonTypeFindFriends;
    findFriendsInner.color = [TungCommonObjects tungColor];
    [findFriendsInner addTarget:self action:@selector(pushFindFriendsView) forControlEvents:UIControlEventTouchUpInside];
    _findFriendsBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:findFriendsInner];
    self.navigationItem.leftBarButtonItem = _findFriendsBarButtonItem;
    
    // Following feed
    _followingFeed = [self.storyboard instantiateViewControllerWithIdentifier:@"storiesTableView"];
    _followingFeed.isForFollowing = YES;
    //_followingFeed.edgesForExtendedLayout = UIRectEdgeNone; // seems to not do anything
    [self addChildViewController:_followingFeed];
    _followingFeed.navController = [self navigationController];
    _followingFeed.profiledUserId = @"";
    [self.view addSubview:_followingFeed.view];
    
    /* There's some kind of bug in 9.0 that causes edgesForExtendedLayout to not behave properly.
     ONLY in 9.0 (not 8.4 or 9.1+) the top constraint needs to be 64 so stories feed isn't positioned behind nav bar.
     I tried every combination imaginable for edgesForExtendedLayout, automaticallyAdjustsScrollViewInsets, 
     and extendedLayoutIncludesOpaqueBars. Without the top constraint the status bar will be transparent or 
     feed will positioned wrong. The translucence of the nav bar also affects the layout.
     
     doesn't seem to be an issue with 2 child view controllers (instead of 1)
     
    CGFloat topConstraint = 0;
    NSInteger majorVersion = [[NSProcessInfo processInfo] operatingSystemVersion].majorVersion;
    NSInteger minorVersion = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
    NSString *version = [NSString stringWithFormat:@"%ld.%ld", (long)majorVersion, (long)minorVersion];
    if ([version isEqualToString:@"9.0"]) topConstraint = 64;
     */
    
    CGFloat bottomConstraint = -44;
    
    _followingFeed.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_followingFeed.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:64]]; // top constraint
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_followingFeed.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_followingFeed.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:bottomConstraint]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_followingFeed.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_followingFeed.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_followingFeed.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_followingFeed.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    _followingFeed.view.hidden = YES;
    
    // trending feed
    _trendingFeed = [self.storyboard instantiateViewControllerWithIdentifier:@"storiesTableView"];
    _trendingFeed.isForTrending = YES;
    //_followingFeed.edgesForExtendedLayout = UIRectEdgeNone; // seems to not do anything
    [self addChildViewController:_trendingFeed];
    _trendingFeed.navController = [self navigationController];
    _trendingFeed.profiledUserId = @"";
    [self.view insertSubview:_trendingFeed.view atIndex:1];
    
    _trendingFeed.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_trendingFeed.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_trendingFeed.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_trendingFeed.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:bottomConstraint]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_trendingFeed.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_trendingFeed.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_trendingFeed.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_trendingFeed.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    _trendingFeed.view.hidden = NO;
    
    // first load
    _tung.feedNeedsRefresh = [NSNumber numberWithBool:YES];
    _tung.trendingFeedNeedsRefresh = [NSNumber numberWithBool:YES];
    
    // notifs
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareView) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleUniversalLink:) name:@"receivedUniversalLink" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pushFindFriendsView) name:@"shouldPushFindFriends" object:nil];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) viewWillAppear:(BOOL)animated {
    self.navigationController.navigationBar.translucent = NO;
    self.definesPresentationContext = YES;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    _tung.viewController = self;
    [self prepareView];
        
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    //self.navigationController.navigationBar.translucent = YES;
    [_tungPodcast.feedPreloadQueue cancelAllOperations];
    self.definesPresentationContext = NO;
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    /* ppl want what was there to remain
    if (_tungPodcast.searchController.active) {
        [_tungPodcast.searchController setActive:NO];
        [self dismissPodcastSearch];
    }*/
}

- (void) prepareView {
    // if feed hasn't been fetched in the last 5 minutes
    [_tung checkFeedsLastFetchedTime];
    
    [self refreshActiveFeedAsNeeded];
    
}

#pragma mark - handling Universal links

- (void) handleUniversalLink:(NSNotification *)notification {
    
    NSArray *components = [[notification userInfo] objectForKey:@"pathComponents"];
    //NSLog(@"handle universal link: %@", components);
    
    if (components.count >= 3) {
        if ([components[1] isEqualToString:@"e"]) {
            // episode
            [self pushEpisodeViewForEpisodeShortlink:components[2]];
        }
        else if ([components[1] isEqualToString:@"p"]) {
            // podcast
            [self pushPodcastViewForId:components[2]];
        }
        else if ([components[1] isEqualToString:@"u"]) {
            // user
            [self pushProfileViewForUsername:components[2]];
        }
    }
    
}

- (void) pushEpisodeViewForEpisodeShortlink:(NSString *)shortlink {
    
    EpisodeViewController *episodeView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"episodeView"];
    episodeView.episodeShortlink = shortlink;
    
    [self.navigationController pushViewController:episodeView animated:YES];
}

- (void) pushPodcastViewForId:(NSString *)collectionId {
    PodcastViewController *podcastView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"podcastView"];
    podcastView.collectionId = collectionId;
    [self.navigationController pushViewController:podcastView animated:YES];
}

- (void) pushProfileViewForUsername:(NSString *)username {
    // push profile
    if ([username isEqualToString:_tung.loggedInUser.username]) {
        AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate switchTabBarSelectionToTabIndex:3];
    }
    else {
        ProfileViewController *profileView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"profileView"];
        profileView.profiledUsername = username;
        [self.navigationController pushViewController:profileView animated:YES];
    }
}

#pragma mark - misc view maintenance


- (void) refreshActiveFeedAsNeeded {
    // trending feed
    if (_switcher.selectedSegmentIndex == 0) {
        [_trendingFeed.tableView reloadData];
        if (_tung.trendingFeedNeedsRefetch.boolValue) {
            [_trendingFeed refetchFeed];
        }
        else if (_tung.trendingFeedNeedsRefresh.boolValue) {
            [_trendingFeed refreshFeed];
        }
    }
    // following feed
    else {
        [_followingFeed.tableView reloadData];
        if (_tung.feedNeedsRefetch.boolValue) {
            [_followingFeed refetchFeed];
        }
        else if (_tung.feedNeedsRefresh.boolValue) {
            // let's get retarded in here
            [_followingFeed refreshFeed];
        }
    }
}

- (void) pushFindFriendsView {
    FindFriendsTableViewController *findFriendsView = [self.storyboard instantiateViewControllerWithIdentifier:@"findFriendsView"];
    [self.navigationController pushViewController:findFriendsView animated:YES];
}

- (void) switchFeeds:(id)sender {
    
    UISegmentedControl *switcher = (UISegmentedControl *)sender;
    //NSLog(@"switcher selected index: %ld", (long)switcher.selectedSegmentIndex);
    if (switcher.selectedSegmentIndex == 0) {
        _followingFeed.view.hidden = YES;
        _trendingFeed.view.hidden = NO;
        [_followingFeed stopClipPlayback];
    } else {
        _followingFeed.view.hidden = NO;
        _trendingFeed.view.hidden = YES;
        [_trendingFeed stopClipPlayback];
    }
    [self refreshActiveFeedAsNeeded];
    
}

#pragma mark - tungObjects/tungPodcasts delegate methods

- (void) initiatePodcastSearch {
    [_tungPodcast.searchController setActive:YES];
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"revealSearch"];
    
    self.navigationItem.titleView = _tungPodcast.searchController.searchBar;
    [self.navigationItem setRightBarButtonItem:nil animated:YES];
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    
    [_tungPodcast.searchController.searchBar becomeFirstResponder];
}

-(void) dismissPodcastSearch {
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"hideSearch"];
    
    self.navigationItem.titleView = _switcher;
    UIBarButtonItem *searchBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiatePodcastSearch)];
    [self.navigationItem setRightBarButtonItem:searchBtn animated:YES];
    [self.navigationItem setLeftBarButtonItem:_findFriendsBarButtonItem animated:YES];
    
}


@end
