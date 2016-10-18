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
@property ProfileListTableViewController *notificationsView;
@property (strong, nonatomic) ProfileHeaderView *profileHeader;
@property UIBarButtonItem *tableHeaderLabel;
@property NSString *urlStringToPass;
@property UserEntity *userEntity;
@property NSLayoutConstraint *profileHeightConstraint;

@property BOOL isLoggedInUser;
@property BOOL reachable;
@property BOOL preparingView;

// switcher
@property UIToolbar *switcherBar;
@property UISegmentedControl *switcher;
@property NSInteger switcherIndex;

@property CGFloat screenWidth;
@property NSTimer *promptTimer;

@end

@implementation ProfileViewController


- (void) viewDidLoad {
    
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    
    _screenWidth = [TungCommonObjects screenSize].width;
    
    _preparingView = NO;
    
    // profiled user
    if (!_profiledUserId && !_profiledUsername) {
        _profiledUserId = _tung.loggedInUser.tung_id;
        _profiledUsername = @"";
        _isLoggedInUser = YES;
        self.navigationItem.title = @"My Profile";
        
        // settings button
        IconButton *settingsInner = [[IconButton alloc] initWithFrame:CGRectMake(0, 0, 34, 34)];
        settingsInner.type = kIconButtonTypeSettings;
        settingsInner.color = [TungCommonObjects tungColor];
        [settingsInner addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *signOutButton = [[UIBarButtonItem alloc] initWithCustomView:settingsInner];
        self.navigationItem.rightBarButtonItem = signOutButton;
        
        // find friends button
        IconButton *findFriendsInner = [[IconButton alloc] initWithFrame:CGRectMake(0, 0, 34, 34)];
        findFriendsInner.type = kIconButtonTypeFindFriends;
        findFriendsInner.color = [TungCommonObjects tungColor];
        [findFriendsInner addTarget:self action:@selector(pushFindFriendsView) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:findFriendsInner];
        
    }
    else if (_profiledUserId) {
        _profiledUsername = @"";
        self.navigationItem.title = @"Loading…";
        if ([_profiledUserId isEqualToString:_tung.loggedInUser.tung_id]) {
            _isLoggedInUser = YES;
        }
    }
    else if (_profiledUsername) {
        _profiledUserId = @"";
        self.navigationItem.title = @"Loading…";
        if ([_profiledUsername isEqualToString:_tung.loggedInUser.username]) {
            _isLoggedInUser = YES;
        }
    }
    
    self.definesPresentationContext = YES;
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    // profile header
    CGFloat topConstraint = 64;
    CGFloat profileHeaderViewHeight = 223;
    _profileHeader = [[ProfileHeaderView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, profileHeaderViewHeight)];
	[self.view addSubview:_profileHeader];
    _profileHeader.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_profileHeader attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:topConstraint]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_profileHeader attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    _profileHeightConstraint = [NSLayoutConstraint constraintWithItem:_profileHeader attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:profileHeaderViewHeight];
    [_profileHeader addConstraint:_profileHeightConstraint];
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
    
    _storiesView.profileHeader = _profileHeader;
    
    // notifications view
    if (_isLoggedInUser) {
        _notificationsView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileListView"];
        _notificationsView.queryType = @"Notifications";
        _notificationsView.target_id = _tung.loggedInUser.tung_id;
        _notificationsView.doNotRequestImmediately = [NSNumber numberWithBool:YES];
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
        
        _notificationsView.profileHeader = _profileHeader;
        
        _switcherIndex = 0;
        [_switcher setSelectedSegmentIndex:_switcherIndex];
        [self switchViews:_switcher];
    }
    
    
	// get data in viewDidAppear
    _tung.profileNeedsRefresh = [NSNumber numberWithBool:YES];
    _tung.profileFeedNeedsRefresh = [NSNumber numberWithBool:YES];
    
    // notifs
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(followingCountChanged:) name:@"followingCountChanged" object:nil];// respond to follow/unfollow events
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(minimizeProfileHeaderview) name:@"shouldMinimizeHeaderView" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(maximizeProfileHeaderview) name:@"shouldMaximizeHeaderView" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(respondToProfiledUserFollowChange:) name:@"profiledUserFollowChange" object:nil];
    
}
- (void) appDidBecomeActive {
    //NSLog(@"responding to appDidBecomeActive");
    [self prepareView];
}
- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _tung.viewController = self;
    [self.navigationController.navigationBar setTitleTextAttributes:@{ NSForegroundColorAttributeName:[TungCommonObjects tungColor] }];

    [self prepareView];

}

-(void) viewWillAppear:(BOOL)animated {
    self.definesPresentationContext = YES;
    
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.definesPresentationContext = NO;
    [_promptTimer invalidate];
}

- (void) prepareView {
    if (!_preparingView) {
        _preparingView = YES;
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
                _preparingView = NO;
            }
            else if (_tung.profileFeedNeedsRefresh.boolValue) {
                //JPLog(@"profile feed needs refresh");
                [_storiesView refreshFeed];
                _preparingView = NO;
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

        if (!settings.hasSeenMentionsPrompt.boolValue && ![[UIApplication sharedApplication] isRegisteredForRemoteNotifications]) {
            _promptTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:_tung selector:@selector(promptForNotificationsForMentions) userInfo:nil repeats:NO];
        }
    }
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
            if (_tung.profileFeedNeedsRefresh.boolValue) {
                [_storiesView refreshFeed];
            }
            break;
        default: // show notifications
            _notificationsView.view.hidden = NO;
            _storiesView.view.hidden = YES;
            break;
    }
    _switcherIndex = switcher.selectedSegmentIndex;
}

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
                _profiledUserData = [[TungCommonObjects entityToDict:_tung.loggedInUser] mutableCopy];
                // _profiledUserId may not be set if we used _profiledUsername
                _profiledUserId = _tung.loggedInUser.tung_id;
                _storiesView.profiledUserId = _profiledUserId;
                //JPLog(@"Is logged in user: Has logged-in user data.");
                [self setUpProfileHeaderViewForData];
                // request profile just to get current follower/following counts
                [_tung getProfileDataForUserWithId:_profiledUserId orUsername:_profiledUsername withCallback:^(NSDictionary *jsonData) {
                    if (jsonData != nil) {
                        NSDictionary *responseDict = jsonData;
                        if ([responseDict objectForKey:@"user"]) {
                            _profiledUserData = [[responseDict objectForKey:@"user"] mutableCopy];
                            [self updateUserFollowingCounts];
                            [_notificationsView refreshFeed];
                        }
                        else if ([responseDict objectForKey:@"error"]) {
                            [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                            JPLog(@"Error getting profile: %@", responseDict);
                        }
                    }
                }];
            }
            else {
                
                [_tung getProfileDataForUserWithId:_profiledUserId orUsername:_profiledUsername withCallback:^(NSDictionary *jsonData) {
                    NSLog(@"get profile data with id: %@ or username: %@", _profiledUserId, _profiledUsername);
                    if (jsonData != nil) {
                        NSDictionary *responseDict = jsonData;
                        if ([responseDict objectForKey:@"user"]) {
                            _profiledUserData = [[responseDict objectForKey:@"user"] mutableCopy];
                            // _profiledUserId may not be set if we used _profiledUsername
                            _profiledUserId = [_profiledUserData objectForKey:@"tung_id"];
                            _storiesView.profiledUserId = _profiledUserId;
                            //JPLog(@"profiled user data %@", _profiledUserData);
                            [self setUpProfileHeaderViewForData];
                            if (_tung.profileFeedNeedsRefresh.boolValue) {
                                [_storiesView refreshFeed];
                            }
                        }
                        else if ([responseDict objectForKey:@"error"]) {
                            [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                            JPLog(@"Error getting profile: %@", responseDict);
                        }
                    }
                }];
            }
        }
        // unreachable
        else {
            [TungCommonObjects showNoConnectionAlert];
        }
    }];
}

- (void) refreshProfile {
    [_tung getProfileDataForUserWithId:_profiledUserId orUsername:_profiledUsername withCallback:^(NSDictionary *jsonData) {
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
    
    _profileHeader.nameLabel.text = [_profiledUserData objectForKey:@"name"];
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
    
    _preparingView = NO;
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
    
    if (_tung.connectionAvailable.boolValue) {
    
        NSMutableDictionary *userInfo = [@{
                                          @"profiledUserId": _profiledUserId,
                                          @"username": [_profiledUserData objectForKey:@"username"]
                                          } mutableCopy];
        
        if (_profileHeader.editFollowBtn.on) {
            // unfollow
            [userInfo setObject:@"unfollow" forKey:@"action"];
            
        }
        else {
            // follow
            [userInfo setObject:@"follow" forKey:@"action"];
        }
        
        NSNotification *profiledUserFollowChangeNotif = [NSNotification notificationWithName:@"profiledUserFollowChange" object:nil userInfo:userInfo];
        [[NSNotificationCenter defaultCenter] postNotification:profiledUserFollowChangeNotif];
    }
    else {
        [TungCommonObjects showNoConnectionAlert];
    }
}

- (void) respondToProfiledUserFollowChange:(NSNotification*)notification {
    
    //NSLog(@"respond to profiled user follow change. profile page for id: %@", _profiledUserId);
    NSString *targetId = [[notification userInfo] objectForKey:@"profiledUserId"];
    NSString *action = [[notification userInfo] objectForKey:@"action"];
    
    if ([targetId isEqualToString:_profiledUserId]) {
        // NOT the user: update follow count and make follow/unfollow request
        
        NSNumber *followersStartingValue = [_profiledUserData objectForKey:@"followerCount"];
        
        if ([action isEqualToString:@"follow"]) {
            //NSLog(@"follow user");
            // follow
            [_tung followUserWithId:_profiledUserId withCallback:^(BOOL success, NSDictionary *response) {
                if (success && ![response objectForKey:@"userAlreadyFollowing"]) {
                    _tung.feedNeedsRefresh = [NSNumber numberWithBool:YES];
                }
            }];
            [_profiledUserData setValue:[NSNumber numberWithInt:1] forKey:@"userFollows"];
            [_profiledUserData setValue:[NSNumber numberWithInt:[followersStartingValue intValue] +1] forKey:@"followerCount"];
        }
        else {
            //NSLog(@"unfollow user");
            [_tung unfollowUserWithId:_profiledUserId withCallback:^(BOOL success, NSDictionary *response) {
                if (success && ![response objectForKey:@"userNotFollowing"]) {
                    _tung.feedNeedsRefetch = [NSNumber numberWithBool:YES];
                }
            }];
            [_profiledUserData setValue:[NSNumber numberWithInt:0] forKey:@"userFollows"];
            [_profiledUserData setValue:[NSNumber numberWithInt:[followersStartingValue intValue] -1] forKey:@"followerCount"];
        }
    }
    else {
        // user profile page: update follow count and notifs
        NSNumber *followingStartingValue = [_profiledUserData objectForKey:@"followingCount"];
        NSNumber *follows = [NSNumber numberWithBool:NO];
        
        if ([action isEqualToString:@"follow"]) {
            
            follows = [NSNumber numberWithBool:YES];
            [_profiledUserData setValue:[NSNumber numberWithInt:[followingStartingValue intValue] +1] forKey:@"followingCount"];
        }
        else {
            [_profiledUserData setValue:[NSNumber numberWithInt:[followingStartingValue intValue] -1] forKey:@"followingCount"];
            
        }
        [_notificationsView makeTableConsistentForFollowing:follows userId:targetId];
    }
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
    
    // saved episodes size
    NSString *savedEpisodesDir = [TungCommonObjects getSavedEpisodesDirectoryPath];
    NSError *error;
    NSNumber *savedFilesBytes = [TungCommonObjects getAllocatedSizeOfDirectoryAtURL:[NSURL URLWithString:savedEpisodesDir] error:&error];
    NSString *clearSavedEpisodesOption;
    if (!error) {
        NSString *savedFilesMB = [TungCommonObjects formatBytes:savedFilesBytes];
        clearSavedEpisodesOption = [NSString stringWithFormat:@"Delete saved episodes (%@)", savedFilesMB];
    } else {
        JPLog(@"error calculating saved data size: %@", error.localizedDescription);
        clearSavedEpisodesOption = @"Delete saved episodes";
        error = nil;
    }
    // cached episodes size
    NSString *tempEpisodeDir = [TungCommonObjects getCachedEpisodesDirectoryPath];
    NSNumber *tempEpisodesBytes = [TungCommonObjects getAllocatedSizeOfDirectoryAtURL:[NSURL URLWithString:tempEpisodeDir] error:&error];
    NSString *clearCachedEpisodesOption;
    if (!error) {
        NSString *tempEpisodeFilesMB = [TungCommonObjects formatBytes:tempEpisodesBytes];
        clearCachedEpisodesOption = [NSString stringWithFormat:@"Delete cached episodes (%@)", tempEpisodeFilesMB];
    } else {
        JPLog(@"error calculating temp data size: %@", error.localizedDescription);
        clearCachedEpisodesOption = @"Delete cached episodes";
        error = nil;
    }
    
    // other cached data (audio clips, feeds, avatars, podcast art)
    /*
    NSString *clearCachedDataOption;
    NSNumber *totalTempFilesBytes = [NSNumber numberWithInteger:0];
    NSArray *tmpFolderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:&error];
    if ([tmpFolderContents count] > 0 && error == nil) {
        for (NSString *item in tmpFolderContents) {
            if (![item isEqualToString:@"MediaCache"] && ![item isEqualToString:@"episodes"]) {
                NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:item];
                NSNumber *size = [TungCommonObjects getAllocatedSizeOfDirectoryAtURL:[NSURL URLWithString:path] error:&error];
                if (!error) {
                	totalTempFilesBytes = [NSNumber numberWithDouble:totalTempFilesBytes.doubleValue + size.doubleValue];
                } else {
                    JPLog(@"error getting size of contents at path: %@ - %@", path, error.localizedDescription);
                    error = nil;
                }
            }
        }
        if (totalTempFilesBytes.doubleValue > 0) {
            NSString *tempFilesMB = [TungCommonObjects formatBytes:totalTempFilesBytes];
            clearCachedDataOption = [NSString stringWithFormat:@"Delete cached data: (%@)", tempFilesMB];
        }
        else {
            clearCachedDataOption = @"Delete cached data (0 MB)";
        }
    } else {
        JPLog(@"error getting temp folder contents: %@", error.localizedDescription);
        clearCachedDataOption = @"Clear cached data";
        error = nil;
    }*/
    
    UIAlertController *settingsSheet = [UIAlertController alertControllerWithTitle:nil message:[NSString stringWithFormat:@"You are running v %@ (%@) of tung.", version, build] preferredStyle:UIAlertControllerStyleActionSheet];
    [settingsSheet addAction:[UIAlertAction actionWithTitle:clearSavedEpisodesOption style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [_tung deleteAllSavedEpisodes];
        [TungCommonObjects showBannerAlertForText:@"All saved episodes have been deleted."];
    }]];
    [settingsSheet addAction:[UIAlertAction actionWithTitle:clearCachedEpisodesOption style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [TungCommonObjects deleteAllCachedEpisodes];
        [TungCommonObjects showBannerAlertForText:@"All cached episodes have been deleted."];
    }]];
    [settingsSheet addAction:[UIAlertAction actionWithTitle:@"Import podcast subscriptions" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [_tung promptAndRequestMediaLibraryAccess];
    }]];
    /*
    [settingsSheet addAction:[UIAlertAction actionWithTitle:clearCachedDataOption style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [TungCommonObjects deleteCachedData];
        [TungCommonObjects showBannerAlertForText:@"All cached data has been deleted."];
    }]]; */
    /*
    [settingsSheet addAction:[UIAlertAction actionWithTitle:@"Application log" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self performSegueWithIdentifier:@"presentLogView" sender:self];
    }]]; */
    [settingsSheet addAction:[UIAlertAction actionWithTitle:@"Sign out" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [_tung signOut];
    }]];
    [settingsSheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:settingsSheet animated:YES completion:nil];
}

#pragma mark - Profile header view resizing

static float profileHeaderScrollViewHeight = 162;
static float profileHeaderMinScrollViewHeight = 82;
static float profileFollowingViewHeight = 61;
static float profileHeaderViewHeight = 223;
static CGSize profileHeaderScrollViewSize;

- (void) minimizeProfileHeaderview {
    
    if (!_profileHeader.isAnimating) {
        //NSLog(@"MIN-imize profile header view");
        _profileHeader.isMinimized = YES;
        _profileHeader.isAnimating = YES;
        profileHeaderScrollViewSize = _profileHeader.scrollView.contentSize;
        
        _profileHeader.nameLabel.hidden = NO;
        _profileHeader.nameLabel.alpha = 0;
        
        [UIView animateWithDuration:.5
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             
                             _profileHeightConstraint.constant = profileHeaderMinScrollViewHeight;
                             _profileHeader.scrollSubView1Height.constant = profileHeaderMinScrollViewHeight;
                             _profileHeader.scrollSubView2Height.constant = profileHeaderMinScrollViewHeight;
                             _profileHeader.nameLabel.alpha = 1;
                             _profileHeader.basicInfoWebView.alpha = 0;
                             _profileHeader.pageControl.alpha = 0;
                             
                             _profileHeader.followingViewHeightConstraint.constant = 0;
                             _profileHeader.editFollowBtn.alpha = 0;
                             _profileHeader.followersLabel.alpha = 0;
                             _profileHeader.followingLabel.alpha = 0;
                             _profileHeader.followerCountBtn.alpha = 0;
                             _profileHeader.followingCountBtn.alpha = 0;
                             
                             [self.view layoutIfNeeded];
                         }
                         completion:^(BOOL completed) {
                             _profileHeader.isAnimating = NO;
                             _profileHeader.basicInfoWebView.hidden = YES;
                             [_profileHeader.scrollView setScrollEnabled:NO];
                         }];
    }
}

- (void) maximizeProfileHeaderview {
    
    if (!_profileHeader.isAnimating) {
        //NSLog(@"MAX-imize profile header view");
        _profileHeader.isMinimized = NO;
        _profileHeader.isAnimating = YES;
        _profileHeader.basicInfoWebView.hidden = NO;
        
        [UIView animateWithDuration:.3
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             
                             _profileHeightConstraint.constant = profileHeaderViewHeight;
                             _profileHeader.scrollSubView1Height.constant = profileHeaderScrollViewHeight;
                             _profileHeader.scrollSubView2Height.constant = profileHeaderScrollViewHeight;
                             _profileHeader.nameLabel.alpha = 0;
                             _profileHeader.basicInfoWebView.alpha = 1;
                             _profileHeader.pageControl.alpha = 1;
                             
                             _profileHeader.followingViewHeightConstraint.constant = profileFollowingViewHeight;
                             _profileHeader.editFollowBtn.alpha = 1;
                             _profileHeader.followersLabel.alpha = 1;
                             _profileHeader.followingLabel.alpha = 1;
                             _profileHeader.followerCountBtn.alpha = 1;
                             _profileHeader.followingCountBtn.alpha = 1;
                             
                             [self.view layoutIfNeeded];
                         }
                         completion:^(BOOL completed) {
                             _profileHeader.isAnimating = NO;
                             _profileHeader.nameLabel.hidden = YES;
                             _profileHeader.scrollView.contentSize = profileHeaderScrollViewSize;
                             [_profileHeader.scrollView setScrollEnabled:YES];
                             
                         }];
    }
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
        _urlStringToPass = request.URL.absoluteString;
        [self performSegueWithIdentifier:@"presentWebView" sender:self];
        
        return NO;
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UINavigationController *destination = segue.destinationViewController;
    
    if ([[segue identifier] isEqualToString:@"presentWebView"]) {
        BrowserViewController *browserViewController = (BrowserViewController *)destination;
        [browserViewController setValue:_urlStringToPass forKey:@"urlStringToNavigateTo"];
    }
    else if ([[segue identifier] isEqualToString:@"presentEditProfileView"]) {
        [destination setValue:@"editProfile" forKey:@"rootView"];
    }
    
}

@end
