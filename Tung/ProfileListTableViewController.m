//
//  ProfileListTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 11/3/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "ProfileListTableViewController.h"
#import "TungCommonObjects.h"
#import "ProfileListCell.h"
#import "ProfileViewController.h"
#import "EpisodeViewController.h"
#import "FinishSignUpController.h"
#import "IconCell.h"

@interface ProfileListTableViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;

@property (nonatomic, assign) BOOL feedRefreshed;
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;
@property NSNumber *lastSeenNotification;
@property CGFloat screenWidth;
@property BOOL forOnboarding;
@property NSNumber *page;
@property BOOL socialPlatform;
@property (nonatomic, assign) CGFloat lastScrollViewOffset; // for determining scroll direction
@property NSString *navTitle;

// for search
@property NSTimer *searchTimer;
@property (strong, nonatomic) NSURLConnection *profileSearchConnection;
@property (strong, nonatomic) NSMutableData *profileSearchResultData;

@end

@implementation ProfileListTableViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    _tung = [TungCommonObjects establishTungObjects];
    _tung.viewController = self;
    
    _screenWidth = [TungCommonObjects screenSize].width;
    
    if (_screenWidth == 0.0f) {
        _screenWidth = self.view.frame.size.width;
    }
    
    // default nav controller
    if (!_navController) {
    	_navController = self.navigationController;
    }
    self.navigationItem.backBarButtonItem.title = @"Back";
    
    // onboarding: platform friends
    if (_profileData) {
        
        _forOnboarding = YES;
        _socialPlatform = YES;
        
        _usersToFollow = [NSMutableArray array];
        
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Next" style:UIBarButtonItemStyleDone target:self action:@selector(finishSignUp)];
        self.tableView.allowsSelection = NO;
        
        if ([_profileData objectForKey:@"twitterFriends"]) {
            _queryType = @"Twitter";
            _profileArray = [NSMutableArray arrayWithArray:[_profileData objectForKey:@"twitterFriends"]];
        }
        else if ([_profileData objectForKey:@"facebookFriends"]) {
            _queryType = @"Facebook";
            _profileArray = [NSMutableArray arrayWithArray:[_profileData objectForKey:@"facebookFriends"]];
        }
        [self preloadAvatarsForArray:_profileArray];
        // load up usersToFollow with profileArray ids
        for (int i = 0; i < _profileArray.count; i++) {
            NSString *userId = [[[_profileArray objectAtIndex:i] objectForKey:@"_id"] objectForKey:@"$id"];
            if (![_usersToFollow containsObject:userId]) {
            	[_usersToFollow addObject:userId];
            }
        }
    }
    
    // respond to follow/unfollow events
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(followingChanged:) name:@"followingChanged" object:nil];
    
    if (_queryType) {
        // table view
        UIActivityIndicatorView *spinnerBehindTable = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        spinnerBehindTable.alpha = 1;
        [spinnerBehindTable startAnimating];
        self.tableView.backgroundView = spinnerBehindTable;
        self.tableView.backgroundColor = [TungCommonObjects bkgdGrayColor];
        self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
        self.tableView.separatorColor = [UIColor grayColor];
        self.tableView.scrollsToTop = YES;
        self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
        self.tableView.separatorInset = UIEdgeInsetsMake(0, 12, 0, 12);
        
        if ([_queryType isEqualToString:@"Twitter"]) {
            
            _socialPlatform = YES;
            
            _navTitle = @"Twitter Friends";
            [self.navigationController.navigationBar setTitleTextAttributes:@{ NSForegroundColorAttributeName:[TungCommonObjects twitterColor] }];
            _page = [NSNumber numberWithInt:0];
            
            if (_forOnboarding) {
                // _profileArray will have been set above
                self.tableView.backgroundView = nil;
                [self.tableView reloadData];
                if ([_profileData objectForKey:@"twitterFriends"]) {
                    _page = [NSNumber numberWithInt:1];
                }
            }
            else {
                // assumes that user is already logged into twitter
                [self getNextPageOfTwitterFriends];
            }
        }
        else if ([_queryType isEqualToString:@"Facebook"]) {
            _socialPlatform = YES;
            _navTitle = @"Facebook Friends";
            [self.navigationController.navigationBar setTitleTextAttributes:@{ NSForegroundColorAttributeName:[TungCommonObjects facebookColor] }];
            
            if (_forOnboarding) {
                // _profileArray will have been set above
                self.tableView.backgroundView = nil;
                [self.tableView reloadData];
            }
            else {
                // assumes user is already logged into FB
                NSString *tokenString = [[FBSDKAccessToken currentAccessToken] tokenString];
                [_tung findFacebookFriendsWithFacebookAccessToken:tokenString withCallback:^(BOOL success, NSDictionary *responseDict) {
                    self.tableView.backgroundView = nil;
                    if (success) {
                        //NSLog(@"responseDict: %@", responseDict);
                        NSNumber *platformFriendsCount = [responseDict objectForKey:@"resultsCount"];
                        if ([platformFriendsCount integerValue] > 0) {
                            _profileArray = [NSMutableArray arrayWithArray:[responseDict objectForKey:@"results"]];
                            [self preloadAvatarsForArray:_profileArray];
                        }
                        else {
                            _noResults = YES;
                        }
                    }
                    else {
                        [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                    }
                    
                    [self.tableView reloadData];
                }];
            }
        }

        if (!_socialPlatform) {
            
            _navTitle = _queryType;
            
            // default target
            if (_target_id == NULL) _target_id = _tung.loggedInUser.tung_id;
            
        	// refresh control
            self.refreshControl = [[UIRefreshControl alloc] init];
            [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
            
            if ([_queryType isEqualToString:@"Notifications"]) {
                // establish last seen notification time
                _lastSeenNotification = _tung.loggedInUser.lastSeenNotification;
            }
            if (!_doNotRequestImmediately.boolValue) {
            	[self refreshFeed];
            }
        }
    }
    else {
        // no query type: profile search
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
        self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectZero];
        self.tableView.contentInset = UIEdgeInsetsMake(64, 0, 44, 0);
        self.automaticallyAdjustsScrollViewInsets = NO;
        self.tableView.backgroundView = nil;
    }
}

- (void) viewWillAppear:(BOOL)animated {
    self.navigationItem.title = _navTitle;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden
{
    if (_profileData) {
    	return YES;
    } else {
        return NO;
    }
}


#pragma mark - Requesting

- (void) getNextPageOfTwitterFriends {
    //NSLog(@"get next page of twitter friends on page %@", _page);
    // each request returns up to 100 profiles... make sure we need to
    if (_profileArray.count == 0 || _profileArray.count == _page.integerValue * 100) {
        [_tung findTwitterFriendsWithPage:_page andCallback:^(BOOL success, NSDictionary *responseDict) {
            
            if (success) {
                
                self.tableView.backgroundView = nil;
                NSNumber *platformFriendsCount = [responseDict objectForKey:@"resultsCount"];
                if ([platformFriendsCount integerValue] < 100) {
                    _noMoreItemsToGet = YES;
                }
                
                NSArray *twitterFriends = [responseDict objectForKey:@"results"];
                [self preloadAvatarsForArray:twitterFriends];
                if ([platformFriendsCount integerValue] > 0) {
                    if (_page.integerValue == 0) {
                        _profileArray = [NSMutableArray arrayWithArray:twitterFriends];
                    } else {
                        [_profileArray addObjectsFromArray:twitterFriends];
                        // TODO: load 
                        if (_forOnboarding) {
                            // load up usersToFollow with profileArray ids
                            for (int i = 0; i < twitterFriends.count; i++) {
                                NSString *userId = [[[twitterFriends objectAtIndex:i] objectForKey:@"_id"] objectForKey:@"$id"];
                                if (![_usersToFollow containsObject:userId]) {
                                    [_usersToFollow addObject:userId];
                                }
                            }
                        }
                    }
                }
                else {
                    if (_page.integerValue == 0) {
                        _profileArray = [NSMutableArray array];
                        _noResults = YES;
                    } else {
                        _noMoreItemsToGet = YES;
                    }
                }
                [self.tableView reloadData];
                // increment page
                _page = [NSNumber numberWithInteger:_page.integerValue + 1];
            }
            else {
                [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
            }
        }];
    }
    else {
        _noMoreItemsToGet = YES;
        [self.tableView reloadData];
    }
}
// refresh feed by checking or newer items or getting all items
- (void) refreshFeed {
    //NSLog(@"profile list for query: %@. \n%@", _queryType, [NSThread callStackSymbols]);
    // query users
    _feedRefreshed = YES;
    NSNumber *mostRecent;
    if (_profileArray.count > 0) {
        //JPLog(@"profile list: refresh feed");
        [self.refreshControl beginRefreshing];
        mostRecent = [[_profileArray objectAtIndex:0] objectForKey:@"time_secs"];
    } else {
        //JPLog(@"profile list: get feed");
        mostRecent = [NSNumber numberWithInt:0];
    }
    [self requestProfileListWithQuery:_queryType
                            forTarget:_target_id
                            newerThan:mostRecent
                          orOlderThan:[NSNumber numberWithInt:0]];
}

// for re-fetching the entire feed
- (void) refetchFeed {
    
    if (_tung.connectionAvailable.boolValue) {
        [self requestProfileListWithQuery:_queryType
                                forTarget:_target_id
                                newerThan:[NSNumber numberWithInt:0]
                              orOlderThan:[NSNumber numberWithInt:0]];
    }
    
}

- (void) requestProfileListWithQuery:(NSString *)queryType
                           forTarget:(NSString *)target_id
                           newerThan:(NSNumber *)afterTime
                         orOlderThan:(NSNumber *)beforeTime {
    
    NSURL *getProfileListRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/profile-list.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *getProfileListRequest = [NSMutableURLRequest requestWithURL:getProfileListRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [getProfileListRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_tung.sessionId,
                             @"queryType": queryType,
                             @"target_id": target_id,
                             @"newerThan": afterTime,
                             @"olderThan": beforeTime};
    //NSLog(@"get profile list with params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [getProfileListRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:getProfileListRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            if (jsonData != nil && error == nil) {
                if ([jsonData isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                                // get new session and re-request
                                JPLog(@"SESSION EXPIRED");
                                [_tung getSessionWithCallback:^{
                                    [self requestProfileListWithQuery:queryType forTarget:target_id newerThan:afterTime orOlderThan:beforeTime];
                                }];
                            } else {
                                [self endRefreshing];
                                // other error - alert user
                                [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                            }
                        });
                    }
                }
                else if ([jsonData isKindOfClass:[NSArray class]]) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        NSArray *newItems = jsonData;
                        [self preloadAvatarsForArray:newItems];
                        
                        //NSLog(@"profile list items: %@", newItems);
                        
                        if (newItems.count == 0) _noResults = YES;
                        else _noResults = NO;
                        
                        _queryExecuted = YES;
                        
                        [self endRefreshing];
                        
                        // pull refresh
                        if ([afterTime intValue] > 0) {
                            //[self stopPlayback];
                            NSArray *newItemsArray = [newItems arrayByAddingObjectsFromArray:_profileArray];
                            _profileArray = [newItemsArray mutableCopy];
                            NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
                            for (int i = 0; i < newItems.count; i++) {
                                [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                            }
                            if (newItems.count > 0) {
                                // if new posts were retrieved
                                
                                [UIView setAnimationsEnabled:NO];
                                [self.tableView beginUpdates];
                                [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationLeft];
                                [self.tableView endUpdates];
                                [UIView setAnimationsEnabled:YES];
                                
                                [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
                            }
                        }
                        // auto-loaded posts as user scrolls down
                        else if ([beforeTime intValue] > 0) {
                            _requestingMore = NO;
                            if (newItems.count == 0) {
                                //JPLog(@"no more items to get");
                                _noMoreItemsToGet = YES;
                                // hide footer
                                //[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_profileArray.count-1 inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:YES]; // causes crash on search page
                                [self.tableView reloadData];
                            } else {
                                //JPLog(@"\tgot items older than: %@", beforeTime);
                                int startingIndex = (int)_profileArray.count;
                                // JPLog(@"\tstarting index: %d", startingIndex);
                                NSArray *newItemsArray = [_profileArray arrayByAddingObjectsFromArray:newItems];
                                _profileArray = [newItemsArray mutableCopy];
                                NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
                                for (int i = startingIndex; i < _profileArray.count; i++) {
                                    [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                                }
                                [UIView setAnimationsEnabled:NO];
                                [self.tableView beginUpdates];
                                [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationLeft];
                                [self.tableView endUpdates];
                                [UIView setAnimationsEnabled:YES];
                                
                            }
                        }
                        // initial request
                        else {
                            _profileArray = [newItems mutableCopy];
                            
                            [self.tableView reloadData];
                        }
                        
                        //JPLog(@"got items. profileArray count: %lu", (unsigned long)[_profileArray count]);
                        
                        // 1 second delay to set new lastSeenNotification
                        if ([queryType isEqualToString:@"Notifications"]) {
                            _tung.notificationsNeedRefresh = [NSNumber numberWithBool:NO];
                            [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(markNotificationsAsSeen) userInfo:nil repeats:NO];
                        }
                    });
                }
            }
            else if ([data length] == 0 && error == nil) {
                JPLog(@"get profile list: no response");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self endRefreshing];
                });
            }
            else if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self endRefreshing];
                });
                JPLog(@"get profile list: Error: %@", error);
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                JPLog(@"HTML: %@", html);
            }
        }
        // error
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self endRefreshing];
                
                //[_tung showConnectionErrorAlertForError:error];
            });
        }
    }];
}

- (void) endRefreshing {
    _requestingMore = NO;
    _loadMoreIndicator.alpha = 0;
    [self.refreshControl endRefreshing];
    self.tableView.backgroundView = nil;
}


-(void) preloadAvatarsForArray:(NSArray *)profiles {
    
    // de-dupe urls
    NSMutableArray *profileAvatarUrls = [NSMutableArray array];
    for (int i = 0; i < profiles.count; i++) {
        NSString *avatarURLString = [[profiles objectAtIndex:i] objectForKey:@"small_av_url"];
        [profileAvatarUrls addObject:avatarURLString];
    }
    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithArray:profileAvatarUrls];
    NSArray *dedupedAvatarUrls = [orderedSet array];

    NSOperationQueue *preloadQueue = [[NSOperationQueue alloc] init];
    preloadQueue.maxConcurrentOperationCount = 3;
    
    for (int i = 0; i < dedupedAvatarUrls.count; i++) {
        
        [preloadQueue addOperationWithBlock:^{
            NSString *avatarURLString = [dedupedAvatarUrls objectAtIndex:i];
            //NSLog(@"preload %@", avatarURLString);
            [TungCommonObjects retrieveSmallAvatarDataWithUrlString:avatarURLString];
        }];
    }
}

// solely for the purpose of setting new lastSeenNotification property of UserEntity
// only called if _queryType == 'Notifications'
- (void) markNotificationsAsSeen {
    
    if (_profileArray && _profileArray.count) {
        NSNumber *mostRecent = [[_profileArray objectAtIndex:0] objectForKey:@"time_secs"];
        _tung.loggedInUser.lastSeenNotification = mostRecent;
        _lastSeenNotification = mostRecent;
        [TungCommonObjects saveContextWithReason:@"marking new notifications as \"seen\""];
    }
}

- (void) finishSignUp {
    if (_profileData && _usersToFollow) {
        FinishSignUpController *finishView = [self.storyboard instantiateViewControllerWithIdentifier:@"finishSignup"];
        finishView.profileData = _profileData;
        finishView.usersToFollow = _usersToFollow;
        [self.navigationController pushViewController:finishView animated:YES];
    }
}

- (void) tableCellButtonTapped:(id)sender {
    long tag = [sender tag];
    ProfileListCell* cell = (ProfileListCell*)[[sender superview] superview];

    NSIndexPath* indexPath = [self.tableView indexPathForCell:cell];
    switch (tag) {
        // profile of user
        case 100: {
            [self pushProfileForUserAtIndexPath:indexPath];
            break;
        }
    }
}

- (void) pushProfileForUserAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *profileDict = [NSDictionary dictionaryWithDictionary:[_profileArray objectAtIndex:indexPath.row]];
    
    //JPLog(@"push profile of user: %@", [profileDict objectForKey:@"username"]);
    
    ProfileViewController *profileView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"profileView"];
    profileView.profiledUserId = [profileDict objectForKey:@"id"];
    [_navController pushViewController:profileView animated:YES];
}

- (void) pushEpisodeViewForIndexPath:(NSIndexPath *)indexPath withFocusedEventId:(NSString *)eventId {
    
    NSDictionary *profileDict = [NSDictionary dictionaryWithDictionary:[_profileArray objectAtIndex:indexPath.row]];
    NSDictionary *episodeMiniDict = [profileDict objectForKey:@"episode"];
    
    EpisodeViewController *episodeView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"episodeView"];
    episodeView.episodeMiniDict = episodeMiniDict;
    episodeView.focusedEventId = eventId;
    
    [_navController pushViewController:episodeView animated:YES];
}

- (void) followingChanged:(NSNotification*)notification {
    //NSLog(@"following changed. for onboarding: %@, %@", (_forOnboarding) ? @"YES" : @"NO", [notification userInfo]);
    PillButton *btn = [[notification userInfo] objectForKey:@"sender"];
    
    if (_forOnboarding) {
        
        if ([[notification userInfo] objectForKey:@"unfollowedUser"]) {
            // unfollow
            [_usersToFollow removeObject:[[notification userInfo] objectForKey:@"unfollowedUser"]];
        }
        if ([[notification userInfo] objectForKey:@"followedUser"]) {
            // follow
            NSString *userId = [[notification userInfo] objectForKey:@"followedUser"];
            if (![_usersToFollow containsObject:userId]) {
                [_usersToFollow addObject:userId];
            }
        }
    }
    else {
        
        if ([[notification userInfo] objectForKey:@"unfollowedUser"]) {
            
            UIAlertController *unfollowConfirmAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Unfollow @%@?", [[notification userInfo] objectForKey:@"username"]] message:nil preferredStyle:UIAlertControllerStyleAlert];
            [unfollowConfirmAlert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                
                NSString *userId = [[notification userInfo] objectForKey:@"unfollowedUser"];
                // unfollow
                [_tung unfollowUserWithId:userId withCallback:^(BOOL success, NSDictionary *response) {
                    if (success) {
                        if (![response objectForKey:@"userNotFollowing"]) {
                            _tung.feedNeedsRefetch = [NSNumber numberWithBool:YES]; // following changed
                            NSNotification *followingCountChangedNotif = [NSNotification notificationWithName:@"followingCountChanged" object:nil userInfo:response];
                            [[NSNotificationCenter defaultCenter] postNotification:followingCountChangedNotif];
                        }
                        [self makeTableConsistentForFollowing:[NSNumber numberWithBool:NO] userId:userId];
                    }
                    else {
                        btn.on = YES;
                        [btn setNeedsDisplay];
                    }
                    [self.tableView reloadData];
                }];

            }]];
            [unfollowConfirmAlert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:nil]];
            if ([TungCommonObjects iOSVersionFloat] >= 9.0) {
            	unfollowConfirmAlert.preferredAction = [unfollowConfirmAlert.actions objectAtIndex:1];
            }
            [self presentViewController:unfollowConfirmAlert animated:YES completion:nil];
            
        }
        if ([[notification userInfo] objectForKey:@"followedUser"]) {
            NSString *userId = [[notification userInfo] objectForKey:@"followedUser"];
            // follow
            [_tung followUserWithId:userId withCallback:^(BOOL success, NSDictionary *response) {
                if (success) {
                    if (![response objectForKey:@"userAlreadyFollowing"]) {
                    	_tung.feedNeedsRefresh = [NSNumber numberWithBool:YES]; // following changed
                        NSNotification *followingCountChangedNotif = [NSNotification notificationWithName:@"followingCountChanged" object:nil userInfo:response];
                        [[NSNotificationCenter defaultCenter] postNotification:followingCountChangedNotif];
                    }
                    [self makeTableConsistentForFollowing:[NSNumber numberWithBool:YES] userId:userId];
                }
                else {
                    btn.on = NO;
                    [btn setNeedsDisplay];
                }
            }];
        }
    }
}

- (void) makeTableConsistentForFollowing:(NSNumber *)following userId:(NSString *)userId {
	
    for (int i = 0; i < _profileArray.count; i++) {
        NSString *idToCompare = [[_profileArray objectAtIndex:i] objectForKey:@"id"];
        if ([idToCompare isEqualToString:userId]) {
            NSMutableDictionary *replacementDict = [NSMutableDictionary dictionaryWithDictionary:[_profileArray objectAtIndex:i]];
            [replacementDict setObject:following forKey:@"userFollows"];
            [_profileArray replaceObjectAtIndex:i withObject:replacementDict];
        }
    }
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return [_profileArray count];
    } else {
        return 0;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ProfileListCell"];
    //JPLog(@"profile list cell for row at index path: %ld", (long)indexPath.row);
    ProfileListCell *profileCell = (ProfileListCell *)cell;
    
    // cell data
    NSDictionary *profileDict = [NSDictionary dictionaryWithDictionary:[_profileArray objectAtIndex:indexPath.row]];
    profileCell.userId = [profileDict objectForKey:@"id"];
    profileCell.username = [profileDict objectForKey:@"username"];
    //NSLog(@"%@", profileDict);
    
    // avatar
    NSString *avatarUrlString = [profileDict objectForKey:@"small_av_url"];
    NSData *avatarImageData = [TungCommonObjects retrieveSmallAvatarDataWithUrlString:avatarUrlString];
    profileCell.avatarContainerView.backgroundColor = [UIColor clearColor];
    profileCell.avatarContainerView.avatar = nil;
    profileCell.avatarContainerView.avatar = [[UIImage alloc] initWithData:avatarImageData];
    profileCell.avatarContainerView.borderColor = [UIColor whiteColor];
    [profileCell.avatarContainerView setNeedsDisplay];
    
    // username
    if (_screenWidth < 375) {
        profileCell.usernameLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    }
    [profileCell.avatarButton addTarget:self action:@selector(tableCellButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    profileCell.avatarButton.tag = 100;
    
    // set username label, sub-label, icon
    if (!_socialPlatform) {
        
        profileCell.usernameLabel.text = profileCell.username;
        NSString *action = [profileDict objectForKey:@"action"];
        if ([_queryType isEqualToString:@"Notifications"]) {
            
            profileCell.subLabelLeadingConstraint.constant = 30;
            profileCell.iconView.hidden = NO;
            //JPLog(@"action: %@", action);
            NSString *eventString;
            if ([action isEqualToString:@"followed"]) {
                profileCell.iconView.type = kIconTypeAdd;
                eventString = @"Followed you";
            }
            else if ([action isEqualToString:@"mentioned"]) {
                profileCell.iconView.type = kIconTypeComment;
                eventString = @"Mentioned you";
            }
            profileCell.iconView.color = [UIColor grayColor];
            [profileCell.iconView setNeedsDisplay];
            profileCell.subLabel.text = eventString;
            
            // background color
            NSNumber *time_secs = [profileDict objectForKey:@"time_secs"];
            //NSLog(@"lastSeenNotification: %@, time_secs: (%ld) %@", _lastSeenNotification, (long)indexPath.row, time_secs);
            if (time_secs.doubleValue > _lastSeenNotification.doubleValue) {
                profileCell.backgroundColor = [TungCommonObjects lightTungColor];
            } else {
                profileCell.backgroundColor = [UIColor whiteColor];
            }
            
        }
        else {
            
            profileCell.subLabel.text = [profileDict objectForKey:@"name"];
            profileCell.subLabelLeadingConstraint.constant = 7;
            profileCell.iconView.hidden = YES;
        }
    }
    else if (_socialPlatform) {
        
        profileCell.subLabelLeadingConstraint.constant = 30;
        profileCell.smallIconView.hidden = NO;

        
        NSString *subLabel;
        if ([_queryType isEqualToString:@"Twitter"]) {
            
            profileCell.usernameLabel.text = [profileDict objectForKey:@"name"];
            subLabel = [NSString stringWithFormat:@"@%@", [profileDict objectForKey:@"twitter_username"]];
            profileCell.smallIconView.type = kIconTypeTwitter;
            profileCell.smallIconView.color = [TungCommonObjects twitterColor];
        }
        else if ([_queryType isEqualToString:@"Facebook"]) {
            profileCell.usernameLabel.text = [profileDict objectForKey:@"username"];
            subLabel = [profileDict objectForKey:@"name"];
            profileCell.smallIconView.type = kIconTypeFacebook;
            profileCell.smallIconView.color = [TungCommonObjects facebookColor];
        }
        profileCell.subLabel.text = subLabel;
        
    }
    
    // follow button
    if (_forOnboarding) {
        if ([_usersToFollow containsObject:profileCell.userId]) {
            profileCell.followBtn.on = YES;
        } else {
            profileCell.followBtn.on = NO;
        }
        profileCell.accessoryType = UITableViewCellAccessoryNone;
        profileCell.followBtnTrailingConstraint.constant = 12;
    }
    else {
        if ([_tung.loggedInUser.tung_id isEqualToString:[profileDict objectForKey:@"id"]]) {
            profileCell.followBtn.hidden = YES;
            profileCell.youLabel.hidden = NO;
            profileCell.accessoryType = UITableViewCellAccessoryNone;
        }
        else {
            // user/user relationship
            //NSLog(@"userfollows: %@", [profileDict objectForKey:@"userFollows"]);
            profileCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            NSNumber *userFollows = [profileDict objectForKey:@"userFollows"];
            if (userFollows.boolValue) {
                profileCell.followBtn.on = YES;
            } else {
                profileCell.followBtn.on = NO;
            }
            
            profileCell.followBtn.hidden = NO;
            profileCell.youLabel.hidden = YES;
        }
        profileCell.followBtnTrailingConstraint.constant = 1;
    }
    [profileCell.followBtn setNeedsDisplay];
    
    return cell;
}


#pragma mark - Table view delegate methods

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_screenWidth > 320) {
    	return 80;
    } else {
        return 64;
    }
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *profileDict = [NSDictionary dictionaryWithDictionary:[_profileArray objectAtIndex:indexPath.row]];
    //JPLog(@"selected %@", profileDict);
    
    if ([profileDict objectForKey:@"event_id"]) {
        NSString *eventId = [[profileDict objectForKey:@"event_id"] objectForKey:@"$id"];
        [self pushEpisodeViewForIndexPath:indexPath withFocusedEventId:eventId];
    }
    else {
        if (![_tung.loggedInUser.tung_id isEqualToString:[profileDict objectForKey:@"id"]]) {
    		[self pushProfileForUserAtIndexPath:indexPath];
        }
    }
    
}

- (UILabel *) labelWithMessageAndBottomMargin:(NSString *)message {
    // label
    UILabel *label = [[UILabel alloc] init];
    label.text = [NSString stringWithFormat:@"%@\n", message];
    label.textColor = [UIColor grayColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    return label;
}

// HEADER

-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (_profileData && _socialPlatform && section == 0) {
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _screenWidth, 60)];
        headerView.backgroundColor = [TungCommonObjects bkgdGrayColor];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, _screenWidth - 20, 60)];
        NSString *message;
        if (_profileArray.count == 1) {
            message = [NSString stringWithFormat:@"We found 1 %@ friend on Tung:", _queryType];
        }
        else {
            message = [NSString stringWithFormat:@"We found some of your %@ friends on Tung:", _queryType];
        }
        label.text = message;
        label.font = [UIFont systemFontOfSize:13.5];
        label.textColor = [UIColor darkGrayColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 0;
        [headerView addSubview:label];

        return headerView;
    }
    else {
        return nil;
    }
    
}
-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (_profileData && section == 0) {
        return 60.0;
    }
    else {
        return 0;
    }
}


-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {

    if (_noMoreItemsToGet && section == 1) {
        NSString *thatsAll = ([_queryType isEqualToString:@"Notifications"]) ? @"That's everything. " : @"That's everyone.";
        return [self labelWithMessageAndBottomMargin:thatsAll];
    }
    else if (_noResults && section == 1) {
        NSString *message = ([_queryType isEqualToString:@"Notifications"]) ? @"Nothing yet. " : @"No results.";
        UILabel *noResultsLabel = [[UILabel alloc] init];
        noResultsLabel.text = message;
        noResultsLabel.textColor = [UIColor grayColor];
        noResultsLabel.textAlignment = NSTextAlignmentCenter;
        return noResultsLabel;
    }
    else {
        _loadMoreIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        return _loadMoreIndicator;
    }
}

-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (!_noResults && !_noMoreItemsToGet && section == 0)
        return 66.0;
    else if ((_noResults || _noMoreItemsToGet) && section == 1)
        return 66.0;
    else
        return 0;
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
    if (!_queryType) {
    	view.backgroundColor = [UIColor whiteColor];
    }
}

#pragma mark - Search misc.

- (void) initSearchController {
    _searchController = [[UISearchController alloc] initWithSearchResultsController:self];
    _searchController.delegate = self;
    //_searchController.searchResultsUpdater = self;
    _searchController.hidesNavigationBarDuringPresentation = NO;
    
    _searchController.searchBar.delegate = self;
    _searchController.searchBar.showsCancelButton = YES;
    _searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchController.searchBar.tintColor = [TungCommonObjects tungColor];
    _searchController.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _searchController.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    _searchController.searchBar.placeholder = @"Find people on Tung";
    _searchController.searchBar.frame = CGRectMake(self.searchController.searchBar.frame.origin.x, self.searchController.searchBar.frame.origin.y, self.searchController.searchBar.frame.size.width, 44.0);
}

#pragma mark - Search Bar delegate methods

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    // placeholder
}

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
        [_profileArray removeAllObjects];
        [self.tableView reloadData];
    }
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {

    
    //[_searchController.searchBar setShowsCancelButton:YES animated:YES];

    return YES;
}

- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar {
    return YES;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    //NSLog(@"cancel button clicked");
    _searchController.searchBar.text = @""; // clear search
    NSNotification *dismissSearchNotif = [NSNotification notificationWithName:@"shouldDismissProfileSearch" object:nil userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotification:dismissSearchNotif];
}

#pragma mark - UISearchControllerDelegate methods

- (void) didDismissSearchController:(UISearchController *)searchController {
    _searchController.searchBar.text = @""; // clear search
    NSNotification *dismissSearchNotif = [NSNotification notificationWithName:@"shouldDismissProfileSearch" object:nil userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotification:dismissSearchNotif];
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
        
        _noResults = NO;
        
        NSURL *profileSearchUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/profile-search.php", [TungCommonObjects apiRootUrl]]];
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

#pragma mark - UISearchController delegate methods

- (void) didPresentSearchController:(UISearchController *)searchController {

    if (![_searchController.searchBar isFirstResponder]) {
        [_searchController.searchBar becomeFirstResponder];
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
                        [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                    }
                });
            }
        }
        else if ([jsonData isKindOfClass:[NSArray class]]) {
            
            _queryExecuted = YES;
            
            NSArray *newUsers = jsonData;
            
            if (newUsers.count > 0) {
                
                _profileArray = [newUsers mutableCopy];
                
                //JPLog(@"got results: %lu", (unsigned long)_profileArray.count);
                //JPLog(@"%@", _profileArray);
                [self preloadAvatarsForArray:newUsers];
                [self.tableView reloadData];
                
            }
            else {
                _noResults = YES;
                _profileArray = [NSMutableArray array];
                //JPLog(@"NO RESULTS");
                [self.tableView reloadData];
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
    JPLog(@"profile search connection failed: %@", error.localizedDescription);
    
    /* this error pops up occasionally, probably because of rapid requests.
     makes user think something is wrong when it really isn't.
     [_tung showConnectionErrorAlertForError:error];
     */
}

/* unused NSURLConnection delegate methods
 - (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	JPLog(@"connection received response: %@", response);
 }
 
 */

#pragma mark - scroll view delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    //NSLog(@"profile list scroll view did scroll");
    if (scrollView == self.tableView) {
        // shrink profile header
        if ([_queryType isEqualToString:@"Notifications"]) {
            if (!_profileHeader.isMinimized && scrollView.contentSize.height > scrollView.frame.size.height + 100 && scrollView.contentOffset.y > _lastScrollViewOffset) {
                // scrolling down (content moving up)
                NSNotification *minimizeHeaderNotif = [NSNotification notificationWithName:@"shouldMinimizeHeaderView" object:nil userInfo:nil];
                [[NSNotificationCenter defaultCenter] postNotification:minimizeHeaderNotif];
            }
            
            else if (scrollView.contentOffset.y < _lastScrollViewOffset) {
                // scrolling up (content moving down)
                if (_profileHeader.isMinimized && scrollView.contentOffset.y <= 100) {
                    NSNotification *maximizeHeaderNotif = [NSNotification notificationWithName:@"shouldMaximizeHeaderView" object:nil userInfo:nil];
                    [[NSNotificationCenter defaultCenter] postNotification:maximizeHeaderNotif];
                }
            }
            if (scrollView.contentOffset.y >= 0) _lastScrollViewOffset = scrollView.contentOffset.y;
        }
        // detect when user hits bottom of feed
        float bottomOffset = scrollView.contentSize.height - scrollView.frame.size.height;
        if (scrollView.contentOffset.y >= bottomOffset) {
            // request more posts if they didn't reach the end
            if ((_queryType || _socialPlatform) && !_requestingMore && !_noMoreItemsToGet && _profileArray.count > 0) {
                
                if (!_socialPlatform && _queryType) {
                    
                    _requestingMore = YES;
                    _loadMoreIndicator.alpha = 1;
                    [_loadMoreIndicator startAnimating];
                    
                    NSNumber *oldest = [[_profileArray objectAtIndex:_profileArray.count-1] objectForKey:@"time_secs"];
                    [self requestProfileListWithQuery:_queryType
                                                   forTarget:_target_id
                                                   newerThan:[NSNumber numberWithInt:0]
                                                 orOlderThan:oldest];
                }
                else if (_socialPlatform) {
                    // only happens if there are > 100 users on tung that user follows on fb/twitter
                    if ([_queryType isEqualToString:@"Twitter"]) {
                        
                        _requestingMore = YES;
                        _loadMoreIndicator.alpha = 1;
                        [_loadMoreIndicator startAnimating];
                        
                        [self getNextPageOfTwitterFriends];
                    }
                }
            }
        }
    }
}


@end
