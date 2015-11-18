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
@property NSIndexPath *focusedIndexPath;
@property NSIndexPath *buttonPressIndexPath;

@end

@implementation CommentsTableViewController

CGFloat screenWidth, labelWidth;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    
    _commentsArray = [NSMutableArray new];
    
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
    
    screenWidth = self.view.frame.size.width;
    labelWidth = screenWidth - 130 - 8; // right margin, left margin
    
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
    commentCell.commentBkgd.backgroundColor = [UIColor clearColor];
    [commentCell.commentBkgd setNeedsDisplay];
    
    // background color
    if (_focusedId && [_focusedId isEqualToString:[[commentDict objectForKey:@"_id"] objectForKey:@"$id"]]) {
        _focusedIndexPath = indexPath;
        commentCell.backgroundColor = [TungCommonObjects lightTungColor];
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
    [commentCell.usernameBtn setTitle:[[commentDict objectForKey:@"user"] objectForKey:@"username"] forState:UIControlStateNormal];
    [commentCell.usernameBtn addTarget:self action:@selector(theirCommentUsernameButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    commentCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    commentCell.commentBkgd.type = kCommentBkgdTypeTheirs;
    commentCell.commentBkgd.backgroundColor = [UIColor clearColor];
    [commentCell.commentBkgd setNeedsDisplay];
    
    // background color
    if (_focusedId && [_focusedId isEqualToString:[[commentDict objectForKey:@"_id"] objectForKey:@"$id"]]) {
        _focusedIndexPath = indexPath;
        commentCell.backgroundColor = [TungCommonObjects lightTungColor];
    } else {
        commentCell.backgroundColor = [UIColor whiteColor];
    }
    
}

#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //CLS_LOG(@"%@", [_commentsArray objectAtIndex:indexPath.row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    _buttonPressIndexPath = indexPath;
    NSDictionary *commentDict = [NSDictionary dictionaryWithDictionary:[_commentsArray objectAtIndex:indexPath.row]];
    NSString *idString = [[[commentDict objectForKey:@"user"] objectForKey:@"id"] objectForKey:@"$id"];
    
    if ([idString isEqualToString:_tung.tungId]) {
        // logged-in user's comment
        UIActionSheet *deleteCommentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete this comment" otherButtonTitles:nil];

        [deleteCommentActionSheet setTag:1];
        [deleteCommentActionSheet showInView:self.view];
    } else {
        // other user's comment
        UIActionSheet *commentOptionsActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Flag this comment" otherButtonTitles:nil];
        
        [commentOptionsActionSheet setTag:2];
        [commentOptionsActionSheet showInView:self.view];
    }
}

- (void) tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"accessory pressed at index path: %@", indexPath);
    [self pushProfileForUserAtIndexPath:indexPath];
}

//- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath

UILabel *prototypeLabel;

-(CGSize) getCommentSizeForIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *commentDict = [NSDictionary dictionaryWithDictionary:[_commentsArray objectAtIndex:indexPath.row]];
    if (!prototypeLabel) {
        prototypeLabel = [[UILabel alloc] init];
        prototypeLabel.font = [UIFont systemFontOfSize:15];
        prototypeLabel.numberOfLines = 0;
    }
    
    prototypeLabel.text = [commentDict objectForKey:@"comment"];
    CGSize labelSize = [prototypeLabel sizeThatFits:CGSizeMake(labelWidth, 400)];
    //CLS_LOG(@"label size for row %ld: %@", (long)indexPath.row, NSStringFromCGSize(labelSize));
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
    
    UILabel *toCommentLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 25, screenWidth, 40)];
    toCommentLabel.text = @"To comment, play this episode.\nThen tap 🔈 to to view Now Playing";
    toCommentLabel.numberOfLines = 2;
    toCommentLabel.textColor = [UIColor lightGrayColor];
    toCommentLabel.textAlignment = NSTextAlignmentCenter;
    toCommentLabel.font = [UIFont systemFontOfSize:15];
    
    if (_commentsArray.count > 0 && section == 1) {
        UILabel *noMoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, screenWidth, 20)];
        noMoreLabel.text = @"That's everything.\n ";
        noMoreLabel.numberOfLines = 0;
        noMoreLabel.textColor = [UIColor grayColor];
        noMoreLabel.textAlignment = NSTextAlignmentCenter;
        if (_isForNowPlaying) {
        	return noMoreLabel;
        }
        UIView *commentFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 60)];
        [commentFooterView addSubview:noMoreLabel];
        [commentFooterView addSubview:toCommentLabel];
        return commentFooterView;
    }
    else if (_noResults && section == 1) {
        UILabel *noCommentsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, screenWidth, 20)];
        noCommentsLabel.text = @"No comments yet.";
        noCommentsLabel.textColor = [UIColor grayColor];
        noCommentsLabel.textAlignment = NSTextAlignmentCenter;
        noCommentsLabel.font = [UIFont systemFontOfSize:15];
        if (_isForNowPlaying) {
            return noCommentsLabel;
        }
        UIView *commentFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 60)];
        [commentFooterView addSubview:noCommentsLabel];
        [commentFooterView addSubview:toCommentLabel];
        return commentFooterView;
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

#pragma mark - Table cell taps

- (void) theirCommentUsernameButtonTapped:(id)sender {
    NSLog(@"username button tapped");
    CommentCell* cell  = (CommentCell*)[[sender superview] superview];
    _buttonPressIndexPath = [self.tableView indexPathForCell:cell];
    
    [self pushProfileForUserAtIndexPath:_buttonPressIndexPath];
    
}

- (void) pushProfileForUserAtIndexPath:(NSIndexPath *)indexPath {
    
    // push profile
    NSDictionary *commentDict = [NSDictionary dictionaryWithDictionary:[_commentsArray objectAtIndex:indexPath.row]];
    NSString *idString = [[[commentDict objectForKey:@"user"] objectForKey:@"id"] objectForKey:@"$id"];
    
    ProfileViewController *profileView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"profileView"];
    profileView.profiledUserId = idString;
    [_navController pushViewController:profileView animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    CLS_LOG(@"dismissed commentsTableView action sheet with button: %ld", (long)buttonIndex);
    NSDictionary *commentDict = [NSDictionary dictionaryWithDictionary:[_commentsArray objectAtIndex:_buttonPressIndexPath.row]];
    // delete own comment
    if (actionSheet.tag == 1) {
        
        if (buttonIndex == 0) { // destructive option
            
            NSString *eventId = [[commentDict objectForKey:@"_id"] objectForKey:@"$id"];
            [_tung deleteStoryEventWithId:eventId withCallback:^(BOOL success) {
                [_commentsArray removeObjectAtIndex:_buttonPressIndexPath.row];
                // remove table row
                [self.tableView beginUpdates];
                [self.tableView deleteRowsAtIndexPaths:@[_buttonPressIndexPath] withRowAnimation:UITableViewRowAnimationRight];
                [self.tableView endUpdates];
                _tung.feedNeedsRefresh = [NSNumber numberWithBool:YES];
            }];
        }
    }
    // their comment
    if (actionSheet.tag == 2) {
        
        if (buttonIndex == 0) { // destructive option
            
            NSString *eventId = [[commentDict objectForKey:@"_id"] objectForKey:@"$id"];
            [_tung flagCommentWithId:eventId];
        }
    }
}

#pragma mark - Requests

// comments request
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
    //CLS_LOG(@"request for comments with params: %@", params);
    _queryExecuted = YES;
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [feedRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:feedRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            //CLS_LOG(@"got response: %@", jsonData);
            if (jsonData != nil && error == nil) {
                if ([jsonData isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                                // get new session and re-request
                                CLS_LOG(@"SESSION EXPIRED");
                                [_tung getSessionWithCallback:^{
                                    [self requestCommentsForEpisodeEntity:episodeEntity NewerThan:afterTime orOlderThan:beforeTime];
                                }];
                            } else {
                                [self endRefreshing];
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
                        CLS_LOG(@"new comments count: %lu", (unsigned long)newComments.count);
                        
                        // end refreshing
                        [self endRefreshing];
                        
                        // comments are sorted by timestamp, so we can't get newest/oldest by time_secs.
                        // commenting out for now until I can spend time on a better solution.
                        /*
                        // pull refresh
                        if ([afterTime intValue] > 0) {
                            if (newComments.count > 0) {
                                CLS_LOG(@"\tgot comments newer than: %@", afterTime);
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
                                CLS_LOG(@"no more comments to get");
                                _reachedEndOfPosts = YES;
                                // hide footer
                                //[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_commentsArray.count-1 inSection:_feedSection] atScrollPosition:UITableViewScrollPositionMiddle animated:YES]; // causes crash on search page
                                [self.tableView reloadData];
                                
                            } else {
                                CLS_LOG(@"\tgot comments older than: %@", beforeTime);
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
                                CLS_LOG(@"got comments. commentsArray count: %lu", (unsigned long)[_commentsArray count]);
                                //CLS_LOG(@"%@", _commentsArray);
                            } else {
                                _noResults = YES;
                            }
                            [self.tableView reloadData];
                        }*/
                        
                        if (newComments.count > 0) {
                            _noResults = NO;
                            _commentsArray = [newComments mutableCopy];
                            //CLS_LOG(@"%@", _commentsArray);
                        } else {
                            _noResults = YES;
                        }
                        [self.tableView reloadData];
                        
                        // focused comment
                        if (_focusedId && _focusedIndexPath) {
                        	[self.tableView scrollToRowAtIndexPath:_focusedIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
                    	}
                        
                    });
                }
            }
            else if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self endRefreshing];
                });
                CLS_LOG(@"Error: %@", error);
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"HTML: %@", html);
            }
        }
        // connection error
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self endRefreshing];
                
                UIAlertView *connectionErrorAlert = [[UIAlertView alloc] initWithTitle:@"Connection error" message:[error localizedDescription] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [connectionErrorAlert show];
            });
        }
    }];
}

- (void) endRefreshing {
    _requestingMore = NO;
    self.requestStatus = @"finished";
    _loadMoreIndicator.alpha = 0;
    [self.refreshControl endRefreshing];
    self.tableView.backgroundView = nil;
}


@end
