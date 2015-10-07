//
//  TungActivity.m
//  Tung
//
//  Created by Jamie Perkins on 6/22/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "TungStories.h"
#import "TungCommonObjects.h"
#import "StoryHeaderCell.h"
#import "StoryEventCell.h"
#import "StoryFooterCell.h"
#import "PodcastViewController.h"
#import "ProfileViewController.h"

@implementation TungStories

CGFloat headerViewHeight, headerScrollViewHeight, tableHeaderRow, animationDistance;

- (id)init {
    
    self = [super init];
    if (self) {
        
        _tung = [TungCommonObjects establishTungObjects];
        
        _storiesArray = [NSMutableArray new];
        
        _activeRowIndex = 0;
        _activeSectionIndex = 0;
        _selectedRowIndex = -1;
        _selectedSectionIndex = -1;
        
        self.requestStatus = @"";
        
        // feed table
        _feedTableViewController = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"feedTableViewController"];
        _feedTableViewController.tableView.delegate = self;
        _feedTableViewController.tableView.dataSource = self;
        _feedTableViewController.tableView.backgroundColor = _tung.bkgdGrayColor;
        _feedTableViewController.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
        _feedTableViewController.tableView.scrollsToTop = YES;
        _feedTableViewController.tableView.contentInset = UIEdgeInsetsMake(0, 0, -5, 0);
        _feedTableViewController.tableView.separatorInset = UIEdgeInsetsMake(0, 12, 0, 12);
        _feedTableViewController.tableView.separatorColor = [UIColor colorWithWhite:1 alpha:.7];
        // refresh control
        _feedTableViewController.refreshControl = [[UIRefreshControl alloc] init];
        [_feedTableViewController.refreshControl addTarget:self action:@selector(refreshFeed:) forControlEvents:UIControlEventValueChanged];
        // table bkgd
        UIActivityIndicatorView *tableSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        tableSpinner.alpha = 1;
        [tableSpinner startAnimating];
        _feedTableViewController.tableView.backgroundView = tableSpinner;
        
        // for animating header height
        CGFloat minHeaderHeight = 80;
        tableHeaderRow = 61;
        headerViewHeight = 223;
        headerScrollViewHeight = headerViewHeight - tableHeaderRow;
        animationDistance = headerScrollViewHeight - minHeaderHeight;
        
    }
    return self;
}

- (void) refreshFeed:(BOOL)fullRefresh {
    NSLog(@"refresh feed");
    
    NSNumber *mostRecent;
    if (fullRefresh) {
        mostRecent = [NSNumber numberWithInt:0];
    } else {
        if (_storiesArray.count > 0) {
            [_feedTableViewController.refreshControl beginRefreshing];
            mostRecent = [[[_storiesArray objectAtIndex:0] objectAtIndex:0] objectForKey:@"time_secs"];
        } else { // if initial request timed out and they are trying again
            mostRecent = [NSNumber numberWithInt:0];
        }
    }
    [self requestPostsNewerThan:mostRecent
                        orOlderThan:[NSNumber numberWithInt:0]
                           fromUser:_profiledUserId];
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

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //NSLog(@"selected cell at row %ld", (long)[indexPath row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row == 0) {
        // push podcast view
        NSDictionary *storyDict = [[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        NSDictionary *podcastDict = [NSDictionary dictionaryWithDictionary:[storyDict objectForKey:@"podcast"]];
        //NSLog(@"selected %@", [podcastDict objectForKey:@"collectionName"]);
        
        PodcastViewController *podcastView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"podcastView"];
        if ([podcastDict objectForKey:@"episode"]) {
            podcastView.focusedGUID = [[podcastDict objectForKey:@"episode"] objectForKey:@"guid"];
        }
        podcastView.podcastDict = [podcastDict mutableCopy];
        [_navController pushViewController:podcastView animated:YES];
    }
    else if (indexPath.row == [[_storiesArray objectAtIndex:indexPath.section] count] - 1) {
        // push story view
    }
    else {
        // if clip, play
        NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row]];
        if ([eventDict objectForKey:@"clip_url"]) {
            _selectedSectionIndex = indexPath.section;
            _selectedRowIndex = indexPath.row;
            [self playPause];
        }
    }
    
}

//- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
UILabel *prototypeLabel;
static CGFloat labelWidth = 0;

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
                labelWidth = _screenWidth -63 - 60;
            }
            prototypeLabel.text = [eventDict objectForKey:@"comment"];
            CGSize labelSize = [prototypeLabel sizeThatFits:CGSizeMake(labelWidth, 100)];
            CGFloat diff = labelSize.height - 18;
            return defaultEventCellHeight + diff;
        } else {
        	return defaultEventCellHeight;
        }
    }
}


-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    
    if (section == _storiesArray.count) {
        return 66.0;
    }
    else {
        return 1;
    }
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == _storiesArray.count) {
        if (_reachedEndOfPosts) {
            UILabel *noMoreLabel = [[UILabel alloc] init];
            noMoreLabel.text = @"That's everything.";
            noMoreLabel.textColor = [UIColor grayColor];
            noMoreLabel.textAlignment = NSTextAlignmentCenter;
            return noMoreLabel;
        } else {
            _loadMoreIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            return _loadMoreIndicator;
        }
    } else {
        UIView *separator = [UIView new];
        separator.backgroundColor = [UIColor whiteColor];
        return separator;
    }
}



NSString static *avatarsDir;
NSString static *audioClipsDir;
NSString static *podcastArtDir;

- (void) configureHeaderCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
    StoryHeaderCell *headerCell = (StoryHeaderCell *)cell;
    headerCell.clipsToBounds = YES;
    //NSLog(@"story header cell for row at index path, section: %ld", (long)indexPath.section);
    
    // cell data
    NSDictionary *storyDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:indexPath.row]];
    NSDictionary *podcastDict = [storyDict objectForKey:@"podcast"];
    NSDictionary *userDict = [storyDict objectForKey:@"user"];
    
    // color
    UIColor *keyColor = [TungCommonObjects colorFromHexString:[podcastDict objectForKey:@"keyColor1Hex"]];
    headerCell.backgroundColor = keyColor;
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [_tung darkenKeyColor:keyColor];
    [headerCell setSelectedBackgroundView:bgColorView];
    
    // user
    headerCell.usernameButton.tag = 101;
    [headerCell.usernameButton addTarget:self action:@selector(headerCellButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [headerCell.usernameButton setTitle:[userDict objectForKey:@"username"] forState:UIControlStateNormal];
    headerCell.avatarButton.tag = 101;
    [headerCell.avatarButton addTarget:self action:@selector(headerCellButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // avatar
    NSString *avatarFilename = [[userDict objectForKey:@"small_av_url"] lastPathComponent];
    NSString *avatarFilepath = [avatarsDir stringByAppendingPathComponent:avatarFilename];
    NSData *avatarImageData;
    // make sure it is cached, even though we preloaded it
    if ([[NSFileManager defaultManager] fileExistsAtPath:avatarFilepath]) {
        avatarImageData = [NSData dataWithContentsOfFile:avatarFilepath];
    } else {
        avatarImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString: [userDict objectForKey:@"small_av_url"]]];
        [avatarImageData writeToFile:avatarFilepath atomically:YES];
    }
    headerCell.avatarContainerView.backgroundColor = [UIColor clearColor];
    headerCell.avatarContainerView.avatar = nil;
    headerCell.avatarContainerView.avatar = [[UIImage alloc] initWithData:avatarImageData];
    headerCell.avatarContainerView.borderColor = [UIColor whiteColor];
    [headerCell.avatarContainerView setNeedsDisplay];
    
    // album art
    NSString *artUrlString = [podcastDict objectForKey:@"artworkUrl600"];
    NSData *artImageData = [TungCommonObjects retrievePodcastArtDataWithUrlString:artUrlString];
    UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
    headerCell.albumArt.image = artImage;
    
	// title
    NSString *title;
    if ([podcastDict objectForKey:@"episode"]) {
        title = [[podcastDict objectForKey:@"episode"] objectForKey:@"title"];
    } else {
        title = [podcastDict objectForKey:@"collectionName"];
    }
    headerCell.title.text = title;
    headerCell.title.font = [UIFont systemFontOfSize:21 weight:UIFontWeightLight];
    if (title.length > 42) {
        headerCell.title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightLight];
    }
    if (title.length > 62) {
        headerCell.title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightLight];
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
    
    // color
    UIColor *keyColor = (UIColor *)[eventDict objectForKey:@"keyColor"];
    eventCell.backgroundColor = keyColor;
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [_tung darkenKeyColor:keyColor];
    [eventCell setSelectedBackgroundView:bgColorView];
    
    // event
    NSString *type = [eventDict objectForKey:@"type"];
    if ([type isEqualToString:@"recommended"]) {
        eventCell.iconView.type = kIconTypeRecommend;
        eventCell.simpleEventLabel.hidden = NO;
        eventCell.simpleEventLabel.text = @"Recommended this episode";
        eventCell.eventDetailLabel.hidden = YES;
        eventCell.commentLabel.hidden = YES;
        eventCell.clipProgress.hidden = YES;
    }
    else if ([type isEqualToString:@"subscribed"]) {
        eventCell.iconView.type = kIconTypeSubscribe;
        eventCell.simpleEventLabel.hidden = NO;
        eventCell.simpleEventLabel.text = @"Subscribed to this podcast";
        eventCell.eventDetailLabel.hidden = YES;
        eventCell.commentLabel.hidden = YES;
        eventCell.clipProgress.hidden = YES;
    }
    else if ([type isEqualToString:@"comment"]) {
        eventCell.iconView.type = kIconTypeComment;
        eventCell.simpleEventLabel.hidden = YES;
        eventCell.eventDetailLabel.text = [eventDict objectForKey:@"timestamp"];
        eventCell.eventDetailLabel.hidden = NO;
        eventCell.commentLabel.text = [eventDict objectForKey:@"comment"];
        eventCell.commentLabel.hidden = NO;
        eventCell.clipProgress.hidden = YES;
    }
    else if ([type isEqualToString:@"clip"]) {
        eventCell.iconView.type = kIconTypeClip;
        if ([[eventDict objectForKey:@"comment"] length] > 0) {
            eventCell.simpleEventLabel.hidden = YES;
            eventCell.eventDetailLabel.text = [NSString stringWithFormat:@"%@ - tap to play", [eventDict objectForKey:@"timestamp"]];
            eventCell.eventDetailLabel.hidden = NO;
            eventCell.commentLabel.text = [eventDict objectForKey:@"comment"];
            eventCell.commentLabel.hidden = NO;
        } else {
            eventCell.simpleEventLabel.hidden = NO;
            eventCell.simpleEventLabel.text = [NSString stringWithFormat:@"Shared a clip @ %@ - tap to play", [eventDict objectForKey:@"timestamp"]];
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
    
    // view all
    NSNumber *moreEvents = [footerDict objectForKey:@"moreEvents"];
    footerCell.viewAllLabel.hidden = YES;
    if (moreEvents.boolValue) {
        footerCell.viewAllLabel.hidden = NO;
    }
    
    // options button
    footerCell.optionsButton.type = kIconButtonTypeOptions;
    footerCell.optionsButton.color = [UIColor whiteColor];
    
    // color
    UIColor *keyColor = (UIColor *)[footerDict objectForKey:@"keyColor"];
    footerCell.backgroundColor = keyColor;
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [_tung darkenKeyColor:keyColor];
    [footerCell setSelectedBackgroundView:bgColorView];
    
    // separator
    footerCell.preservesSuperviewLayoutMargins = NO;
    [footerCell setLayoutMargins:UIEdgeInsetsZero];
}

#pragma mark - Feed cell controls

-(void) headerCellButtonTapped:(id)sender {
    long tag = [sender tag];
    
    if (tag == 101) {
        StoryHeaderCell *cell = (StoryHeaderCell *)[[sender superview] superview];
        NSIndexPath *indexPath = [_feedTableViewController.tableView indexPathForCell:cell];
        NSDictionary *storyDict = [[_storiesArray objectAtIndex:indexPath.section] objectAtIndex:0];
        NSString *userId = [[storyDict objectForKey:@"user"] objectForKey:@"id"];
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
        if ([_clipPlayer isPlaying]) {
            [self pauseClipPlayback];
        } else {
            [self playbackClip];
        }
    }
    // different clip selected than the one playing
    else {
        [self stopClipPlayback];
        _clipPlayer = nil;
    }
    // start playing new clip
    if (_clipPlayer == nil) {
        
        // check for cached audio data and init player
        NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:_selectedSectionIndex] objectAtIndex:_selectedRowIndex]];
        NSString *clipURLString = [eventDict objectForKey:@"clip_url"];
        NSString *clipFilename = [clipURLString lastPathComponent];
        NSString *clipFilepath = [audioClipsDir stringByAppendingPathComponent:clipFilename];
        NSData *clipData;
        if ([[NSFileManager defaultManager] fileExistsAtPath:clipFilepath]) {
            clipData = [[NSData alloc] initWithContentsOfFile:clipFilepath];
        } else {
            clipData = [[NSData alloc] initWithContentsOfURL: [NSURL URLWithString:clipURLString]];
            [clipData writeToFile:clipFilepath atomically:YES];
        }
        NSError *playbackError;
        _clipPlayer = [[AVAudioPlayer alloc] initWithData:clipData error:&playbackError];
        
        // play
        if (_clipPlayer != nil) {
            _clipPlayer.delegate = self;
            // PLAY
            [self playbackClip];
            
        } else {
            NSLog(@"failed to create audio player: %@", playbackError);
        }
        
    }
}

- (void) playbackClip {
    
    [_tung playerPause];
    
    [_clipPlayer prepareToPlay];
    [_clipPlayer play]; // play on, player
    
    _activeSectionIndex = _selectedSectionIndex;
    _activeRowIndex = _selectedRowIndex;
    
    [self setActiveClipCellReference];
    
    // begin "onEnterFrame"
    _onEnterFrame = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateView)];
    [_onEnterFrame addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void) stopClipPlayback {
    NSLog(@"stop");
    // stop "onEnterFrame"
    [_onEnterFrame invalidate];
    //NSLog(@"%@",[NSThread callStackSymbols]);
    if ([_clipPlayer isPlaying]) {
        
        [_clipPlayer stop];
        [_clipPlayer setCurrentTime:0];
    }
    
    // reset GUI
    NSDictionary *eventDict = [NSDictionary dictionaryWithDictionary:[[_storiesArray objectAtIndex:_activeSectionIndex] objectAtIndex:_activeRowIndex]];
    
    _activeClipProgressView.seconds = [NSString stringWithFormat:@":%@", [eventDict objectForKey:@"duration"]];
    _activeClipProgressView.arc = 0.0f;
    [_activeClipProgressView setNeedsDisplay];

}

- (void) pauseClipPlayback {

    if ([_clipPlayer isPlaying]) [_clipPlayer pause];
    // stop "onEnterFrame"
    [_onEnterFrame invalidate];
    
}

- (void) updateView {
    float progress = _clipPlayer.currentTime / _clipPlayer.duration;
    float arc = 360 - (360 * progress);
    _activeClipProgressView.arc = arc;
    _activeClipProgressView.seconds = [NSString stringWithFormat:@":%02ld", lroundf(_clipPlayer.duration - _clipPlayer.currentTime)];
    [_activeClipProgressView setNeedsDisplay];
}

- (void) setActiveClipCellReference {

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_activeRowIndex inSection:_activeSectionIndex];
    UITableViewCell *cell = [_feedTableViewController.tableView cellForRowAtIndexPath:indexPath];
    StoryEventCell *activeCell = (StoryEventCell *)cell;
    _activeClipProgressView = activeCell.clipProgress;

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

#pragma mark - Requests

// feed request
-(void) requestPostsNewerThan:(NSNumber *)afterTime
                  orOlderThan:(NSNumber *)beforeTime
                     fromUser:(NSString *)user_id {
    NSLog(@"feed request for posts newer than: %@, or older than: %@, from user: %@", afterTime, beforeTime, user_id);
    self.requestStatus = @"initiated";

    NSURL *feedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/feed.php", _tung.apiRootUrl]];
    NSMutableURLRequest *feedRequest = [NSMutableURLRequest requestWithURL:feedURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [feedRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{
                             @"sessionId": _tung.sessionId,
                             @"newerThan": afterTime,
                             @"olderThan": beforeTime,
                             @"profiled_user_id": user_id
                             };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [feedRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:feedRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            //NSLog(@"got response: %@", jsonData);
            if (jsonData != nil && error == nil) {
                if ([jsonData isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                                // get new session and re-request
                                NSLog(@"SESSION EXPIRED");
                                [_tung getSessionWithCallback:^{
                                    [self requestPostsNewerThan:afterTime orOlderThan:beforeTime fromUser:user_id];
                                }];
                            } else {
                                self.requestStatus = @"finished";
                                // other error - alert user
                                UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:[responseDict objectForKey:@"error"] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                                [errorAlert show];
                            }
                        });
                    }
                }
                else if ([jsonData isKindOfClass:[NSArray class]]) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        NSArray *newStories = jsonData;
                        NSLog(@"new posts count: %lu", (unsigned long)newStories.count);
                        
                        // end refreshing
                        _feedTableViewController.tableView.backgroundView = nil;
                        [_feedTableViewController.refreshControl endRefreshing];
                            
                        // pull refresh
                        if ([afterTime intValue] > 0) {
                            if (newStories.count > 0) {
                                NSLog(@"\tgot posts newer than: %@", afterTime);
                                [self stopClipPlayback];
                                NSArray *newItems = [self processStories:newStories];
                                NSArray *newFeedArray = [newItems arrayByAddingObjectsFromArray:_storiesArray];
                                _storiesArray = [newFeedArray mutableCopy];
                                
                                [UIView setAnimationsEnabled:NO];
                                [_feedTableViewController.tableView beginUpdates];
                                for (NSInteger i = 0; i < newStories.count; i++) {
                                    [_feedTableViewController.tableView insertSections:[NSIndexSet indexSetWithIndex:i] withRowAnimation:UITableViewRowAnimationNone];
                                }
                                [_feedTableViewController.tableView endUpdates];
                                [UIView setAnimationsEnabled:YES];
                                
                                [_feedTableViewController.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
                            }
                        }
                        // auto-loaded posts as user scrolls down
                        else if ([beforeTime intValue] > 0) {
                            
                            _requestingMore = NO;
                            _loadMoreIndicator.alpha = 0;
                            
                            if (newStories.count == 0) {
                                NSLog(@"no more posts to get");
                                _reachedEndOfPosts = YES;
                                // hide footer
                                //[_feedTableViewController.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_storiesArray.count-1 inSection:_feedSection] atScrollPosition:UITableViewScrollPositionMiddle animated:YES]; // causes crash on search page
                                [_feedTableViewController.tableView reloadData];
                                
                            } else {
                                NSLog(@"\tgot posts older than: %@", beforeTime);
                                int startingIndex = (int)_storiesArray.count;
                                
                                NSArray *newFeedArray = [_storiesArray arrayByAddingObjectsFromArray:[self processStories:newStories]];
                                _storiesArray = [newFeedArray mutableCopy];
                                newFeedArray = nil;
                                
                                [UIView setAnimationsEnabled:NO];
                                [_feedTableViewController.tableView beginUpdates];
                                for (int i = startingIndex-1; i < _storiesArray.count-1; i++) {
                                    [_feedTableViewController.tableView insertSections:[NSIndexSet indexSetWithIndex:i] withRowAnimation:UITableViewRowAnimationNone];
                                }
                                [_feedTableViewController.tableView endUpdates];
                                [UIView setAnimationsEnabled:YES];
                                
                                
                            }
                        }
                        // initial request
                        else {
                            _storiesArray = [self processStories:newStories];
                            NSLog(@"got posts. storiesArray count: %lu", (unsigned long)[_storiesArray count]);
                            [_feedTableViewController.tableView reloadData];
                        }
                        
                        // feed is now refreshed
                        self.requestStatus = @"finished";
                        _tung.feedNeedsRefresh = [NSNumber numberWithBool:NO];
                        
                    });
                }
            }
            // errors
            else if ([data length] == 0 && error == nil) {
                NSLog(@"no response");
                dispatch_async(dispatch_get_main_queue(), ^{
                    _requestingMore = NO;
                    self.requestStatus = @"finished";
                    _loadMoreIndicator.alpha = 0;
                    [_feedTableViewController.refreshControl endRefreshing];
                });
            }
            else if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    _requestingMore = NO;
                    self.requestStatus = @"finished";
                    _loadMoreIndicator.alpha = 0;
                    [_feedTableViewController.refreshControl endRefreshing];
                });
                NSLog(@"Error: %@", error);
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"HTML: %@", html);
            }
        }
        // connection error
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                _requestingMore = NO;
                [_feedTableViewController.refreshControl endRefreshing];
                _loadMoreIndicator.alpha = 0;
                // end refreshing
                self.requestStatus = @"finished";
                _feedTableViewController.tableView.backgroundView = nil;
                
                UIAlertView *connectionErrorAlert = [[UIAlertView alloc] initWithTitle:@"Connection error" message:[error localizedDescription] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                _feedTableViewController.tableView.backgroundView = nil;
                [connectionErrorAlert show];
            });
        }
    }];
}

// break events apart from story and into their own array items in _storiesArray,
// while we're at it, preload avatars, album art and clips.
- (NSMutableArray *) processStories:(NSArray *)stories {
    
    // for preloading
    if (!audioClipsDir) {
        audioClipsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"audioClips"];
        avatarsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"avatars"];
        podcastArtDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"podcastArt"];
    }
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:audioClipsDir withIntermediateDirectories:YES attributes:nil error:&error];
    [[NSFileManager defaultManager] createDirectoryAtPath:avatarsDir withIntermediateDirectories:YES attributes:nil error:&error];
    [[NSFileManager defaultManager] createDirectoryAtPath:podcastArtDir withIntermediateDirectories:YES attributes:nil error:&error];
    
    NSOperationQueue *preloadQueue = [[NSOperationQueue alloc] init];
    preloadQueue.maxConcurrentOperationCount = 3;
    
    // process stories
    NSMutableArray *results = [NSMutableArray new];
    for (int i = 0; i < stories.count; i++) {

        NSMutableArray *storyArray = [NSMutableArray new];
        NSMutableDictionary *dict = [[stories objectAtIndex:i] mutableCopy];
        UIColor *keyColor = [TungCommonObjects colorFromHexString:[[dict objectForKey:@"podcast"] objectForKey:@"keyColor1Hex"]];
        NSArray *events = [dict objectForKey:@"events"];
        [storyArray addObject:dict];
        
        // preload avatar and album art
        [preloadQueue addOperationWithBlock:^{
            // avatar
            NSString *avatarURLString = [[dict objectForKey:@"user"] objectForKey:@"small_av_url"];
            NSString *avatarFilename = [avatarURLString lastPathComponent];
            NSString *avatarFilepath = [avatarsDir stringByAppendingPathComponent:avatarFilename];
            if (![[NSFileManager defaultManager] fileExistsAtPath:avatarFilepath]) {
                NSData *avatarImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:avatarURLString]];
                [avatarImageData writeToFile:avatarFilepath atomically:YES];
            }
            // album art
            NSString *artURLString = [[dict objectForKey:@"podcast"] objectForKey:@"artworkUrl600"];
            NSString *artFilename = [TungCommonObjects getAlbumArtFilenameFromUrlString:artURLString];
            NSString *artFilepath = [podcastArtDir stringByAppendingPathComponent:artFilename];
            if (![[NSFileManager defaultManager] fileExistsAtPath:artFilepath]) {
                NSData *artImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:artURLString]];
                [artImageData writeToFile:artFilepath atomically:YES];
            }
        }];
        
        for (int e = 0; e < events.count; e++) {
            
            NSMutableDictionary *eventDict = [[events objectAtIndex:e] mutableCopy];
            [eventDict setObject:keyColor forKey:@"keyColor"];
            // preload clip
            if ([[eventDict objectForKey:@"type"] isEqualToString:@"clip"]) {
                [preloadQueue addOperationWithBlock:^{
                    NSString *clipURLString = [eventDict objectForKey:@"clip_url"];
                    NSString *clipFilename = [clipURLString lastPathComponent];
                    NSString *clipFilepath = [audioClipsDir stringByAppendingPathComponent:clipFilename];
                    if (![[NSFileManager defaultManager] fileExistsAtPath:clipFilepath]) {
                        NSData *clipData = [NSData dataWithContentsOfURL:[NSURL URLWithString:clipURLString]];
                        [clipData writeToFile:clipFilepath atomically:YES];
                    }
                }];
            }
            if (e < 5) {
                [storyArray addObject:eventDict];
            } else {
                break;
            }
        }
        [dict removeObjectForKey:@"events"];
        NSNumber *moreEvents = [NSNumber numberWithBool:events.count > 5];
        NSDictionary *footerDict = [NSDictionary dictionaryWithObjects:@[
                                                                         [dict objectForKey:@"shortlink"],
                                                                         keyColor,
                                                                         moreEvents]
                                                               forKeys:@[@"shortlink",
                                                                         @"keyColor",
                                                                         @"moreEvents"]];
        [storyArray addObject:footerDict];
        [results addObject:storyArray];

    }
    return results;
}

#pragma mark - scroll view delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == _feedTableViewController.tableView) {
        // shrink header
        if (_profiledUserId.length > 0 && scrollView.contentOffset.y > 0 && scrollView.contentOffset.y <= animationDistance) {
            //NSLog(@"table offset: %f", scrollView.contentOffset.y);
            _profileHeaderHeight.constant = headerViewHeight - scrollView.contentOffset.y;
            _profileHeader.scrollSubView1Height.constant = headerScrollViewHeight - scrollView.contentOffset.y;
            _profileHeader.scrollSubView2Height.constant = headerScrollViewHeight - scrollView.contentOffset.y;
            
            [_profileHeader layoutIfNeeded];
        }
        // detect when user hits bottom of feed
        float bottomOffset = scrollView.contentSize.height - scrollView.frame.size.height;
        if (scrollView.contentOffset.y >= bottomOffset) {
            // request more posts if they didn't reach the end
            if (!_requestingMore && !_reachedEndOfPosts && _storiesArray.count > 0) {
                _requestingMore = YES;
                _loadMoreIndicator.alpha = 1;
                [_loadMoreIndicator startAnimating];
                NSNumber *oldest = [[[_storiesArray objectAtIndex:_storiesArray.count-1] objectAtIndex:0] objectForKey:@"time_secs"];
                
                [self requestPostsNewerThan:[NSNumber numberWithInt:0]
                                    orOlderThan:oldest
                                       fromUser:@""];
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
    // set scroll view content size for height
    CGFloat scrollViewHeight = _profileHeaderHeight.constant - tableHeaderRow;
//    NSLog(@"scroll view height: %f", scrollViewHeight);
//    NSLog(@"scroll view content size: %@", NSStringFromCGSize(_profileHeader.scrollView.contentSize));
    CGSize contentSize = CGSizeMake(_screenWidth * 2, scrollViewHeight);
    _profileHeader.scrollView.contentSize = contentSize;
//    NSLog(@"scroll view NEW content size: %@", NSStringFromCGSize(contentSize));
}


@end
