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

@end

@implementation EpisodesTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    
    // set up table
    self.tableView.backgroundColor = [TungCommonObjects bkgdGrayColor];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.scrollsToTop = YES;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 9, 0, 9);
    self.tableView.contentInset = UIEdgeInsetsZero;// UIEdgeInsetsMake(0, 0, 0, 0);
    self.tableView.separatorColor = [UIColor lightGrayColor];
    
    UIActivityIndicatorView *tableSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    tableSpinner.alpha = 1;
    [tableSpinner startAnimating];
    self.tableView.backgroundView = tableSpinner;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) findEachEpisodesProgress {
    
    //NSLog(@"find each episode's progress");
    for (EpisodeEntity *ep in _podcastEntity.episodes) {
        // if episode has progress, loop through episode array and assign value to matching episode
        if (ep.trackPosition.floatValue > 0.0f) {
            for (int i = 0; i < _episodeArray.count; i++) {
                NSMutableDictionary *episodeDict = [[NSDictionary dictionaryWithDictionary:[_episodeArray objectAtIndex:i]] mutableCopy];
                if ([ep.guid isEqualToString:[episodeDict objectForKey:@"guid"]]) {
                    //NSLog(@"set track position %f for %@", ep.trackPosition.floatValue, ep.title);
                    [episodeDict setObject:ep.trackPosition forKey:@"trackPosition"];
                    [_episodeArray replaceObjectsAtIndexes:[NSIndexSet indexSetWithIndex:i] withObjects:@[episodeDict]];
                    break;
                }
            }
        }
    }
}

// used for setting entity properties after new subscribe,
// and also marking new episodes as "seen" to reset badge.
-(void) markNewEpisodesAsSeen {
    
    SettingsEntity *settings = [TungCommonObjects settings];
    
    if (_episodeArray && _episodeArray.count) {
        NSNumber *numNew = _podcastEntity.numNewEpisodes;
        _podcastEntity.numNewEpisodes = [NSNumber numberWithInt:0];
        // in case mostRecentEpisodeDate was not set yet or new episode was published after bkgd fetch
        NSDate *mostRecentEpisodeDate = [[_episodeArray objectAtIndex:0] objectForKey:@"pubDate"];
        _podcastEntity.mostRecentEpisodeDate = mostRecentEpisodeDate;
        _podcastEntity.mostRecentSeenEpisodeDate = mostRecentEpisodeDate;
        NSInteger numPodcastNotifications = settings.numPodcastNotifications.integerValue - numNew.integerValue;
        if (numPodcastNotifications < 0) numPodcastNotifications = 0;
        settings.numPodcastNotifications = [NSNumber numberWithInteger:numPodcastNotifications];
        [_tung setBadgeNumber:settings.numPodcastNotifications forBadge:_tung.subscriptionsBadge];
        
        [TungCommonObjects saveContextWithReason:@"marking new episodes as \"seen\""];
    }
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:settings.numProfileNotifications.integerValue];
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

static NSDateFormatter *airDateFormatter = nil;
static NSString *cellIdentifier = @"EpisodeCell";

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    EpisodeCell *episodeCell = (EpisodeCell *)cell;
    
    // cell data
    NSDictionary *episodeDict = [NSDictionary dictionaryWithDictionary:[_episodeArray objectAtIndex:indexPath.row]];
    //NSLog(@"episode cell for row at index path, row: %ld", (long)indexPath.row);
    
    // title
    episodeCell.episodeTitle.text = [episodeDict objectForKey:@"title"];
    UIColor *keyColor = _podcastEntity.keyColor1;
    episodeCell.episodeTitle.textColor = keyColor;
    // air date
    if (!airDateFormatter) {
        airDateFormatter = [[NSDateFormatter alloc] init];
        [airDateFormatter setDateFormat:@"MMM d, yyyy"];
    }
    NSDate *pubDate = [episodeDict objectForKey:@"pubDate"];
    episodeCell.airDate.text = [airDateFormatter stringFromDate:pubDate];
    
    // now playing?
    episodeCell.iconView.backgroundColor = [UIColor clearColor];
    if (_tung.playQueue.count > 0) {
        NSString *urlString = [[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"url"];
        NSURL *playingUrl = [_tung.playQueue objectAtIndex:0];
        
        if ([urlString isEqualToString:playingUrl.absoluteString]) {
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
    episodeCell.episodeProgress.color = _podcastEntity.keyColor2;
    float position = 0;
    if ([episodeDict objectForKey:@"trackPosition"]) {
        NSNumber *nPosition = [episodeDict objectForKey:@"trackPosition"];
        position = nPosition.floatValue;
    }
    episodeCell.episodeProgress.progress = position;
    [episodeCell.episodeProgress setNeedsDisplay];
    
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
    if (section == 1) {
        return 60.0;
    }
    else {
        return 0;
    }
}

@end
