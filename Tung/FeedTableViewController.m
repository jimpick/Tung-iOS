//
//  FeedTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 8/7/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "FeedTableViewController.h"

@interface FeedTableViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) TungPodcast *podcast;

@property (nonatomic, assign) BOOL feedRefreshed;
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;

@end

@implementation FeedTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tungNavBarLogo.png"]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiateSearch)];
    
    _tung = [TungCommonObjects establishTungObjects];
    [_tung establishCred];
    _tung.ctrlBtnDelegate = self;
    _tung.viewController = self;
    
    // for search controller
    _podcast = [TungPodcast new];
    self.definesPresentationContext = YES;
    _podcast.navController = [self navigationController];
    _podcast.delegate = self;
    
    // additional table setup
    self.tableView.backgroundColor = _tung.bkgdGrayColor;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.scrollsToTop = YES;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 9, 0, 9);
    self.tableView.contentInset = UIEdgeInsetsMake(1, 0, 10, 0);
    self.tableView.separatorColor = [UIColor whiteColor];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    /*
    _tableSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _tableSpinner.alpha = 1;
    [_tableSpinner startAnimating];
    tableView.backgroundView = _tableSpinner;
     */
    
    // refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
    
    //[TungCommonObjects clearTempDirectory]; // DEV only
    
    // Show user entities
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSFetchRequest *findUsers = [[NSFetchRequest alloc] initWithEntityName:@"UserEntity"];
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:findUsers error:&error];
    if (result.count > 0) {
        for (int i = 0; i < result.count; i++) {
            UserEntity *userEntity = [result objectAtIndex:i];
            NSDictionary *userDict = [TungCommonObjects userEntityToDict:userEntity];
            NSLog(@"user at index: %d", i);
            NSLog(@"%@", userDict);
        }
    } else {
        NSLog(@"no user entities found");
    }
    
    // let's get retarded in here
    [self refreshFeed];

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
            _feedRefreshed = YES;
            // refresh feed
            if (_tung.sessionId != NULL && _tung.sessionId.length > 0) {
//                NSLog(@"refresh feed");
//                [self.refreshControl beginRefreshing];
//                
//                if (_tung.needsReload.boolValue) {
//                    NSLog(@"needed reload");
//                    _tungStereo.clipArray = [[NSMutableArray alloc] init];
//                    _tung.needsReload = [NSNumber numberWithBool:NO];
//                }
//                NSNumber *mostRecent;
//                if (_tungStereo.clipArray.count > 0) {
//                    mostRecent = [[_tungStereo.clipArray objectAtIndex:0] objectForKey:@"time_secs"];
//                } else { // if initial request timed out and they are trying again
//                    mostRecent = [NSNumber numberWithInt:0];
//                }
//                [_tungStereo requestPostsNewerThan:mostRecent
//                                       orOlderThan:[NSNumber numberWithInt:0]
//                                          fromUser:_profiledUser
//                                        orCategory:_profiledCategory
//                                    withSearchTerm:@""];
            }
            // get session then feed
            else {
                NSLog(@"get feed");
                [_tung getSessionWithCallback:^{
                    // since this is the first call the app makes and we now have session
                    // check to see if user has no podcast data so it can be restored
                    BOOL hasPodcastData = [TungCommonObjects checkForPodcastData];
                    NSLog(@"has podcast data: %@", (hasPodcastData) ? @"Yes" : @"No");
                    if (!hasPodcastData) {
                        [_tung restorePodcastDataWithCallback:^(BOOL success, NSDictionary *response) {
                            if (success && [response objectForKey:@"results"]) {
                                NSArray *data = [response objectForKey:@"results"];
                                NSLog(@"restoring podcast data from dict: %@", data);
                                
                                for (NSDictionary *story in data) {
                                    NSMutableDictionary *podcastDict, *episodeDict;
                                    PodcastEntity *podcastEntity = nil;
                                    EpisodeEntity *episodeEntity = nil;
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
                                        BOOL isSubscribeStory = NO;
                                        if ([key isEqualToString:@"events"]) {
                                    		for (NSDictionary *event in [story objectForKey:@"events"]) {
                                                NSString *type = [event objectForKey:@"type"];
                                                if ([type isEqualToString:@"recommended"]) {
                                                    episodeEntity.isRecommended = [NSNumber numberWithBool:YES];
                                                }
                                                if ([type isEqualToString:@"subscribed"]) {
                                                    podcastEntity.isSubscribed = [NSNumber numberWithBool:YES];
                                                    isSubscribeStory = YES;
                                                }
                                            }
                                        }
                                        // story shortlink
                                        if ([key isEqualToString:@"shortlink"]) {
                                            if (!isSubscribeStory) {
                                                episodeEntity.storyShortlink = [story objectForKey:@"shortlink"];
                                            }
                                        }
                                    }
                                    [TungCommonObjects saveContext];
                                }
                            }
                            // <INSERT FEED QUERY HERE>
                        }];
                    } else {
                    	// <INSERT FEED QUERY HERE>
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
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 0;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // tung activity cell
    return nil;
    
}

#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //NSLog(@"selected cell at row %ld", (long)[indexPath row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    
}

//- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return 60;
}


//-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {

//-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {


#pragma mark - scroll view delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.tableView) {
        // detect when user hits bottom of feed
        float bottomOffset = scrollView.contentSize.height - scrollView.frame.size.height;
        if (scrollView.contentOffset.y >= bottomOffset) {
            // request more posts if they didn't reach the end
//            if (!_tungStereo.requestingMore && !_tungStereo.noMoreItemsToGet && _tungStereo.clipArray.count > 0) {
//                _tungStereo.requestingMore = YES;
//                _loadMoreIndicator.alpha = 1;
//                [_loadMoreIndicator startAnimating];
//                NSNumber *oldest = [[_tungStereo.clipArray objectAtIndex:_tungStereo.clipArray.count-1] objectForKey:@"time_secs"];
//                [_tungStereo requestPostsNewerThan:[NSNumber numberWithInt:0]
//                                       orOlderThan:oldest
//                                          fromUser:_profiledUser
//                                        orCategory:_profiledCategory
//                                    withSearchTerm:_searchTerm];
//            }
        }
    }
}



@end
