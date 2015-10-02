//
//  tungPeople.m
//  Tung
//
//  Created by Jamie Perkins on 11/5/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "tungPeople.h"
#import "ProfileListCell.h"
#import "ProfileTableViewController.h"

@implementation tungPeople

- (id)init {
    
    self = [super init];
    if (self) {
        
        _tungObjects = [TungCommonObjects establishTungObjects];
        _systemVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
        _itemArray = [[NSMutableArray alloc] init];
        
    }
    return self;
}


- (void) requestProfileListWithQuery:(NSString *)queryType
                           forTarget:(NSString *)target_id
                        orSearchTerm:(NSString *)term
                           newerThan:(NSNumber *)afterTime
                         orOlderThan:(NSNumber *)beforeTime {
    NSLog(@"get profile list with query: \"%@\" for target: %@ or search term: %@ newer than: %@, older than: %@", queryType, target_id, term, afterTime, beforeTime);
    NSURL *getProfileListRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/profileList.php", _tungObjects.apiRootUrl]];
    NSMutableURLRequest *getProfileListRequest = [NSMutableURLRequest requestWithURL:getProfileListRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [getProfileListRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_tungObjects.sessionId,
                             @"queryType": queryType,
                             @"target_id": target_id,
                             @"searchTerm": term,
                             @"newerThan": afterTime,
                             @"olderThan": beforeTime};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [getProfileListRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:getProfileListRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
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
                                [_tungObjects getSessionWithCallback:^{
                                    [self requestProfileListWithQuery:queryType forTarget:target_id orSearchTerm:term newerThan:afterTime orOlderThan:beforeTime];
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
                        
                        NSArray *newUsers = jsonData;
                        
                        if (newUsers.count == 0) _noResults = YES;
                        else _noResults = NO;
                        
                        _queryExecuted = YES;
                        // end refreshing
                        [self.refreshControl endRefreshing];
                        _tableView.backgroundView = nil;
                        // clip section
                        _itemSection = 0;
                        
                        // pull refresh
                        if ([afterTime intValue] > 0) {
                            //[self stopPlayback];
                            NSArray *newUsersArray = [newUsers arrayByAddingObjectsFromArray:_itemArray];
                            _itemArray = [newUsersArray mutableCopy];
                            NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
                            for (int i = 0; i < newUsers.count; i++) {
                                [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:_itemSection]];
                            }
                            if (newUsers.count > 0) {
                                // if new posts were retrieved
                                [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:_itemSection] atScrollPosition:UITableViewScrollPositionTop animated:YES];
                                
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
                            if (newUsers.count == 0) {
                                NSLog(@"no more items to get");
                                _noMoreItemsToGet = YES;
                                // hide footer
                                //[_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_itemArray.count-1 inSection:_itemSection] atScrollPosition:UITableViewScrollPositionMiddle animated:YES]; // causes crash on search page
                                _loadMoreIndicator.alpha = 0;
                                
                                [_tableView reloadData];
                            } else {
                                NSLog(@"\tgot items older than: %@", beforeTime);
                                int startingIndex = (int)_itemArray.count;
                                // NSLog(@"\tstarting index: %d", startingIndex);
                                NSArray *newUsersArray = [_itemArray arrayByAddingObjectsFromArray:newUsers];
                                _itemArray = [newUsersArray mutableCopy];
                                NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
                                for (int i = startingIndex; i < _itemArray.count; i++) {
                                    [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:_itemSection]];
                                }
                                [_tableView beginUpdates];
                                [_tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationLeft];
                                [_tableView endUpdates];
                                
                                [_tableView reloadData];
                                
                            }
                        }
                        // initial request
                        else {
                            _itemArray = [newUsers mutableCopy];
                            
                            [_tableView reloadData];
                        }
                        
                        NSLog(@"got items. itemArray count: %lu", (unsigned long)[_itemArray count]);
                        [self preloadAvatars];
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

-(void) preloadAvatars {
    
    NSOperationQueue *preloadQueue = [[NSOperationQueue alloc] init];
    preloadQueue.maxConcurrentOperationCount = 3;
    // download and save avatars to temp directory if they don't exist
    
    for (int i = 0; i < _itemArray.count; i++) {
        
        [preloadQueue addOperationWithBlock:^{
            // avatar
            NSString *avatarURLString = [[[_itemArray objectAtIndex:i] objectForKey:@"user"] objectForKey:@"small_av_url"];
            NSString *avatarFilename = [avatarURLString lastPathComponent];
            NSString *avatarFilepath = [NSTemporaryDirectory() stringByAppendingPathComponent:avatarFilename];
            if (![[NSFileManager defaultManager] fileExistsAtPath:avatarFilepath]) {
                NSData *avatarImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:avatarURLString]];
                [avatarImageData writeToFile:avatarFilepath atomically:YES];
            }
        }];
    }
}

-(void) configureProfileListCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    
//    NSLog(@"profile list cell for row at index path: %ld", (long)indexPath.row);
    ProfileListCell *profileCell = (ProfileListCell *)cell;
    
    // cell data
    NSDictionary *itemDict = [NSDictionary dictionaryWithDictionary:[_itemArray objectAtIndex:indexPath.row]];
    NSDictionary *userDict = [NSDictionary dictionaryWithDictionary:[itemDict objectForKey:@"user"]];
    NSString *action = [itemDict objectForKey:@"action"];
    
    // avatar
    NSString *avatarFilename = [[userDict objectForKey:@"small_av_url"] lastPathComponent];
    NSString *avatarFilepath = [NSTemporaryDirectory() stringByAppendingPathComponent:avatarFilename];
    NSData *avatarImageData;
    // make sure it is cached, even though we preloaded it
    if ([[NSFileManager defaultManager] fileExistsAtPath:avatarFilepath]) {
        avatarImageData = [NSData dataWithContentsOfFile:avatarFilepath];
    } else {
        avatarImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString: [userDict objectForKey:@"small_av_url"]]];
        [avatarImageData writeToFile:avatarFilepath atomically:YES];
    }
    profileCell.avatarContainerView.backgroundColor = [UIColor clearColor];
    profileCell.avatarContainerView.avatar = nil;
    profileCell.avatarContainerView.avatar = [[UIImage alloc] initWithData:avatarImageData];
    profileCell.avatarContainerView.borderColor = [UIColor whiteColor];
    [profileCell.avatarContainerView setNeedsDisplay];
    
    // username
    [profileCell.usernameButton setTitle:[userDict objectForKey:@"username"] forState:UIControlStateNormal];
    [profileCell.usernameButton addTarget:self action:@selector(tableCellButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    profileCell.usernameButton.tag = 100;
    [profileCell.avatarButton addTarget:self action:@selector(tableCellButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    profileCell.avatarButton.tag = 100;
    
//    NSLog(@"username top constraint: %@", profileCell.usernameTopConstraint);
    
    // sub label
    if ([_queryType isEqualToString:@"Activity"]) {
        
        profileCell.subLabelLeadingConstraint.constant = 30;
        profileCell.iconView.hidden = NO;
        profileCell.iconView.backgroundColor = [UIColor clearColor];
//        NSLog(@"action: %@", action);
        NSString *eventString;
        if ([action isEqualToString:@"followed"]) {
            profileCell.iconView.type = kIconTypeAdd;
            profileCell.iconView.color = [UIColor grayColor];
            eventString = @"Followed you";
        }
        profileCell.subLabel.text = eventString;
    }
    else {
        
        profileCell.subLabel.text = [userDict objectForKey:@"name"];
        profileCell.subLabelLeadingConstraint.constant = 14;
        profileCell.iconView.hidden = YES;
    }
    
    // user/user relationship
//    NSLog(@"userfollows: %@", [userDict objectForKey:@"userFollows"]);
    
//    NSLog(@"-----");
    [profileCell.iconView setNeedsDisplay];

}

-(UIBarButtonItem *) generateStereoButtonWithImageName:(NSString *)imageName {
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, 38, 44);
    [btn setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
    [btn setContentMode:UIViewContentModeCenter];
    return [[UIBarButtonItem alloc] initWithCustomView:btn];
}

- (void) tableCellButtonTapped:(id)sender {
    long tag = [sender tag];
    ProfileListCell* cell;
    if (_systemVersion < 8) {
        //NSLog(@"ios 7");
        cell = (ProfileListCell*)[[[sender superview] superview] superview];
    } else {
        //NSLog(@"ios 8+");
        cell = (ProfileListCell*)[[sender superview] superview];
    }
    NSIndexPath* indexPath = [self.tableView indexPathForCell:cell];
    _buttonPressedAtIndex = [indexPath row];
    NSLog(@"-*- table cell button pressed at index: %ld with tag: %ld", (long)_buttonPressedAtIndex, tag);
    
    switch (tag) {
        // profile of user
        case 100: {
            [self pushProfileForUserAtIndex:_buttonPressedAtIndex];
            break;
        }
    }
}

- (void) pushProfileForUserAtIndex:(NSInteger)index {
    NSDictionary *itemDict = [NSDictionary dictionaryWithDictionary:[_itemArray objectAtIndex:index]];
    NSDictionary *userDict = [NSDictionary dictionaryWithDictionary:[itemDict objectForKey:@"user"]];
    
    NSLog(@"push profile of user: %@", [userDict objectForKey:@"username"]);
    // push profile
    ProfileTableViewController *profileView = [_viewController.storyboard instantiateViewControllerWithIdentifier:@"profileView"];
    profileView.profiledUserId = [userDict objectForKey:@"id"];
    [_viewController.navigationController pushViewController:profileView animated:YES];
}

@end
