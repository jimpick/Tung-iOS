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

@implementation TungStories


- (id)init {
    
    self = [super init];
    if (self) {
        
        _tung = [TungCommonObjects establishTungObjects];
        
        _storiesArray = [NSMutableArray new];
        
        _activeCellIndex = 0;
        _activeClipIndex = 0;
        
    }
    return self;
}

NSString static *avatarsDir;
NSString static *audioClipsDir;

- (void) configureHeaderCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
    StoryHeaderCell *headerCell = (StoryHeaderCell *)cell;
    //NSLog(@"story cell for row at index path, row: %ld", (long)indexPath.row);
    
    // cell data
    NSDictionary *storyDict = [NSDictionary dictionaryWithDictionary:[_storiesArray objectAtIndex:indexPath.row]];
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

    // kill insets for iOS 8+
    /*
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 8) {
        headerCell.preservesSuperviewLayoutMargins = NO;
        [headerCell setLayoutMargins:UIEdgeInsetsZero];
    }
     */
}

- (void) configureEventCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
    StoryEventCell *eventCell = (StoryEventCell *)cell;
    
    NSDictionary *eventDict = [_storiesArray objectAtIndex:indexPath.row];
    
    // color
    UIColor *keyColor = (UIColor *)[eventDict objectForKey:@"keyColor"];
    eventCell.backgroundColor = keyColor;
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [_tung darkenKeyColor:keyColor];
    [eventCell setSelectedBackgroundView:bgColorView];
    
    // event
    NSString *type = [eventDict objectForKey:@"type"];
    NSString *eventLabelText;
    if ([type isEqualToString:@"recommended"]) {
        eventCell.iconView.type = kIconTypeRecommend;
        eventLabelText = @"Recommended this episode";
    }
    else if ([type isEqualToString:@"subscribed"]) {
        eventCell.iconView.type = kIconTypeSubscribe;
        eventLabelText = @"Subscribed to this podcast";
    }
    else if ([type isEqualToString:@"comment"]) {
        eventCell.iconView.type = kIconTypeComment;
        eventLabelText = [NSString stringWithFormat:@"Commented @ %@", [eventDict objectForKey:@"timestamp"]];
    }
    else if ([type isEqualToString:@"clip"]) {
        eventCell.iconView.type = kIconTypeClip;
        eventLabelText = [NSString stringWithFormat:@"Shared a clip @ %@ (tap to play)", [eventDict objectForKey:@"timestamp"]];
    }
    eventCell.eventLabel.text = eventLabelText;
    eventCell.iconView.color = [UIColor whiteColor];
    eventCell.iconView.backgroundColor = [UIColor clearColor];
    [eventCell.iconView setNeedsDisplay];
    
}

- (void) configureFooterCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
    StoryFooterCell *footerCell = (StoryFooterCell *)cell;
    
    NSDictionary *footerDict = [_storiesArray objectAtIndex:indexPath.row];
    
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
    
    // kill insets for iOS 8+
    footerCell.preservesSuperviewLayoutMargins = NO;
    [footerCell setLayoutMargins:UIEdgeInsetsZero];
}

#pragma mark - Feed cell controls

-(void) headerCellButtonTapped:(id)sender {
    
}

#pragma mark - Audio clips

-(void) stopClipPlayback {
    
}

- (void) resetActiveheaderCellReference {
    
    // reset references to active progress bar and duration label
    /*
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_activeCellIndex inSection:_feedSection];
    UITableViewCell* tcell = [_tableView cellForRowAtIndexPath:indexPath];
    StoryEventCell *activeCell = ( StoryEventCell  *)tcell;
    _activeProgressBar = activeCell.progressBar;
    _activeDurationLabel = activeCell.durationLabel;
    NSLog(@"set active clip cell reference to row: %ld, and section: %ld", (long)_activeClipIndex, (long)_feedSection);
    */
}

#pragma mark - Requests

// feed request
-(void) requestPostsNewerThan:(NSNumber *)afterTime
                  orOlderThan:(NSNumber *)beforeTime
                     fromUser:(NSString *)user_id {
    NSLog(@"feed request for posts newer than: %@, or older than: %@, from user: %@", afterTime, beforeTime, user_id);
    _noResults = NO;
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
                                [self.refreshControl endRefreshing];
                                // other error - alert user
                                UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:[responseDict objectForKey:@"error"] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                                [errorAlert show];
                            }
                        });
                    }
                }
                else if ([jsonData isKindOfClass:[NSArray class]]) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        NSArray *newPosts = jsonData;
                        NSLog(@"new posts count: %lu", (unsigned long)newPosts.count);
                        
                        if (newPosts.count == 0) _noResults = YES;
                        else _noResults = NO;
                        
                        _queryExecuted = YES;
                        // end refreshing
                        [_refreshControl endRefreshing];
                        _tableView.backgroundView = nil;
                        
                        // pull refresh
                        if ([afterTime intValue] > 0 && newPosts.count > 0) {
                            NSLog(@"\tgot posts newer than: %@", afterTime);
                            [self stopClipPlayback];
                            NSArray *newItems = [self processStories:newPosts];
                            NSArray *newFeedArray = [newItems arrayByAddingObjectsFromArray:_storiesArray];
                            _storiesArray = [newFeedArray mutableCopy];
                            newFeedArray = nil;
                            NSMutableArray *newIndexPaths = [[NSMutableArray alloc] init];
                            for (int i = 0; i < newItems.count; i++) {
                                [newIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:_feedSection]];
                            }
                            // if new posts were retrieved
                            [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:_feedSection] atScrollPosition:UITableViewScrollPositionTop animated:YES];
                            
                            [_tableView beginUpdates];
                            [_tableView insertRowsAtIndexPaths:newIndexPaths withRowAnimation:UITableViewRowAnimationLeft];
                            [_tableView endUpdates];
                            [_tableView reloadData];
                            
                            [self resetActiveheaderCellReference];
                        }
                        // auto-loaded posts as user scrolls down
                        else if ([beforeTime intValue] > 0) {
                            
                            _requestingMore = NO;
                            _loadMoreIndicator.alpha = 0;
                            
                            if (newPosts.count == 0) {
                                NSLog(@"no more posts to get");
                                _noMoreItemsToGet = YES;
                                // hide footer
                                //[_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_storiesArray.count-1 inSection:_feedSection] atScrollPosition:UITableViewScrollPositionMiddle animated:YES]; // causes crash on search page
                                _loadMoreIndicator.alpha = 0;
                                [_tableView reloadData];
                                
                            } else {
                                NSLog(@"\tgot posts older than: %@", beforeTime);
                                int startingIndex = (int)_storiesArray.count;
                                // NSLog(@"\tstarting index: %d", startingIndex);
                                NSArray *newFeedArray = [_storiesArray arrayByAddingObjectsFromArray:[self processStories:newPosts]];
                                _storiesArray = [newFeedArray mutableCopy];
                                newFeedArray = nil;
                                NSMutableArray *newIndexPaths = [[NSMutableArray alloc] init];
                                for (int i = startingIndex; i < _storiesArray.count; i++) {
                                    [newIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:_feedSection]];
                                }
                                [_tableView beginUpdates];
                                [_tableView insertRowsAtIndexPaths:newIndexPaths withRowAnimation:UITableViewRowAnimationLeft];
                                [_tableView endUpdates];
                                [_tableView reloadData];
                                
                                [self resetActiveheaderCellReference];
                                
                            }
                        }
                        // initial request
                        else {
                            _storiesArray = [self processStories:newPosts];
                            NSLog(@"got posts. storiesArray count: %lu", (unsigned long)[_storiesArray count]);
                            [_tableView reloadData];
                        }
                        // feed is now refreshed
                        _tung.feedNeedsRefresh = [NSNumber numberWithBool:NO];
                        
                        // preload
                        [_tung preloadPodcastArtForArray:_storiesArray];
                        [self preloadAudioClipsAndAvatars];
                        
                    });
                }
            }
            // errors
            else if ([data length] == 0 && error == nil) {
                NSLog(@"no response");
                _requestingMore = NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    _loadMoreIndicator.alpha = 0;
                });
            }
            else if (error != nil) {
                _requestingMore = NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    _loadMoreIndicator.alpha = 0;
                });
                NSLog(@"Error: %@", error);
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"HTML: %@", html);
            }
        }
        // connection error
        else {
            _requestingMore = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                _loadMoreIndicator.alpha = 0;
                // end refreshing
                [self.refreshControl endRefreshing];
                _tableView.backgroundView = nil;
                
                UIAlertView *connectionErrorAlert = [[UIAlertView alloc] initWithTitle:@"Connection error" message:[error localizedDescription] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                self.tableView.backgroundView = nil;
                [connectionErrorAlert show];
            });
        }
    }];
}

// break events apart from story and into their own array items in _storiesArray
- (NSMutableArray *) processStories:(NSArray *)stories {
    
    NSMutableArray *results = [NSMutableArray new];
    for (int i = 0; i < stories.count; i++) {
        
        NSMutableDictionary *dict = [[stories objectAtIndex:i] mutableCopy];
        UIColor *keyColor = [TungCommonObjects colorFromHexString:[[dict objectForKey:@"podcast"] objectForKey:@"keyColor1Hex"]];
        NSArray *events = [dict objectForKey:@"events"];
        [results addObject:dict];
        for (int e = 0; e < events.count; e++) {
            
            NSMutableDictionary *eventDict = [[events objectAtIndex:e] mutableCopy];
            [eventDict setObject:keyColor forKey:@"keyColor"];
            if (e < 5) {
                [results addObject:eventDict];
            } else {
                break;
            }
        }
        [dict removeObjectForKey:@"events"];
        NSNumber *moreEvents = [NSNumber numberWithBool:events.count > 5];
        NSDictionary *footerDict = [NSDictionary dictionaryWithObjects:@[
                                                                         [dict objectForKey:@"shortlink"],
                                                                         keyColor,
                                                                         moreEvents,
                                                                         [dict objectForKey:@"time_secs"]]
                                                               forKeys:@[@"shortlink",
                                                                         @"keyColor",
                                                                         @"moreEvents",
                                                                         @"time_secs"]];
        [results addObject:footerDict];

    }
    return results;
}

-(void) preloadAudioClipsAndAvatars {
    
    if (!audioClipsDir) {
        audioClipsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"audioClips"];
        avatarsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"avatars"];
    }
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:audioClipsDir withIntermediateDirectories:YES attributes:nil error:&error];
    [[NSFileManager defaultManager] createDirectoryAtPath:avatarsDir withIntermediateDirectories:YES attributes:nil error:&error];
        
    NSArray *itemArrayCopy = [_storiesArray copy];
    
    NSOperationQueue *preloadQueue = [[NSOperationQueue alloc] init];
    preloadQueue.maxConcurrentOperationCount = 3;
    
    for (int i = 0; i < itemArrayCopy.count; i++) {
        
        // avatar
        [preloadQueue addOperationWithBlock:^{
            NSString *avatarURLString = [[[itemArrayCopy objectAtIndex:i] objectForKey:@"user"] objectForKey:@"small_av_url"];
            NSString *avatarFilename = [avatarURLString lastPathComponent];
            NSString *avatarFilepath = [avatarsDir stringByAppendingPathComponent:avatarFilename];
            if (![[NSFileManager defaultManager] fileExistsAtPath:avatarFilepath]) {
                NSData *avatarImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:avatarURLString]];
                [avatarImageData writeToFile:avatarFilepath atomically:YES];
            }
        }];
        
        // clip(s)
        NSArray *events = [[itemArrayCopy objectAtIndex:i] objectForKey:@"events"];
        for (int j = 0; j < events.count; j++) {
            
            if ([[[events objectAtIndex:j] objectForKey:@"type"] isEqualToString:@"clip"]) {
                [preloadQueue addOperationWithBlock:^{
                    
                    NSString *clipURLString = [[events objectAtIndex:j] objectForKey:@"clip_url"];
                    NSString *clipFilename = [clipURLString lastPathComponent];
                    NSString *clipFilepath = [audioClipsDir stringByAppendingPathComponent:clipFilename];
                    if (![[NSFileManager defaultManager] fileExistsAtPath:clipFilepath]) {
                        NSData *clipData = [NSData dataWithContentsOfURL:[NSURL URLWithString:clipURLString]];
                        [clipData writeToFile:clipFilepath atomically:YES];
                    }
                }];
            }
        }
    }
}


@end
