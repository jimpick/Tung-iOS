//
//  FeedTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 8/7/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "FeedViewController.h"
#import "StoriesTableViewController.h"

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
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiateSearch)];
    
    _tung = [TungCommonObjects establishTungObjects];
    [_tung establishCred];
    
    // for search controller
    _podcast = [TungPodcast new];
    self.definesPresentationContext = YES;
    _podcast.navController = [self navigationController];
    _podcast.delegate = self;
    
    // FEED
    _storiesView = [self.storyboard instantiateViewControllerWithIdentifier:@"storiesTableView"];
    _storiesView.navController = [self navigationController];
    _storiesView.viewController = self;
    _storiesView.profiledUserId = @"";
    
    //_storiesView.edgesForExtendedLayout = UIRectEdgeNone; // seems to not do anything
    [self addChildViewController:_storiesView];
    [self.view addSubview:_storiesView.view];
    
    
    CGFloat topConstraint = 0;
    /* There's some kind of bug in 9.0 that causes edgesForExtendedLayout to not behave properly.
     ONLY in 9.0 (not 8.4 or 9.1) the top constraint needs to be 64 so stories feed isn't positioned behind nav bar.
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
    
    _hasPodcastData = [TungCommonObjects checkForPodcastData];
    _hasUserData = [TungCommonObjects checkForUserData];
    
    // first load
    _tung.feedNeedsRefresh = [NSNumber numberWithBool:YES];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) viewWillAppear:(BOOL)animated {
    self.navigationController.navigationBar.translucent = NO;
    

}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    _tung.ctrlBtnDelegate = self;
    _tung.viewController = self;
    
    // let's get retarded in here
    if (_tung.feedNeedsRefresh.boolValue) {
    	[self refreshFeed];
    }
    
    self.navigationController.navigationBar.translucent = NO;
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    //self.navigationController.navigationBar.translucent = YES;
    NSLog(@"cancel feed preloading");
    [_podcast.feedPreloadQueue cancelAllOperations];

}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (_podcast.searchController.active) {
        NSLog(@"search was active, dismissed!");
        [_podcast.searchController setActive:NO];
        [self dismissPodcastSearch];
    }
}

#pragma mark - tungObjects/tungPodcasts delegate methods

- (void) initiateSearch {
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
    UIBarButtonItem *searchBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiateSearch)];
    [self.navigationItem setRightBarButtonItem:searchBtn animated:YES];
    
}

#pragma mark - Feed

- (void) refreshFeed {
    
    [TungCommonObjects checkReachabilityWithCallback:^(BOOL reachable) {
        if (reachable) {
            // refresh feed
            if (_tung.sessionId && _tung.sessionId.length > 0) {
                [_storiesView refreshFeed:YES];
            }
            // get missing data or get session and feed
            else {
                if (!_hasUserData || !_hasPodcastData) {
                    // since this is the first call the app makes, check to see if user has no podcast
                    // data or no user data so it can be restored. Does not YET sync track progress
                    [_tung getSessionWithCallback:^{
                        NSLog(@"has USER data: %@", (_hasUserData) ? @"Yes" : @"No");
                        if (!_hasUserData) {
                            [_tung getProfileDataForUser:_tung.tungId withCallback:^(NSDictionary *jsonData) {
                                if (jsonData != nil) {
                                    NSDictionary *responseDict = jsonData;
                                    if ([responseDict objectForKey:@"user"]) {
                                        NSLog(@"got user: %@", [responseDict objectForKey:@"user"]);
                                        [TungCommonObjects saveUserWithDict:[responseDict objectForKey:@"user"]];
                                        _hasUserData = YES;
                                    }
                                }
                            }];
                        }
                        NSLog(@"has PODCAST data: %@", (_hasPodcastData) ? @"Yes" : @"No");
                        if (!_hasPodcastData) {
                            [_tung restorePodcastDataWithCallback:^(BOOL success, NSDictionary *response) {
                                if (success) {
                                    if ([response objectForKey:@"podcasts"]) {
                                        // restore subscribes
                                        NSArray *podcasts = [response objectForKey:@"podcasts"];
                                        for (NSDictionary *podcastDict in podcasts) {
                                            [TungCommonObjects getEntityForPodcast:podcastDict save:YES];
                                        }
                                    }
                                    if ([response objectForKey:@"episodes"]) {
                                        // restore recommends
                                        NSArray *episodes = [response objectForKey:@"episodes"];
                                        for (NSDictionary *episodeDict in episodes) {
                                            NSDictionary *eDict = [episodeDict objectForKey:@"episode"];
                                            NSDictionary *pDict = [episodeDict objectForKey:@"podcast"];
                                            [TungCommonObjects getEntityForPodcast:pDict andEpisode:eDict save:YES];
                                        }
                                    }
                                    _hasPodcastData = YES;
                                }
                                // get feed
                                [_storiesView refreshFeed:YES];
                            }];
                        }
                    }];
                }
                // if has data
                else {
                    [_storiesView getSessionAndFeed];
                }
            }
        }
        // unreachable
        else {
            _tung.connectionAvailable = [NSNumber numberWithInt:0];
            UIAlertView *noReachabilityAlert = [[UIAlertView alloc] initWithTitle:@"No Connection" message:@"tung requires an internet connection" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
            [noReachabilityAlert setTag:49];
            [noReachabilityAlert show];
        }
    }];
}


@end
