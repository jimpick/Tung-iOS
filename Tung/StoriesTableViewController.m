//
//  TungActivity.m
//  Tung
//
//  Created by Jamie Perkins on 6/22/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "StoriesTableViewController.h"
#import "TungCommonObjects.h"
#import "TungPodcast.h"
#import "StoryHeaderCell.h"
#import "StoryEventCell.h"
#import "StoryFooterCell.h"
#import "EpisodeViewController.h"
#import "ProfileViewController.h"
#import "FeedViewController.h"
#import "KLCPopup.h"
#import "WelcomePopupView.h"
#import "JPLogRecorder.h"

@interface StoriesTableViewController()

@property CGPoint contentOffset;
@property BOOL contentOffsetSet;

- (void) groupStoriesByEpisodeAndInsertInTable:(UITableView *)tableView withRange:(NSRange)tableRange;

@end

@implementation StoriesTableViewController

CGFloat screenWidth, headerViewHeight, headerScrollViewHeight, tableHeaderRow, animationDistance;


- (void)viewDidLoad {

    [super viewDidLoad];
        
    _tung = [TungCommonObjects establishTungObjects];
    
    if (!_profiledUserId) _profiledUserId = @"";
    
    _storiesArray = [NSMutableArray new];
    
    _activeRowIndex = -2; // < 0 && != -1
    _activeSectionIndex = -2;
    _selectedRowIndex = -1;
    _selectedSectionIndex = -1;
    
    self.requestStatus = @"";
    
    // default vc and nav controller (can get overwritten)
    _navController = self.navigationController;
    
    // table
    self.tableView.backgroundColor = [TungCommonObjects bkgdGrayColor];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.scrollsToTop = YES;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, -5, 0);
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 12, 0, 12);
    self.tableView.separatorColor = [UIColor colorWithWhite:1 alpha:.7];
    // refresh control
    if (!_episodeId) {
        self.refreshControl = [[UIRefreshControl alloc] init];
        [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
    }
    // table bkgd
    UIActivityIndicatorView *tableSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    tableSpinner.alpha = 1;
    [tableSpinner startAnimating];
    self.tableView.backgroundView = tableSpinner;
    // long press recognizer
    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tableCellLongPress:)];
    longPressRecognizer.minimumPressDuration = 0.75; //seconds
    longPressRecognizer.delegate = self;
    [self.tableView addGestureRecognizer:longPressRecognizer];
    
    // for animating header height
    CGFloat minHeaderHeight = 80;
    tableHeaderRow = 61;
    headerViewHeight = 223;
    headerScrollViewHeight = headerViewHeight - tableHeaderRow;
    animationDistance = headerScrollViewHeight - minHeaderHeight;
    screenWidth = self.view.frame.size.width;
    _tung.screenWidth = screenWidth;
    
    if (_episodeId) {
        self.navigationItem.title = @"Episode";
        self.tableView.bounces = NO;
        [self getStoriesForEpisodeWithId:_episodeId fromUser:_profiledUserId];
    }
        
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (!_contentOffsetSet) {
    	_contentOffset = self.tableView.contentOffset;
        _contentOffsetSet = YES;
    }
}

- (void) refreshFeed {
    
    if (_tung.connectionAvailable.boolValue) {
    
        NSNumber *mostRecent;

        if (_storiesArray.count > 0) {
            // animate refresh control if table is scrolled to top
            if (self.tableView.contentOffset.y <= _contentOffset.y) {
                [self.refreshControl beginRefreshing];
                [self.tableView setContentOffset:CGPointMake(0, - (self.refreshControl.frame.size.height - _contentOffset.y)) animated:YES];
            }
            mostRecent = [[[_storiesArray objectAtIndex:0] objectAtIndex:0] objectForKey:@"time_secs"];
            
        }
        // if initial request timed out and they are trying again
        else {
            mostRecent = [NSNumber numberWithInt:0];
        }

        [self requestPostsNewerThan:mostRecent
                        orOlderThan:[NSNumber numberWithInt:0]
                           fromUser:_profiledUserId
                           withCred:NO];
    }
    else {
        [_tung checkReachabilityWithCallback:^(BOOL reachable) {
            if (reachable) [self refreshFeed];
        }];
    }
}

- (void) refetchFeed {
    
    [self requestPostsNewerThan:[NSNumber numberWithInt:0]
                    orOlderThan:[NSNumber numberWithInt:0]
                       fromUser:_profiledUserId
                       withCred:NO];

}

-(void) getSessionAndFeed {
    
    if (_tung.connectionAvailable.boolValue) {
        [self requestPostsNewerThan:[NSNumber numberWithInt:0]
                        orOlderThan:[NSNumber numberWithInt:0]
                           fromUser:_profiledUserId
                           withCred:YES];
    }
    else {
        [_tung checkReachabilityWithCallback:^(BOOL reachable) {
            if (reachable) [self getSessionAndFeed];
        }];
    }
}

- (void) pushEpisodeViewForIndexPath:(NSIndexPath *)indexPath withFocusedEventId:(NSString *)eventId {
    
    // id method
    NSDictionary *storyDict = [[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:0];
    NSDictionary *episodeMiniDict = [storyDict objectForKey:@"episode"];
    
    EpisodeViewController *episodeView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"episodeView"];
    episodeView.episodeMiniDict = episodeMiniDict;
    episodeView.focusedEventId = eventId;

    
    [_navController pushViewController:episodeView animated:YES];
}

#pragma mark - Requests

NSInteger requestTries = 0;

// single story request
- (void) getStoriesForEpisodeWithId:(NSString *)episodeId fromUser:(NSString *)userId {
    
    NSLog(@"get stories for episode with id: %@, from user: %@", episodeId, userId);
    NSURL *storyURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/stories-for-episode.php", _tung.apiRootUrl]];
    NSMutableURLRequest *storyRequest = [NSMutableURLRequest requestWithURL:storyURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [storyRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{
                             @"sessionId": _tung.sessionId,
                             @"episode_id": episodeId,
                             @"profiled_user_id": userId
                             };
    //JPLog(@"request for stories with params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [storyRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:storyRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            
            if (jsonData != nil && error == nil) {
                
                NSDictionary *responseDict = jsonData;
                
                if ([responseDict objectForKey:@"error"]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            //JPLog(@"SESSION EXPIRED");
                            [_tung getSessionWithCallback:^{
                                [self getStoriesForEpisodeWithId:episodeId fromUser:userId];
                            }];
                        } else {
                            [self endRefreshing];
                            // other error - alert user
                            [_tung simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                        }
                    });
                }
                else if ([responseDict objectForKey:@"success"]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        [self endRefreshing];
                        
                        NSArray *newStories = [responseDict objectForKey:@"stories"];
                        if (newStories.count > 0) {
                            _storiesArray = [self processStories:newStories];
                            _noResults = NO;
                        } else {
                            _noResults = YES;
                        }
                        
                        [self groupStoriesByEpisodeAndInsertInTable:self.tableView withRange:NSMakeRange(0, 0)];
                        
                    });
                }
            }
            // errors
            else if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self endRefreshing];
                });
                JPLog(@"Error: %@", error);
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                JPLog(@"HTML: %@", html);
            }
        }
        // connection error
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [self endRefreshing];
            });
        }
    }];
}


// feed request
-(void) requestPostsNewerThan:(NSNumber *)afterTime
                  orOlderThan:(NSNumber *)beforeTime
                     fromUser:(NSString *)user_id
                     withCred:(BOOL)withCred {
    
//    if (!_tung.connectionAvailable.boolValue) {
//        [self endRefreshing];
//        [TungCommonObjects showNoConnectionAlert];
//    }
    
    requestTries++;
    self.requestStatus = @"initiated";
    NSDate *requestStarted = [NSDate date];
    
    NSURL *feedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/feed.php", _tung.apiRootUrl]];
    NSMutableURLRequest *feedRequest = [NSMutableURLRequest requestWithURL:feedURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [feedRequest setHTTPMethod:@"POST"];
    NSMutableDictionary *params = [@{@"sessionId": _tung.sessionId,
                                     @"newerThan": afterTime,
                                     @"olderThan": beforeTime,
                                     @"profiled_user_id": user_id
                                     } mutableCopy];
    if (withCred) {
        NSDictionary *credParams = @{@"tung_id": _tung.tungId,
                                     @"token": _tung.tungToken
                                     };
        [params addEntriesFromDictionary:credParams];
    }
    //JPLog(@"request for stories with params: %@", params);
    
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [feedRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:feedRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                requestTries = 0;
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self requestPostsNewerThan:afterTime orOlderThan:beforeTime fromUser:user_id withCred:YES];
                            
                        }
                        else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Unauthorized"]) {
                            [_tung handleUnauthorizedWithCallback:^{
                                [self requestPostsNewerThan:afterTime orOlderThan:beforeTime fromUser:user_id withCred:NO];
                            }];
                        }
                        else {
                            [self endRefreshing];
                            self.requestStatus = @"finished";
                            // other error - alert user
                            [_tung simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        
                        NSTimeInterval requestDuration = [requestStarted timeIntervalSinceNow];
                        NSArray *newStories = [responseDict objectForKey:@"stories"];
                        //NSLog(@"new stories: %@", newStories);
                        NSLog(@"new stories count: %lu", (unsigned long)newStories.count);
                        
                        // if this is for the main feed, set feedLastFetched date (seconds)
                        if (user_id.length == 0) {
                            SettingsEntity *settings = [TungCommonObjects settings];
                            settings.feedLastFetched = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
                            [TungCommonObjects saveContextWithReason:@"set feedLastFetched"];
                        }
                        
                        if (withCred) {
                            
                            JPLog(@"got stories AND session in %f seconds.", fabs(requestDuration));
                            _tung.sessionId = [responseDict objectForKey:@"sessionId"];
                            _tung.connectionAvailable = [NSNumber numberWithInt:1];
                            // check if data needs syncing
                            UserEntity *loggedUser = [TungCommonObjects retrieveUserEntityForUserWithId:_tung.tungId];
                            NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                            if (loggedUser) {
                                JPLog(@"lastDataChange (server): %@, lastDataChange (local): %@", lastDataChange, loggedUser.lastDataChange);
                                if (lastDataChange.doubleValue > loggedUser.lastDataChange.doubleValue) {
                                    JPLog(@"needs restore. ");
                                    [_tung restorePodcastDataSinceTime:loggedUser.lastDataChange];
                                }
                            } else {
                                // no logged in user data - save with data from request
                                JPLog(@"no logged in user data... save new entity and restore data");
                                UserEntity *loggedUser = [TungCommonObjects saveUserWithDict:[responseDict objectForKey:@"user"]];
                                
                                // we don't have local data to compare, so we just restore
                                [_tung restorePodcastDataSinceTime:loggedUser.lastDataChange];
                            }
                        }
                        else {
                            
                            //JPLog(@"got stories in %f seconds.", fabs(requestDuration));
                        }
                        
                        [self endRefreshing];
                        
                        // pull refresh
                        if ([afterTime intValue] > 0) {
                            if (newStories.count > 0) {
                                //JPLog(@"got stories newer than: %@", afterTime);
                                [self stopClipPlayback];
                                
                                [self removeOlderDuplicatesOfNewStories:newStories];
                                
                                NSArray *newItems = [self processStories:newStories];
                                NSArray *newFeedArray = [newItems arrayByAddingObjectsFromArray:_storiesArray];
                                _storiesArray = [newFeedArray mutableCopy];
                                
                                [self groupStoriesByEpisodeAndInsertInTable:self.tableView withRange:NSMakeRange(0, 0)];
                                
                            }
                        }
                        // auto-loaded posts as user scrolls down
                        else if ([beforeTime intValue] > 0) {
                            
                            _reachedEndOfPosts = (newStories.count == 0);
                            if (_reachedEndOfPosts) {
                                //JPLog(@"no more stories to get");
                                // hide footer
                                //[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_storiesArray.count-1 inSection:_feedSection] atScrollPosition:UITableViewScrollPositionMiddle animated:YES]; // causes crash on search page
                                [self.tableView reloadData];
                                
                            } else {
                                //JPLog(@"got stories older than: %@", beforeTime);
                                int startingIndex = (int)_storiesArray.count;
                                
                                NSArray *newFeedArray = [_storiesArray arrayByAddingObjectsFromArray:[self processStories:newStories]];
                                _storiesArray = [newFeedArray mutableCopy];
                                newFeedArray = nil;
                                
                                [self groupStoriesByEpisodeAndInsertInTable:self.tableView withRange:NSMakeRange(0, startingIndex)];
                                
                            }
                        }
                        // initial request
                        else {
                            
                            // feed is now reFETCHED
                            if (_profiledUserId.length && [_profiledUserId isEqualToString:_tung.tungId]) {
                                _tung.profileFeedNeedsRefetch = [NSNumber numberWithBool:NO];
                            }
                            else if (!_profiledUserId.length && !_episodeId) {
                                _tung.feedNeedsRefetch = [NSNumber numberWithBool:NO];
                            }

                            
                            _noResults = (newStories.count == 0);
                            if (!_noResults) {
                                _storiesArray = [self processStories:newStories];
                            }
                            
                            [self groupStoriesByEpisodeAndInsertInTable:self.tableView withRange:NSMakeRange(0, 0)];
                            
                            // welcome tutorial
                            SettingsEntity *settings = [TungCommonObjects settings];
                            if (!settings.hasSeenWelcomePopup.boolValue) {
                                [NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(showWelcomePopup) userInfo:nil repeats:NO];
                            }
                        }
                        
                        
                        //JPLog(@"stories array: %@", _storiesArray);
                        
                        // feed is now refreshed
                        self.requestStatus = @"finished";
                        
                        if (_profiledUserId.length && [_profiledUserId isEqualToString:_tung.tungId]) {
                            // profile feed has been refreshed
                            _tung.profileFeedNeedsRefresh = [NSNumber numberWithBool:NO];
                        }
                        else if (!_profiledUserId.length && !_episodeId) {
                            // main feed page has been refreshed
                            _tung.feedNeedsRefresh = [NSNumber numberWithBool:NO];
                        }
                    }
                }
                // errors
                else if ([data length] == 0 && error == nil) {
                    JPLog(@"no response");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self endRefreshing];
                    });
                }
                else if (error != nil) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self endRefreshing];
                    });
                    JPLog(@"Error: %@", error);
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"HTML: %@", html);
                }
                
            });
        }
        // connection error
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (requestTries < 3) {
                    
                    JPLog(@"request %ld failed, trying again", (long)requestTries);
                    [self requestPostsNewerThan:afterTime orOlderThan:beforeTime fromUser:user_id withCred:withCred];
                }
                else {
                    [self endRefreshing];
                    
                    [_tung showConnectionErrorAlertForError:error];
                }
            });
        }
    }];
}

- (void) endRefreshing {
    _requestingMore = NO;
    self.requestStatus = @"finished";
    _loadMoreIndicator.alpha = 0;
    
    if (self.refreshControl.refreshing) {
        [self.refreshControl endRefreshing];
        [self.tableView setContentOffset:_contentOffset animated:YES];
    }
    
    if (_tung.connectionAvailable.boolValue) {
    	self.tableView.backgroundView = nil;
    } else {
        UILabel *retryLabel = [[UILabel alloc] init];
        retryLabel.text = @"Swipe down to retry";
        retryLabel.numberOfLines = 1;
        retryLabel.textColor = [UIColor grayColor];
        retryLabel.textAlignment = NSTextAlignmentCenter;
        self.tableView.backgroundView = retryLabel;
    }
}

/*	break events apart from story and into their own array items in story sections in _storiesArray,
	while we're at it, preload avatars, album art and clips.
 */
- (NSMutableArray *) processStories:(NSArray *)stories {
    
    NSOperationQueue *preloadQueue = [[NSOperationQueue alloc] init];
    preloadQueue.maxConcurrentOperationCount = 3;
    
    // process stories
    NSMutableArray *results = [NSMutableArray new];
    for (int i = 0; i < stories.count; i++) {
        
        NSMutableArray *storyArray = [NSMutableArray new];
        NSMutableDictionary *headerDict = [[stories objectAtIndex:i] mutableCopy];
        UIColor *keyColor = [TungCommonObjects colorFromHexString:[[headerDict objectForKey:@"episode"] objectForKey:@"keyColor1Hex"]];
        [headerDict setObject:keyColor forKey:@"keyColor"];
        NSArray *events = [headerDict objectForKey:@"events"];
        NSString *username = [[headerDict objectForKey:@"user"] objectForKey:@"username"];
        NSString *episodeShortlink = [[headerDict objectForKey:@"episode"] objectForKey:@"shortlink"];
        NSString *episodeLink = [NSString stringWithFormat:@"%@e/%@", _tung.tungSiteRootUrl, episodeShortlink];
        [headerDict setObject:episodeLink forKey:@"episodeLink"];
        NSString *storyLink = [NSString stringWithFormat:@"%@e/%@/%@", _tung.tungSiteRootUrl, episodeShortlink, username];
        [headerDict setObject:storyLink forKey:@"storyLink"];
        [headerDict setObject:[headerDict objectForKey:@"time_secs"] forKey:@"time_secs_end"];
        
        [storyArray addObject:headerDict];
        
        // preload avatar and album art
        [preloadQueue addOperationWithBlock:^{
            // avatar
            NSString *avatarURLString = [[headerDict objectForKey:@"user"] objectForKey:@"small_av_url"];
            [TungCommonObjects retrieveSmallAvatarDataWithUrlString:avatarURLString];
            // album art
            NSString *artURLString = [[headerDict objectForKey:@"episode"] objectForKey:@"artworkUrlSSL"];
            NSNumber *collectionId = [[headerDict objectForKey:@"episode"] objectForKey:@"collectionId"];
            [TungCommonObjects retrievePodcastArtDataWithUrlString:artURLString andCollectionId:collectionId];
        }];
        
        int eventLimit = 5;
        if (_episodeId) eventLimit = 50; // per story event limit
        
        for (int e = 0; e < events.count; e++) {
            
            NSMutableDictionary *eventDict = [[events objectAtIndex:e] mutableCopy];
            [eventDict setObject:keyColor forKey:@"keyColor"];
            [eventDict setObject:[headerDict objectForKey:@"user"] forKey:@"user"];
            NSString *type = [eventDict objectForKey:@"type"];
            // preload clip
            if ([type isEqualToString:@"clip"]) {
                [preloadQueue addOperationWithBlock:^{
                    NSString *clipURLString = [eventDict objectForKey:@"clip_url"];
                    [TungCommonObjects retrieveAudioClipDataWithUrlString:clipURLString];
                }];
            }
            if (e < eventLimit) {
                [storyArray addObject:eventDict];
            } else {
                break;
            }
        }
        [headerDict removeObjectForKey:@"events"];
        NSDictionary *footerDict = [NSDictionary dictionaryWithObjects:@[keyColor]
                                                               forKeys:@[@"keyColor"]];
        [storyArray addObject:footerDict];
        [results addObject:storyArray];
        
    }
    return results;
}


/* 	new stories fetched after feed has already been fetched may be part of those already fetched.
	if the same story id comes down again, this method removes the older duplicate.
 */
- (void) removeOlderDuplicatesOfNewStories:(NSArray *)newStories {
    
    for (int i = 0; i < newStories.count; i++) {
        NSString *storyIdToMatch = [[[newStories objectAtIndex:i] objectForKey:@"_id"] objectForKey:@"$id"];
        
        // check for story id match in main stories array
        for (int j = 0; j < _storiesArray.count; j++) {
            NSDictionary *headerDict = [[_storiesArray objectAtIndex:j] objectAtIndex:0];
            
            // story match
            if ([storyIdToMatch isEqualToString:[[headerDict objectForKey:@"_id"] objectForKey:@"$id"]]) {
                [_storiesArray removeObjectAtIndex:j];
                // remove section (story)
                [UIView setAnimationsEnabled:NO];
                [self.tableView beginUpdates];
                [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:j]withRowAnimation:UITableViewRowAnimationNone];
                [self.tableView endUpdates];
                [UIView setAnimationsEnabled:YES];
                
                break;
            }
        }
    }
}


/*	group stories by episode across entire _storiesArray so that all users who listened to it appear in one story.
 	tableRange is a range where stories already exist in the table, where table updates will need to be made.
 	Finally, this methods inserts story sections into the table where necessary.
 */
- (void) groupStoriesByEpisodeAndInsertInTable:(UITableView *)tableView withRange:(NSRange)tableRange {
    
    //NSLog(@"group stories with range (%lu, %lu) begin: %lu", (unsigned long)tableRange.location, (unsigned long)tableRange.length, (unsigned long)_storiesArray.count);
    
    NSMutableIndexSet *indexesToDelete = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *indexesToReload = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *indexesToInsert = [NSMutableIndexSet indexSet];
    
    for (int i = 0; i < _storiesArray.count; i++) {
        NSMutableArray *story = [_storiesArray objectAtIndex:i];
        NSMutableDictionary *dict = [story objectAtIndex:0];
        NSString *episodeId = [[[dict objectForKey:@"episode"] objectForKey:@"id"] objectForKey:@"$id"];
        //NSLog(@"check for match against story %@ at index %d", [[dict objectForKey:@"episode"] objectForKey:@"title"], i);
        
        // check for match
        for (int j = 0; j < _storiesArray.count; j++) {
            
            if (j != i) {
                NSArray *comparedStory = [_storiesArray objectAtIndex:j];
                NSDictionary *comparedDict = [comparedStory objectAtIndex:0];
                NSString *comparedEpisodeId = [[[comparedDict objectForKey:@"episode"] objectForKey:@"id"] objectForKey:@"$id"];
                
                // story match
                if ([episodeId isEqualToString:comparedEpisodeId]) {
                    
                    //NSLog(@"several users listened to %@", [[dict objectForKey:@"episode"] objectForKey:@"title"]);
                    NSDictionary *userDict = [comparedDict objectForKey:@"user"];
                    
                    // add user dict to story header for avatars
                    NSMutableArray *users = [NSMutableArray array];
                    // was the story previously grouped?
                    if ([comparedDict objectForKey:@"users"]) {
                        [users addObjectsFromArray:[comparedDict objectForKey:@"users"]];
                    }
                 	else {
                        [users addObject:userDict];
                    }
                    // add newer occurences after older, so oldest appears first
                    if ([dict objectForKey:@"users"]) {
                        [users addObjectsFromArray:[dict objectForKey:@"users"]];
                    }
                    else {
                        // this is the first match found
                        [users addObject:[dict objectForKey:@"user"]];
                    }
                    
                    [dict setObject:users forKey:@"users"];
                    [dict setObject:[comparedDict objectForKey:@"time_secs_end"] forKey:@"time_secs_end"];
                    [story replaceObjectAtIndex:0 withObject:dict];
                    
                    // add events of compared story into *story
                    int insertIndex = 1;
                    for (int k = 1; k < comparedStory.count -1; k++) {
                        [story insertObject:[comparedStory objectAtIndex:k] atIndex:insertIndex];
                        insertIndex++;
                    }
                    
                    // remove match
                    [_storiesArray removeObjectAtIndex:j];
                    if (NSLocationInRange(j, tableRange)) {
                        //NSLog(@"••• delete section at index: %d", j);
                        [indexesToDelete addIndex:j];
                    }
                    j--;
                    
                    // replace *story with grouped story.
                    [_storiesArray replaceObjectAtIndex:i withObject:story];
                    if (NSLocationInRange(i, tableRange)) {
                        //NSLog(@"••• reload section at index: %d", i);
                        [indexesToReload addIndex:i];
                    }
                }
            }
        }
        
        if (!NSLocationInRange(i, tableRange) && tableRange.length) {
            //NSLog(@"••• insert story at index: %d (has %lu rows)", i, (unsigned long)[[_storiesArray objectAtIndex:i] count]);
            [indexesToInsert addIndex:i];
        }
    }
    
    //NSLog(@"group stories end: %lu", (unsigned long)_storiesArray.count);
    
    if (tableRange.length) {
        
        [UIView setAnimationsEnabled:NO];
        [tableView beginUpdates];
        
        if (indexesToDelete.count) {
            //NSLog(@"deleting indexes: %@", indexesToDelete);
            [tableView deleteSections:indexesToDelete withRowAnimation:UITableViewRowAnimationNone];
        }
        if (indexesToReload.count) {
            //NSLog(@"reloading indexes: %@", indexesToReload);
            [tableView reloadSections:indexesToReload withRowAnimation:UITableViewRowAnimationNone];
        }
        if (indexesToInsert.count) {
            //NSLog(@"inserting indexes: %@", indexesToInsert);
            [tableView insertSections:indexesToInsert withRowAnimation:UITableViewRowAnimationNone];
        }

        [tableView endUpdates];
        [UIView setAnimationsEnabled:YES];
    }
    else {
        [tableView reloadData];
    }
    
}

- (void) showWelcomePopup {
    
    WelcomePopupView *popupView = [[WelcomePopupView alloc] initWithFrame:CGRectMake(0,0,230,270)];
    
    KLCPopup *welcomePopup = [KLCPopup popupWithContentView:popupView
                                                   showType:KLCPopupShowTypeGrowIn
                                                dismissType:KLCPopupDismissTypeShrinkOut
                                                   maskType:KLCPopupMaskTypeClear
                                   dismissOnBackgroundTouch:NO
                                      dismissOnContentTouch:NO];
    
    welcomePopup.didFinishShowingCompletion = ^{
        [popupView setContentSize];
    };
    [welcomePopup show];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _storiesArray.count + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_storiesArray.count) {
        if (section < _storiesArray.count) {
            return [[_storiesArray objectAtIndex:section] count];
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

static NSString *feedCellIdentifier = @"storyHeaderCell";
static NSString *eventCellIdentifier = @"storyEventCell";
static NSString *footerCellIdentifier = @"storyFooterCell";

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.row == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:feedCellIdentifier];
        [self configureHeaderCell:cell forIndexPath:indexPath];
        return cell;
    } else if (indexPath.row == [[_storiesArray objectAtIndex:indexPath.section] count] - 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:footerCellIdentifier];
        [self configureFooterCell:cell forIndexPath:indexPath];
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:eventCellIdentifier];
        [self configureEventCell:cell forIndexPath:indexPath];
        return cell;
    }
    
}

#pragma mark - Table view delegate methods

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // don't select footer cell bc if _episodeId, already on story detail view.
    if (_episodeId && indexPath.row == [[_storiesArray objectAtIndex:indexPath.section] count] - 1) {
        return nil;
    } else {
        return indexPath;
    }
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //JPLog(@"selected cell at row %ld", (long)[indexPath row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger footerIndex = [[_storiesArray objectAtIndex:indexPath.section] count] - 1;
    
    if (indexPath.row == 0) {
        // header
        [self pushEpisodeViewForIndexPath:indexPath withFocusedEventId:nil];
        
    }
    else if (indexPath.row == footerIndex) {
        // footer
        // view all events for episode id
        NSDictionary *headerDict = [[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:0];
        NSString *episodeId = [[[headerDict objectForKey:@"episode"] objectForKey:@"id"] objectForKey:@"$id"];
        NSLog(@"episodeId: %@", episodeId);
        StoriesTableViewController *storyDetailView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"storiesTableView"];
        storyDetailView.episodeId = episodeId;
    
        [_navController pushViewController:storyDetailView animated:YES];
    }
    else {
        // event
        // if clip, play
        NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row]];
        NSString *type = [eventDict objectForKey:@"type"];
        if ([eventDict objectForKey:@"clip_url"]) {
            _selectedSectionIndex = indexPath.section;
            _selectedRowIndex = indexPath.row;
            [self playPause];
        }
        else if ([type isEqualToString:@"comment"]) {
            NSString *commentId = [[eventDict objectForKey:@"id"] objectForKey:@"$id"];
            [self pushEpisodeViewForIndexPath:indexPath withFocusedEventId:commentId];
        }
        else {
            [self pushEpisodeViewForIndexPath:indexPath withFocusedEventId:nil];
        }
    }
}

// Buhbie's comment:
// ABCD

//- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
UILabel *prototypeLabel;
CGFloat labelWidth = 0;

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.row == 0) {
        // header cell
        return 127;
    } else if (indexPath.row == [[_storiesArray objectAtIndex:indexPath.section] count] - 1) {
        // footer cell
        return 35;
    } else {
        // event cell
        CGFloat defaultEventCellHeight = 57;
        NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row]];
        if ([[eventDict objectForKey:@"comment"] length] > 0) {
            if (!prototypeLabel) {
                prototypeLabel = [[UILabel alloc] init];
                prototypeLabel.font = [UIFont systemFontOfSize:15];
                prototypeLabel.numberOfLines = 0;
            }
            if (labelWidth == 0) {
                labelWidth = screenWidth -63 - 60;
            }
            prototypeLabel.text = [eventDict objectForKey:@"comment"];
            CGSize labelSize = [prototypeLabel sizeThatFits:CGSizeMake(labelWidth, 400)];
            CGFloat diff = labelSize.height - 18;
            return defaultEventCellHeight + diff;
        } else {
        	return defaultEventCellHeight;
        }
    }
}


-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0.01f;
}

-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    
    if (section == _storiesArray.count) {
        return 66.0;
    }
    else {
        return 1;
    }
}

-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *separator = [UIView new];
    separator.backgroundColor = [UIColor whiteColor];
    return separator;
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == _storiesArray.count) {
        if (_reachedEndOfPosts) {
            UILabel *noMoreLabel = [[UILabel alloc] init];
            noMoreLabel.text = @"That's everything.\n ";
            noMoreLabel.numberOfLines = 0;
            noMoreLabel.textColor = [UIColor grayColor];
            noMoreLabel.textAlignment = NSTextAlignmentCenter;
            return noMoreLabel;
        }
        else if (_noResults) {
            UILabel *noResultsLabel = [[UILabel alloc] init];
            noResultsLabel.text = @"No activity yet.";
            noResultsLabel.textColor = [UIColor grayColor];
            noResultsLabel.textAlignment = NSTextAlignmentCenter;
            return noResultsLabel;
        }
        else {
            _loadMoreIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            return _loadMoreIndicator;
        }
    } else {
        UIView *separator = [UIView new];
        separator.backgroundColor = [UIColor whiteColor];
        return separator;
    }
}

- (void) configureHeaderCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
    StoryHeaderCell *headerCell = (StoryHeaderCell *)cell;
    headerCell.clipsToBounds = YES;
    //JPLog(@"story header cell for row at index path, section: %ld", (long)indexPath.section);
    
    // cell data
    NSDictionary *storyDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row]];
    NSDictionary *episodeMiniDict = [storyDict objectForKey:@"episode"];
    NSDictionary *userDict = [storyDict objectForKey:@"user"];
    
    // color
    UIColor *keyColor = (UIColor *)[storyDict objectForKey:@"keyColor"];
    headerCell.backgroundColor = keyColor;
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [TungCommonObjects darkenKeyColor:keyColor];
    [headerCell setSelectedBackgroundView:bgColorView];
    
    // user or users
    NSString *avatarUrlString;
    
    // remove any extra avatars since this view is being recycled
    for (UIView *subview in headerCell.contentView.subviews) {
        if ([subview isKindOfClass:[AvatarContainerView class]] && subview != headerCell.avatarContainerView) {
            [subview removeFromSuperview];
        }
    }
    if ([storyDict objectForKey:@"users"]) {
        // users
        CGRect avatarRect = CGRectMake(12, 12, 40, 40);
        NSArray *users = [storyDict objectForKey:@"users"];
        
        // avatar spacing
        int spacing = 30;
        int threshold = 4;
        int max = 6;
        if (screenWidth > 320) {
            threshold = 5;
            max = 8;
        }
        if (users.count > threshold) {
            spacing = 20;
        }
        
        headerCell.usernameButton.hidden = YES;
        avatarUrlString = [[users objectAtIndex:0] objectForKey:@"small_av_url"];
        
        AvatarContainerView *lastAvatar = headerCell.avatarContainerView;
        NSUInteger limit = MIN(users.count, max);
        
        for (int i = 1; i < limit; i++) {
            NSString *avUrlString = [[users objectAtIndex:i] objectForKey:@"small_av_url"];
            NSData *avImageData = [TungCommonObjects retrieveSmallAvatarDataWithUrlString:avUrlString];
            avatarRect.origin.x += spacing;
            AvatarContainerView *avContainerView = [[AvatarContainerView alloc] initWithFrame:avatarRect];
            avContainerView.avatar = [[UIImage alloc] initWithData:avImageData];
            [headerCell.contentView insertSubview:avContainerView belowSubview:lastAvatar];
            [avContainerView setNeedsDisplay];
            lastAvatar = avContainerView;
        }
    }
    else {
        // user
        headerCell.usernameButton.hidden = NO;
        headerCell.usernameButton.tag = 101;
        [headerCell.usernameButton addTarget:self action:@selector(headerCellButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [headerCell.usernameButton setTitle:[userDict objectForKey:@"username"] forState:UIControlStateNormal];
        headerCell.avatarButton.tag = 101;
        [headerCell.avatarButton addTarget:self action:@selector(headerCellButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        avatarUrlString = [userDict objectForKey:@"small_av_url"];
        
    }
    // avatar
    NSData *avatarImageData = [TungCommonObjects retrieveSmallAvatarDataWithUrlString:avatarUrlString];
    headerCell.avatarContainerView.avatar = nil;
    headerCell.avatarContainerView.avatar = [[UIImage alloc] initWithData:avatarImageData];
    headerCell.avatarContainerView.borderColor = [UIColor whiteColor];
    [headerCell.avatarContainerView setNeedsDisplay];
    
    // album art
    NSString *artUrlString = [episodeMiniDict objectForKey:@"artworkUrlSSL"];
    NSNumber *collectionId = [episodeMiniDict objectForKey:@"collectionId"];
    NSData *artImageData = [TungCommonObjects retrievePodcastArtDataWithUrlString:artUrlString andCollectionId:collectionId];
    UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
    headerCell.albumArt.image = artImage;
    
	// title
    NSString *title = [episodeMiniDict objectForKey:@"title"];
    headerCell.title.text = title;
    if (screenWidth >= 414) { // iPhone 6+/6s+
        headerCell.title.font = [UIFont systemFontOfSize:21 weight:UIFontWeightLight];
        if (title.length > 82) {
            headerCell.title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightLight];
        }
        else if (title.length > 52) {
            headerCell.title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightLight];
        }
    }
    else if (screenWidth >= 375) { // iPhone 6/6s
        headerCell.title.font = [UIFont systemFontOfSize:21 weight:UIFontWeightLight];
        
        if (title.length > 54) {
            headerCell.title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightLight];
        }
        else if (title.length > 42) {
            headerCell.title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightLight];
        }
    }
    else { // iPhone 5/5s
        headerCell.title.font = [UIFont systemFontOfSize:21 weight:UIFontWeightLight];
        if (title.length > 52) {
            headerCell.title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightLight];
        }
        else if (title.length > 32) {
            headerCell.title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightLight];
        }
    }
    
    // post date
    headerCell.postedDateLabel.text = [TungCommonObjects timeElapsed:[storyDict objectForKey:@"time_secs"]];

    // separator
    headerCell.preservesSuperviewLayoutMargins = NO;
    [headerCell setLayoutMargins:UIEdgeInsetsZero];
}

- (void) configureEventCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
    StoryEventCell *eventCell = (StoryEventCell *)cell;
    
    NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row]];
    NSDictionary *headerDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:0]];
    BOOL isGroup = NO;
    if ([headerDict objectForKey:@"users"]) {
        isGroup = YES;
    }
    
    // color
    UIColor *keyColor = (UIColor *)[eventDict objectForKey:@"keyColor"];
    eventCell.backgroundColor = keyColor;
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [TungCommonObjects darkenKeyColor:keyColor];
    [eventCell setSelectedBackgroundView:bgColorView];
    
    // event
    NSString *type = [eventDict objectForKey:@"type"];
    NSString *username = [[eventDict objectForKey:@"user"] objectForKey:@"username"];
    
    if ([type isEqualToString:@"recommended"]) {
        eventCell.iconView.type = kIconTypeRecommend;
        eventCell.simpleEventLabel.hidden = NO;
        eventCell.simpleEventLabel.text =  @"Recommended";
        if (isGroup) {
            eventCell.simpleEventLabel.text =  [NSString stringWithFormat:@"%@ recommended", username];
        }
        eventCell.eventDetailLabel.hidden = YES;
        eventCell.commentLabel.hidden = YES;
        eventCell.clipProgress.hidden = YES;
    }
    else if ([type isEqualToString:@"comment"]) {
        eventCell.iconView.type = kIconTypeComment;
        eventCell.simpleEventLabel.hidden = YES;
        eventCell.eventDetailLabel.text = [NSString stringWithFormat:@"%@", [eventDict objectForKey:@"timestamp"]];
        if (isGroup) {
            eventCell.eventDetailLabel.text = [NSString stringWithFormat:@"%@ at %@", username, [eventDict objectForKey:@"timestamp"]];
        }
        eventCell.eventDetailLabel.hidden = NO;
        eventCell.commentLabel.text = [eventDict objectForKey:@"comment"];
        eventCell.commentLabel.hidden = NO;
        eventCell.clipProgress.hidden = YES;
    }
    else if ([type isEqualToString:@"clip"]) {
        eventCell.iconView.type = kIconTypeClip;
        NSString *eventLabelString = [NSString stringWithFormat:@"%@ - tap to play", [eventDict objectForKey:@"timestamp"]];
        if (isGroup) {
            eventLabelString = [NSString stringWithFormat:@"%@ at %@ - tap to play", username, [eventDict objectForKey:@"timestamp"]];
        }
        if ([[eventDict objectForKey:@"comment"] length] > 0) {
            eventCell.simpleEventLabel.hidden = YES;
            eventCell.eventDetailLabel.text = eventLabelString;
            eventCell.eventDetailLabel.hidden = NO;
            eventCell.commentLabel.text = [eventDict objectForKey:@"comment"];
            eventCell.commentLabel.hidden = NO;
        } else {
            eventCell.simpleEventLabel.hidden = NO;
            eventCell.simpleEventLabel.text = eventLabelString;
            eventCell.eventDetailLabel.hidden = YES;
            eventCell.commentLabel.hidden = YES;
        }
        eventCell.clipProgress.hidden = NO;
        eventCell.clipProgress.arc = 0.0f;
        eventCell.clipProgress.seconds = [NSString stringWithFormat:@":%@", [eventDict objectForKey:@"duration"]];
        eventCell.clipProgress.backgroundColor = [UIColor clearColor];
    }
    eventCell.iconView.color = [UIColor whiteColor];
    eventCell.iconView.backgroundColor = [UIColor clearColor];
    [eventCell.iconView setNeedsDisplay];
    
    // bkgd image (album shadow)
    if (indexPath.row == 1) {
        eventCell.bkgdImage.hidden = NO;
    } else {
        eventCell.bkgdImage.hidden = YES;
    }
    
    // separator
    eventCell.preservesSuperviewLayoutMargins = NO;
    [eventCell setLayoutMargins:UIEdgeInsetsZero];
    
}

- (void) configureFooterCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
    StoryFooterCell *footerCell = (StoryFooterCell *)cell;
    
    NSDictionary *footerDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row]];
    
    // hide view all if we are alreadying viewing all
    if (_episodeId) {
        footerCell.viewAllLabel.hidden = YES;
    } else {
        footerCell.viewAllLabel.hidden = NO;
    }
    
    // options button
    footerCell.optionsButton.type = kIconButtonTypeOptions;
    footerCell.optionsButton.color = [UIColor whiteColor];
    [footerCell.optionsButton addTarget:self action:@selector(optionsButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // color
    UIColor *keyColor = (UIColor *)[footerDict objectForKey:@"keyColor"];
    footerCell.backgroundColor = keyColor;
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [TungCommonObjects darkenKeyColor:keyColor];
    [footerCell setSelectedBackgroundView:bgColorView];
    
    // separator
    footerCell.preservesSuperviewLayoutMargins = NO;
    [footerCell setLayoutMargins:UIEdgeInsetsZero];
}


- (void) tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([_tung.clipPlayer isPlaying]) {
        // stop animating if cell goes out of view, somehow causes other cells to animate
        NSIndexPath *activeIndexPath = [NSIndexPath indexPathForRow:_activeRowIndex inSection:_activeSectionIndex];
        if ([indexPath isEqual:activeIndexPath]) {
            [_onEnterFrame invalidate];
        }
    }
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if ([_tung.clipPlayer isPlaying]) {
        // resume animation
        NSIndexPath *activeIndexPath = [NSIndexPath indexPathForRow:_activeRowIndex inSection:_activeSectionIndex];
        if ([indexPath isEqual:activeIndexPath]) {
            
            // begin "onEnterFrame"
            _onEnterFrame = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateView)];
            [_onEnterFrame addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        }
    }
}


#pragma mark - long press and action sheet

- (void) tableCellLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    
    //JPLog(@"long press detected with state: %ld", (long)gestureRecognizer.state);
    
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        CGPoint loc = [gestureRecognizer locationInView:self.tableView];
    	NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:loc];
        
        if (indexPath) {
            
            NSUInteger footerIndex = [[_storiesArray objectAtIndex:indexPath.section] count] - 1;
            if (indexPath.row == 0 || indexPath.row == footerIndex) {
                // story header/footer
                return;
            }
            NSDictionary *headerDict = [[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:0];
            //JPLog(@"header dict: %@", headerDict);
            
            // story event
            NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row]];
            NSString *timestamp = [eventDict objectForKey:@"timestamp"];
            NSString *playFromString = [NSString stringWithFormat:@"Play from %@", timestamp];
            NSString *type = [eventDict objectForKey:@"type"];
            NSString *shareItemOption, *copyLinkOption, *destructiveOption, *shareLink, *shareText;
            NSString *userId = [[[eventDict objectForKey:@"user"] objectForKey:@"id"] objectForKey:@"$id"];
            
            if ([type isEqualToString:@"clip"]) {
                shareItemOption = @"Share this clip";
                copyLinkOption = @"Copy link to clip";
                NSString *clipShortlink = [eventDict objectForKey:@"shortlink"];
                shareLink = [NSString stringWithFormat:@"%@c/%@", _tung.tungSiteRootUrl, clipShortlink];
                shareText = [NSString stringWithFormat:@"Here's a clip from %@: %@", [[headerDict objectForKey:@"episode"] objectForKey:@"title"], shareLink];
                NSString *comment = [eventDict objectForKey:@"comment"];
                if ([userId isEqualToString:_tung.tungId]) {
                    if (comment.length > 0) {
                        destructiveOption = @"Delete clip & comment";
                    } else {
                        destructiveOption = @"Delete this clip";
                    }
                } else {
                    if (comment.length > 0) {
                        destructiveOption = @"Flag this comment";
                    } else {
                        destructiveOption = nil;
                    }
                }
            }
            else if ([type isEqualToString:@"comment"]) {
                shareItemOption = @"Share this comment";
                copyLinkOption = @"Copy link to comment";
                shareLink = [headerDict objectForKey:@"storyLink"];
                shareText = [self getShareTextForStoryWithDict:headerDict];
                if ([userId isEqualToString:_tung.tungId]) {
                    destructiveOption = @"Delete this comment";
                } else {
                    destructiveOption = @"Flag this comment";
                }
            }
            else {
                return;
            }

            UIAlertController *storyOptionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            
            // share option
            [storyOptionSheet addAction:[UIAlertAction actionWithTitle:shareItemOption style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                UIActivityViewController *shareSheet = [[UIActivityViewController alloc] initWithActivityItems:@[shareText] applicationActivities:nil];
                [self presentViewController:shareSheet animated:YES completion:nil];
                
            }]];
            // copy link option
            [storyOptionSheet addAction:[UIAlertAction actionWithTitle:copyLinkOption style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[UIPasteboard generalPasteboard] setString:shareLink];
            }]];
            // play from timestamp
            [storyOptionSheet addAction:[UIAlertAction actionWithTitle:playFromString style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                
                NSString *episodeId = [[[headerDict objectForKey:@"episode"] objectForKey:@"id"] objectForKey:@"$id"];
                NSString *collectionId = [[headerDict objectForKey:@"episode"] objectForKey:@"collectionId"];
                [self playFromTimestamp:timestamp forEpisodeWithId:episodeId andCollectionId:collectionId];
                
            }]];
            // delete or flag
            if (destructiveOption) {
                [storyOptionSheet addAction:[UIAlertAction actionWithTitle:destructiveOption style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    // delete story event
                    if ([userId isEqualToString:_tung.tungId]) {
                        
                        UIAlertController *confirmDelete = [UIAlertController alertControllerWithTitle:@"Delete" message:@"Are you sure? This can't be undone." preferredStyle:UIAlertControllerStyleAlert];
                        [confirmDelete addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
                        [confirmDelete addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                            [self deleteEventAtIndexPath:indexPath];
                            
                        }]];
                        [self presentViewController:confirmDelete animated:YES completion:nil];
                    }
                    // request moderation
                    else {
                        // can only flag comments
                        if ([[eventDict objectForKey:@"comment"] length] > 0) {
                            
                            NSString *quotedComment = [NSString stringWithFormat:@"\"%@\"", [eventDict objectForKey:@"comment"]];
                            UIAlertController *confirmFlag = [UIAlertController alertControllerWithTitle:@"Flag for moderation?" message:quotedComment preferredStyle:UIAlertControllerStyleAlert];
                            [confirmFlag addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
                            [confirmFlag addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                                
                                 NSString *eventId = [[eventDict objectForKey:@"id"] objectForKey:@"$id"];
                                 [_tung flagCommentWithId:eventId];
                                
                            }]];
                            [self presentViewController:confirmFlag animated:YES completion:nil];
                        }
                    }
                }]];
            }
            
            [storyOptionSheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:storyOptionSheet animated:YES completion:nil];
        }
    }
}

- (void) playFromTimestamp:(NSString *)timestamp forEpisodeWithId:(NSString *)episodeId andCollectionId:(NSString *)collectionId {
    // check for episode entity
    EpisodeEntity *epEntity = [TungCommonObjects getEpisodeEntityFromEpisodeId:episodeId];
    
    if (epEntity) {
        //NSLog(@"play from timestamp, episode entity exists");
        [_tung playUrl:epEntity.url fromTimestamp:timestamp];
    }
    else {
        //NSLog(@"play from timestamp, fetch episode entity");
        [_tung requestEpisodeInfoForId:episodeId andCollectionId:collectionId withCallback:^(BOOL success, NSDictionary *responseDict) {
            NSDictionary *episodeDict = [responseDict objectForKey:@"episode"];
            NSDictionary *podcastDict = [responseDict objectForKey:@"podcast"];
            PodcastEntity *podcastEntity = [TungCommonObjects getEntityForPodcast:podcastDict save:NO];
            [TungCommonObjects getEntityForEpisode:episodeDict withPodcastEntity:podcastEntity save:YES];
            
            NSString *urlString = [episodeDict objectForKey:@"url"];
            
            if (urlString) {
                [_tung playUrl:urlString fromTimestamp:timestamp];
            }
        }];
    }

}

- (void) deleteEventAtIndexPath:(NSIndexPath *)indexPath {
    
	NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row]];
    NSString *eventId = [[eventDict objectForKey:@"id"] objectForKey:@"$id"];
    
    [_tung deleteStoryEventWithId:eventId withCallback:^(BOOL success) {
        if (success) {
            // remove story or just event
            NSArray *storyArray = [_storiesArray objectAtIndex:indexPath.section];
            if (storyArray.count == 3) {
                [_storiesArray removeObjectAtIndex:indexPath.section];
                // remove section (story)
                [self.tableView beginUpdates];
                [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section]withRowAnimation:UITableViewRowAnimationRight];
                [self.tableView endUpdates];
            }
            // remove just event
            else {
                [[_storiesArray objectAtIndex:indexPath.section] removeObjectAtIndex:indexPath.row];
                // remove table row
                [self.tableView beginUpdates];
                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationRight];
                [self.tableView endUpdates];
            }
        }
    }];

}

- (void) optionsButtonTapped:(id)sender {
    
	StoryFooterCell* cell  = (StoryFooterCell*)[[sender superview] superview];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    NSDictionary *headerDict = [[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:0];
    //NSLog(@"header dict: %@", headerDict);
    
    UIAlertController *optionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    // share option
    [optionSheet addAction:[UIAlertAction actionWithTitle:@"Share episode" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *episodeShareText = [self getShareTextForEpisodeWithDict:headerDict];
        UIActivityViewController *shareSheet = [[UIActivityViewController alloc] initWithActivityItems:@[episodeShareText] applicationActivities:nil];
        [self presentViewController:shareSheet animated:YES completion:nil];
    }]];
    // copy link
    [optionSheet addAction:[UIAlertAction actionWithTitle:@"Copy link to episode" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *episodeLink = [headerDict objectForKey:@"episodeLink"];
        [[UIPasteboard generalPasteboard] setString:episodeLink];
        
    }]];
    // share interaction
    /*
    [optionSheet addAction:[UIAlertAction actionWithTitle:@"Share this interaction" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *storyShareText = [self getShareTextForStoryWithDict:headerDict];
        UIActivityViewController *shareSheet = [[UIActivityViewController alloc] initWithActivityItems:@[storyShareText] applicationActivities:nil];
        [self presentViewController:shareSheet animated:YES completion:nil];
    }]];
    // copy link for interaction
    [optionSheet addAction:[UIAlertAction actionWithTitle:@"Copy link to interaction" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *storyLink = [headerDict objectForKey:@"storyLink"];
        [[UIPasteboard generalPasteboard] setString:storyLink];
    }]]; 
     */
    // flag
    [optionSheet addAction:[UIAlertAction actionWithTitle:@"Flag this" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        UIAlertController *howToFlagAlert = [UIAlertController alertControllerWithTitle:@"Flagging" message:@"To flag a comment for moderation, long press on the comment, and select 'Flag this comment'.\n\nPlease remember Tung cannot moderate the content of podcasts." preferredStyle:UIAlertControllerStyleAlert];
        [howToFlagAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:howToFlagAlert animated:YES completion:nil];
    }]];
    
    [optionSheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:optionSheet animated:YES completion:nil];
}

- (NSString *) getShareTextForStoryWithDict:(NSDictionary *)headerDict {
    NSString *shareLink = [headerDict objectForKey:@"storyLink"];
    NSString *shareText;
    NSString *uid = [[[headerDict objectForKey:@"user"] objectForKey:@"id"] objectForKey:@"$id"];
    if ([uid isEqualToString:_tung.tungId]) {
        shareText = [NSString stringWithFormat:@"I listened to %@ on #tung: %@", [[headerDict objectForKey:@"episode"] objectForKey:@"title"], shareLink];
    } else {
        shareText = [NSString stringWithFormat:@"%@ listened to %@ on #tung: %@", [[headerDict objectForKey:@"user"] objectForKey:@"username"], [[headerDict objectForKey:@"episode"] objectForKey:@"title"], shareLink];
    }
    return shareText;
}
- (NSString *) getShareTextForEpisodeWithDict:(NSDictionary *)headerDict {
    NSString *shareLink = [headerDict objectForKey:@"episodeLink"];
    NSString *shareText = [NSString stringWithFormat:@"Check out %@ on #tung: %@", [[headerDict objectForKey:@"episode"] objectForKey:@"title"], shareLink];
    return shareText;
}

#pragma mark - Feed cell controls

-(void) headerCellButtonTapped:(id)sender {
    long tag = [sender tag];
    
    if (tag == 101) {
        StoryHeaderCell *cell = (StoryHeaderCell *)[[sender superview] superview];
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        NSDictionary *storyDict = [[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:0];
        NSString *userId = [[[storyDict objectForKey:@"user"] objectForKey:@"id"] objectForKey:@"$id"];
        // push profile
        if (![_profiledUserId isEqualToString:userId]) {
            ProfileViewController *profileView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"profileView"];
            profileView.profiledUserId = userId;
            [_navController pushViewController:profileView animated:YES];
        }
    }
}

#pragma mark - Audio clips

-(void) playPause {
    // toggle play/pause
    if (_selectedSectionIndex == _activeSectionIndex && _selectedRowIndex == _activeRowIndex) {
        if ([_tung.clipPlayer isPlaying]) {
            [self pauseClipPlayback];
        } else {
            [self playbackClip];
        }
    }
    // different clip selected than the one playing
    else {
        
        if ([_tung.clipPlayer isPlaying]) [self stopClipPlayback];
    
        // start playing new clip
        _tung.clipPlayer = nil;
        // check for cached audio data and init player
        NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:_selectedSectionIndex] objectAtIndex:_selectedRowIndex]];
        NSString *clipURLString = [eventDict objectForKey:@"clip_url"];
        NSData *clipData = [TungCommonObjects retrieveAudioClipDataWithUrlString:clipURLString];
        NSError *playbackError;
        _tung.clipPlayer = [[AVAudioPlayer alloc] initWithData:clipData error:&playbackError];
        
        // play
        if (_tung.clipPlayer != nil) {
            _tung.clipPlayer.delegate = self;
            // PLAY
            [self playbackClip];
            
        } else {
            JPLog(@"failed to create audio player: %@", playbackError);
        }
    }
}

- (void) playbackClip {
    
    [_tung playerPause];
    
    [_tung.clipPlayer prepareToPlay];
    [_tung.clipPlayer play]; // play on, player
    
    _activeSectionIndex = _selectedSectionIndex;
    _activeRowIndex = _selectedRowIndex;
    
    [self setActiveClipCellReference];
    
    // begin "onEnterFrame"
    _onEnterFrame = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateView)];
    [_onEnterFrame addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void) stopClipPlayback {
    //JPLog(@"stop");
    
    if (_activeSectionIndex >= 0 && _activeRowIndex >= 0) {
        // stop "onEnterFrame"
        [_onEnterFrame invalidate];
        //JPLog(@"%@",[NSThread callStackSymbols]);
        [_tung stopClipPlayback];
        
        // reset GUI
        NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:_activeSectionIndex] objectAtIndex:_activeRowIndex]];
        
        _activeClipProgressView.seconds = [NSString stringWithFormat:@":%@", [eventDict objectForKey:@"duration"]];
        _activeClipProgressView.arc = 0.0f;
        [_activeClipProgressView setNeedsDisplay];
    }

}

- (void) pauseClipPlayback {
	
    if ([_tung.clipPlayer isPlaying]) {
        [_tung.clipPlayer pause];
    }
    // stop "onEnterFrame"
    [_onEnterFrame invalidate];
    
}

- (void) updateView {
    
    if (_activeClipProgressView) {
        float progress = _tung.clipPlayer.currentTime / _tung.clipPlayer.duration;
        float arc = 360 - (360 * progress);
        _activeClipProgressView.arc = arc;
        _activeClipProgressView.seconds = [NSString stringWithFormat:@":%02ld", lroundf(_tung.clipPlayer.duration - _tung.clipPlayer.currentTime)];
        [_activeClipProgressView setNeedsDisplay];
    }
}

- (void) setActiveClipCellReference {
    if (_activeRowIndex >= 1 && _activeSectionIndex >= 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_activeRowIndex inSection:_activeSectionIndex];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        StoryEventCell *activeCell = (StoryEventCell *)cell;
        _activeClipProgressView = activeCell.clipProgress;
    }

}

#pragma mark - Audio player delegate methods

-(void) audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    [self pauseClipPlayback];
}
-(void) audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags {
    if (flags == AVAudioSessionInterruptionOptionShouldResume)
        [self playbackClip];
}
-(void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [self stopClipPlayback];
}

#pragma mark - scroll view delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.tableView) {
        // shrink profile header
        if (_profiledUserId.length > 0 && scrollView.contentOffset.y > 0 && scrollView.contentOffset.y <= animationDistance) {
            //JPLog(@"table offset: %f", scrollView.contentOffset.y);
            _profileHeightConstraint.constant = headerViewHeight - scrollView.contentOffset.y;
            _profileHeader.scrollSubView1Height.constant = headerScrollViewHeight - scrollView.contentOffset.y;
            _profileHeader.scrollSubView2Height.constant = headerScrollViewHeight - scrollView.contentOffset.y;
            
            [_profileHeader layoutIfNeeded];
        }
        // detect when user hits bottom of feed
        if (!_episodeId) {
            float bottomOffset = scrollView.contentSize.height - scrollView.frame.size.height;
            if (scrollView.contentOffset.y >= bottomOffset) {
                // request more posts if they didn't reach the end
                if (!_requestingMore && !_reachedEndOfPosts && _storiesArray.count > 0) {
                    JPLog(@"requesting more stories");
                    _requestingMore = YES;
                    _loadMoreIndicator.alpha = 1;
                    [_loadMoreIndicator startAnimating];
                    NSNumber *oldest = [[[_storiesArray objectAtIndex:_storiesArray.count-1] objectAtIndex:0] objectForKey:@"time_secs_end"];
                    
                    [self requestPostsNewerThan:[NSNumber numberWithInt:0]
                                    orOlderThan:oldest
                                       fromUser:_profiledUserId
                                       withCred:NO];
                }
            }
        }
    }
}

- (void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (_profiledUserId.length > 0) {
        [self setScrollViewContentSizeForHeight];
    }
}

- (void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (_profiledUserId.length > 0 && !decelerate) {
        [self setScrollViewContentSizeForHeight];
    }
}

- (void) setScrollViewContentSizeForHeight {
    //JPLog(@"set scroll view content size for height");
    // set scroll view content size for height
    CGFloat scrollViewHeight = _profileHeightConstraint.constant - tableHeaderRow;
//    JPLog(@"scroll view height: %f", scrollViewHeight);
//    JPLog(@"scroll view content size: %@", NSStringFromCGSize(_profileHeader.scrollView.contentSize));
    CGSize contentSize = CGSizeMake(screenWidth * 2, scrollViewHeight);
    _profileHeader.scrollView.contentSize = contentSize;
//    JPLog(@"scroll view NEW content size: %@", NSStringFromCGSize(contentSize));
}


@end
