//
//  ProfileViewController.m
//  Tung
//
//  Created by Jamie Perkins on 10/4/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import "ProfileViewController.h"
#import "StoriesTableViewController.h"
#import "ProfileHeaderView.h"
#import "AvatarContainerView.h"
#import "ProfileListTableViewController.h"
#import "BrowserViewController.h"
#import "IconButton.h"
#import "FindFriendsTableViewController.h"

@class TungCommonObjects;

@interface ProfileViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) StoriesTableViewController *storiesView;
@property (strong, nonatomic) ProfileHeaderView *profileHeader;
@property UIBarButtonItem *tableHeaderLabel;
@property NSURL *urlToPass;
@property UserEntity *userEntity;

@property BOOL isLoggedInUser;
@property BOOL reachable;

// search
@property UISearchController *searchController;
@property ProfileListTableViewController *profileSearchView;
@property ProfileListTableViewController *notificationsView;
@property UIBarButtonItem *profileSearchButton;
@property NSTimer *searchTimer;
@property (strong, nonatomic) NSURLConnection *profileSearchConnection;
@property (strong, nonatomic) NSMutableData *profileSearchResultData;
@property (strong, nonatomic) NSMutableArray *profileArray;

// switcher
@property UIToolbar *switcherBar;
@property UISegmentedControl *switcher;
@property NSInteger switcherIndex;

@property CGFloat screenWidth;


@end

@implementation ProfileViewController

- (void) viewDidLoad {
    
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    _tung.ctrlBtnDelegate = self;
    
    _screenWidth = [TungCommonObjects screenSize].width;
    
    // profiled user
    if (!_profiledUserId) {
        _profiledUserId = _tung.tungId;
        
        _isLoggedInUser = YES;
        self.navigationItem.title = @"My Profile";
        
        // settings button
        IconButton *settingsInner = [[IconButton alloc] initWithFrame:CGRectMake(0, 0, 34, 34)];
        settingsInner.type = kIconButtonTypeSettings;
        settingsInner.color = [TungCommonObjects tungColor];
        [settingsInner addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *signOutButton = [[UIBarButtonItem alloc] initWithCustomView:settingsInner];
        self.navigationItem.leftBarButtonItem = signOutButton;
        // profile search button
        IconButton *profileSearchInner = [[IconButton alloc] initWithFrame:CGRectMake(0, 0, 34, 34)];
        profileSearchInner.type = kIconButtonTypeProfileSearch;
        profileSearchInner.color = [TungCommonObjects tungColor];
        //[profileSearchInner addTarget:self action:@selector(initiateProfileSearch) forControlEvents:UIControlEventTouchUpInside];
        [profileSearchInner addTarget:self action:@selector(pushFindFriendsView) forControlEvents:UIControlEventTouchUpInside];
        _profileSearchButton = [[UIBarButtonItem alloc] initWithCustomView:profileSearchInner];
        self.navigationItem.rightBarButtonItem = _profileSearchButton;
        
        // profile search
        _profileSearchView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileListView"];
        _profileSearchView.tableView.backgroundColor = [UIColor clearColor];
        _profileSearchView.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
        _profileSearchView.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectZero];
        _profileSearchView.tableView.backgroundView = nil;
        _profileSearchView.navController = [self navigationController];
        _profileSearchView.profileArray = [NSMutableArray array];
        //_profileSearchView.queryType = @"Search";
        
        _searchController = [[UISearchController alloc] initWithSearchResultsController:_profileSearchView];
        _searchController.delegate = self;
        _searchController.hidesNavigationBarDuringPresentation = NO;
        
        _searchController.searchBar.delegate = self;
        _searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
        _searchController.searchBar.tintColor = [TungCommonObjects tungColor];
        _searchController.searchBar.showsCancelButton = YES;
        _searchController.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _searchController.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
        _searchController.searchBar.placeholder = @"Find people on Tung";
        _searchController.searchBar.frame = CGRectMake(self.searchController.searchBar.frame.origin.x, self.searchController.searchBar.frame.origin.y, self.searchController.searchBar.frame.size.width, 44.0);
        
    } else {
        self.navigationItem.title = @"Loading...";
        // first if above determines if this is the profile page by checking if
        // profiledUserId is set, but logged in user's id may still be pushed
        if ([_profiledUserId isEqualToString:_tung.tungId]) {
            _isLoggedInUser = YES;
        }
    }
    
    self.definesPresentationContext = YES;
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    // profile header
    CGFloat topConstraint = 64;
    CGFloat profileHeaderHeight = 223;
    _profileHeader = [[ProfileHeaderView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, profileHeaderHeight)];
	[self.view addSubview:_profileHeader];
    _profileHeader.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_profileHeader attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:topConstraint]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_profileHeader attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    NSLayoutConstraint *profileHeightConstraint = [NSLayoutConstraint constraintWithItem:_profileHeader attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:profileHeaderHeight];
    [_profileHeader addConstraint:profileHeightConstraint];
    [_profileHeader addConstraint:[NSLayoutConstraint constraintWithItem:_profileHeader attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:self.view.frame.size.width]];
    
    _profileHeader.scrollView.delegate = self;
    _profileHeader.largeAvatarView.backgroundColor = [UIColor clearColor];
    _profileHeader.largeAvatarView.borderColor = [UIColor whiteColor];
    _profileHeader.largeAvatarView.hidden = YES;
    _profileHeader.editFollowBtn.hidden = YES;
    
    _profileHeader.basicInfoWebView.delegate = self;
    _profileHeader.bioWebView.delegate = self;
    [_profileHeader.basicInfoWebView setBackgroundColor:[UIColor clearColor]];
    [_profileHeader.bioWebView setBackgroundColor:[UIColor clearColor]];
    [_profileHeader.basicInfoWebView.scrollView setScrollEnabled:NO];
    [_profileHeader.bioWebView.scrollView setScrollEnabled:NO];
    
    [_profileHeader.followingCountBtn addTarget:self action:@selector(viewFollowing) forControlEvents:UIControlEventTouchUpInside];
    [_profileHeader.followerCountBtn addTarget:self action:@selector(viewFollowers) forControlEvents:UIControlEventTouchUpInside];
    
    // switcher bar
    _switcherBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    _switcherBar.clipsToBounds = YES;
//    _switcherBar.opaque = YES;
//    _switcherBar.translucent = NO;
    _switcherBar.backgroundColor = [UIColor whiteColor];
    // set up segemented control
    NSArray *switcherItems = @[@"Notifications", @"My Activity"];
    _switcher = [[UISegmentedControl alloc] initWithItems:switcherItems];
    //_switcher.apportionsSegmentWidthsByContent = YES;
    _switcher.tintColor = [TungCommonObjects tungColor];
    _switcher.frame = CGRectMake(0, 0, self.view.bounds.size.width - 20, 28);
    [_switcher addTarget:self action:@selector(switchViews:) forControlEvents:UIControlEventValueChanged];
    UIBarButtonItem *switcherBarItem = [[UIBarButtonItem alloc] initWithCustomView:(UIView *)_switcher];
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    
    if (_isLoggedInUser) {
    	[_switcherBar setItems:@[flexSpace, switcherBarItem, flexSpace] animated:NO];
    } else {
        _tableHeaderLabel = [[UIBarButtonItem alloc] initWithTitle:@"Activity" style:UIBarButtonItemStylePlain target:self action:nil];
        _tableHeaderLabel.tintColor = [TungCommonObjects tungColor];
        UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil];
        fixedSpace.width = 1;
        [_switcherBar setItems:@[fixedSpace, _tableHeaderLabel] animated:NO];
    }
    [self.view addSubview:_switcherBar];
    _switcherBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_switcherBar attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_profileHeader attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [_switcherBar addConstraint:[NSLayoutConstraint constraintWithItem:_switcherBar attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:44]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_switcherBar attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_switcherBar.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_switcherBar attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_switcherBar.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
    CGFloat bottomConstraint = -44;
    
    // for activity feed
    _storiesView = [self.storyboard instantiateViewControllerWithIdentifier:@"storiesTableView"];
    _storiesView.profiledUserId = _profiledUserId;
    // for animating header
    _storiesView.profileHeader = _profileHeader;
    _storiesView.profileHeightConstraint = profileHeightConstraint;
    
    _storiesView.edgesForExtendedLayout = UIRectEdgeNone;
    _storiesView.tableView.contentInset = UIEdgeInsetsMake(0, 0, -5, 0);
    [self addChildViewController:_storiesView];
    [self.view addSubview:_storiesView.view];
    _storiesView.navController = [self navigationController];
    
    _storiesView.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_storiesView.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_switcherBar attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_storiesView.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_storiesView.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:bottomConstraint]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_storiesView.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_storiesView.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_storiesView.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_storiesView.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
    // notifications view
    if (_isLoggedInUser) {
        _notificationsView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileListView"];
        _notificationsView.queryType = @"Notifications";
        _notificationsView.target_id = _tung.tungId;
        _notificationsView.edgesForExtendedLayout = UIRectEdgeNone;
        _notificationsView.tableView.contentInset = UIEdgeInsetsMake(0, 0, -5, 0);
        [self addChildViewController:_notificationsView];
        [self.view addSubview:_notificationsView.view];
        _notificationsView.navController = [self navigationController];
        
        _notificationsView.view.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_notificationsView.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_switcherBar attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_notificationsView.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_notificationsView.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:bottomConstraint]];
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_notificationsView.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_notificationsView.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_notificationsView.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_notificationsView.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
        
        _switcherIndex = 0;
        [_switcher setSelectedSegmentIndex:_switcherIndex];
        [self switchViews:_switcher];
    }
    
    
	// get data in viewDidAppear
    _tung.profileNeedsRefresh = [NSNumber numberWithBool:YES];
    _tung.profileFeedNeedsRefresh = [NSNumber numberWithBool:YES];
    
    // notifs
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareView) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(followingCountChanged:) name:@"followingCountChanged" object:nil];
    
}

NSTimer *promptTimer;

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _tung.viewController = self;
    [self.navigationController.navigationBar setTitleTextAttributes:@{ NSForegroundColorAttributeName:[TungCommonObjects tungColor] }];
    // scroll view
    if (!_profileHeader.contentSizeSet) {
        CGSize contentSize = _profileHeader.scrollView.contentSize;
        //JPLog(@"scroll view content size: %@", NSStringFromCGSize(_profileHeader.scrollView.contentSize));
        contentSize.width = contentSize.width * 2;
        _profileHeader.scrollView.contentSize = contentSize;
        _profileHeader.scrollView.contentInset = UIEdgeInsetsZero;
        //JPLog(@"scroll view NEW content size: %@", NSStringFromCGSize(contentSize));
        _profileHeader.contentSizeSet = YES;
    }
    
    [self prepareView];

}

- (void) prepareView {
    SettingsEntity *settings = [TungCommonObjects settings];
    
    // refresh based on flags
    if (_isLoggedInUser) {
        // profile header view and activity feed
        if (_tung.profileFeedNeedsRefresh.boolValue && _tung.profileNeedsRefresh.boolValue) {
            //JPLog(@"profile feed and data need refresh");
            [self requestPageData];
        }
        else if (_tung.profileFeedNeedsRefetch.boolValue) {
            [_storiesView refetchFeed];
        }
        else if (_tung.profileFeedNeedsRefresh.boolValue) {
            //JPLog(@"profile feed needs refresh");
            [_storiesView refreshFeed];
        }
        else if (_tung.profileNeedsRefresh.boolValue) {
            //JPLog(@"profile data needs refresh");
            [self refreshProfile];
        }
        // notifications
        if (_tung.notificationsNeedRefresh.boolValue) {
            //[_notificationsView.refreshControl beginRefreshing]; // doesn't seem to work
            //[_notificationsView.tableView setContentOffset:CGPointMake(0, -_notificationsView.refreshControl.frame.size.height) animated:YES];
            [_notificationsView refreshFeed];
        }
        // clear colored background on new notifications
        else if (_notificationsView.profileArray.count > 0) {
            [_notificationsView.tableView reloadData];
        }
        
        // clear profile badge and adjust app badge
        if (settings.numProfileNotifications.integerValue > 0) {
            
            NSInteger startingVal = settings.numProfileNotifications.integerValue;
            if ([UIApplication sharedApplication].applicationIconBadgeNumber > 0) {
                [UIApplication sharedApplication].applicationIconBadgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber - settings.numProfileNotifications.integerValue;
            }
            settings.numProfileNotifications = [NSNumber numberWithInteger:0];
            [_tung setBadgeNumber:[NSNumber numberWithInteger:0] forBadge:_tung.profileBadge];
            [TungCommonObjects saveContextWithReason:@"adjust subscriptions badge number"];
            // adjust app icon badge number
            NSInteger newBadgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber - startingVal;
            newBadgeNumber = MAX(0, newBadgeNumber);
            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:newBadgeNumber];
        }
        
    } else {
        [self requestPageData];
    }
    
    if (!settings.hasSeenMentionsPrompt.boolValue && ![TungCommonObjects hasGrantedNotificationPermissions]) {
        promptTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:_tung selector:@selector(promptForNotificationsForMentions) userInfo:nil repeats:NO];
    }
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [promptTimer invalidate];
    /*
    @try {
    	[self removeObserver:self forKeyPath:@"storiesView.requestStatus"];
    }
    @catch (id exception) {}
    */
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    /*
    if (_isLoggedInUser && _searchController.active) {
        [_searchController setActive:NO];
        [self dismissProfileSearch];
    }*/
}


- (void) switchViews:(id)sender {
    UISegmentedControl *switcher = (UISegmentedControl *)sender;
    
    switch (switcher.selectedSegmentIndex) {
        case 1: // show activity
            _storiesView.view.hidden = NO;
            _notificationsView.view.hidden = YES;
            break;
        default: // show notifications
            _notificationsView.view.hidden = NO;
            _storiesView.view.hidden = YES;
            break;
    }
    _switcherIndex = switcher.selectedSegmentIndex;
}


#pragma mark Profile search

- (void) initiateProfileSearch {
    [_searchController setActive:YES];
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"revealSearch"];
    
    self.navigationItem.titleView = _searchController.searchBar;
    [self.navigationItem setRightBarButtonItem:nil animated:YES];
    
    [_searchController.searchBar becomeFirstResponder];
    
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(reloadSearchTable) userInfo:nil repeats:NO];
    
}

- (void) reloadSearchTable {
    NSLog(@"reload search table");
    [_profileSearchView.tableView reloadData];
}

-(void) dismissProfileSearch {
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"hideSearch"];
    
    self.navigationItem.titleView = nil;
    [self.navigationItem setRightBarButtonItem:_profileSearchButton animated:YES];
    
}

#pragma mark - Search Bar delegate methods

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    
    [_searchTimer invalidate];
    // timeout to resign keyboard
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(resignKeyboard) userInfo:nil repeats:NO];
    // search
    [self searchProfilesWithTerm:searchBar.text];
    
}
-(void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    //JPLog(@"search bar text did change: %@", searchText);
    [_searchTimer invalidate];
    if (searchText.length > 1) {
        _searchTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(keyupSearch:) userInfo:searchText repeats:NO];
    }
    else {
        [_profileSearchView.profileArray removeAllObjects];
        [_profileSearchView.tableView reloadData];
    }
}

- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar {
    return YES;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    _searchController.searchBar.text = @""; // clear search
    [self dismissProfileSearch];
}

#pragma mark - UISearchControllerDelegate methods

- (void) didDismissSearchController:(UISearchController *)searchController {
    _searchController.searchBar.text = @""; // clear search
    [self dismissProfileSearch];
}
#pragma mark - Search general methods

-(void) keyupSearch:(NSTimer *)timer {
    [self searchProfilesWithTerm:timer.userInfo];
}

- (void) resignKeyboard {
    [_searchController.searchBar resignFirstResponder];
}

// PODCAST SEARCH
-(void) searchProfilesWithTerm:(NSString *)searchTerm {
    
    if (searchTerm.length > 0) {
        
        _profileSearchView.noResults = NO;
        
        NSURL *profileSearchUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/profile-search.php", _tung.apiRootUrl]];
        NSMutableURLRequest *profileSearchRequest = [NSMutableURLRequest requestWithURL:profileSearchUrl cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:6.0f];
        [profileSearchRequest setHTTPMethod:@"POST"];
        NSDictionary *params = @{@"sessionId":_tung.sessionId,
                                 @"searchTerm": searchTerm };
        NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
        [profileSearchRequest setHTTPBody:serializedParams];
        
        // reset data and connection
        _profileSearchResultData = nil;
        _profileSearchResultData = [NSMutableData new];
        
        if (_profileSearchConnection) {
            [_profileSearchConnection cancel];
            _profileSearchConnection = nil;
        }
        _profileSearchConnection = [[NSURLConnection alloc] initWithRequest:profileSearchRequest delegate:self];
        //JPLog(@"search profiles for: %@", searchTerm);
    }
}

#pragma mark - NSURLConnection delegate methods


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    //JPLog(@"did receive data");
    [_profileSearchResultData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    NSError *error;
    id jsonData = [NSJSONSerialization JSONObjectWithData:_profileSearchResultData options:NSJSONReadingAllowFragments error:&error];
    if (jsonData != nil && error == nil) {
        if ([jsonData isKindOfClass:[NSDictionary class]]) {
            NSDictionary *responseDict = jsonData;
            if ([responseDict objectForKey:@"error"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        JPLog(@"SESSION EXPIRED");
                        [_tung getSessionWithCallback:^{
                            [self searchProfilesWithTerm:_searchController.searchBar.text];
                        }];
                    } else {
                        // other error - alert user
                        UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:[responseDict objectForKey:@"error"] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                        [errorAlert show];
                    }
                });
            }
        }
        else if ([jsonData isKindOfClass:[NSArray class]]) {
            
            _profileSearchView.queryExecuted = YES;
            
            NSArray *newUsers = jsonData;
            
            if (newUsers.count > 0) {
                
                _profileSearchView.profileArray = [newUsers mutableCopy];
                
                //JPLog(@"got results: %lu", (unsigned long)_profileSearchView.profileArray.count);
                //JPLog(@"%@", _profileArray);
                [_profileSearchView preloadAvatars];
                [_profileSearchView.tableView reloadData];
                
            }
            else {
                _profileSearchView.noResults = YES;
                _profileSearchView.profileArray = [NSMutableArray array];
                //JPLog(@"NO RESULTS");
                [_profileSearchView.tableView reloadData];
            }
        }
    }
    else if ([_profileSearchResultData length] == 0 && error == nil) {
        JPLog(@"no response for profile search");
        
    }
    else if (error != nil) {
        
        JPLog(@"Error: %@", error);
        NSString *html = [[NSString alloc] initWithData:_profileSearchResultData encoding:NSUTF8StringEncoding];
        JPLog(@"HTML: %@", html);
    }
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {
    JPLog(@"connection failed: %@", error);
    /* this error pops up occaisionally, probably because of rapid requests.
     makes user think something is wrong when it really isn't.
     
     [_tung showConnectionErrorAlertForError:error];
     */
}

/* unused NSURLConnection delegate methods
 - (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	JPLog(@"connection received response: %@", response);
 }
 
 */

#pragma mark - specific to Profile View

NSTimer *sessionCheckTimer;

- (void) requestPageData {
    
    // make sure session id is set, in case user switched to this view really fast
    if (_tung.sessionId.length == 0) {
        [sessionCheckTimer invalidate];
        sessionCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(requestPageData) userInfo:nil repeats:NO];
        return;
    }
    [sessionCheckTimer invalidate];
    sessionCheckTimer = nil;
    [_tung checkReachabilityWithCallback:^(BOOL reachable) {
        if (reachable) {
        
            if (_isLoggedInUser) {
                _profiledUserData = [[_tung getLoggedInUserData] mutableCopy];
                if (_profiledUserData) {
                    //JPLog(@"Is logged in user: Has logged-in user data.");
                    [self setUpProfileHeaderViewForData];
                    // request profile just to get current follower/following counts
                    [_tung getProfileDataForUser:_tung.tungId withCallback:^(NSDictionary *jsonData) {
                        if (jsonData != nil) {
                            NSDictionary *responseDict = jsonData;
                            if ([responseDict objectForKey:@"user"]) {
                                _profiledUserData = [[responseDict objectForKey:@"user"] mutableCopy];
                                [self updateUserFollowingCounts];
                                if (_tung.profileFeedNeedsRefresh.boolValue) {
                                    [_storiesView refreshFeed];
                                }
                            }
                        }
                    }];
                }
                else {
                    // restore logged in user data
                    JPLog(@"Is logged in user: Was missing logged-in user data - fetching");
                    [_tung getProfileDataForUser:_tung.tungId withCallback:^(NSDictionary *jsonData) {
                        if (jsonData != nil) {
                            NSDictionary *responseDict = jsonData;
                            if ([responseDict objectForKey:@"user"]) {
                                //JPLog(@"got user: %@", [responseDict objectForKey:@"user"]);
                                [TungCommonObjects saveUserWithDict:[responseDict objectForKey:@"user"]];
                                _profiledUserData = [[responseDict objectForKey:@"user"] mutableCopy];
                                [self setUpProfileHeaderViewForData];
                                if (_tung.profileFeedNeedsRefresh.boolValue) {
                                    [_storiesView refreshFeed];
                                }
                            }
                        }
                    }];
                }
            }
            else {
                
                [_tung getProfileDataForUser:_profiledUserId withCallback:^(NSDictionary *jsonData) {
                    if (jsonData != nil) {
                        NSDictionary *responseDict = jsonData;
                        if ([responseDict objectForKey:@"user"]) {
                            _profiledUserData = [[responseDict objectForKey:@"user"] mutableCopy];
                            //JPLog(@"profiled user data %@", _profiledUserData);
                            [self setUpProfileHeaderViewForData];
                            if (_tung.profileFeedNeedsRefresh.boolValue) {
                                [_storiesView refreshFeed];
                            }
                        }
                        else if ([responseDict objectForKey:@"error"]) {
                            UIAlertView *profileErrorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:[responseDict objectForKey:@"error"] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                            [profileErrorAlert show];
                            // TODO: user not found, if user was deleted
                        }
                    }
                }];
            }
        }
        // unreachable
        else {
            [_tung showNoConnectionAlert];
        }
    }];
}

- (void) refreshProfile {
    [_tung getProfileDataForUser:_profiledUserId withCallback:^(NSDictionary *jsonData) {
        if (jsonData != nil) {
            NSDictionary *responseDict = jsonData;
            if ([responseDict objectForKey:@"user"]) {
                _profiledUserData = [[responseDict objectForKey:@"user"] mutableCopy];
                [self setUpProfileHeaderViewForData];
                _tung.profileNeedsRefresh = [NSNumber numberWithBool:NO];
            }
        }
    }];
}

- (void) setUpProfileHeaderViewForData {
    
    // navigation bar title
    if (_isLoggedInUser) {
    	self.navigationItem.title = @"My Profile";
    } else {
        self.navigationItem.title = [_profiledUserData objectForKey:@"username"];
    }
    
    CGSize contentSize = _profileHeader.scrollSubViewOne.frame.size;
    //JPLog(@"scroll view starting content size: %@", NSStringFromCGSize(contentSize));
    
    // basic info web view
    NSString *style = [NSString stringWithFormat:@"<style type=\"text/css\">body { margin:0; color:white; font: .9em/1.4em -apple-system, Helvetica; } a { color:rgba(255,255,255,.6); } .name { font-size:1.1em; } .location { color:rgba(0,0,0,.4) } table { width:100%%; height:100%%; border-spacing:0; border-collapse:collapse; border:none; } td { text-align:center; vertical-align:middle; }</style>\n"];
    NSString *basicInfoBody = [NSString stringWithFormat:@"<table><td><p><span class=\"name\">%@</span>", [_profiledUserData objectForKey:@"name"]];
    NSString *location = [_profiledUserData objectForKey:@"location"];
    if (location.length > 0) {
        basicInfoBody = [basicInfoBody stringByAppendingString:[NSString stringWithFormat:@"<br><span class=\"location\">%@</span>", location]];
    }
    NSString *url = [_profiledUserData objectForKey:@"url"];
    if (url.length > 0) {
        NSString *displayUrl = [TungCommonObjects cleanURLStringFromString:url];
        basicInfoBody = [basicInfoBody stringByAppendingString:[NSString stringWithFormat:@"<br><a href=\"%@\">%@</a>", url, displayUrl]];
    }
    basicInfoBody = [basicInfoBody stringByAppendingString:@"</p></td></table>"];
    NSString *webViewString = [NSString stringWithFormat:@"%@%@", style, basicInfoBody];
    [_profileHeader.basicInfoWebView loadHTMLString:webViewString baseURL:[NSURL URLWithString:@"desc"]];
    
    // bio
    NSString *bio = [_profiledUserData objectForKey:@"bio"];
    if (bio.length > 0) {
        contentSize.width += contentSize.width;
        NSString *bioBody = [NSString stringWithFormat:@"<table><td>%@", bio];
        NSString *bioWebViewString = [NSString stringWithFormat:@"%@%@</td></table>", style, bioBody];
        [_profileHeader.bioWebView loadHTMLString:bioWebViewString baseURL:[NSURL URLWithString:@"desc"]];
    }
    else {
        _profileHeader.pageControl.hidden = YES;
        _profileHeader.scrollView.scrollEnabled = NO;
    }
    
    // avatar
    NSString *avatarUrlString = [_profiledUserData objectForKey:@"large_av_url"];
    NSData *largeAvatarImageData = [TungCommonObjects retrieveLargeAvatarDataWithUrlString:avatarUrlString];
    UIImage *largeAvImage = [[UIImage alloc] initWithData:largeAvatarImageData];
    _profileHeader.largeAvatarView.hidden = NO;
    _profileHeader.largeAvatarView.avatar = largeAvImage;
    [_profileHeader.largeAvatarView setNeedsDisplay];
    
    [self updateUserFollowingCounts];
    
    
    _profileHeader.scrollView.contentSize = contentSize;
    
}

// currently only used for when logged in user follows someone on their profile page (notifications)
- (void) followingCountChanged:(NSNotification*)notification {
    
    NSString *userId;
    NSNumber *increment = [NSNumber numberWithInteger:0];
    
    if ([[notification userInfo] objectForKey:@"unfollowTargetId"]) {
        userId = [[notification userInfo] objectForKey:@"unfollowTargetId"];
        increment = [NSNumber numberWithInteger:-1];
    }
    if ([[notification userInfo] objectForKey:@"followTargetId"]) {
        userId = [[notification userInfo] objectForKey:@"followTargetId"];
        increment = [NSNumber numberWithInteger:1];
    }
    if (_isLoggedInUser || [_profiledUserId isEqualToString:userId]) {
        NSNumber *currentFollowingCount = [_profiledUserData objectForKey:@"followingCount"];
        
        NSInteger newCount = [currentFollowingCount integerValue] + [increment integerValue];
        if (_isLoggedInUser) {
        	[_profiledUserData setObject:[NSNumber numberWithInteger:newCount] forKey:@"followingCount"];
        }
        else if ([_profiledUserId isEqualToString:userId]) {
            [_profiledUserData setObject:[NSNumber numberWithInteger:newCount] forKey:@"followerCount"];
        }
        [self updateUserFollowingCounts];
        
    }
}

- (void) updateUserFollowingCounts {
    
    // following
    NSString *followingString;
    if ([_profiledUserData objectForKey:@"followingCount"]) {
    	followingString = [TungCommonObjects formatNumberForCount:[_profiledUserData objectForKey:@"followingCount"]];
        [_profileHeader.followingCountBtn setEnabled:YES];
    } else {
        followingString = @"";
        [_profileHeader.followingCountBtn setEnabled:NO];
    }
    [_profileHeader.followingCountBtn setTitle:followingString forState:UIControlStateNormal];
    
    // followers
    NSString *followerString;
    if ([_profiledUserData objectForKey:@"followerCount"]) {
        followerString = [TungCommonObjects formatNumberForCount:[_profiledUserData objectForKey:@"followerCount"]];
        [_profileHeader.followerCountBtn setEnabled:YES];
    } else {
        followerString = @"";
        [_profileHeader.followerCountBtn setEnabled:NO];
    }
    [_profileHeader.followerCountBtn setTitle:followerString forState:UIControlStateNormal];
    // button
    _profileHeader.editFollowBtn.backgroundColor = [UIColor clearColor];
    _profileHeader.editFollowBtn.on = NO;
    if (_isLoggedInUser) {
        _profileHeader.editFollowBtn.type = kPillTypeOnDark;
        _profileHeader.editFollowBtn.buttonText = @"Edit profile";
        _profileHeader.editFollowBtn.on = NO;
        [_profileHeader.editFollowBtn addTarget:self action:@selector(editProfile) forControlEvents:UIControlEventTouchUpInside];
        
    } else {
        _profileHeader.editFollowBtn.type = kPillTypeFollow;
        [_profileHeader.editFollowBtn addTarget:self action:@selector(followOrUnfollowProfiledUser) forControlEvents:UIControlEventTouchUpInside];
        if ([[_profiledUserData objectForKey:@"userFollows"] boolValue]) {
            //_profileHeader.editFollowBtn.buttonText = @"Following";
            _profileHeader.editFollowBtn.on = YES;
        }
        else {
            //_profileHeader.editFollowBtn.buttonText = @"Follow";
            _profileHeader.editFollowBtn.on = NO;
        }
    }
    _profileHeader.editFollowBtn.hidden = NO;
    [_profileHeader.editFollowBtn setNeedsDisplay];
    
    _tung.profileNeedsRefresh = [NSNumber numberWithBool:NO];

}

- (void) viewFollowers {
    //JPLog(@"view followers");
    if ([[_profiledUserData objectForKey:@"followerCount"] integerValue] > 0)
    	[self pushProfileListForTargetId:_profiledUserId andQuery:@"Followers"];
}
- (void) viewFollowing {
    //JPLog(@"view following");
    if ([[_profiledUserData objectForKey:@"followingCount"] integerValue] > 0)
        [self pushProfileListForTargetId:_profiledUserId andQuery:@"Following"];
}
- (void) editProfile {
    //JPLog(@"edit profile");
    [self performSegueWithIdentifier:@"presentEditProfileView" sender:self];
}

- (void) followOrUnfollowProfiledUser {
    
    NSNumber *userFollowsStartingValue = [_profiledUserData objectForKey:@"userFollows"];
    NSNumber *followersStartingValue = [_profiledUserData objectForKey:@"followerCount"];
    BOOL follows = [userFollowsStartingValue boolValue];
    
    if (follows) {
        // unfollow
        [_tung unfollowUserWithId:_profiledUserId withCallback:^(BOOL success, NSDictionary *response) {
            if (success) {
                if (![response objectForKey:@"userNotFollowing"]) {
                	_tung.feedNeedsRefetch = [NSNumber numberWithBool:YES];
                }
            }
            else {
                [_profiledUserData setValue:userFollowsStartingValue forKey:@"userFollows"];
                [_profiledUserData setValue:followersStartingValue forKey:@"followerCount"];
                [self updateUserFollowingCounts];
            }
        }];
        [_profiledUserData setValue:[NSNumber numberWithInt:0] forKey:@"userFollows"];
        [_profiledUserData setValue:[NSNumber numberWithInt:[followersStartingValue intValue] -1] forKey:@"followerCount"];
    }
    else {
        // follow
        [_tung followUserWithId:_profiledUserId withCallback:^(BOOL success, NSDictionary *response) {
            if (success) {
                if (![response objectForKey:@"userAlreadyFollowing"]) {
                	_tung.feedNeedsRefresh = [NSNumber numberWithBool:YES];
                }
            }
            else {
                [_profiledUserData setValue:userFollowsStartingValue forKey:@"userFollows"];
                [_profiledUserData setValue:followersStartingValue forKey:@"followerCount"];
                [self updateUserFollowingCounts];
            }
        }];
        [_profiledUserData setValue:[NSNumber numberWithInt:1] forKey:@"userFollows"];
        [_profiledUserData setValue:[NSNumber numberWithInt:[followersStartingValue intValue] +1] forKey:@"followerCount"];
    }
    // GUI
    [self updateUserFollowingCounts];
}

- (void) pushProfileListForTargetId:(NSString *)target_id andQuery:(NSString *)query {
    
    ProfileListTableViewController *profileListView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileListView"];
    profileListView.target_id = target_id;
    profileListView.queryType = query;
    [self.navigationController pushViewController:profileListView animated:YES];
}

- (void) pushFindFriendsView {
    FindFriendsTableViewController *findFriendsView = [self.storyboard instantiateViewControllerWithIdentifier:@"findFriendsView"];
    [self.navigationController pushViewController:findFriendsView animated:YES];
}

- (void) openSettings {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    
    // saved files size
    NSString *savedEpisodesDir = [_tung getSavedEpisodesDirectoryPath];
    NSError *error;
    NSNumber *savedFilesBytes = [TungCommonObjects getAllocatedSizeOfDirectoryAtURL:[NSURL URLWithString:savedEpisodesDir] error:&error];
    NSString *clearSavedDataOption;
    if (!error) {
        NSString *savedFilesMB = [TungCommonObjects formatBytes:savedFilesBytes];
        clearSavedDataOption = [NSString stringWithFormat:@"Delete saved episodes (%@)", savedFilesMB];
    } else {
        JPLog(@"error calculating saved data size: %@", error);
        clearSavedDataOption = @"Delete saved episodes";
        error = nil;
    }
    // temp files size
    NSString *tempEpisodeDir = [_tung getCachedEpisodesDirectoryPath];
    NSNumber *tempFilesBytes = [TungCommonObjects getAllocatedSizeOfDirectoryAtURL:[NSURL URLWithString:tempEpisodeDir] error:&error];
    NSString *clearTempDataOption;
    if (!error) {
        NSString *tempFilesMB = [TungCommonObjects formatBytes:tempFilesBytes];
        clearTempDataOption = [NSString stringWithFormat:@"Delete cached episodes (%@)", tempFilesMB];
    } else {
        JPLog(@"error calculating temp data size: %@", error);
        clearTempDataOption = @"Delete cached episodes";
        error = nil;
    }
    
    UIAlertController *settingsSheet = [UIAlertController alertControllerWithTitle:nil message:[NSString stringWithFormat:@"You are running v %@ (%@) of tung.", version, build] preferredStyle:UIAlertControllerStyleActionSheet];
    [settingsSheet addAction:[UIAlertAction actionWithTitle:clearSavedDataOption style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [_tung deleteAllSavedEpisodes];
        [TungCommonObjects showBannerAlertForText:@"All saved episodes have been deleted."];
    }]];
    [settingsSheet addAction:[UIAlertAction actionWithTitle:clearTempDataOption style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [_tung deleteAllCachedEpisodes];
        [TungCommonObjects showBannerAlertForText:@"All cached episodes have been deleted."];
    }]];
    
    [settingsSheet addAction:[UIAlertAction actionWithTitle:@"Application log"	 style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self performSegueWithIdentifier:@"presentLogView" sender:self];
    }]];
    [settingsSheet addAction:[UIAlertAction actionWithTitle:@"Sign out" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [_tung signOut];
    }]];
    [settingsSheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:settingsSheet animated:YES completion:nil];
}

#pragma mark - UIScrollView delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if (scrollView == _profileHeader.scrollView) {
        float fractionalPage = (uint) scrollView.contentOffset.x / _screenWidth;
        NSInteger page = lround(fractionalPage);
        _profileHeader.pageControl.currentPage = page;
    }
    
}

#pragma mark - UIWebView delegate methods

-(BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    if ([request.URL.scheme isEqualToString:@"file"]) {
        return YES;
        
    } else {
        
        // open web browsing modal
        _urlToPass = request.URL;
        [self performSegueWithIdentifier:@"presentWebView" sender:self];
        
        return NO;
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UINavigationController *destination = segue.destinationViewController;
    
    if ([[segue identifier] isEqualToString:@"presentWebView"]) {
        BrowserViewController *browserViewController = (BrowserViewController *)destination;
        [browserViewController setValue:_urlToPass forKey:@"urlToNavigateTo"];
    }
    else if ([[segue identifier] isEqualToString:@"presentEditProfileView"]) {
        [destination setValue:@"editProfile" forKey:@"rootView"];
    }
    
}

@end
