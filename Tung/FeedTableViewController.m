//
//  FeedTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 8/7/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "FeedTableViewController.h"
#import "PodcastViewController.h"

@interface FeedTableViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) TungPodcast *podcast;
@property (strong, nonatomic) TungStories *stories;
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;

@property BOOL hasPodcastData;

@end

@implementation FeedTableViewController

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
    
    // for feed
    _stories = [TungStories new];
    _stories.tableView = self.tableView;
    _stories.loadMoreIndicator = self.loadMoreIndicator;
    _stories.feedSectionStartingIndex = 0;
    _stories.navController = [self navigationController];
    
    [_stories addObserver:self forKeyPath:@"requestStatus" options:NSKeyValueObservingOptionNew context:nil];

    
    // additional table setup
    self.tableView.backgroundColor = _tung.bkgdGrayColor;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.scrollsToTop = YES;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 12, 0, 12);
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, -5, 0);
    self.tableView.separatorColor = [UIColor colorWithWhite:1 alpha:.7];

//    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLineEtched;
    
    UIActivityIndicatorView *tableSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    tableSpinner.alpha = 1;
    [tableSpinner startAnimating];
    self.tableView.backgroundView = tableSpinner;
    
    
    // refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
    
    //[TungCommonObjects clearTempDirectory]; // DEV only
    
    /* dev purposes - log out of fb
    if ([FBSDKAccessToken currentAccessToken]) {
        [[FBSDKLoginManager new] logOut];
    } */
    
    _hasPodcastData = [TungCommonObjects checkForPodcastData];
    
    // first load
    _tung.feedNeedsRefresh = [NSNumber numberWithBool:YES];
    
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if (object == _stories && [keyPath isEqualToString:@"requestStatus"]) {
        if ([_stories.requestStatus isEqualToString:@"finished"]) {
            [self.refreshControl endRefreshing];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    //self.navigationController.navigationBar.translucent = YES;
    NSLog(@"cancel feed preloading");
    [_podcast.feedPreloadQueue cancelAllOperations];
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    _tung.ctrlBtnDelegate = self;
    _tung.viewController = self;
    
    // let's get retarded in here
    if (_tung.feedNeedsRefresh.boolValue) {
    	[self refreshFeed];
    }
    
    //self.navigationController.navigationBar.translucent = NO;
}

#pragma mark - tungObjects/tungPodcasts delegate methods

// ControlButtonDelegate required method
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
// ControlButtonDelegate required method
-(void) dismissPodcastSearch {
    [_podcast.searchController setActive:NO];
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"hideSearch"];
    
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tungNavBarLogo.png"]];;
    UIBarButtonItem *searchBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiateSearch)];
    [self.navigationItem setRightBarButtonItem:searchBtn animated:YES];
    
}

#pragma mark - Feed

- (void) refreshFeed {
    
    [TungCommonObjects checkReachabilityWithCallback:^(BOOL reachable) {
        if (reachable) {
            // refresh feed
            if (_tung.sessionId && _tung.sessionId.length > 0) {
                NSLog(@"refresh feed");
                [self.refreshControl beginRefreshing];
                
                NSNumber *mostRecent;
                if (_stories.storiesArray.count > 0) {
                    mostRecent = [[[_stories.storiesArray objectAtIndex:0] objectAtIndex:0] objectForKey:@"time_secs"];
                } else { // if initial request timed out and they are trying again
                    mostRecent = [NSNumber numberWithInt:0];
                }
                [_stories requestPostsNewerThan:mostRecent
                                       orOlderThan:[NSNumber numberWithInt:0]
                                          fromUser:@""];
            }
            // get session then feed
            else {
                NSLog(@"get feed");
                [_tung getSessionWithCallback:^{
                    // since this is the first call the app makes and we now have session
                    // check to see if user has no podcast data so it can be restored.
                    // does not sync track progress
                    NSLog(@"has podcast data: %@", (_hasPodcastData) ? @"Yes" : @"No");
                    if (!_hasPodcastData) {
                        [_tung restorePodcastDataWithCallback:^(BOOL success, NSDictionary *response) {
                            if (success && [response objectForKey:@"results"]) {
                                NSArray *data = [response objectForKey:@"results"];
                                NSLog(@"restoring podcast data...");
                                for (NSDictionary *story in data) {
                                    NSMutableDictionary *podcastDict, *episodeDict;
                                    PodcastEntity *podcastEntity = nil;
                                    EpisodeEntity *episodeEntity = nil;
                                    BOOL isSubscribeStory = NO;
                                    BOOL isRecommendStory = NO;
                                    
                                    for (NSString* key in story) {
                                        // podcast
                                        if ([key isEqualToString:@"podcast"]) {
                                            podcastDict = [[story objectForKey:@"podcast"] mutableCopy];
                                            UIColor *keyColor1 = [TungCommonObjects colorFromHexString:[podcastDict objectForKey:@"keyColor1Hex"]];
                                            UIColor *keyColor2 = [TungCommonObjects colorFromHexString:[podcastDict objectForKey:@"keyColor2Hex"]];
                                            [podcastDict setObject:keyColor1 forKey:@"keyColor1"];
                                            [podcastDict setObject:keyColor2 forKey:@"keyColor2"];
                                            
                                            if ([podcastDict objectForKey:@"episode"]) {
                                                episodeDict = [[podcastDict objectForKey:@"episode"] mutableCopy];
                                                [episodeDict setObject:[podcastDict objectForKey:@"collectionId"] forKey:@"collectionId"];
                                                NSDate *pubDate = [self pubDateToNSDate:[episodeDict objectForKey:@"pubDate"]];
                                                [episodeDict setObject:pubDate forKey:@"pubDate"];
                                                episodeEntity = [TungCommonObjects getEntityForPodcast:podcastDict andEpisode:episodeDict save:NO];
                                            } else {
                                                
                                                podcastEntity = [TungCommonObjects getEntityForPodcast:podcastDict save:NO];
                                            }
                                        }
                                        // events
                                        if ([key isEqualToString:@"events"]) {
                                    		for (NSDictionary *event in [story objectForKey:@"events"]) {
                                                NSString *type = [event objectForKey:@"type"];
                                                if ([type isEqualToString:@"recommended"]) {
                                                    isRecommendStory = YES;
                                                }
                                                if ([type isEqualToString:@"subscribed"]) {
                                                    isSubscribeStory = YES;
                                                }
                                            }
                                        }
                                    }
                                    
                                    if (isSubscribeStory) {
                                        podcastEntity.isSubscribed = [NSNumber numberWithBool:YES];
                                        double secs = [[story objectForKey:@"time_secs"] doubleValue];
                                        NSDate *subDate = [NSDate dateWithTimeIntervalSince1970:secs];
                                        podcastEntity.dateSubscribed = subDate;
                                    }
                                    else {
                                        episodeEntity.storyShortlink = [story objectForKey:@"shortlink"];
                                        if (isRecommendStory) {
                                            episodeEntity.isRecommended = [NSNumber numberWithBool:YES];
                                        }
                                    }
                                    
                                    BOOL saved = [TungCommonObjects saveContextWithReason:@"restoring podcast data"];
                                    if (!saved) NSLog(@"error on story: %@", story);
                                }
                                _hasPodcastData = YES;
                            }
                            // get feed
                            [_stories requestPostsNewerThan:[NSNumber numberWithInt:0]
                                                orOlderThan:[NSNumber numberWithInt:0]
                                                   fromUser:@""];
                        }];
                    }
                    // if _hasPodcastData
                    else {
                        // get feed
                        [_stories requestPostsNewerThan:[NSNumber numberWithInt:0]
                                            orOlderThan:[NSNumber numberWithInt:0]
                                               fromUser:@""];
                    }
                }];
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

// date converter for restoring podcast data
static NSDateFormatter *pubDateInterpreter = nil;
-(NSDate *) pubDateToNSDate: (NSString *)pubDate {
    
    NSDate *date = nil;
    if (pubDateInterpreter == nil) {
        pubDateInterpreter = [[NSDateFormatter alloc] init]; // "2014-09-05 14:27:40 +0000",
        [pubDateInterpreter setDateFormat:@"yyyy-MM-dd HH:mm:ss Z"];
    }
    
    if ([pubDateInterpreter dateFromString:pubDate]) {
        date = [pubDateInterpreter dateFromString:pubDate];
    }
    else {
        NSLog(@"could not convert date: %@", pubDate);
        date = [NSDate date];
    }
    return date;
    
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _stories.storiesArray.count + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_stories.storiesArray.count) {
        if (section < _stories.storiesArray.count) {
    		return [[_stories.storiesArray objectAtIndex:section] count];
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
        [_stories configureHeaderCell:cell forIndexPath:indexPath];
        return cell;
    } else if (indexPath.row == [[_stories.storiesArray objectAtIndex:indexPath.section] count] - 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:footerCellIdentifier];
        [_stories configureFooterCell:cell forIndexPath:indexPath];
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:eventCellIdentifier];
        [_stories configureEventCell:cell forIndexPath:indexPath];
        return cell;
    }
    
}

#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //NSLog(@"selected cell at row %ld", (long)[indexPath row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row == 0) {
        // push podcast view
        NSDictionary *storyDict = [[_stories.storiesArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        NSDictionary *podcastDict = [NSDictionary dictionaryWithDictionary:[storyDict objectForKey:@"podcast"]];
        //NSLog(@"selected %@", [podcastDict objectForKey:@"collectionName"]);
        
        PodcastViewController *podcastView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"podcastView"];
        if ([podcastDict objectForKey:@"episode"]) {
            podcastView.focusedGUID = [[podcastDict objectForKey:@"episode"] objectForKey:@"guid"];
        }
        podcastView.podcastDict = [podcastDict mutableCopy];
        [self.navigationController pushViewController:podcastView animated:YES];
    }
    else if (indexPath.row == [[_stories.storiesArray objectAtIndex:indexPath.section] count] - 1) {
        // push story view
    }
    else {
        // if clip, play
    }

}

//- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.row == 0) {
        // header cell
        return 127;
    } else if (indexPath.row == [[_stories.storiesArray objectAtIndex:indexPath.section] count] - 1) {
        // footer cell
        return 35;
    } else {
        // event cell
        return 57;
    }
}


-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    
    if (section == _stories.storiesArray.count) {
        return 66.0;
    }
    else {
        return 1;
    }
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == _stories.storiesArray.count) {
        if (_stories.reachedEndOfPosts) {
            UILabel *noMoreLabel = [[UILabel alloc] init];
            noMoreLabel.text = @"That's everything.";
            noMoreLabel.textColor = [UIColor grayColor];
            noMoreLabel.textAlignment = NSTextAlignmentCenter;
            return noMoreLabel;
        } else {
            _loadMoreIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            _stories.loadMoreIndicator = _loadMoreIndicator;
            return _loadMoreIndicator;
        }
    } else {
        UIView *separator = [UIView new];
        separator.backgroundColor = [UIColor whiteColor];
        return separator;
    }
}


#pragma mark - scroll view delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.tableView) {
        // detect when user hits bottom of feed
        float bottomOffset = scrollView.contentSize.height - scrollView.frame.size.height;
        if (scrollView.contentOffset.y >= bottomOffset) {
            // request more posts if they didn't reach the end
            if (!_stories.requestingMore && !_stories.reachedEndOfPosts && _stories.storiesArray.count > 0) {
                _stories.requestingMore = YES;
                _loadMoreIndicator.alpha = 1;
                [_loadMoreIndicator startAnimating];
                NSNumber *oldest = [[[_stories.storiesArray objectAtIndex:_stories.storiesArray.count-1] objectAtIndex:0] objectForKey:@"time_secs"];
                
                [_stories requestPostsNewerThan:[NSNumber numberWithInt:0]
                                    orOlderThan:oldest
                                       fromUser:@""];
            }
        }
    }
}



@end
