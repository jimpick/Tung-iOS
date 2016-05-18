//
//  SuggestedUsersTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 5/10/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//

#import "SuggestedUsersTableViewController.h"
#import "SuggestedUserCell.h"
#import "ProfileListTableViewController.h"

#define NUM_REQUIRED_FOLLOWS 2

@interface SuggestedUsersTableViewController ()

@property NSMutableArray *usersToFollow;
@property UILabel *subtitleLabel;
@property UIBarButtonItem *proceedButton;

@end

@implementation SuggestedUsersTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    
    // title and subtitle
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    //titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = [TungCommonObjects tungColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.text = [NSString stringWithFormat:@"Follow %d", NUM_REQUIRED_FOLLOWS];
    [titleLabel sizeToFit];
    
    _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 22, 0, 0)];
    //subTitleLabel.backgroundColor = [UIColor clearColor];
    _subtitleLabel.textColor = [UIColor grayColor];
    _subtitleLabel.font = [UIFont systemFontOfSize:12];
    _subtitleLabel.text = [NSString stringWithFormat:@"%d remaining", NUM_REQUIRED_FOLLOWS];
    [_subtitleLabel sizeToFit];
    
    UIView *twoLineTitleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, MAX(_subtitleLabel.frame.size.width, titleLabel.frame.size.width), 30)];
    [twoLineTitleView addSubview:titleLabel];
    [twoLineTitleView addSubview:_subtitleLabel];
    
    float widthDiff = _subtitleLabel.frame.size.width - titleLabel.frame.size.width;
    
    if (widthDiff > 0) {
        CGRect frame = titleLabel.frame;
        frame.origin.x = widthDiff / 2;
        titleLabel.frame = CGRectIntegral(frame);
    } else {
        CGRect frame = _subtitleLabel.frame;
        frame.origin.x = fabsf(widthDiff) / 2;
        _subtitleLabel.frame = CGRectIntegral(frame);
    }
    
    self.navigationItem.titleView = twoLineTitleView;
    
    // right bar button item
    _proceedButton = [[UIBarButtonItem alloc] initWithTitle:@"Next" style:UIBarButtonItemStyleDone target:self action:@selector(proceedToNextView)];
    
    
    // table view
    UIActivityIndicatorView *spinnerBehindTable = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    spinnerBehindTable.alpha = 1;
    [spinnerBehindTable startAnimating];
    self.tableView.backgroundView = spinnerBehindTable;
    self.tableView.backgroundColor = [TungCommonObjects bkgdGrayColor];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.separatorColor = [UIColor grayColor];
    self.tableView.scrollsToTop = YES;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 12, 0, 12);
    self.tableView.allowsSelection = NO;
    
    _usersToFollow = [NSMutableArray array];
    
    // get users
    [self getSuggestedUsersAndForceNew:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// get suggested users and optionally bust cached result
- (void) getSuggestedUsersAndForceNew:(BOOL)forceNew {
    NSURL *suggestedUsersURL;
    if (forceNew) {
    	suggestedUsersURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/suggested-users.php%@", _tung.apiRootUrl, [TungCommonObjects serializeParamsForGetRequest:@{ @"forceNew": @"true" }]]];
    } else {
        suggestedUsersURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/suggested-users.php", _tung.apiRootUrl]];
    }
    NSMutableURLRequest *suggestedUsersRequest = [NSMutableURLRequest requestWithURL:suggestedUsersURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0f];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:suggestedUsersRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            
            if (jsonData != nil && error == nil) {
                
                NSDictionary *responseDict = jsonData;
                
                if ([responseDict objectForKey:@"error"]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            [_tung getSessionWithCallback:^{
                                [self getSuggestedUsersAndForceNew:NO];
                            }];
                        } else {
                            self.tableView.backgroundView = nil;
                            // other error - alert user
                            [_tung simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                        }
                    });
                }
                else if ([responseDict objectForKey:@"success"]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        self.tableView.backgroundView = nil;
                        
                        _usersArray = [responseDict objectForKey:@"success"];
                        [self preloadAlbumArtForSuggestedUsers];
                        [self.tableView reloadData];
                        
                        // see if user should proceed to platform friends or finsish
                        [self checkForPlatformFriends];
                        
                    });
                }
            }
            // errors
            else if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    JPLog(@"Error: %@", error);
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"HTML: %@", html);
                    [self getSuggestedUsersAndForceNew:YES];
                });
            }
        }
        // connection error
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                self.tableView.backgroundView = nil;
            });
        }
    }];
}

- (void) preloadAlbumArtForSuggestedUsers {
    
    NSOperationQueue *preloadQueue = [[NSOperationQueue alloc] init];
    preloadQueue.maxConcurrentOperationCount = 3;
    
    for (int i = 0; i < _usersArray.count; i++) {
        
        NSArray *podcasts = [[_usersArray objectAtIndex:i] objectForKey:@"podcasts"];
        
        for (int j = 0; j < podcasts.count; j++) {
        
            // preload avatar and album art
            [preloadQueue addOperationWithBlock:^{
                
                NSString *podcastArtUrlString = [[podcasts objectAtIndex:j] objectForKey:@"artworkUrlSSL"];
                NSNumber *podcastId = [[podcasts objectAtIndex:j] objectForKey:@"_id"];
                [TungCommonObjects retrievePodcastArtDataWithUrlString:podcastArtUrlString andCollectionId:podcastId];
            }];
        }
    }
}

- (void) followOrUnfollowUser:(id)sender {
    
    PillButton *btn = (PillButton *)sender;
    SuggestedUserCell *cell = (SuggestedUserCell *)[[sender superview] superview];
    
    if (btn.on) {
        // unfollow
        [_usersToFollow removeObject:cell.userId];
    }
    else {
        // follow
        [_usersToFollow addObject:cell.userId];
    }
    // GUI
    btn.on = !btn.on;
    [btn setNeedsDisplay];
    
    // update subtitle
    NSInteger result = NUM_REQUIRED_FOLLOWS - _usersToFollow.count;
    if (result <= 0) {
        result = 0;
        self.navigationItem.rightBarButtonItem = _proceedButton;
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
    _subtitleLabel.text = [NSString stringWithFormat:@"%ld remaining", (long)result];
    //NSLog(@"%@", _usersToFollow);
}

// see if user has any friends on tung from the service they signed up with.
- (void) checkForPlatformFriends {
    NSLog(@"check for platform friends");
    [_proceedButton setEnabled:NO];
    
    if ([_profileData objectForKey:@"twitter_id"]) {
        
        [_tung findFriendsForUsername:[_profileData objectForKey:@"twitter_username"] withCallback:^(BOOL success, NSDictionary *responseDict) {
            if (success) {
                NSLog(@"responseDict: %@", responseDict);
                NSNumber *platformFriendsCount = [responseDict objectForKey:@"resultsCount"];
                if ([platformFriendsCount integerValue] > 0) {
                    [_profileData setObject:[responseDict objectForKey:@"results"] forKey:@"twitterFriends"];
                }
            }
        }];
        
    }
    else if ([_profileData objectForKey:@"facebook_id"]) {
        
    }
    
}

- (void) proceedToNextView {
    
    if ([_profileData objectForKey:@"twitterFriends"] || [_profileData objectForKey:@"facebookFriends"]) {
        ProfileListTableViewController *profileListView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileListView"];
        profileListView.queryType = @"platformFriends";
        if ([_profileData objectForKey:@"twitterFriends"]) {
            profileListView.profileArray = [_profileData objectForKey:@"twitterFriends"];
            [_profileData removeObjectForKey:@"twitterFriends"];
        }
        else if ([_profileData objectForKey:@"facebookFriends"]) {
            profileListView.profileArray = [_profileData objectForKey:@"facebookFriends"];
            [_profileData removeObjectForKey:@"facebookFriends"];
        }
        profileListView.profileData = _profileData;
        [self.navigationController pushViewController:profileListView animated:YES];
    }
    else {
        // finish sign-up
    }
    
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _usersArray.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    //NSLog(@"suggested user cell for index: %lu", (unsigned long)indexPath.row);
    UITableViewCell *tCell = [tableView dequeueReusableCellWithIdentifier:@"SuggestedUserCell" forIndexPath:indexPath];
    
    SuggestedUserCell *cell = (SuggestedUserCell *)tCell;
    
    NSDictionary *userDict = [[_usersArray objectAtIndex:indexPath.row] objectForKey:@"user"];
    cell.userId = [[userDict objectForKey:@"id"] objectForKey:@"$id"];
    NSArray *podcasts = [[_usersArray objectAtIndex:indexPath.row] objectForKey:@"podcasts"];
    
    // avatar
    NSString *avatarUrlString = [userDict objectForKey:@"small_av_url"];
    NSData *avatarImageData = [TungCommonObjects retrieveSmallAvatarDataWithUrlString:avatarUrlString];
    cell.avatarContainerView.backgroundColor = [UIColor clearColor];
    cell.avatarContainerView.avatar = nil;
    cell.avatarContainerView.avatar = [[UIImage alloc] initWithData:avatarImageData];
    cell.avatarContainerView.borderColor = [UIColor whiteColor];
    [cell.avatarContainerView setNeedsDisplay];
    
    // username & name
    cell.usernameLabel.text = [userDict objectForKey:@"username"];
    if (_tung.screenWidth < 375) {
        cell.usernameLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    }
    cell.subLabel.text = [userDict objectForKey:@"name"];
    
    // follow button
    cell.followBtn.type = kPillTypeFollow;
    cell.followBtn.backgroundColor = [UIColor clearColor];
    if ([_usersToFollow containsObject:cell.userId]) {
        cell.followBtn.on = YES;
    } else {
        cell.followBtn.on = NO;
    }
    [cell.followBtn setNeedsDisplay];
    [cell.followBtn addTarget:self action:@selector(followOrUnfollowUser:) forControlEvents:UIControlEventTouchUpInside];
    
    // recommended podcasts
    cell.iconView.type = kIconTypeTinyRecommend;
    [cell.iconView setNeedsDisplay];
    NSString *firstNameUpper = [[[[userDict objectForKey:@"name"] componentsSeparatedByString:@" "] objectAtIndex:0] uppercaseString];
    cell.mostReccdLabel.text = [NSString stringWithFormat:@"MOST RECOMMENDED BY %@", firstNameUpper];
    // remove any existing images/
    for (UIView *subview in cell.scrollView.subviews) {
        [subview removeFromSuperview];
    }
    // add podcast art image views
    int margin = 13;
    int separator = 3;
    CGRect imageViewRect = CGRectMake(margin, 0, 68, 68);
    CGSize contentSize = CGSizeMake(0, imageViewRect.size.height);
    for (int i = 0; i < podcasts.count; i++) {
        NSString *podcastArtUrlString = [[podcasts objectAtIndex:i] objectForKey:@"artworkUrlSSL"];
        NSNumber *podcastId = [[podcasts objectAtIndex:i] objectForKey:@"_id"];
        NSData *imgData = [TungCommonObjects retrievePodcastArtDataWithUrlString:podcastArtUrlString andCollectionId:podcastId];
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:imageViewRect];
        imgView.image = [UIImage imageWithData:imgData];
        [cell.scrollView addSubview:imgView];
        
        contentSize.width = imageViewRect.origin.x + imageViewRect.size.width;
        imageViewRect.origin.x += imageViewRect.size.width + separator;
    }
    contentSize.width += margin;
    cell.scrollView.contentSize = contentSize;
    
    return cell;
}

#pragma mark - Table view delegate methods

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 176;
}



#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    UIViewController *destination = segue.destinationViewController;
    
    if ([[segue identifier] isEqualToString:@"proceedToPlatformFriends"]) {
        // update profileData
        [_profileData setValue:[_usersToFollow componentsJoinedByString:@", "] forKey:@"usersToFollow"];
        // set value
        [destination setValue:_profileData forKey:@"profileData"];
        [destination setValue:@"platformFriends" forKey:@"queryType"];
    }
}

@end
