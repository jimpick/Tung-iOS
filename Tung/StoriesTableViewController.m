//
//  TungActivity.m
//  Tung
//
//  Created by Jamie Perkins on 6/22/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//
// 3 types of stories views:
//
// - feed (following)
// - feed (trending)
// - stories for episode

#import "StoriesTableViewController.h"
#import "TungCommonObjects.h"
#import "TungPodcast.h"
#import "StoryHeaderCell.h"
#import "StoryCountCell.h"
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
@property BOOL animateEndRefresh;
@property CGFloat screenWidth;
@property NSNumber *page;

@property (nonatomic, assign) CGFloat lastScrollViewOffset; // for determining scroll direction

// get stories for following feed or trending feed
- (void) getStoriesNewerThan:(NSNumber *)afterTime
                 orOlderThan:(NSNumber *)beforeTime
                    trending:(BOOL)trending
                    withCred:(BOOL)withCred;

// all stories from a profiled user or for a single episode
- (void) getStoriesForProfiledUserId:(NSString *)profiledUserId
                         orEpisodeId:(NSString *)episodeId
                           newerThan:(NSNumber *)afterTime
                         orOlderThan:(NSNumber *)beforeTime
                            withCred:(BOOL)withCred;

@end

@implementation StoriesTableViewController



- (void)viewDidLoad {

    [super viewDidLoad];
        
    _tung = [TungCommonObjects establishTungObjects];
    
    _screenWidth = [TungCommonObjects screenSize].width;
    
    if (!_profiledUserId) _profiledUserId = @"";
    
    _storiesArray = [NSMutableArray new];
    
    _activeRowIndex = -2; // < 0 && != -1
    _activeSectionIndex = -2;
    _selectedRowIndex = -1;
    _selectedSectionIndex = -1;
    
    _page = [NSNumber numberWithInteger:0];
    
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
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];

    // table bkgd
    UIActivityIndicatorView *tableSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    tableSpinner.alpha = 1;
    [tableSpinner startAnimating];
    self.tableView.backgroundView = tableSpinner;
    // long press recognizer
    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tableCellLongPress:)];
    longPressRecognizer.minimumPressDuration = 0.6; //seconds
    longPressRecognizer.delegate = self;
    [self.tableView addGestureRecognizer:longPressRecognizer];
    
    // for animating header height
    _lastScrollViewOffset = 0;

}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (!_contentOffsetSet) {
    	_contentOffset = self.tableView.contentOffset;
        _contentOffsetSet = YES;
    }
    
    if (_episodeId.length) {
        self.navigationItem.title = @"Episode";
        [self getStoriesForProfiledUserId:nil
                              orEpisodeId:_episodeId
                                newerThan:[NSNumber numberWithInt:0]
                              orOlderThan:[NSNumber numberWithInt:0]
                                 withCred:NO];
    }
}

- (void) refreshFeed {
    
    if (_tung.connectionAvailable.boolValue) {
    
        NSNumber *mostRecent = [NSNumber numberWithInt:0];

        if (_storiesArray.count > 0) {
            // animate refresh control if table is scrolled to top
            if (self.tableView.contentOffset.y <= _contentOffset.y) {
                _animateEndRefresh = YES;
                [self.refreshControl beginRefreshing];
                [self.tableView setContentOffset:CGPointMake(0, - (self.refreshControl.frame.size.height - _contentOffset.y)) animated:YES];
            }
            mostRecent = [[[_storiesArray objectAtIndex:0] objectAtIndex:0] objectForKey:@"time_secs"];
            
        }
        
        BOOL withCred = (_tung.sessionId.length) ? NO : YES;
        
        if (_profiledUserId.length || _episodeId.length) {
        	[self getStoriesForProfiledUserId:_profiledUserId
                                  orEpisodeId:_episodeId
                                    newerThan:mostRecent
                                  orOlderThan:[NSNumber numberWithInt:0]
                                     withCred:withCred];
        
        }
        else {
            [self getStoriesNewerThan:mostRecent
                          orOlderThan:[NSNumber numberWithInt:0]
                             trending:_isForTrending
                             withCred:withCred];
        }
    }
    else {
        [_tung checkReachabilityWithCallback:^(BOOL reachable) {
            if (reachable) {
                [self refreshFeed];
            } else {
                [self endRefreshing];
            }
        }];
    }
}


- (void) refetchFeed {
    
    if (_profiledUserId.length) {
        [self getStoriesForProfiledUserId:_profiledUserId
                              orEpisodeId:_episodeId
                                newerThan:[NSNumber numberWithInt:0]
                              orOlderThan:[NSNumber numberWithInt:0]
                                 withCred:NO];
        _tung.profileFeedNeedsRefetch = [NSNumber numberWithBool:NO];
    }
    else {
        [self getStoriesNewerThan:[NSNumber numberWithInt:0]
                      orOlderThan:[NSNumber numberWithInt:0]
                         trending:_isForTrending
                         withCred:NO];
        
        if (_isForTrending) {
            _tung.trendingFeedNeedsRefetch = [NSNumber numberWithBool:NO];
        } else {
            _tung.feedNeedsRefetch = [NSNumber numberWithBool:NO];
        }
    }

}

- (void) pushEpisodeViewForIndexPath:(NSIndexPath *)indexPath withFocusedEventId:(NSString *)eventId {
    
    // id method
    NSDictionary *storyDict = [[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:0];
    //NSLog(@"story dict: %@", storyDict);
    NSDictionary *episodeMiniDict = [storyDict objectForKey:@"episode"];
    
    EpisodeViewController *episodeView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"episodeView"];
    episodeView.episodeMiniDict = episodeMiniDict;
    episodeView.focusedEventId = eventId;

    
    [_navController pushViewController:episodeView animated:YES];
}

#pragma mark - Requests

// get stories for following feed or trending feed
- (void) getStoriesNewerThan:(NSNumber *)afterTime
                 orOlderThan:(NSNumber *)beforeTime
                    trending:(BOOL)trending
                    withCred:(BOOL)withCred {
    
    
    NSDate *requestStarted = [NSDate date];
    
    NSMutableDictionary *getParams = [@{
                                        @"newerThan": afterTime,
                                		@"olderThan": beforeTime
                                		} mutableCopy];
    if (trending) {
        [getParams addEntriesFromDictionary:@{@"trending": @"1"}];
    }
    
    NSURL *storyURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/feed-grouped.php%@", [TungCommonObjects apiRootUrl], [TungCommonObjects serializeParamsForGetRequest:getParams]]];
    NSMutableURLRequest *storyRequest = [NSMutableURLRequest requestWithURL:storyURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [storyRequest setHTTPMethod:@"POST"];
    
    NSMutableDictionary *postParams = [@{@"sessionId": _tung.sessionId} mutableCopy];
    if (withCred) {
        NSDictionary *credParams = @{@"tung_id": _tung.tungId,
                                     @"token": _tung.tungToken
                                     };
        [postParams addEntriesFromDictionary:credParams];
    }
    //NSLog(@"request stories with get params: %@ and post params: %@", getParams, postParams);
    
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:postParams];
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
                            [self getStoriesNewerThan:afterTime orOlderThan:beforeTime trending:trending withCred:YES];
                        }
                        else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Unauthorized"]) {
                            [_tung handleUnauthorizedWithCallback:^{
                                [self getStoriesNewerThan:afterTime orOlderThan:beforeTime trending:trending withCred:NO];
                            }];
                        }
                        else {
                            [self endRefreshing];
                            // other error - alert user
                            [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                        }

                    });
                }
                else if ([responseDict objectForKey:@"success"]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        NSTimeInterval requestDuration = [requestStarted timeIntervalSinceNow];
                        NSMutableArray *newStories = [[responseDict objectForKey:@"stories"] mutableCopy];
                        
                        // set feedLastFetched date (seconds)
                        SettingsEntity *settings = [TungCommonObjects settings];
                        if (trending) {
                        	settings.trendingFeedLastFetched = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
                            _tung.trendingFeedNeedsRefresh = [NSNumber numberWithBool:NO];
                        } else {
                            settings.feedLastFetched = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
                            _tung.feedNeedsRefresh = [NSNumber numberWithBool:NO];
                        }
                        [TungCommonObjects saveContextWithReason:@"set feedLastFetched"];
                        
                        if (withCred) {
                            
                            JPLog(@"got stories AND session in %f seconds.", fabs(requestDuration));
                            _tung.sessionId = [responseDict objectForKey:@"sessionId"];
                            // TODO: remove before release
                            NSLog(@"session id: %@", _tung.sessionId);
                            //NSLog(@"user: %@", [responseDict objectForKey:@"user"]);
                            _tung.connectionAvailable = [NSNumber numberWithBool:YES];
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
                        
                        // pull-refresh
                        if ([afterTime intValue] > 0) {
                            if (newStories.count > 0) {
                                //JPLog(@"got stories newer than: %@", afterTime);
                                
                                [self stopClipPlayback];
                                
                                [self removeOlderDuplicatesOfNewStories:newStories];
                                
                                NSArray *newItems = [self processStories:newStories];
                                NSArray *newFeedArray = [newItems arrayByAddingObjectsFromArray:_storiesArray];
                                _storiesArray = [newFeedArray mutableCopy];
                                
                                [UIView setAnimationsEnabled:NO];
                                [self.tableView beginUpdates];
                                for (NSInteger i = 0; i < newStories.count; i++) {
                                    [self.tableView insertSections:[NSIndexSet indexSetWithIndex:i] withRowAnimation:UITableViewRowAnimationNone];
                                }
                                [self.tableView endUpdates];
                                [UIView setAnimationsEnabled:YES];
                                
                                [self endRefreshingWithNewPosts:YES];
                                
                            } else {
                                [self endRefreshing];
                            }
                        }
                        // auto-loaded posts as user scrolls down
                        else if ([beforeTime intValue] > 0) {
                            
                            [self endRefreshingWithNewPosts:YES];
                            
                            _reachedEndOfPosts = (newStories.count == 0);
                            if (_reachedEndOfPosts) {
                                [self.tableView reloadData];
                                
                            } else {
                                //JPLog(@"got stories older than: %@", beforeTime);
                                int startingIndex = (int)_storiesArray.count;
                                
                                [_storiesArray addObjectsFromArray:[self processStories:newStories]];
                                
                                [UIView setAnimationsEnabled:NO];
                                [self.tableView beginUpdates];
                                for (int i = startingIndex; i < _storiesArray.count; i++) {
                                    [self.tableView insertSections:[NSIndexSet indexSetWithIndex:i] withRowAnimation:UITableViewRowAnimationNone];
                                }
                                [self.tableView endUpdates];
                                [UIView setAnimationsEnabled:YES];
                            }
                        }
                        // initial request
                        else {
                            
                            [self endRefreshingWithNewPosts:YES];
                            
                            if (newStories.count > 0) {
                                _storiesArray = [self processStories:newStories];
                                //NSLog(@"processed episode stories: %@", _storiesArray);
                                _noResults = NO;
                            } else {
                                _noResults = YES;
                            }
                            [self.tableView reloadData];
                            
                        }
                        
                    });
                }
            }
            // errors
            else if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self endRefreshing];
                });
                JPLog(@"Error: %@", error.localizedDescription);
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

// all stories from a profiled user or for a single episode
- (void) getStoriesForProfiledUserId:(NSString *)profiledUserId
                         orEpisodeId:(NSString *)episodeId
                           newerThan:(NSNumber *)afterTime
                         orOlderThan:(NSNumber *)beforeTime
                            withCred:(BOOL)withCred {
    
    NSURL *storyURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/feed.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *storyRequest = [NSMutableURLRequest requestWithURL:storyURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [storyRequest setHTTPMethod:@"POST"];
    
    NSString *userId = (profiledUserId) ? profiledUserId : @"";
    NSString *epId = (episodeId) ? episodeId : @"";
    
    NSMutableDictionary *params = [@{
                             @"profiled_user_id": userId,
                             @"episode_id": epId,
                             @"newerThan": afterTime,
                             @"olderThan": beforeTime
                             } mutableCopy];
    if (withCred) {
        NSDictionary *credParams = @{@"tung_id": _tung.tungId,
                                     @"token": _tung.tungToken
                                     };
        [params addEntriesFromDictionary:credParams];
    }
    
    //NSLog(@"request for stories for single episode with params: %@", params);
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
                            [self getStoriesForProfiledUserId:userId
                                                  orEpisodeId:epId
                                                    newerThan:afterTime
                                                  orOlderThan:beforeTime
                                                     withCred:YES];
                        }
                        else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Unauthorized"]) {
                            [_tung handleUnauthorizedWithCallback:^{
                                [self getStoriesForProfiledUserId:userId
                                                      orEpisodeId:epId
                                                        newerThan:afterTime
                                                      orOlderThan:beforeTime
                                                         withCred:YES];
                            }];
                        }
                        else {
                            [self endRefreshing];
                            // other error - alert user
                            [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                        }
                    });
                }
                else if ([responseDict objectForKey:@"success"]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        NSMutableArray *newStories = [[responseDict objectForKey:@"stories"] mutableCopy];
                        if (profiledUserId) {
                        	_tung.profileFeedNeedsRefresh = [NSNumber numberWithBool:NO];
                        }
                        
                        if (withCred) {
                            _tung.sessionId = [responseDict objectForKey:@"sessionId"];
                            _tung.connectionAvailable = [NSNumber numberWithBool:YES];
                        }
                        
                        // pull-refresh
                        if ([afterTime intValue] > 0) {
                            if (newStories.count > 0) {
                                //JPLog(@"got stories newer than: %@", afterTime);
                                
                                [self stopClipPlayback];
                                
                                [self removeOlderDuplicatesOfNewStories:newStories];
                                
                                NSArray *newItems = [self processStories:newStories];
                                NSArray *newFeedArray = [newItems arrayByAddingObjectsFromArray:_storiesArray];
                                _storiesArray = [newFeedArray mutableCopy];
                                
                                [UIView setAnimationsEnabled:NO];
                                [self.tableView beginUpdates];
                                for (NSInteger i = 0; i < newStories.count; i++) {
                                    [self.tableView insertSections:[NSIndexSet indexSetWithIndex:i] withRowAnimation:UITableViewRowAnimationNone];
                                }
                                [self.tableView endUpdates];
                                [UIView setAnimationsEnabled:YES];
                                
                                [self endRefreshingWithNewPosts:YES];
                                
                            } else {
                                [self endRefreshing];
                            }
                        }
                        // auto-loaded posts as user scrolls down
                        else if ([beforeTime intValue] > 0) {
                            
                            [self endRefreshingWithNewPosts:YES];
                            
                            _reachedEndOfPosts = (newStories.count == 0);
                            if (_reachedEndOfPosts) {
                                [self.tableView reloadData];
                                
                            } else {
                                //JPLog(@"got stories older than: %@", beforeTime);
                                int startingIndex = (int)_storiesArray.count;
                                
                                [_storiesArray addObjectsFromArray:[self processStories:newStories]];
                                
                                [UIView setAnimationsEnabled:NO];
                                [self.tableView beginUpdates];
                                for (int i = startingIndex; i < _storiesArray.count; i++) {
                                    [self.tableView insertSections:[NSIndexSet indexSetWithIndex:i] withRowAnimation:UITableViewRowAnimationNone];
                                }
                                [self.tableView endUpdates];
                                [UIView setAnimationsEnabled:YES];
                            }
                        }
                        // initial request
                        else {
                            
                            [self endRefreshingWithNewPosts:YES];
                            
                            if (newStories.count > 0) {
                                _storiesArray = [self processStories:newStories];
                                //NSLog(@"processed episode stories: %@", _storiesArray);
                                _noResults = NO;
                            } else {
                                _noResults = YES;
                            }
                            [self.tableView reloadData];
                            
                        }
                        
                    });
                }
            }
            // errors
            else if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self endRefreshing];
                });
                JPLog(@"Error: %@", error.localizedDescription);
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


- (void) endRefreshing {
    [self endRefreshingWithNewPosts:NO];
}

- (void) endRefreshingWithNewPosts:(BOOL)newPosts {
    //NSLog(@"end refreshing. new posts: %@", newPosts ? @"yes" : @"no");
    _requestingMore = NO;
    _loadMoreIndicator.alpha = 0;
    
    if (self.refreshControl.refreshing) {
        [self.refreshControl endRefreshing];
        if (!newPosts && _animateEndRefresh) {
        	[self.tableView setContentOffset:_contentOffset animated:YES];
            _animateEndRefresh = NO;
        }
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
        
        BOOL isGrouped = NO;
        
        NSMutableArray *storyArray = [NSMutableArray new];
        NSMutableDictionary *headerDict = [[stories objectAtIndex:i] mutableCopy];
        UIColor *keyColor = [TungCommonObjects colorFromHexString:[[headerDict objectForKey:@"episode"] objectForKey:@"keyColor1Hex"]];
        [headerDict setObject:keyColor forKey:@"keyColor"];
        if ([headerDict objectForKey:@"users"]) {
            isGrouped = YES;
        }
        NSArray *events = [headerDict objectForKey:@"events"];
        [headerDict removeObjectForKey:@"events"];
        NSString *episodeShortlink = [[headerDict objectForKey:@"episode"] objectForKey:@"shortlink"];
        NSString *episodeLink = [NSString stringWithFormat:@"%@e/%@", [TungCommonObjects tungSiteRootUrl], episodeShortlink];
        [headerDict setObject:episodeLink forKey:@"episodeLink"];
        if (!isGrouped) {
            NSString *username = [[headerDict objectForKey:@"user"] objectForKey:@"username"];
            NSString *storyLink = [NSString stringWithFormat:@"%@e/%@/%@", [TungCommonObjects tungSiteRootUrl], episodeShortlink, username];
            [headerDict setObject:storyLink forKey:@"storyLink"];
            [headerDict setObject:[headerDict objectForKey:@"time_secs"] forKey:@"time_secs_end"];
        }
        
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
        
        int eventLimit = 25;
        if (_profiledUserId) eventLimit = 100;
        
        // events
        for (int e = 0; e < events.count; e++) {
            
            NSMutableDictionary *eventDict = [[events objectAtIndex:e] mutableCopy];
            if (_profiledUserId.length || _episodeId.length) { // because non-grouping endpoint was used
                [eventDict setObject:[headerDict objectForKey:@"user"] forKey:@"user"];
            }
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
        
        [results addObject:storyArray];
        
    }
    return results;
}


/* 	new stories fetched after feed has already been fetched may be part of those already fetched.
	if the same episode id comes down again, this method removes the older duplicate,
 	and adds any new events/users to the new story.
 */
- (void) removeOlderDuplicatesOfNewStories:(NSMutableArray *)newStories {
    
    for (int i = 0; i < newStories.count; i++) {
        NSString *newStoryIdToMatch = [[[newStories objectAtIndex:i] objectForKey:@"_id"] objectForKey:@"$id"];
        // new story is grouped?
        BOOL newStoryIsGrouped = NO;
        if ([[newStories objectAtIndex:i] objectForKey:@"users"]) {
            newStoryIsGrouped = YES;
        }
        
        // check for story id match in main stories array
        for (int j = 0; j < _storiesArray.count; j++) {
            NSArray *existingStory = [_storiesArray objectAtIndex:j];
            NSDictionary *headerDict = [existingStory objectAtIndex:0];
            // story match
            if ([newStoryIdToMatch isEqualToString:[[headerDict objectForKey:@"_id"] objectForKey:@"$id"]]) {
                
                NSMutableDictionary *newStory = [[newStories objectAtIndex:i] mutableCopy];
                
                NSNumber *time_secs_end = [headerDict objectForKey:@"time_secs_end"];
                [newStory setObject:time_secs_end forKey:@"time_secs_end"];
                
                // move existing events into new story
                NSMutableArray *allEvents = [[newStory objectForKey:@"events"] mutableCopy];
                for (int k = 1; k < existingStory.count; k++) {
                    [allEvents addObject:[existingStory objectAtIndex:k]];
                }
                [newStory setObject:allEvents forKey:@"events"];
                
                // move existing users to new story, adjust as needed
                if (newStoryIsGrouped) {
                    
                    NSMutableArray *newStoryUsers = [[newStory objectForKey:@"users"] mutableCopy];
                    // both grouped
                    if ([headerDict objectForKey:@"users"]) {
                        // combine both users arrays
                        NSArray *newArray = [[headerDict objectForKey:@"users"] arrayByAddingObjectsFromArray:newStoryUsers];
                        NSArray *users = [[NSSet setWithArray:newArray] allObjects];
                        [newStory setObject:users forKey:@"users"];
                    }
                    // existing story had one user, new story grouped
                    else {
                        // add existing story avatar if not already in new story
                        NSString *existingAvUrl = [[headerDict objectForKey:@"user"] objectForKey:@"small_av_url"];
                        if (![newStoryUsers containsObject:existingAvUrl]) {
                            [newStoryUsers addObject:existingAvUrl];
                            [newStory setObject:newStoryUsers forKey:@"users"];
                        }
                    }
                }
                else {
                    NSDictionary *newStoryUser = [newStory objectForKey:@"user"];
                    // existing story grouped, new story isn't
                    if ([headerDict objectForKey:@"users"]) {
                        NSMutableArray *newArray = [[headerDict objectForKey:@"users"] mutableCopy];
                        [newArray addObject:[newStoryUser objectForKey:@"small_av_url"]];
                        NSArray *users = [[NSSet setWithArray:newArray] allObjects];
                        [newStory setObject:users forKey:@"users"];
                        [newStory removeObjectForKey:@"user"];
                    }
                    // both stories have one user
                    else {
                        // if they are different
                        if (![newStoryUser isEqualToDictionary:[headerDict objectForKey:@"user"]]) {
                            NSString *existingAvUrl = [[headerDict objectForKey:@"user"] objectForKey:@"small_av_url"];
                            NSArray *users = [NSArray arrayWithObjects:existingAvUrl, [newStoryUser objectForKey:@"small_av_url"], nil];
                            [newStory setObject:users forKey:@"users"];
                            [newStory removeObjectForKey:@"user"];
                        }
                    }
                }
                // finally, replace with the altered new story
                [newStories replaceObjectAtIndex:i withObject:newStory];
                
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
            if (_isForTrending) {
            	return [[_storiesArray objectAtIndex:section] count] + 2; // adding footer and counts
            } else {
                return [[_storiesArray objectAtIndex:section] count] + 1; // adding footer
            }
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger footerIndex = [[_storiesArray objectAtIndex:indexPath.section] count];
    if (_isForTrending) footerIndex = [[_storiesArray objectAtIndex:indexPath.section] count] + 1;
    
    if (indexPath.row == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"storyHeaderCell"];
        [self configureHeaderCell:cell forIndexPath:indexPath];
        return cell;
    }
    else if (_isForTrending && indexPath.row == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"storyCountCell"];
        [self configureCountCell:cell forIndexPath:indexPath];
        return cell;
    }
    else if (indexPath.row == footerIndex) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"storyFooterCell"];
        [self configureFooterCell:cell forIndexPath:indexPath];
        return cell;
    }
    else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"storyEventCell"];
        [self configureEventCell:cell forIndexPath:indexPath];
        return cell;
    }
    
}

#pragma mark - Table view delegate methods

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // don't select footer cell bc if _episodeId, already on story detail view.
    if (_episodeId && indexPath.row == [[_storiesArray objectAtIndex:indexPath.section] count] - 1) {
        return nil;
    }
    else {
        return indexPath;
    }
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //JPLog(@"selected cell at row %ld", (long)[indexPath row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger footerIndex = [[_storiesArray objectAtIndex:indexPath.section] count];
    if (_isForTrending) footerIndex = [[_storiesArray objectAtIndex:indexPath.section] count] + 1;
    
    if (indexPath.row == 0) {
        // header
        [self pushEpisodeViewForIndexPath:indexPath withFocusedEventId:nil];
        
    }
    else if ((_isForTrending && indexPath.row == 1) || (indexPath.row == footerIndex)) {
        // footer or counts
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
        
        NSInteger eventDictIndex = indexPath.row;
        if (_isForTrending) eventDictIndex--;
        NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:eventDictIndex]];
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

UILabel *prototypeLabel;
CGFloat labelWidth = 0;

//-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger footerIndex = [[_storiesArray objectAtIndex:indexPath.section] count];
    if (_isForTrending) footerIndex = [[_storiesArray objectAtIndex:indexPath.section] count] + 1;
    
    if (indexPath.row == 0) {
        // header cell
        return 127;
    } else if (indexPath.row == footerIndex) {
        // footer cell
        return 35;
    } else if (_isForTrending && indexPath.row == 1) {
        // count cell
        return 47;
    } else {
        // event cell
        CGFloat defaultEventCellHeight = 57;
        NSInteger eventDictIndex = indexPath.row;
        if (_isForTrending) eventDictIndex--;
        NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:eventDictIndex]];
        if ([eventDict objectForKey:@"comment"] && [[eventDict objectForKey:@"comment"] length] > 0) {
            if (!prototypeLabel) {
                prototypeLabel = [[UILabel alloc] init];
                prototypeLabel.font = [UIFont systemFontOfSize:15];
                prototypeLabel.numberOfLines = 0;
            }
            if (labelWidth == 0) {
                labelWidth = _screenWidth -63 - 60;
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
        if (_screenWidth > 320) {
            threshold = 5;
            max = 8;
        }
        if (users.count > threshold) {
            spacing = 20;
        }
        
        headerCell.usernameButton.hidden = YES;
        avatarUrlString = [users objectAtIndex:0];
        
        AvatarContainerView *lastAvatar = headerCell.avatarContainerView;
        NSUInteger limit = MIN(users.count, max);
        
        for (int i = 1; i < limit; i++) { // skip the first
            NSString *avUrlString = [users objectAtIndex:i];
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
        NSDictionary *userDict = [storyDict objectForKey:@"user"];
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
    //NSLog(@"configure header cell for %@ (%lu)", title, (unsigned long)title.length);
    headerCell.title.text = title;
    if (_screenWidth >= 414) { // iPhone 6+/6s+
        headerCell.title.font = [UIFont systemFontOfSize:21 weight:UIFontWeightLight];
        if (title.length > 82) {
            headerCell.title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightLight];
        }
        else if (title.length > 52) {
            headerCell.title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightLight];
        }
    }
    else if (_screenWidth >= 375) { // iPhone 6/6s
        headerCell.title.font = [UIFont systemFontOfSize:21 weight:UIFontWeightLight];
        
        if (title.length > 54) {
            headerCell.title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightLight];
        }
        else if (title.length > 40) {
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
    if (_isForTrending) {
        headerCell.postedDateLabel.text = @"";
    } else {
        headerCell.postedDateLabel.text = [TungCommonObjects timeElapsed:[storyDict objectForKey:@"time_secs"]];
    }

    // separator
    headerCell.preservesSuperviewLayoutMargins = NO;
    [headerCell setLayoutMargins:UIEdgeInsetsZero];
}

- (void) configureCountCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
    StoryCountCell *countCell = (StoryCountCell *)cell;
    
    NSDictionary *storyDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:0]];
    
    countCell.recommendCountLabel.text = [TungCommonObjects formatNumberForCount:[storyDict objectForKey:@"recommendCount"]];
    countCell.clipCountLabel.text = [TungCommonObjects formatNumberForCount:[storyDict objectForKey:@"clipCount"]];
    countCell.commentCountLabel.text = [TungCommonObjects formatNumberForCount:[storyDict objectForKey:@"commentCount"]];
    countCell.playCountLabel.text = [TungCommonObjects formatNumberForCount:[storyDict objectForKey:@"listenCount"]];
    
    // color
    UIColor *keyColor = (UIColor *)[storyDict objectForKey:@"keyColor"];
    countCell.backgroundColor = keyColor;
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [TungCommonObjects darkenKeyColor:keyColor];
    [countCell setSelectedBackgroundView:bgColorView];
    
}

- (void) configureEventCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
    StoryEventCell *eventCell = (StoryEventCell *)cell;
    
    NSInteger eventDictIndex = indexPath.row;
    if (_isForTrending) eventDictIndex--;
    
    NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:eventDictIndex]];
    //NSLog(@"cell %ld event dict: %@", (long)indexPath.row, eventDict);
    NSDictionary *headerDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:0]];
    BOOL isGroup = NO;
    if ([headerDict objectForKey:@"users"]) {
        isGroup = YES;
    }
    
    // color
    UIColor *keyColor = (UIColor *)[headerDict objectForKey:@"keyColor"];
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
    
    NSDictionary *storyDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:0]];
    
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
    UIColor *keyColor = (UIColor *)[storyDict objectForKey:@"keyColor"];
    footerCell.backgroundColor = keyColor;
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [TungCommonObjects darkenKeyColor:keyColor];
    [footerCell setSelectedBackgroundView:bgColorView];
    
    // separator
    footerCell.preservesSuperviewLayoutMargins = NO;
    [footerCell setLayoutMargins:UIEdgeInsetsZero];
}



- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // stop clip playback as cell scrolls out of view
    if (indexPath.section == _activeSectionIndex && indexPath.row == _activeRowIndex) {
        [self stopClipPlayback];
    }
}


#pragma mark - long press

- (void) tableCellLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    
    //JPLog(@"long press detected with state: %ld", (long)gestureRecognizer.state);
    
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        CGPoint loc = [gestureRecognizer locationInView:self.tableView];
    	NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:loc];
        
        if (indexPath) {
            
            NSUInteger footerIndex = [[_storiesArray objectAtIndex:indexPath.section] count];
            if (_isForTrending) footerIndex = [[_storiesArray objectAtIndex:indexPath.section] count] + 1;
            
            if (indexPath.row == 0 || indexPath.row == footerIndex) {
                // story header/footer
                return;
            }
            NSDictionary *headerDict = [[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:0];
            //JPLog(@"header dict: %@", headerDict);
            
            // story event
            NSInteger eventDictIndex = indexPath.row;
            if (_isForTrending) eventDictIndex--;
            NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:eventDictIndex]];
            NSString *timestamp = [eventDict objectForKey:@"timestamp"];
            NSString *playFromString = [NSString stringWithFormat:@"Play from %@", timestamp];
            NSString *type = [eventDict objectForKey:@"type"];
            NSString *shareItemOption, *copyLinkOption, *destructiveOption, *shareLink, *shareText;
            NSString *userId = [[[eventDict objectForKey:@"user"] objectForKey:@"id"] objectForKey:@"$id"];
            NSString *username = [[eventDict objectForKey:@"user"] objectForKey:@"username"];
            BOOL shareable = NO;
            BOOL isLoggedInUser =  [userId isEqualToString:_tung.tungId];
            
            if ([type isEqualToString:@"clip"]) {
                shareable = YES;
                shareItemOption = @"Share this clip";
                copyLinkOption = @"Copy link to clip";
                NSString *clipShortlink = [eventDict objectForKey:@"shortlink"];
                shareLink = [NSString stringWithFormat:@"%@c/%@", [TungCommonObjects tungSiteRootUrl], clipShortlink];
                shareText = [NSString stringWithFormat:@"Here's a clip from %@: %@", [[headerDict objectForKey:@"episode"] objectForKey:@"title"], shareLink];
                NSString *comment = [eventDict objectForKey:@"comment"];
                if (isLoggedInUser) {
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
                shareable = YES;
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
            
            
            if (shareable || (!shareable && !isLoggedInUser)) {

                UIAlertController *storyOptionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
                if (shareable) {
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
                }
                
                if (!isLoggedInUser) {
                    // view profile
                    [storyOptionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"View @%@", username] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [self pushProfileForUserId:userId];
                    }]];
                }
                
                // delete or flag
                if (destructiveOption) {
                    [storyOptionSheet addAction:[UIAlertAction actionWithTitle:destructiveOption style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                        // delete story event
                        if (isLoggedInUser) {
                            
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
            if (success) {
                NSDictionary *episodeDict = [responseDict objectForKey:@"episode"];
                NSDictionary *podcastDict = [responseDict objectForKey:@"podcast"];
                PodcastEntity *podcastEntity = [TungCommonObjects getEntityForPodcast:podcastDict save:NO];
                [TungCommonObjects getEntityForEpisode:episodeDict withPodcastEntity:podcastEntity save:YES];
                
                NSString *urlString = [episodeDict objectForKey:@"url"];
                
                if (urlString) {
                    [_tung playUrl:urlString fromTimestamp:timestamp];
                }
            }
        }];
    }

}

- (void) deleteEventAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger eventDictIndex = indexPath.row;
    if (_isForTrending) eventDictIndex--;
	NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:eventDictIndex]];
    NSString *eventId = [[eventDict objectForKey:@"id"] objectForKey:@"$id"];
    
    [_tung deleteStoryEventWithId:eventId withCallback:^(BOOL success) {
        if (success) {
            // remove story or just event
            NSArray *storyArray = [_storiesArray objectAtIndex:indexPath.section];
            if (storyArray.count == 2) {
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
    // share interaction if it's a single user story
    if ([headerDict objectForKey:@"storyLink"]) {
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
    }
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
    if ([headerDict objectForKey:@"user"]) {
        NSString *shareLink = [headerDict objectForKey:@"storyLink"];
        NSString *shareText;
        NSString *uid = [[[headerDict objectForKey:@"user"] objectForKey:@"id"] objectForKey:@"$id"];
        if ([uid isEqualToString:_tung.tungId]) {
            shareText = [NSString stringWithFormat:@"I listened to %@ on #tung: %@", [[headerDict objectForKey:@"episode"] objectForKey:@"title"], shareLink];
        } else {
            shareText = [NSString stringWithFormat:@"%@ listened to %@ on #tung: %@", [[headerDict objectForKey:@"user"] objectForKey:@"username"], [[headerDict objectForKey:@"episode"] objectForKey:@"title"], shareLink];
        }
        return shareText;
    } else {
        return nil;
    }
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
        [self pushProfileForUserId:userId];
    }
}

- (void) pushProfileForUserId:(NSString *)userId {
    // push profile
    if (![_profiledUserId isEqualToString:userId]) {
        ProfileViewController *profileView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"profileView"];
        profileView.profiledUserId = userId;
        [_navController pushViewController:profileView animated:YES];
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
        
        [self stopClipPlayback];
    
        // check for cached audio data and init player
        NSInteger eventDictIndex = _selectedRowIndex;
        if (_isForTrending) eventDictIndex--;
        NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:_selectedSectionIndex] objectAtIndex:eventDictIndex]];
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
    
    [_tung stopClipPlayback];
    
    if (_activeSectionIndex >= 0 && _activeRowIndex >= 0) {
        // stop "onEnterFrame"
        [_onEnterFrame invalidate];
        //JPLog(@"%@",[NSThread callStackSymbols]);
        
        // reset GUI
        NSInteger eventDictIndex = _activeRowIndex;
        if (_isForTrending) eventDictIndex--;
        NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:_activeSectionIndex] objectAtIndex:eventDictIndex]];
        
        _activeClipProgressView.seconds = [NSString stringWithFormat:@":%@", [eventDict objectForKey:@"duration"]];
        _activeClipProgressView.arc = 0.0f;
        [_activeClipProgressView setNeedsDisplay];
        
        // reset active indexes
        _activeRowIndex = -1;
        _activeSectionIndex = -1;
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
        //NSLog(@"table view scrolled to offset: %f", scrollView.contentOffset.y);
        
        // shrink profile header
        if (_profiledUserId.length) {
            if (!_profileHeader.isMinimized && scrollView.contentSize.height > scrollView.frame.size.height + 100 && scrollView.contentOffset.y > _lastScrollViewOffset) {
                NSLog(@"content height: %f, frame height: %f", scrollView.contentSize.height, scrollView.frame.size.height);
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
            if (!_requestingMore && !_reachedEndOfPosts && _storiesArray.count > 0) {
                //NSLog(@"requesting more stories");
                _requestingMore = YES;
                _loadMoreIndicator.alpha = 1;
                [_loadMoreIndicator startAnimating];
                NSNumber *oldest = [[[_storiesArray objectAtIndex:_storiesArray.count-1] objectAtIndex:0] objectForKey:@"time_secs_end"];
                
                if (_profiledUserId.length || _episodeId.length) {
                    [self getStoriesForProfiledUserId:_profiledUserId
                                          orEpisodeId:_episodeId
                                            newerThan:[NSNumber numberWithInt:0]
                                          orOlderThan:oldest
                                             withCred:NO];
                }
                else {
                    [self getStoriesNewerThan:[NSNumber numberWithInt:0]
                                  orOlderThan:oldest
                                     trending:_isForTrending
                                     withCred:NO];
                }
            }
        }
    }
}


@end
