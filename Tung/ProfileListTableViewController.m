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

@interface ProfileListTableViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;

@property (nonatomic, assign) BOOL feedRefreshed;
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;

@end

@implementation ProfileListTableViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    _tung.viewController = self;
    
    // default target
    if (_target_id == NULL) _target_id = _tung.tungId;
    
    // navigation title
    self.navigationItem.title = _queryType;
    
    // table view
    UIActivityIndicatorView *behindTable = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    behindTable.alpha = 1;
    [behindTable startAnimating];
    self.tableView.backgroundView = behindTable;
    self.tableView.backgroundColor = _tung.bkgdGrayColor;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.separatorColor = [UIColor grayColor];
    self.tableView.scrollsToTop = YES;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    
    // refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
    
    // get feed
    if (_queryType) {
        _navController = self.navigationController;
        [self refreshFeed];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) refreshFeed {
    
    [TungCommonObjects checkReachabilityWithCallback:^(BOOL reachable) {
        if (reachable) {
        	// query users
            _feedRefreshed = YES;
            NSNumber *mostRecent;
            if (_profileArray.count > 0) {
                NSLog(@"profile list: refresh feed");
                [self.refreshControl beginRefreshing];
                mostRecent = [[_profileArray objectAtIndex:0] objectForKey:@"time_secs"];
            } else {
                NSLog(@"profile list: get feed");
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
    NSLog(@"get profile list with params: %@", params);
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
                                NSLog(@"SESSION EXPIRED");
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
                                NSLog(@"no more items to get");
                                _noMoreItemsToGet = YES;
                                // hide footer
                                //[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_profileArray.count-1 inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:YES]; // causes crash on search page
                                [self.tableView reloadData];
                            } else {
                                NSLog(@"\tgot items older than: %@", beforeTime);
                                int startingIndex = (int)_profileArray.count;
                                // NSLog(@"\tstarting index: %d", startingIndex);
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
                        
                        NSLog(@"got items. profileArray count: %lu", (unsigned long)[_profileArray count]);
                        [self preloadAvatars];
                    });
                }
            }
            else if ([data length] == 0 && error == nil) {
                NSLog(@"no response");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self endRefreshing];
                });
            }
            else if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self endRefreshing];
                });
                NSLog(@"Error: %@", error);
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"HTML: %@", html);
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


NSString static *avatarsDir;

-(void) preloadAvatars {
    
    if (!avatarsDir) {
        avatarsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"avatars"];
    }
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:avatarsDir withIntermediateDirectories:YES attributes:nil error:&error];
    
    NSOperationQueue *preloadQueue = [[NSOperationQueue alloc] init];
    preloadQueue.maxConcurrentOperationCount = 3;
    // download and save avatars to temp directory if they don't exist
    
    for (int i = 0; i < _profileArray.count; i++) {
        
        [preloadQueue addOperationWithBlock:^{
            // avatar
            NSString *avatarURLString = [[[_profileArray objectAtIndex:i] objectForKey:@"user"] objectForKey:@"small_av_url"];
            NSString *avatarFilename = [avatarURLString lastPathComponent];
            NSString *avatarFilepath = [avatarsDir stringByAppendingPathComponent:avatarFilename];
            if (![[NSFileManager defaultManager] fileExistsAtPath:avatarFilepath]) {
                NSData *avatarImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:avatarURLString]];
                [avatarImageData writeToFile:avatarFilepath atomically:YES];
            }
        }];
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
    
    NSLog(@"push profile of user: %@", [profileDict objectForKey:@"username"]);
    // push profile
    ProfileViewController *profileView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileView"];
    profileView.profiledUserId = [profileDict objectForKey:@"id"];
    [_navController pushViewController:profileView animated:YES];
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
    NSLog(@"profile list cell for row at index path: %ld", (long)indexPath.row);
    ProfileListCell *profileCell = (ProfileListCell *)cell;
    
    // cell data
    profileCell.profileDict = [NSDictionary dictionaryWithDictionary:[_profileArray objectAtIndex:indexPath.row]];
    NSString *action = [profileCell.profileDict objectForKey:@"action"];
    
    // avatar
    if (!avatarsDir) {
        avatarsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"avatars"];
    }
    NSString *avatarFilename = [[profileCell.profileDict objectForKey:@"small_av_url"] lastPathComponent];
    NSString *avatarFilepath = [avatarsDir stringByAppendingPathComponent:avatarFilename];
    NSData *avatarImageData;
    // make sure it is cached, even though we preloaded it
    if ([[NSFileManager defaultManager] fileExistsAtPath:avatarFilepath]) {
        avatarImageData = [NSData dataWithContentsOfFile:avatarFilepath];
    } else {
        avatarImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString: [profileCell.profileDict objectForKey:@"small_av_url"]]];
        [avatarImageData writeToFile:avatarFilepath atomically:YES];
    }
    profileCell.avatarContainerView.backgroundColor = [UIColor clearColor];
    profileCell.avatarContainerView.avatar = nil;
    profileCell.avatarContainerView.avatar = [[UIImage alloc] initWithData:avatarImageData];
    profileCell.avatarContainerView.borderColor = [UIColor whiteColor];
    [profileCell.avatarContainerView setNeedsDisplay];
    
    // username
    [profileCell.usernameButton setTitle:[profileCell.profileDict objectForKey:@"username"] forState:UIControlStateNormal];
    [profileCell.usernameButton addTarget:self action:@selector(tableCellButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    profileCell.usernameButton.tag = 100;
    [profileCell.avatarButton addTarget:self action:@selector(tableCellButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    profileCell.avatarButton.tag = 100;
    
    // sub label
    if ([_queryType isEqualToString:@"Notifications"]) {
        
        profileCell.subLabelLeadingConstraint.constant = 38;
        profileCell.iconView.hidden = NO;
        profileCell.iconView.backgroundColor = [UIColor clearColor];
        NSLog(@"action: %@", action);
        NSString *eventString;
        if ([action isEqualToString:@"followed"]) {
            profileCell.iconView.type = kIconTypeAdd;
            eventString = @"Followed you";
        }
        else if ([action isEqualToString:@"mentioned"]) {
            profileCell.iconView.type = kIconTypeComment;
            eventString = @"Mentioned you in a comment";
        }
        profileCell.iconView.color = [UIColor grayColor];
        [profileCell.iconView setNeedsDisplay];
        profileCell.subLabel.text = eventString;
    }
    else {
        
        profileCell.subLabel.text = [profileCell.profileDict objectForKey:@"name"];
        profileCell.subLabelLeadingConstraint.constant = 14;
        profileCell.iconView.hidden = YES;
    }
    
    // follow button
    if ([_tung.tungId isEqualToString:[profileCell.profileDict objectForKey:@"id"]]) {
        profileCell.followBtn.hidden = YES;
        profileCell.accessoryType = UITableViewCellAccessoryNone;
    }
    else {
        // user/user relationship
        //NSLog(@"userfollows: %@", [profileCell.profileDict objectForKey:@"userFollows"]);
        profileCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        profileCell.followBtn.hidden = NO;
        if ([profileCell.profileDict objectForKey:@"userFollows"]) {
            profileCell.followBtn.on = YES;
        } else {
            profileCell.followBtn.on = NO;
        }
    }
    profileCell.followBtn.type = kPillTypeFollow;
    profileCell.followBtn.backgroundColor = [UIColor clearColor];
    [profileCell.followBtn setNeedsDisplay];
    
    
    NSLog(@"-----");
    return cell;
}

#pragma mark - Table view delegate methods

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {

    return 80;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    
    NSDictionary *profileDict = [NSDictionary dictionaryWithDictionary:[_profileArray objectAtIndex:indexPath.row]];
    if ([profileDict objectForKey:@"eventId"]) {
        
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
        NSString *thatsAll = ([_queryType isEqualToString:@"Notifications"]) ? @"That's everything" : @"That's everyone";
        noMoreLabel.text = thatsAll;
        noMoreLabel.textColor = [UIColor grayColor];
        noMoreLabel.textAlignment = NSTextAlignmentCenter;
        return noMoreLabel;
    }
    /* only used if search was in title bar (not currently)
     else if (_tungStereo.noResults && section == 1) {
     UILabel *noResultsLabel = [[UILabel alloc] init];
     noResultsLabel.text = @"No clips for that query.";
     noResultsLabel.textColor = [UIColor grayColor];
     noResultsLabel.textAlignment = NSTextAlignmentCenter;
     return noResultsLabel;
     }
     */
    else {
        _loadMoreIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        return _loadMoreIndicator;
    }
}
-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (!_noMoreItemsToGet && section == 0)
        return 60.0;
    else if (_noMoreItemsToGet && section == 1)
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
