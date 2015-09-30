//
//  TungActivity.m
//  Tung
//
//  Created by Jamie Perkins on 6/22/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "TungStories.h"
#import "TungCommonObjects.h"
#import "FeedCell.h"

@implementation TungStories


- (id)init {
    
    self = [super init];
    if (self) {
        
        _tung = [TungCommonObjects establishTungObjects];
        
        _storiesArray = [NSMutableArray new];
        
    }
    return self;
}

- (void) configureFeedCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
    FeedCell *feedCell = (FeedCell *)cell;
    
    // cell data
    NSDictionary *storyDict = [NSDictionary dictionaryWithDictionary:[_storiesArray objectAtIndex:indexPath.row]];
    //NSLog(@"story cell for row at index path, row: %ld", (long)indexPath.row);
    

    
    // kill insets for iOS 8+
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 8) {
        feedCell.preservesSuperviewLayoutMargins = NO;
        [feedCell setLayoutMargins:UIEdgeInsetsZero];
    }
}

#pragma mark - Audio clips

-(void) stopClipPlayback {
    
}

- (void) resetActiveClipCellReference {
    
    // reset references to active progress bar and duration label
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_activeCellIndex inSection:_feedSection];
    UITableViewCell* tcell = [_tableView cellForRowAtIndexPath:indexPath];
    FeedCell *activeCell = (FeedCell *)tcell;
    //_activeProgressBar = activeCell.progressBar;
    //_activeDurationLabel = activeCell.durationLabel;
    NSLog(@"set active clip cell reference to row: %ld, and section: %ld", (long)_activeClipIndex, (long)_feedSection);
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
                        
                        if (newPosts.count == 0) _noResults = YES;
                        else _noResults = NO;
                        
                        _queryExecuted = YES;
                        // end refreshing
                        [self.refreshControl endRefreshing];
                        _tableView.backgroundView = nil;
                        
                        // pull refresh
                        if ([afterTime intValue] > 0) {
                            [self stopClipPlayback];
                            NSArray *newFeedArray = [newPosts arrayByAddingObjectsFromArray:_storiesArray];
                            _storiesArray = [newFeedArray mutableCopy];
                            NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
                            for (int i = 0; i < newPosts.count; i++) {
                                [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:_feedSection]];
                            }
                            if (newPosts.count > 0) {
                                // if new posts were retrieved
                                [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:_feedSection] atScrollPosition:UITableViewScrollPositionTop animated:YES];
                                
                                [_tableView beginUpdates];
                                [_tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationLeft];
                                [_tableView endUpdates];
                                [_tableView reloadData];
                            }
                        }
                        // auto-loaded posts as user scrolls down
                        else if ([beforeTime intValue] > 0) {
                            _requestingMore = NO;
                            _loadMoreIndicator.alpha = 0;
                            if (newPosts.count == 0) {
                                NSLog(@"no more clips to get");
                                _noMoreItemsToGet = YES;
                                // hide footer
                                //[_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_storiesArray.count-1 inSection:_feedSection] atScrollPosition:UITableViewScrollPositionMiddle animated:YES]; // causes crash on search page
                                _loadMoreIndicator.alpha = 0;
                                
                                [_tableView reloadData];
                            } else {
                                NSLog(@"\tgot posts older than: %@", beforeTime);
                                int startingIndex = (int)_storiesArray.count;
                                // NSLog(@"\tstarting index: %d", startingIndex);
                                NSArray *newFeedArray = [_storiesArray arrayByAddingObjectsFromArray:newPosts];
                                _storiesArray = [newFeedArray mutableCopy];
                                NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
                                for (int i = startingIndex; i < _storiesArray.count; i++) {
                                    [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:_feedSection]];
                                }
                                [_tableView beginUpdates];
                                [_tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationLeft];
                                [_tableView endUpdates];
                                
                                [_tableView reloadData];
                                
                                [self resetActiveClipCellReference];
                                
                            }
                        }
                        // initial request
                        else {
                            _storiesArray = [newPosts mutableCopy];
                            
                            [_tableView reloadData];
                        }
                        
                        NSLog(@"got posts. clipArray count: %lu", (unsigned long)[_storiesArray count]);
                        
                        // preload
                        [_tung preloadPodcastArtForArray:_storiesArray];
                        [self preloadAudioClipsAndAvatars];
                        
                    });
                }
            }
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
        // error
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

-(void) preloadAudioClipsAndAvatars {
    
    NSString *audioClipsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"audioClips"];
    NSString *avatarsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"avatars"];
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
