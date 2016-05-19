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
#import "JPLogRecorder.h"
#import "FinishSignUpController.h"

@interface ProfileListTableViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;

@property (nonatomic, assign) BOOL feedRefreshed;
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;
@property NSNumber *lastSeenNotification;

@end

@implementation ProfileListTableViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    _tung = [TungCommonObjects establishTungObjects];
    _tung.viewController = self;
    
    if (_tung.screenWidth == 0.0f) {
        _tung.screenWidth = self.view.frame.size.width;
    }
    
    // default target
    if (_target_id == NULL) _target_id = _tung.tungId;
    
    // default nav controller
    _navController = self.navigationController;
    
    // navigation title
    if (_queryType) {
    	self.navigationItem.title = _queryType;
    }
    // onboarding: platform friends
    else if (_profileData && _usersToFollow) {
        
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Next" style:UIBarButtonItemStyleDone target:self action:@selector(finishSignUp)];
        self.tableView.allowsSelection = NO;
        
        if ([_profileData objectForKey:@"twitterFriends"]) {
            _socialPlatform = @"Twitter";
            _profileArray = [NSMutableArray arrayWithArray:[_profileData objectForKey:@"twitterFriends"]];
            [_profileData removeObjectForKey:@"twitterFriends"];
        }
        else if ([_profileData objectForKey:@"facebookFriends"]) {
            _socialPlatform = @"Facebook";
            _profileArray = [NSMutableArray arrayWithArray:[_profileData objectForKey:@"facebookFriends"]];
            [_profileData removeObjectForKey:@"facebookFriends"];
        }
        [self preloadAvatars];
        // load up usersToFollow with profileArray ids
        for (int i = 0; i < _profileArray.count; i++) {
            NSString *userId = [[[_profileArray objectAtIndex:i] objectForKey:@"_id"] objectForKey:@"$id"];
            if (![_usersToFollow containsObject:userId]) {
            	[_usersToFollow addObject:userId];
            }
        }
    }
    
    // social platform friends
    if (_socialPlatform) {
        if ([_socialPlatform isEqualToString:@"Twitter"]) {
            
            self.navigationItem.title = @"Twitter Friends";
            [self.navigationController.navigationBar setTitleTextAttributes:@{ NSForegroundColorAttributeName:[TungCommonObjects twitterColor] }];
        }
        else if ([_socialPlatform isEqualToString:@"Facebook"]) {
            self.navigationItem.title = @"Facebook Friends";
            [self.navigationController.navigationBar setTitleTextAttributes:@{ NSForegroundColorAttributeName:[TungCommonObjects facebookColor] }];
            
        }
    }
    
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
    
    // get feed
    if (_queryType) {
        
        // refresh control
        self.refreshControl = [[UIRefreshControl alloc] init];
        [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
        
        if ([_queryType isEqualToString:@"Notifications"]) {
            // establish last seen notification time
            UserEntity *loggedUser = [TungCommonObjects retrieveUserEntityForUserWithId:_tung.tungId];
            _lastSeenNotification = loggedUser.lastSeenNotification;
        }
        [self refreshFeed];
    }
    else if (_socialPlatform) {
        
        if (_profileData) {
            // _profileArray will have been set above
            self.tableView.backgroundView = nil;
            [self.tableView reloadData];
        }
        else {
            // fetch twitter or fb friends (for friend search)
        }
    }
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

// refresh feed by checking or newer items or getting all items
- (void) refreshFeed {
    
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
    
    NSURL *getProfileListRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/profile-list.php", _tung.apiRootUrl]];
    NSMutableURLRequest *getProfileListRequest = [NSMutableURLRequest requestWithURL:getProfileListRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [getProfileListRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_tung.sessionId,
                             @"queryType": queryType,
                             @"target_id": target_id,
                             @"newerThan": afterTime,
                             @"olderThan": beforeTime};
    JPLog(@"get profile list with params: %@", params);
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
                                UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:[responseDict objectForKey:@"error"] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                                [errorAlert show];
                            }
                        });
                    }
                }
                else if ([jsonData isKindOfClass:[NSArray class]]) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        NSArray *newItems = jsonData;
                        
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
                        [self preloadAvatars];
                        
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


-(void) preloadAvatars {

    
    NSOperationQueue *preloadQueue = [[NSOperationQueue alloc] init];
    preloadQueue.maxConcurrentOperationCount = 3;
    // download and save avatars to temp directory if they don't exist
    
    for (int i = 0; i < _profileArray.count; i++) {
        
        [preloadQueue addOperationWithBlock:^{
            // avatar
            NSString *avatarURLString = [[[_profileArray objectAtIndex:i] objectForKey:@"user"] objectForKey:@"small_av_url"];
            [TungCommonObjects retrieveSmallAvatarDataWithUrlString:avatarURLString];
        }];
    }
}

// solely for the purpose of setting new lastSeenNotification property of UserEntity
// only called if _queryType == 'Notifications'
- (void) markNotificationsAsSeen {
    
    if (_profileArray && _profileArray.count) {
        UserEntity *loggedUser = [TungCommonObjects retrieveUserEntityForUserWithId:_tung.tungId];
        NSNumber *mostRecent = [[_profileArray objectAtIndex:0] objectForKey:@"time_secs"];
        loggedUser.lastSeenNotification = mostRecent;
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

- (void) showInviteFriendsPrompt {
    UIAlertView *inviteFriendsPrompt = [[UIAlertView alloc] initWithTitle:@"Invite Friends" message:@"Enter a comma-separated list of friends’ emails whom you would like to invite." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Send", nil];
    inviteFriendsPrompt.alertViewStyle = UIAlertViewStylePlainTextInput;
    inviteFriendsPrompt.tag = 59;
    [inviteFriendsPrompt show];
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
    profileCell.userId = [[profileDict objectForKey:@"_id"] objectForKey:@"$id"];
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
    if (_tung.screenWidth < 375) {
        profileCell.usernameLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    }
    [profileCell.avatarButton addTarget:self action:@selector(tableCellButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    profileCell.avatarButton.tag = 100;
    
    // set username label, sub-label, icon
    if (!_socialPlatform) {
        
        profileCell.usernameLabel.text = [profileDict objectForKey:@"username"];
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
        
        if (_profileData) { // onboarding
            profileCell.forOnboarding = YES;
            profileCell.usersToFollow = _usersToFollow;
        }
        
        NSString *subLabel;
        if ([_socialPlatform isEqualToString:@"Twitter"]) {
            
            profileCell.usernameLabel.text = [profileDict objectForKey:@"name"];
            subLabel = [NSString stringWithFormat:@"@%@", [profileDict objectForKey:@"twitter_username"]];
            profileCell.smallIconView.type = kIconTypeTwitter;
            profileCell.smallIconView.color = [TungCommonObjects twitterColor];
        }
        else if ([_socialPlatform isEqualToString:@"Facebook"]) {
            profileCell.usernameLabel.text = [profileDict objectForKey:@"username"];
            subLabel = [profileDict objectForKey:@"name"];
            profileCell.smallIconView.type = kIconTypeFacebook;
            profileCell.smallIconView.color = [TungCommonObjects facebookColor];
        }
        profileCell.subLabel.text = subLabel;
        
    }
    
    // follow button
    if (_profileData) {
        if ([_usersToFollow containsObject:profileCell.userId]) {
            profileCell.followBtn.on = YES;
        } else {
            profileCell.followBtn.on = NO;
        }
    }
    else {
        if ([_tung.tungId isEqualToString:[profileDict objectForKey:@"id"]]) {
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
    }
    [profileCell.followBtn setNeedsDisplay];
    
    return cell;
}


#pragma mark - Table view delegate methods

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_tung.screenWidth > 320) {
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
        if (![_tung.tungId isEqualToString:[profileDict objectForKey:@"id"]]) {
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
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _tung.screenWidth, 60)];
        headerView.backgroundColor = [TungCommonObjects bkgdGrayColor];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, _tung.screenWidth - 40, 60)];
        label.text = [NSString stringWithFormat:@"We found some of your %@ friends on Tung:", _socialPlatform];
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

// FOOTER

- (UIView *) footerViewWithMessage:(NSString *)message {
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _tung.screenWidth, 60.0)];
    footerView.backgroundColor = [TungCommonObjects bkgdGrayColor];
    float yPos = 15;
    if (message.length > 0) {
        yPos = 25;
        // label
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, _tung.screenWidth, 20)];
        label.text = message;
        label.textColor = [UIColor grayColor];
        label.textAlignment = NSTextAlignmentCenter;
        [footerView addSubview:label];
    }
    // button
    UIButton *inviteFriendsBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [inviteFriendsBtn setTitle:@"Invite friends to Tung" forState:UIControlStateNormal];
    [inviteFriendsBtn setTitleColor:[TungCommonObjects tungColor] forState:UIControlStateNormal];
    [inviteFriendsBtn.titleLabel setFont:[UIFont boldSystemFontOfSize:15]];
    [inviteFriendsBtn addTarget:self action:@selector(showInviteFriendsPrompt) forControlEvents:UIControlEventTouchUpInside];
    [inviteFriendsBtn setFrame:CGRectMake(0, yPos, self.view.bounds.size.width, 30)];
    [footerView addSubview:inviteFriendsBtn];
    
    return footerView;
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {

    if (_noMoreItemsToGet && section == 1) {
        NSString *thatsAll = ([_queryType isEqualToString:@"Notifications"]) ? @"That's everything. " : @"That's everyone.";
        if (!_queryType) {
        	return [self footerViewWithMessage:thatsAll];
        } else {
            return [self labelWithMessageAndBottomMargin:thatsAll];
        }
    }
    else if (_noResults && section == 1) {
        NSString *message = @"No results.";
        if (!_queryType) {
        	return [self footerViewWithMessage:message];
        } else {
            return [self labelWithMessageAndBottomMargin:message];
        }
    }
    else if (!_queryType && !_profileData && section == 1) {
        return [self footerViewWithMessage:@""];
    }
    else {
        _loadMoreIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        return _loadMoreIndicator;
    }
}
-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	if (!_queryType && !_profileData && section == 1) {
        return 60.0;
    }
    else if ((_noResults || _noMoreItemsToGet) && section == 1) {
        return 60.0;
    }
    else {
        return 0;
    }
}

#pragma mark - handle alerts

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    JPLog(@"dismissed alert with button index: %ld", (long)buttonIndex);
    
    if (alertView.tag == 59 && buttonIndex) { // invite friends request
        NSString *friends = [[alertView textFieldAtIndex:0] text];
        if (friends.length) {
        	[_tung inviteFriends:friends];
        } else {
            UIAlertView *nothingEnteredAlert = [[UIAlertView alloc] initWithTitle:@"Nothing entered" message:@"Try again?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
            nothingEnteredAlert.tag = 58;
            [nothingEnteredAlert show];
        }
    }
    if (alertView.tag == 58 && buttonIndex) { // invite friends: nothing entered
        [self showInviteFriendsPrompt];
    }
}

#pragma mark - scroll view delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if (scrollView == self.tableView) {
        // detect when user hits bottom of feed
        float bottomOffset = scrollView.contentSize.height - scrollView.frame.size.height;
        if (scrollView.contentOffset.y >= bottomOffset) {
            // request more posts if they didn't reach the end
            if (!_profileData) {
                if (!_requestingMore && !_noMoreItemsToGet && _profileArray.count > 0) {
                    _requestingMore = YES;
                    _loadMoreIndicator.alpha = 1;
                    [_loadMoreIndicator startAnimating];
                    NSNumber *oldest = [[_profileArray objectAtIndex:_profileArray.count-1] objectForKey:@"time_secs"];
                    [self requestProfileListWithQuery:_queryType
                                                   forTarget:_target_id
                                                   newerThan:[NSNumber numberWithInt:0]
                                                 orOlderThan:oldest];
                }
            }
            // TODO: onboarding: auto-load more users -
            // only happens if there are > 100 users on tung that user follows on fb/twitter
        }
    }
}


@end
