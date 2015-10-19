//
//  PodcastTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 7/27/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "CommentsTableViewController.h"

@interface CommentsTableViewController ()


@property (nonatomic, retain) TungCommonObjects *tung;

@end

@implementation CommentsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    
    // set up table
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.scrollsToTop = YES;
    self.tableView.separatorInset = UIEdgeInsetsZero;
    self.tableView.contentInset = UIEdgeInsetsZero;// UIEdgeInsetsMake(0, 0, 0, 0);
    self.tableView.separatorColor = [UIColor whiteColor];
    
    UIActivityIndicatorView *tableSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    tableSpinner.alpha = 1;
    [tableSpinner startAnimating];
    self.tableView.backgroundView = tableSpinner;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return _commentsArray.count;
    } else {
        return 0;
    }
}

static NSDateFormatter *airDateFormatter = nil;
static NSString *cellIdentifier = @"CommentCell";

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    CommentCell *commentCell = (CommentCell *)cell;
    
    NSDictionary *commentDict = [NSDictionary dictionaryWithDictionary:[_commentsArray objectAtIndex:indexPath.row]];
    
    commentCell.commentLabel.text = [commentDict objectForKey:@"comment"];
    
    NSString *idString = [[commentDict objectForKey:@"_id"] objectForKey:@"$id"];
    
    if ([idString isEqualToString:_tung.tungId]) {
    	// mine
    	commentCell.usernameLabel.text = @"";
        commentCell.accessoryType = UITableViewCellAccessoryNone;
    }
    else {
        // theirs
        commentCell.usernameLabel.text = [[commentDict objectForKey:@"user"] objectForKey:@"username"];
        commentCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return commentCell;
}

#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //NSLog(@"%@", [_commentsArray objectAtIndex:indexPath.row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    /*
    // play episode selected
    NSDictionary *episodeDict = [_commentsArray objectAtIndex:indexPath.row];
    //NSLog(@"selected episode: %@", episodeDict);
    //NSLog(@"podcast dict: %@", _podcastDict);
    NSString *urlString = [[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"url"];
    if (urlString) {
        [TungCommonObjects getEntityForPodcast:_podcastDict andEpisode:episodeDict save:YES];
        
        // set now playing feed and podcast dict
        [_tung assignCurrentFeed:_commentsArray];
        _tung.npPodcastDict = _podcastDict;
        
        [_tung queueAndPlaySelectedEpisode:urlString];
    } else {
        
        UIAlertView *badXmlAlert = [[UIAlertView alloc] initWithTitle:@"Can't Play - No URL" message:@"Unfortunately, this feed is missing links to its content." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [badXmlAlert show];
    }
    */
}

//- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath

UILabel *prototypeLabel;
static CGFloat labelWidth;
static double screenWidth;

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    CGFloat defaultEventCellHeight = 40;
    NSDictionary *commentDict = [NSDictionary dictionaryWithDictionary:[_commentsArray objectAtIndex:indexPath.row]];
    if (!prototypeLabel) {
        prototypeLabel = [[UILabel alloc] init];
        prototypeLabel.font = [UIFont systemFontOfSize:15];
        prototypeLabel.numberOfLines = 0;
    }
    if (!screenWidth) screenWidth = [[UIScreen mainScreen]bounds].size.width;
    if (!labelWidth) { labelWidth = screenWidth -110 - 4; }// right margin, left margin

    prototypeLabel.text = [commentDict objectForKey:@"comment"];
    CGSize labelSize = [prototypeLabel sizeThatFits:CGSizeMake(labelWidth, 400)];
    CGFloat diff = labelSize.height - 18; // 18 = single-line label height
    return defaultEventCellHeight + diff;
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (_commentsArray.count > 0 && section == 1) {
        UILabel *noMoreLabel = [[UILabel alloc] init];
        noMoreLabel.text = @"That's everything.";
        noMoreLabel.textColor = [UIColor grayColor];
        noMoreLabel.textAlignment = NSTextAlignmentCenter;
        return noMoreLabel;
    }
    else if (_noResults && section == 1) {
        UILabel *noCommentsLabel = [[UILabel alloc] init];
        noCommentsLabel.text = @"No comments yet.";
        noCommentsLabel.textColor = [UIColor grayColor];
        noCommentsLabel.textAlignment = NSTextAlignmentCenter;
        return noCommentsLabel;
    }
    else {
        return nil;
    }
}

-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 1) {
        return 92.0;
    }
    else {
        return 0;
    }
}

#pragma mark - Requests

// feed request
-(void) requestCommentsForEpisodeEntity:(EpisodeEntity *)episodeEntity
                              NewerThan:(NSNumber *)afterTime
                            orOlderThan:(NSNumber *)beforeTime {
    
    NSLog(@"request for comments newer than: %@, or older than: %@", afterTime, beforeTime);
    self.requestStatus = @"initiated";
    
    NSURL *commentsURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/comments.php", _tung.apiRootUrl]];
    NSMutableURLRequest *feedRequest = [NSMutableURLRequest requestWithURL:commentsURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [feedRequest setHTTPMethod:@"POST"];
    NSString *episodeId = (episodeEntity.id) ? episodeEntity.id : @"";
    NSDictionary *params = @{
                             @"sessionId": _tung.sessionId,
                             @"GUID": episodeEntity.guid,
                             @"episodeId": episodeId,
                             @"newerThan": afterTime,
                             @"olderThan": beforeTime
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
                                    [self requestCommentsForEpisodeEntity:episodeEntity NewerThan:afterTime orOlderThan:beforeTime];
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
                        
                        NSArray *newComments = jsonData;
                        NSLog(@"new posts count: %lu", (unsigned long)newComments.count);
                        
                        // end refreshing
                        self.tableView.backgroundView = nil;
                        [self.refreshControl endRefreshing];
                        
                        // pull refresh
                        if ([afterTime intValue] > 0) {
                            if (newComments.count > 0) {
                                NSLog(@"\tgot comments newer than: %@", afterTime);
                                NSArray *newCommentsArray = [newComments arrayByAddingObjectsFromArray:_commentsArray];
                                _commentsArray = [newCommentsArray mutableCopy];
                                
                                [UIView setAnimationsEnabled:NO];
                                [self.tableView beginUpdates];
                                for (NSInteger i = 0; i < newComments.count; i++) {
                                    [self.tableView insertSections:[NSIndexSet indexSetWithIndex:i] withRowAnimation:UITableViewRowAnimationNone];
                                }
                                [self.tableView endUpdates];
                                [UIView setAnimationsEnabled:YES];
                                
                                [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
                            }
                        }
                        // auto-loaded posts as user scrolls down
                        else if ([beforeTime intValue] > 0) {
                            
                            _requestingMore = NO;
                            _loadMoreIndicator.alpha = 0;
                            
                            if (newComments.count == 0) {
                                NSLog(@"no more posts to get");
                                _reachedEndOfPosts = YES;
                                // hide footer
                                //[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_commentsArray.count-1 inSection:_feedSection] atScrollPosition:UITableViewScrollPositionMiddle animated:YES]; // causes crash on search page
                                [self.tableView reloadData];
                                
                            } else {
                                NSLog(@"\tgot comments older than: %@", beforeTime);
                                int startingIndex = (int)_commentsArray.count;
                                
                                NSArray *newCommentsArray = [_commentsArray arrayByAddingObjectsFromArray:newComments];
                                _commentsArray = [newCommentsArray mutableCopy];
                                newCommentsArray = nil;
                                
                                [UIView setAnimationsEnabled:NO];
                                [self.tableView beginUpdates];
                                for (int i = startingIndex-1; i < _commentsArray.count-1; i++) {
                                    [self.tableView insertSections:[NSIndexSet indexSetWithIndex:i] withRowAnimation:UITableViewRowAnimationNone];
                                }
                                [self.tableView endUpdates];
                                [UIView setAnimationsEnabled:YES];
                                
                                
                            }
                        }
                        // initial request
                        else {
                            _commentsArray = [newComments mutableCopy];
                            NSLog(@"got posts. storiesArray count: %lu", (unsigned long)[_commentsArray count]);
                            //NSLog(@"%@", _commentsArray);
                            [self.tableView reloadData];
                        }
                        
                        // feed is now refreshed
                        self.requestStatus = @"finished";
                        //_tung.commentsNeedRefresh = [NSNumber numberWithBool:NO];
                        
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
                    [self.refreshControl endRefreshing];
                });
            }
            else if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    _requestingMore = NO;
                    self.requestStatus = @"finished";
                    _loadMoreIndicator.alpha = 0;
                    [self.refreshControl endRefreshing];
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
                [self.refreshControl endRefreshing];
                _loadMoreIndicator.alpha = 0;
                // end refreshing
                self.requestStatus = @"finished";
                self.tableView.backgroundView = nil;
                
                UIAlertView *connectionErrorAlert = [[UIAlertView alloc] initWithTitle:@"Connection error" message:[error localizedDescription] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                self.tableView.backgroundView = nil;
                [connectionErrorAlert show];
            });
        }
    }];
}


@end
