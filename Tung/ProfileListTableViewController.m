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

@interface ProfileListTableViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;

@property (nonatomic, assign) BOOL feedRefreshed;
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;
@property NSNumber *lastSeenNotification;

@end

CGFloat screenWidth;

@implementation ProfileListTableViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    _tung = [TungCommonObjects establishTungObjects];
    _tung.viewController = self;
    
    screenWidth = self.view.frame.size.width;
    
    // default target
    if (_target_id == NULL) _target_id = _tung.tungId;
    
    // default nav controller (can get overwritten)
    _navController = self.navigationController;
    
    // navigation title
    self.navigationItem.title = _queryType;
    
    // table view
    UIActivityIndicatorView *behindTable = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    behindTable.alpha = 1;
    [behindTable startAnimating];
    self.tableView.backgroundView = behindTable;
    self.tableView.backgroundColor = [TungCommonObjects bkgdGrayColor];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.separatorColor = [UIColor grayColor];
    self.tableView.scrollsToTop = YES;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 12, 0, 12);
    
    // refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
    
    // get feed
    if (_queryType) {
        
        if ([_queryType isEqualToString:@"Notifications"]) {
            // establish last seen notification time
            UserEntity *loggedUser = [TungCommonObjects retrieveUserEntityForUserWithId:_tung.tungId];
            _lastSeenNotification = loggedUser.lastSeenNotification;
        }
        [self refreshFeed];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// refresh feed by checking or newer items or getting all items
- (void) refreshFeed {
    
    [TungCommonObjects checkReachabilityWithCallback:^(BOOL reachable) {
        if (reachable) {
            _tung.connectionAvailable = [NSNumber numberWithBool:YES];
        	// query users
            _feedRefreshed = YES;
            NSNumber *mostRecent;
            if (_profileArray.count > 0) {
                //CLS_LOG(@"profile list: refresh feed");
                [self.refreshControl beginRefreshing];
                mostRecent = [[_profileArray objectAtIndex:0] objectForKey:@"time_secs"];
            } else {
                //CLS_LOG(@"profile list: get feed");
                mostRecent = [NSNumber numberWithInt:0];
            }
            [self requestProfileListWithQuery:_queryType
                                           forTarget:_target_id
                                           newerThan:mostRecent
                                         orOlderThan:[NSNumber numberWithInt:0]];
        }
        // unreachable
        else {
            UIAlertView *noReachabilityAlert = [[UIAlertView alloc] initWithTitle:@"No Connection" message:@"tung requires an internet connection" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
            [noReachabilityAlert setTag:49];
            [noReachabilityAlert show];
        }
    }];
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

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 49) [self refreshFeed]; // unreachable, retry
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
    //CLS_LOG(@"get profile list with params: %@", params);
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
                                CLS_LOG(@"SESSION EXPIRED");
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
                                //CLS_LOG(@"no more items to get");
                                _noMoreItemsToGet = YES;
                                // hide footer
                                //[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_profileArray.count-1 inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:YES]; // causes crash on search page
                                [self.tableView reloadData];
                            } else {
                                //CLS_LOG(@"\tgot items older than: %@", beforeTime);
                                int startingIndex = (int)_profileArray.count;
                                // CLS_LOG(@"\tstarting index: %d", startingIndex);
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
                        
                        CLS_LOG(@"got items. profileArray count: %lu", (unsigned long)[_profileArray count]);
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
                CLS_LOG(@"no response");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self endRefreshing];
                });
            }
            else if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self endRefreshing];
                });
                CLS_LOG(@"Error: %@", error);
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"HTML: %@", html);
            }
        }
        // error
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self endRefreshing];
                
                UIAlertView *connectionErrorAlert = [[UIAlertView alloc] initWithTitle:@"Connection error" message:[error localizedDescription] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                self.tableView.backgroundView = nil;
                [connectionErrorAlert show];
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
    
    CLS_LOG(@"push profile of user: %@", [profileDict objectForKey:@"username"]);
    // push profile
    
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


static NSString *profileListCellIdentifier = @"ProfileListCell";

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:profileListCellIdentifier];
    //CLS_LOG(@"profile list cell for row at index path: %ld", (long)indexPath.row);
    ProfileListCell *profileCell = (ProfileListCell *)cell;
    
    // cell data
    profileCell.profileDict = [NSDictionary dictionaryWithDictionary:[_profileArray objectAtIndex:indexPath.row]];
    //CLS_LOG(@"%@", profileCell.profileDict);
    NSString *action = [profileCell.profileDict objectForKey:@"action"];
    
    // avatar
    NSString *avatarUrlString = [profileCell.profileDict objectForKey:@"small_av_url"];
    NSData *avatarImageData = [TungCommonObjects retrieveSmallAvatarDataWithUrlString:avatarUrlString];
    profileCell.avatarContainerView.backgroundColor = [UIColor clearColor];
    profileCell.avatarContainerView.avatar = nil;
    profileCell.avatarContainerView.avatar = [[UIImage alloc] initWithData:avatarImageData];
    profileCell.avatarContainerView.borderColor = [UIColor whiteColor];
    [profileCell.avatarContainerView setNeedsDisplay];
    
    // username
    profileCell.usernameLabel.text = [profileCell.profileDict objectForKey:@"username"];
    if (screenWidth < 375) {
        profileCell.usernameLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    }
    [profileCell.avatarButton addTarget:self action:@selector(tableCellButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    profileCell.avatarButton.tag = 100;
    
    // query type (sub label)
    if ([_queryType isEqualToString:@"Notifications"]) {
        
        profileCell.subLabelLeadingConstraint.constant = 30;
        profileCell.iconView.hidden = NO;
        //CLS_LOG(@"action: %@", action);
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
        NSNumber *time_secs = [profileCell.profileDict objectForKey:@"time_secs"];
        //NSLog(@"lastSeenNotification: %@, time_secs: (%ld) %@", _lastSeenNotification, (long)indexPath.row, time_secs);
        if (time_secs.doubleValue > _lastSeenNotification.doubleValue) {
            profileCell.backgroundColor = [TungCommonObjects lightTungColor];
        } else {
            profileCell.backgroundColor = [UIColor whiteColor];
        }
        
    }
    else {
        
        profileCell.subLabel.text = [profileCell.profileDict objectForKey:@"name"];
        profileCell.subLabelLeadingConstraint.constant = 7;
        profileCell.iconView.hidden = YES;
    }
    
    // follow button
    if ([_tung.tungId isEqualToString:[profileCell.profileDict objectForKey:@"id"]]) { 
        profileCell.followBtn.hidden = YES;
        profileCell.youLabel.hidden = NO;
        profileCell.accessoryType = UITableViewCellAccessoryNone;
    }
    else {
        // user/user relationship
        //CLS_LOG(@"userfollows: %@", [profileCell.profileDict objectForKey:@"userFollows"]);
        profileCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        profileCell.followBtn.hidden = NO;
        profileCell.youLabel.hidden = YES;
        NSNumber *userFollows = [profileCell.profileDict objectForKey:@"userFollows"];
        if (userFollows.boolValue) {
            profileCell.followBtn.on = YES;
        } else {
            profileCell.followBtn.on = NO;
        }
    }
    profileCell.followBtn.type = kPillTypeFollow;
    profileCell.followBtn.backgroundColor = [UIColor clearColor];
    [profileCell.followBtn setNeedsDisplay];
    
    return cell;
}

#pragma mark - Table view delegate methods

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (screenWidth > 320) {
    	return 80;
    } else {
        return 64;
    }
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *profileDict = [NSDictionary dictionaryWithDictionary:[_profileArray objectAtIndex:indexPath.row]];
    //CLS_LOG(@"selected %@", profileDict);
    
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

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    
    if (_noMoreItemsToGet && section == 1) {
        UILabel *noMoreLabel = [[UILabel alloc] init];
        NSString *thatsAll = ([_queryType isEqualToString:@"Notifications"]) ? @"That's everything.\n " : @"That's everyone.\n ";
        noMoreLabel.text = thatsAll;
        noMoreLabel.numberOfLines = 0;
        noMoreLabel.textColor = [UIColor grayColor];
        noMoreLabel.textAlignment = NSTextAlignmentCenter;
        return noMoreLabel;
    }
    else if (_noResults && section == 1) {
         UILabel *noResultsLabel = [[UILabel alloc] init];
         noResultsLabel.text = @"No results.";
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
    if (!_noMoreItemsToGet && section == 0)
        return 60.0;
    else if ((_noResults || _noMoreItemsToGet) && section == 1)
        return 60.0;
    else
        return 0;
}

#pragma mark - scroll view delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if (scrollView == self.tableView) {
        // detect when user hits bottom of feed
        float bottomOffset = scrollView.contentSize.height - scrollView.frame.size.height;
        if (scrollView.contentOffset.y >= bottomOffset) {
            // request more posts if they didn't reach the end
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
    }
}


@end
