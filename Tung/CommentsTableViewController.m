//
//  PodcastTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 7/27/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "CommentsTableViewController.h"
#import "ProfileViewController.h"

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
    
    // table bkgd
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

static NSString *cellIdentifierTheirs = @"commentCellTheirs";
static NSString *cellIdentifierMine = @"commentCellMine";

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSDictionary *commentDict = [NSDictionary dictionaryWithDictionary:[_commentsArray objectAtIndex:indexPath.row]];
    NSString *idString = [[[commentDict objectForKey:@"user"] objectForKey:@"id"] objectForKey:@"$id"];
    
    if ([idString isEqualToString:_tung.tungId]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifierMine];
        [self configureCommentMineCell:cell forIndexPath:indexPath];
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifierTheirs];
        [self configureCommentTheirsCell:cell forIndexPath:indexPath];
        return cell;
    }
    
}

static CGFloat commentBubbleMargins = 27;

- (void) configureCommentMineCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
    CommentCellMine *commentCell = (CommentCellMine *)cell;
    NSDictionary *commentDict = [NSDictionary dictionaryWithDictionary:[_commentsArray objectAtIndex:indexPath.row]];
    
    commentCell.commentLabel.text = [commentDict objectForKey:@"comment"];
    commentCell.timestampLabel.text = [commentDict objectForKey:@"timestamp"];
    
    CGSize commentLabelSize = [self getCommentSizeForIndexPath:indexPath];
    CGFloat bkgdWidth = commentLabelSize.width + commentBubbleMargins;
    commentCell.commentBkgdWidthConstraint.constant = bkgdWidth;
    [commentCell.contentView layoutIfNeeded];
    
    // mine
    commentCell.accessoryType = UITableViewCellAccessoryNone;
    commentCell.commentBkgd.type = kCommentBkgdTypeMine;

    [commentCell.commentBkgd setNeedsDisplay];
    
    // background color
    if (_focusedId && [_focusedId isEqualToString:[[commentDict objectForKey:@"id"] objectForKey:@"$id"]]) {
        commentCell.backgroundColor = _tung.lightTungColor;
    } else {
        commentCell.backgroundColor = [UIColor whiteColor];
    }
    
}

- (void) configureCommentTheirsCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
    CommentCell *commentCell = (CommentCell *)cell;
    NSDictionary *commentDict = [NSDictionary dictionaryWithDictionary:[_commentsArray objectAtIndex:indexPath.row]];
    
    commentCell.commentLabel.text = [commentDict objectForKey:@"comment"];
    commentCell.timestampLabel.text = [commentDict objectForKey:@"timestamp"];
    
    CGSize commentLabelSize = [self getCommentSizeForIndexPath:indexPath];
    CGFloat bkgdWidth = commentLabelSize.width + commentBubbleMargins;
    commentCell.commentBkgdWidthConstraint.constant = bkgdWidth;
    [commentCell.contentView layoutIfNeeded];
    
    // theirs
    commentCell.commentLabel.textColor = [UIColor darkTextColor];
    commentCell.usernameLabel.text = [[commentDict objectForKey:@"user"] objectForKey:@"username"];
    commentCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    commentCell.commentBkgd.type = kCommentBkgdTypeTheirs;

    [commentCell.commentBkgd setNeedsDisplay];
    
    // background color
    if (_focusedId && [_focusedId isEqualToString:[[commentDict objectForKey:@"id"] objectForKey:@"$id"]]) {
        commentCell.backgroundColor = _tung.lightTungColor;
    } else {
        commentCell.backgroundColor = [UIColor whiteColor];
    }
    
}

#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //NSLog(@"%@", [_commentsArray objectAtIndex:indexPath.row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *commentDict = [NSDictionary dictionaryWithDictionary:[_commentsArray objectAtIndex:indexPath.row]];
    NSString *idString = [[[commentDict objectForKey:@"user"] objectForKey:@"id"] objectForKey:@"$id"];
    
    if ([idString isEqualToString:_tung.tungId]) {
        // logged-in user's comment
        // TODO: preset action sheet with option to delete comment
    } else {
        // other user's comment
        // push profile view
        ProfileViewController *profileView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"profileView"];
        profileView.profiledUserId = idString;
        [_navController pushViewController:profileView animated:YES];
    }
}

//- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath

UILabel *prototypeLabel;
static CGFloat labelWidth;
static double screenWidth;

-(CGSize) getCommentSizeForIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *commentDict = [NSDictionary dictionaryWithDictionary:[_commentsArray objectAtIndex:indexPath.row]];
    if (!prototypeLabel) {
        prototypeLabel = [[UILabel alloc] init];
        prototypeLabel.font = [UIFont systemFontOfSize:15];
        prototypeLabel.numberOfLines = 0;
    }
    if (!screenWidth) screenWidth = [[UIScreen mainScreen]bounds].size.width;
    if (!labelWidth) { labelWidth = screenWidth - 130 - 8; } // right margin, left margin
    
    prototypeLabel.text = [commentDict objectForKey:@"comment"];
    CGSize labelSize = [prototypeLabel sizeThatFits:CGSizeMake(labelWidth, 400)];
    //NSLog(@"label size for row %ld: %@", (long)indexPath.row, NSStringFromCGSize(labelSize));
    return labelSize;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    CGSize labelSize = [self getCommentSizeForIndexPath:indexPath];
    CGFloat totalHeight = labelSize.height;
    
    NSDictionary *commentDict = [NSDictionary dictionaryWithDictionary:[_commentsArray objectAtIndex:indexPath.row]];
    NSString *idString = [[[commentDict objectForKey:@"user"] objectForKey:@"id"] objectForKey:@"$id"];
    // if theirs
    if (![idString isEqualToString:_tung.tungId]) {
        totalHeight += 16; // timestamp label height and space
    }
    totalHeight += 17; // comment bkgd top and bottom margins and extra point
    return totalHeight;
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
    NSLog(@"request for comments with params: %@", params);
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
                        NSLog(@"new comments count: %lu", (unsigned long)newComments.count);
                        
                        // end refreshing
                        self.tableView.backgroundView = nil;
                        [self.refreshControl endRefreshing];
                        
                        // comments are sorted by timestamp, so we can't get newest/oldest by time_secs.
                        // commenting out for now until I can spend time on a better solution.
                        /*
                        // pull refresh
                        if ([afterTime intValue] > 0) {
                            if (newComments.count > 0) {
                                NSLog(@"\tgot comments newer than: %@", afterTime);
                                NSArray *newCommentsArray = [newComments arrayByAddingObjectsFromArray:_commentsArray];
                                _commentsArray = [newCommentsArray mutableCopy];
                                NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
                                for (int i = 0; i < newComments.count; i++) {
                                    [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                                }
                                    
                                [UIView setAnimationsEnabled:NO];
                                [self.tableView beginUpdates];
                                [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationLeft];
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
                                NSLog(@"no more comments to get");
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
                                NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
                                for (int i = startingIndex; i < _commentsArray.count; i++) {
                                    [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                                }
                                [UIView setAnimationsEnabled:NO];
                                [self.tableView beginUpdates];
                                [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationLeft];
                                [self.tableView endUpdates];
                                [UIView setAnimationsEnabled:YES];
                            }
                        }
                        // initial request
                        else {
                            if (newComments.count > 0) {
                                _noResults = NO;
                                _commentsArray = [newComments mutableCopy];
                                NSLog(@"got comments. commentsArray count: %lu", (unsigned long)[_commentsArray count]);
                                //NSLog(@"%@", _commentsArray);
                            } else {
                                _noResults = YES;
                            }
                            [self.tableView reloadData];
                        }*/
                        
                        if (newComments.count > 0) {
                            _noResults = NO;
                            _commentsArray = [newComments mutableCopy];
                            NSLog(@"got comments. commentsArray count: %lu", (unsigned long)[_commentsArray count]);
                            //NSLog(@"%@", _commentsArray);
                        } else {
                            _noResults = YES;
                        }
                        [self.tableView reloadData];
                        
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
