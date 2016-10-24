//
//  FindFriendsTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 5/10/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//

#import "FindFriendsTableViewController.h"
#import "SuggestedUserCell.h"
#import "IconCell.h"
#import "ProfileListTableViewController.h"
#import "FinishSignUpController.h"
#import "ProfileViewController.h"

@interface FindFriendsTableViewController ()

@property NSMutableArray *usersToFollow;
@property UILabel *subtitleLabel;
@property BOOL okayToProceed;

// for search
@property ProfileListTableViewController *profileSearchView;

@end

@implementation FindFriendsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    
    if (_profileData) { // onboarding
        
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
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Next" style:UIBarButtonItemStyleDone target:self action:@selector(proceedToNextView)];
        
        
        self.tableView.allowsSelection = NO;
    }
    else {
        //self.navigationItem.title = @"Find friends";
        
        _profileSearchView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileListView"];
        _profileSearchView.navController = [self navigationController];
        _profileSearchView.profileArray = [NSMutableArray array];
        
        [_profileSearchView initSearchController];
        self.navigationItem.titleView = _profileSearchView.searchController.searchBar;
        [self.navigationItem setRightBarButtonItem:nil animated:NO];
    }
    
    self.definesPresentationContext = YES;
    
    // notifs
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(followingChanged:) name:@"followingSuggestedUserChanged" object:nil];
    
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
    
    _usersToFollow = [NSMutableArray array];
    
    if (!_suggestedUsersArray) {
        // get users
        [_tung getSuggestedUsersWithCallback:^(BOOL success, NSDictionary *response) {
            self.tableView.backgroundView = nil;
            if (success) {
                _suggestedUsersArray = [response objectForKey:@"success"];
                [self preloadImages];
                [_tung preloadAlbumArtForSuggestedUsers:_suggestedUsersArray];
                [self.tableView reloadData];
                
                if (_profileData) { // if onboarding
                	// see if user should proceed to platform friends or finish
                	[self checkForPlatformFriends];
                }
            }
            else {
                // other error - alert user
                [TungCommonObjects simpleErrorAlertWithMessage:[response objectForKey:@"error"]];
            }
        }];
    }
    else {
        [self preloadImages];
    }
    // if onboarding
    if (_profileData) {
        // see if user should proceed to platform friends or finish
        [self checkForPlatformFriends];
        
    }
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.definesPresentationContext = YES;
    
    if ([_profileSearchView.searchController isActive]) {
        [_profileSearchView.searchController.searchBar setShowsCancelButton:YES];
    } else {
        [_profileSearchView.searchController.searchBar setShowsCancelButton:NO];
    }

}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.definesPresentationContext = NO;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _tung.viewController = self;
    [self.navigationController.navigationBar setTitleTextAttributes:@{ NSForegroundColorAttributeName:[TungCommonObjects tungColor] }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (BOOL)prefersStatusBarHidden
{
    if (_profileData) {
    	return YES;
    } else {
        return NO;
    }
}

- (void) preloadImages {
    
    NSOperationQueue *preloadQueue = [[NSOperationQueue alloc] init];
    preloadQueue.maxConcurrentOperationCount = 3;
    
    NSMutableArray *artworkUrls = [NSMutableArray array];
    
    for (int i = 0; i < _suggestedUsersArray.count; i++) {
        
        NSDictionary *dict = [_suggestedUsersArray objectAtIndex:i];
        NSString *avatarURLString = [[dict objectForKey:@"user"] objectForKey:@"small_av_url"];
        [preloadQueue addOperationWithBlock:^{
            //NSLog(@"preload avatar: %@", avatarURLString);
            [TungCommonObjects retrieveSmallAvatarDataWithUrlString:avatarURLString];
        }];
        NSArray *podcasts = [dict objectForKey:@"podcasts"];
        for (int j = 0; j < podcasts.count; j++) {
            NSString *podcastArtUrlString = [[podcasts objectAtIndex:j] objectForKey:@"artworkUrlSSL"];
            [artworkUrls addObject:podcastArtUrlString];
        }
    }

    NSOrderedSet *orderedArtSet = [NSOrderedSet orderedSetWithArray:artworkUrls];
    NSArray *dedupedArtUrls = [orderedArtSet array];
    
    for (int j = 0; j < dedupedArtUrls.count; j++) {
        
        [preloadQueue addOperationWithBlock:^{
            
            NSString *podcastArtUrlString = [dedupedArtUrls objectAtIndex:j];
            //NSLog(@"preload artwork: %@", podcastArtUrlString);
            [TungCommonObjects retrievePodcastArtDataWithSSLUrlString:podcastArtUrlString];
        }];
    }
}

- (void) followingChanged:(NSNotification*)notification {
    
    PillButton *btn = [[notification userInfo] objectForKey:@"sender"];
    
    if (_profileData) { // onboarding
        
        if ([[notification userInfo] objectForKey:@"unfollowedUser"]) {
            // unfollow
            [_usersToFollow removeObject:[[notification userInfo] objectForKey:@"unfollowedUser"]];
            btn.on = NO;
            [btn setNeedsDisplay];
        }
        if ([[notification userInfo] objectForKey:@"followedUser"]) {
            // follow
            NSString *userId = [[notification userInfo] objectForKey:@"followedUser"];
            if (![_usersToFollow containsObject:userId]) {
                [_usersToFollow addObject:userId];
            }
        }
        // update subtitle
        NSInteger result = NUM_REQUIRED_FOLLOWS - _usersToFollow.count;
        if (result <= 0) {
            _okayToProceed = YES;
        } else {
            _okayToProceed = NO;
        }
        if (_okayToProceed) {
        	_subtitleLabel.text = @"Good to go!";
        } else {
            _subtitleLabel.text = [NSString stringWithFormat:@"%ld remaining", (long)result];
        }
    }
    else {
        
        if ([[notification userInfo] objectForKey:@"unfollowedUser"]) {
            
            UIAlertController *unfollowConfirmAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Unfollow @%@?", [[notification userInfo] objectForKey:@"username"]] message:nil preferredStyle:UIAlertControllerStyleAlert];
            [unfollowConfirmAlert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                
                btn.on = NO;
                [btn setNeedsDisplay];
                NSString *userId = [[notification userInfo] objectForKey:@"unfollowedUser"];
                // unfollow
                [_tung unfollowUserWithId:userId withCallback:^(BOOL success, NSDictionary *response) {
                    if (success) {
                        if (![response objectForKey:@"userNotFollowing"]) {
                            _tung.feedNeedsRefetch = [NSNumber numberWithBool:YES]; // following changed
                            NSNotification *followingCountChangedNotif = [NSNotification notificationWithName:@"followingCountChanged" object:nil userInfo:response];
                            [[NSNotificationCenter defaultCenter] postNotification:followingCountChangedNotif];
                        }
                    }
                    else {
                        btn.on = YES;
                        [btn setNeedsDisplay];
                    }
                }];
                
            }]];
            [unfollowConfirmAlert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:nil]];
            if ([TungCommonObjects iOSVersionFloat] >= 9.0) {
            	unfollowConfirmAlert.preferredAction = [unfollowConfirmAlert.actions objectAtIndex:1];
            }
            [self presentViewController:unfollowConfirmAlert animated:YES completion:nil];

        }
        if ([[notification userInfo] objectForKey:@"followedUser"]) {
            NSString *userId = [[notification userInfo] objectForKey:@"followedUser"];
            // follow
            [_tung followUserWithId:userId withCallback:^(BOOL success, NSDictionary *response) {
                if (success) {
                    NSLog(@"successfully followed user from friends");
                    if (![response objectForKey:@"userAlreadyFollowing"]) {
                        _tung.feedNeedsRefresh = [NSNumber numberWithBool:YES]; // following changed
                        NSNotification *followingCountChangedNotif = [NSNotification notificationWithName:@"followingCountChanged" object:nil userInfo:response];
                        [[NSNotificationCenter defaultCenter] postNotification:followingCountChangedNotif];
                    }
                }
                else {
                    btn.on = NO;
                    [btn setNeedsDisplay];
                }
            }];
        }
    }
}

// see if user has any friends on tung from the service they signed up with.
- (void) checkForPlatformFriends {
    
    if ([_profileData objectForKey:@"twitter_id"]) {
        
        [_tung findTwitterFriendsWithPage:[NSNumber numberWithInt:0] andCallback:^(BOOL success, NSDictionary *responseDict) {
            if (success) {
                //NSLog(@"responseDict: %@", responseDict);
                NSNumber *platformFriendsCount = [responseDict objectForKey:@"resultsCount"];
                if ([platformFriendsCount integerValue] > 0) {
                    [_profileData setObject:[responseDict objectForKey:@"results"] forKey:@"twitterFriends"];
                }
            }
        }];
        
    }
    else if ([_profileData objectForKey:@"facebook_id"]) {

        
        if ([FBSDKAccessToken currentAccessToken]) {
            
            NSString *tokenString = [[FBSDKAccessToken currentAccessToken] tokenString];
            [_tung findFacebookFriendsWithFacebookAccessToken:tokenString withCallback:^(BOOL success, NSDictionary *responseDict) {
                //NSLog(@"responseDict: %@", responseDict);
                NSNumber *platformFriendsCount = [responseDict objectForKey:@"resultsCount"];
                if ([platformFriendsCount integerValue] > 0) {
                    [_profileData setObject:[responseDict objectForKey:@"results"] forKey:@"facebookFriends"];
                }
                
            }];
        }
    }
    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_profileData) {
    	return 1;
    } else {
        return 2;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0 && !_profileData) {
        return 2;
    }
    else if ((section == 0 && _profileData) || section == 1) {
    	return _suggestedUsersArray.count;
    }
    else {
        return 0;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    
    if (indexPath.section == 0 && !_profileData) {
        
        cell = [tableView dequeueReusableCellWithIdentifier:@"IconCell" forIndexPath:indexPath];
        IconCell *iCell = (IconCell *)cell;
        
        if (indexPath.row == 0) {
            iCell.iconView.type = kIconTypeTwitter;
            iCell.iconView.color = [TungCommonObjects twitterColor];
            iCell.titleLabel.text = @"Find Twitter friends";
        }
        else if (indexPath.row == 1) {
            iCell.iconView.type = kIconTypeFacebook;
            iCell.iconView.color = [TungCommonObjects facebookColor];
            iCell.titleLabel.text = @"Find Facebook friends";
        }
    }
    else if ((indexPath.section == 0 && _profileData) || indexPath.section == 1) {

        //NSLog(@"suggested user cell for index: %lu", (unsigned long)indexPath.row);
        cell = [tableView dequeueReusableCellWithIdentifier:@"SuggestedUserCell" forIndexPath:indexPath];
        NSMutableDictionary *cellDict = [_suggestedUsersArray objectAtIndex:indexPath.row];
        
        SuggestedUserCell *suCell = (SuggestedUserCell *)cell;
        
        NSMutableDictionary *userDict = [NSMutableDictionary dictionaryWithDictionary:[cellDict objectForKey:@"user"]];
        suCell.userId = [[userDict objectForKey:@"id"] objectForKey:@"$id"];
        suCell.username = [userDict objectForKey:@"username"];
        if (_profileData) {
            NSNumber *userFollows;
            if ([_usersToFollow containsObject:suCell.userId]) {
                userFollows = [NSNumber numberWithBool:YES];
            } else {
                userFollows = [NSNumber numberWithBool:NO];
            }
            [userDict setObject:userFollows forKey:@"userFollows"];
        }
        NSArray *podcasts = [cellDict objectForKey:@"podcasts"];
        
        // avatar
        NSString *avatarUrlString = [userDict objectForKey:@"small_av_url"];
        NSData *avatarImageData = [TungCommonObjects retrieveSmallAvatarDataWithUrlString:avatarUrlString];
        suCell.avatarContainerView.backgroundColor = [UIColor clearColor];
        suCell.avatarContainerView.avatar = nil;
        suCell.avatarContainerView.avatar = [[UIImage alloc] initWithData:avatarImageData];
        suCell.avatarContainerView.borderColor = [UIColor whiteColor];
        [suCell.avatarContainerView setNeedsDisplay];
        
        // username & name
        suCell.usernameLabel.text = suCell.username;
        if ([TungCommonObjects screenSize].width < 375) {
            suCell.usernameLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        }
        suCell.subLabel.text = [userDict objectForKey:@"name"];
        
        // follow button
        if (!_profileData && [_tung.loggedInUser.tung_id isEqualToString:[[userDict objectForKey:@"id"] objectForKey:@"$id"]]) {
            suCell.followBtn.hidden = YES;
            suCell.youLabel.hidden = NO;
        }
        else {
            // user/user relationship
            NSNumber *userFollows = [userDict objectForKey:@"userFollows"];
            if (userFollows.boolValue) {
                suCell.followBtn.on = YES;
            } else {
                suCell.followBtn.on = NO;
            }
            
            suCell.followBtn.hidden = NO;
            suCell.youLabel.hidden = YES;
        }
        [suCell.followBtn setNeedsDisplay];
        
        // recommended podcasts
        suCell.iconView.type = kIconTypeTinyRecommend;
        [suCell.iconView setNeedsDisplay];
        NSString *firstNameUpper = [[[[userDict objectForKey:@"name"] componentsSeparatedByString:@" "] objectAtIndex:0] uppercaseString];
        suCell.mostReccdLabel.text = [NSString stringWithFormat:@"MOST RECOMMENDED BY %@", firstNameUpper];
        // remove any existing images
        for (UIView *subview in suCell.scrollView.subviews) {
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
            [suCell.scrollView addSubview:imgView];
            
            contentSize.width = imageViewRect.origin.x + imageViewRect.size.width;
            imageViewRect.origin.x += imageViewRect.size.width + separator;
        }
        contentSize.width += margin;
        suCell.scrollView.contentSize = contentSize;
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    if (section == 0 && !_profileData) {
        return @"Find Friends";
    }
    else if (section == 1 && !_profileData) {
        return @"Suggested Users";
    }
    else {
        return [NSString stringWithFormat:@"Follow %d suggested users", NUM_REQUIRED_FOLLOWS];
    }
}

#pragma mark - Table view delegate methods

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && !_profileData) {
        return 60;
    }
    else {
    	return 176;
    }
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        if (!_profileData && indexPath.row == 0) {
            // Twitter
            if ([Twitter sharedInstance].sessionStore.session) {
                
                [self pushTwitterFriends];
                
            } else {
                [[Twitter sharedInstance] logInWithCompletion:^(TWTRSession *session, NSError *error) {
                    if (session) {
                        [self pushTwitterFriends];
                    }
                }];
            }
        }
        else if (!_profileData && indexPath.row == 1) {
            // Facebook
            if ([FBSDKAccessToken currentAccessToken]) {
                
                [self pushFacebookFriends];
            }
            else {
                [_tung getFacebookFriendsListPermissionsWithSuccessCallback:^{
                    [self pushFacebookFriends];
                }];
            }
        }
    }
    else {
        if (!_profileData) {
            NSDictionary *cellDict = [_suggestedUsersArray objectAtIndex:indexPath.row];
            NSDictionary *userDict = [cellDict objectForKey:@"user"];
            NSString *userId = [[userDict objectForKey:@"id"] objectForKey:@"$id"];
            ProfileViewController *profileView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"profileView"];
            profileView.profiledUserId = userId;
            [self.navigationController pushViewController:profileView animated:YES];
        }
    }
}

- (void) pushTwitterFriends {
    ProfileListTableViewController *twitterFriendsView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileListView"];
    twitterFriendsView.queryType = @"Twitter";
    [self.navigationController pushViewController:twitterFriendsView animated:YES];
}

- (void) pushFacebookFriends {
    ProfileListTableViewController *facebookFriendsView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileListView"];
    facebookFriendsView.queryType = @"Facebook";
    [self.navigationController pushViewController:facebookFriendsView animated:YES];
}


- (void) proceedToNextView {
    
    if (_okayToProceed) {
        
        if ([_profileData objectForKey:@"twitterFriends"] || [_profileData objectForKey:@"facebookFriends"]) {
            // platform friends
            ProfileListTableViewController *profileListView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileListView"];
            profileListView.profileData = _profileData;
            profileListView.usersToFollow = _usersToFollow;
            [self.navigationController pushViewController:profileListView animated:YES];
        }
        else {
            // finish sign-up
            FinishSignUpController *finishView = [self.storyboard instantiateViewControllerWithIdentifier:@"finishSignup"];
            finishView.profileData = _profileData;
            finishView.usersToFollow = _usersToFollow;
            [self.navigationController pushViewController:finishView animated:YES];
        }
    }
    else {
        // user needs to follow at least X people
        UIAlertController *followMoreAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Follow %d", NUM_REQUIRED_FOLLOWS] message:[NSString stringWithFormat:@"Please follow at least %d accounts by tapping the \"Follow\" buttons before proceeding.", NUM_REQUIRED_FOLLOWS] preferredStyle:UIAlertControllerStyleAlert];
        [followMoreAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:followMoreAlert animated:YES completion:nil];
        
    }
    
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
//    UIViewController *destination = segue.destinationViewController;
    
//    if ([[segue identifier] isEqualToString:@""]) {
//        // update profileData
//        [_profileData setValue:[_usersToFollow componentsJoinedByString:@", "] forKey:@"usersToFollow"];
//        // set value
//        [destination setValue:_profileData forKey:@"profileData"];
//    }
}

@end
