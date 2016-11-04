//
//  EpisodesTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 7/27/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "EpisodesTableViewController.h"
#import "EpisodeViewController.h"

@interface EpisodesTableViewController ()


@property (nonatomic, retain) TungCommonObjects *tung;
@property (nonatomic, assign) NSInteger downloadingEpisodeIndex;
@property (strong, nonatomic) CADisplayLink *onEnterFrame;
@property (strong, nonatomic) CircleButton *activeSaveBtn;
@property NSDateFormatter *airDateFormatter;

@end

@implementation EpisodesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    
    // set up table
    UIActivityIndicatorView *tableSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    tableSpinner.alpha = 1;
    [tableSpinner startAnimating];
    self.tableView.backgroundView = tableSpinner;
    self.tableView.backgroundColor = [TungCommonObjects bkgdGrayColor];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.separatorColor = [UIColor lightGrayColor];
    self.tableView.scrollsToTop = YES;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 9, 0, 9);
    self.tableView.contentInset = UIEdgeInsetsZero;// UIEdgeInsetsMake(0, 0, 0, 0);    
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(getNewestFeed) forControlEvents:UIControlEventValueChanged];
    
    _downloadingEpisodeIndex = -1;
    
    _airDateFormatter = [[NSDateFormatter alloc] init];
    [_airDateFormatter setDateFormat:@"MMM d, yyyy"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveStatusChanged) name:@"saveStatusDidChange" object:nil];
    
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self saveStatusChanged];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:YES];
    
    // remove saveStatusChanged observer
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"saveStatusDidChanged" object:_tung];
    
    [_onEnterFrame invalidate];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) getNewestFeed {
    
    //NSLog(@"get newest feed");
    if (_tung.connectionAvailable.boolValue) {
        
        NSDictionary *feedDict = [TungPodcast retrieveAndCacheFeedForPodcastEntity:_podcastEntity forceNewest:YES reachable:_tung.connectionAvailable.boolValue];
        NSError *feedError;
        _episodeArray = [[TungPodcast extractFeedArrayFromFeedDict:feedDict error:&feedError] mutableCopy];
        
        [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(endRefreshing) userInfo:nil repeats:NO];
        
        if (!feedError) {
            [self assignSavedPropertiesToEpisodeArray];
            [self.tableView reloadData];
        }
        else {
            [TungCommonObjects simpleErrorAlertWithMessage:feedError.localizedDescription];
        }
    }
    else {
        [self.refreshControl endRefreshing];
        [TungCommonObjects showNoConnectionAlert];
    }
    
}

// for calling on delay
- (void) endRefreshing {
    NSLog(@"end refreshing");
    [self.refreshControl endRefreshing];
}

- (void) assignSavedPropertiesToEpisodeArray {
    
    //NSLog(@"find each episode's progress");
    for (EpisodeEntity *ep in _podcastEntity.episodes) {
        for (int i = 0; i < _episodeArray.count; i++) {
            NSMutableDictionary *episodeDict = [[NSDictionary dictionaryWithDictionary:[_episodeArray objectAtIndex:i]] mutableCopy];
            if ([ep.guid isEqualToString:[episodeDict objectForKey:@"guid"]]) {
                //NSLog(@"set track position %f for %@", ep.trackPosition.floatValue, ep.title);
                [episodeDict setObject:ep.trackPosition forKey:@"trackPosition"];
                [episodeDict setObject:ep.isSaved forKey:@"isSaved"];
                [episodeDict setObject:ep.isQueuedForSave forKey:@"isQueuedForSaved"];
                // downloading?
                if (ep.isDownloadingForSave.boolValue) {
                    _downloadingEpisodeIndex = i;
                } else {
                    if (_downloadingEpisodeIndex == i) {
                        _downloadingEpisodeIndex = -1;
                    }
                }
                [_episodeArray replaceObjectsAtIndexes:[NSIndexSet indexSetWithIndex:i] withObjects:@[episodeDict]];
                break;
            }
        }
    }
}

// used for setting entity properties after new subscribe,
// and also marking new episodes as "seen" to reset badge.
-(void) markNewEpisodesAsSeen {
    
    if (_episodeArray && _episodeArray.count) {
        
        //NSLog(@"mark new episodes as seen");
        
        NSMutableArray *rowsToReload = [NSMutableArray array];
        
        if (_podcastEntity.mostRecentEpisodeDate) {
            // find new episodes and fade rows back to white
            NSArray *visibleRows = [self.tableView indexPathsForVisibleRows];
            for (int i = 0; i < visibleRows.count; i++) {
                NSIndexPath *indexPath = [visibleRows objectAtIndex:i];
                NSDictionary *episodeDict = [_episodeArray objectAtIndex:indexPath.row];
                NSDate *pubDate = [episodeDict objectForKey:@"pubDate"];
                if ([_podcastEntity.mostRecentSeenEpisodeDate compare:pubDate] == NSOrderedAscending) {
                    [rowsToReload addObject:indexPath];
                }
            }
        }
        
        SettingsEntity *settings = [TungCommonObjects settings];
    
        NSNumber *numNew = _podcastEntity.numNewEpisodes;
        _podcastEntity.numNewEpisodes = [NSNumber numberWithInt:0];
        // in case mostRecentEpisodeDate was not set yet or new episode was published after bkgd fetch
        NSDate *mostRecentEpisodeDate = [[_episodeArray objectAtIndex:0] objectForKey:@"pubDate"];
        _podcastEntity.mostRecentEpisodeDate = mostRecentEpisodeDate;
        _podcastEntity.mostRecentSeenEpisodeDate = mostRecentEpisodeDate;
        if (rowsToReload.count) {
            [self.tableView reloadRowsAtIndexPaths:rowsToReload withRowAnimation: UITableViewRowAnimationFade];
        }
        
        NSInteger numPodcastNotifications = settings.numPodcastNotifications.integerValue - numNew.integerValue;
        if (numPodcastNotifications < 0) numPodcastNotifications = 0;
        settings.numPodcastNotifications = [NSNumber numberWithInteger:numPodcastNotifications];
        [_tung setBadgeNumber:settings.numPodcastNotifications forBadge:_tung.subscriptionsBadge];
        
        [TungCommonObjects saveContextWithReason:@"marking new episodes as \"seen\""];
		
        NSInteger numApplicationNotifications = numPodcastNotifications + settings.numProfileNotifications.integerValue;
    	[[UIApplication sharedApplication] setApplicationIconBadgeNumber:numApplicationNotifications];
    }
    
}

#pragma mark - respond to save status changes

-(void) saveStatusChanged {
    [self assignSavedPropertiesToEpisodeArray];
    [self.tableView reloadData];
    //JPLog(@"received notification: save status changed, downloadingEpisodeIndex: %ld", (long)_downloadingEpisodeIndex);
    
    if (_downloadingEpisodeIndex >= 0) {
        // set reference to save button of actively downloading episode
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_downloadingEpisodeIndex inSection:0];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        EpisodeCell *activeCell = (EpisodeCell *)cell;
        _activeSaveBtn = activeCell.saveWithProgressBtn;
        // begin "onEnterFrame"
        _onEnterFrame = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateView)];
        [_onEnterFrame addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        
    } else {
        [_onEnterFrame invalidate];
        _activeSaveBtn = nil;
    }
}

- (void) updateView {
    if (_activeSaveBtn) {
        float buffered = _tung.saveTrackData.length;
        float progress = 0;
        if (buffered > 0 && _tung.episodeToSaveEntity.dataLength.doubleValue > 0) {
            progress = buffered / _tung.episodeToSaveEntity.dataLength.doubleValue;
        }
        float arc = 360 - (360 * progress);
        _activeSaveBtn.arc = arc;
        [_activeSaveBtn setNeedsDisplay];
    }
}

#pragma mark - cell controls

-(void) tableCellButtonTapped:(id)sender {
    long tag = [sender tag];
    
    if (tag == 101) {
        EpisodeCell *cell = (EpisodeCell *)[[sender superview] superview];
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        NSDictionary *epDict = [_episodeArray objectAtIndex:indexPath.row];
        EpisodeEntity *epEntity = [TungCommonObjects getEntityForEpisode:epDict withPodcastEntity:_podcastEntity save:YES];
        
        if (epEntity.isSaved.boolValue) {
            // tell user when episode will be auto deleted
            [_tung showSavedInfoAlertForEpisode:epEntity];
            
        }
        else if (epEntity.isQueuedForSave.boolValue) {
            [_tung cancelDownloadForEpisode:epEntity];
        }
        else {
            // initiate download
            [_tung moveToSavedOrQueueDownloadForEpisode:epEntity];
        }
        
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return _episodeArray.count;
    } else {
        return 0;
    }
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EpisodeCell"];
    
    EpisodeCell *episodeCell = (EpisodeCell *)cell;
    
    // cell data
    NSDictionary *episodeDict = [NSDictionary dictionaryWithDictionary:[_episodeArray objectAtIndex:indexPath.row]];
    //NSLog(@"episode cell for row at index path, row: %ld", (long)indexPath.row);
    //NSLog(@"episode: %@", [episodeDict allKeys]);
    
    // title
    episodeCell.episodeTitle.text = [episodeDict objectForKey:@"title"];
    UIColor *keyColor = (UIColor *)_podcastEntity.keyColor1;
    episodeCell.episodeTitle.textColor = keyColor;
    // air date & duration
    NSDate *pubDate = [episodeDict objectForKey:@"pubDate"];
    NSString *infoString;
    if ([episodeDict objectForKey:@"itunes:duration"]) {
        NSString *duration = [TungCommonObjects formatDurationFromString:[episodeDict objectForKey:@"itunes:duration"]];
        infoString = [NSString stringWithFormat:@"%@  •  %@", [_airDateFormatter stringFromDate:pubDate], duration];
    } else {
        infoString = [_airDateFormatter stringFromDate:pubDate];
    }
    episodeCell.airDate.text = infoString;
    
    // now playing?
    episodeCell.iconView.backgroundColor = [UIColor clearColor];
    if (_tung.playQueue.count > 0) {
        
        NSDictionary *enclosureDict = [TungCommonObjects getEnclosureDictForEpisode:episodeDict];
        NSString *urlString = [[enclosureDict objectForKey:@"el:attributes"] objectForKey:@"url"];
        NSString *playingUrlString = [_tung.playQueue objectAtIndex:0];
        
        if ([urlString isEqualToString:playingUrlString]) {
            episodeCell.iconView.type = kIconTypeNowPlaying;
            episodeCell.iconView.color = [TungCommonObjects tungColor];
            episodeCell.leadingTitleConstraint.constant = 36;
        } else {
            episodeCell.iconView.type = kIconTypeNone;
            episodeCell.leadingTitleConstraint.constant = 12;
        }
        [episodeCell.iconView setNeedsDisplay];
    }
    
    // background color
    if (_focusedIndexPath) {
        // only color focused row
        if (_focusedIndexPath.row == indexPath.row) {
            episodeCell.backgroundColor = [TungCommonObjects lightTungColor];
        } else {
            episodeCell.backgroundColor = [UIColor whiteColor];
        }
    }
    else if (_podcastEntity.mostRecentEpisodeDate) {
        // color new episodes if entity has a mostRecentEpisodeDate set
        if ([_podcastEntity.mostRecentSeenEpisodeDate compare:pubDate] == NSOrderedAscending) {
            episodeCell.backgroundColor = [TungCommonObjects lightTungColor];
        } else {
            episodeCell.backgroundColor = [UIColor whiteColor];
        }
    }
    else {
        episodeCell.backgroundColor = [UIColor whiteColor];
    }
    
    // episode Progress
    episodeCell.episodeProgress.type = kMiscViewTypeEpisodeProgress;
    episodeCell.episodeProgress.color = (UIColor *)_podcastEntity.keyColor2;
    float position = 0;
    if ([episodeDict objectForKey:@"trackPosition"]) {
        NSNumber *nPosition = [episodeDict objectForKey:@"trackPosition"];
        position = nPosition.floatValue;
    }
    episodeCell.episodeProgress.progress = position;
    [episodeCell.episodeProgress setNeedsDisplay];
    
    // episode saving
    episodeCell.saveWithProgressBtn.type = kCircleTypeSaveWithProgress;
    episodeCell.saveWithProgressBtn.tag = 101;
    [episodeCell.saveWithProgressBtn addTarget:self action:@selector(tableCellButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    NSNumber *isSaved = [episodeDict objectForKey:@"isSaved"];
    NSNumber *isQueuedForSave = [episodeDict objectForKey:@"isQueuedForSaved"];
    if (isSaved.boolValue) {
        episodeCell.saveWithProgressBtn.on = YES;
        episodeCell.saveWithProgressBtn.queued = NO;
    }
    else if (isQueuedForSave.boolValue) {
        
        episodeCell.saveWithProgressBtn.on = NO;
        episodeCell.saveWithProgressBtn.queued = YES;
    }
    else {
        episodeCell.saveWithProgressBtn.on = NO;
        episodeCell.saveWithProgressBtn.queued = NO;
        episodeCell.saveWithProgressBtn.arc = 0;
    }
    [episodeCell.saveWithProgressBtn setNeedsDisplay];
    
    // kill insets
    episodeCell.preservesSuperviewLayoutMargins = NO;
    [episodeCell setLayoutMargins:UIEdgeInsetsZero];
    
    return episodeCell;
}

#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //NSLog(@"%@", [_episodeArray objectAtIndex:indexPath.row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // play episode selected
    NSDictionary *episodeDict = [_episodeArray objectAtIndex:indexPath.row];
    EpisodeEntity *episodeEntity = [TungCommonObjects getEntityForEpisode:episodeDict withPodcastEntity:_podcastEntity save:YES];
    EpisodeViewController *episodeView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"episodeView"];
    episodeView.episodeEntity = episodeEntity;

    [_navController pushViewController:episodeView animated:YES];
}

//- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 74;
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (_episodeArray.count > 0 && section == 1) {
        UILabel *noMoreLabel = [[UILabel alloc] init];
        noMoreLabel.text = @"That's everything.\n ";
        noMoreLabel.numberOfLines = 0;
        noMoreLabel.textColor = [UIColor grayColor];
        noMoreLabel.textAlignment = NSTextAlignmentCenter;
        return noMoreLabel;
    }
    else if (_noResults && section == 1) {
        UILabel *noEpisodesLabel = [[UILabel alloc] init];
        noEpisodesLabel.text = @"Podcast feed is empty.\n ";
        noEpisodesLabel.numberOfLines = 0;
        noEpisodesLabel.textColor = [UIColor grayColor];
        noEpisodesLabel.textAlignment = NSTextAlignmentCenter;
        return noEpisodesLabel;
    }
    else {
        return nil;
    }
}

-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 1 && _episodeArray.count) {
        return 60.0;
    }
    else {
        return 0;
    }
}

@end
