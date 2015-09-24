//
//  ProfileTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 8/7/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "ProfileTableViewController.h"
#import "TungStories.h"
#import "ProfileCell.h"
#import "FollowersCell.h"
#import "ProfileListTableViewController.h"
#import "ProfileSearchTableViewController.h"

//#import <FacebookSDK/FacebookSDK.h>

@interface ProfileTableViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) TungStories *stories;

@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;

@property (strong, nonatomic) UIBarButtonItem *btn_seekBack;
@property (strong, nonatomic) UIBarButtonItem *btn_loop;
@property (strong, nonatomic) UIBarButtonItem *btn_playPause;
@property (strong, nonatomic) UIBarButtonItem *btn_seekForward;

// Unique to ProfileTableViewController:

@property (nonatomic, assign) BOOL isLoggedInUser;
@property (strong, nonatomic) NSArray *profileControls;
@property (strong, nonatomic) NSString *profileURLString;
@property (strong, nonatomic) UIBarButtonItem *headerLabel;

@property BOOL hasUserData;

@end

@implementation ProfileTableViewController

CGFloat screenWidth;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    _tung.viewController = self;
    
    _stories = [TungStories new];
    
    // set defaults for required properties
    if (!_profiledUserId) _profiledUserId = _tung.tungId;
    
    // check if the profiled user is themself
    if ([_tung.tungId isEqualToString:_profiledUserId]) {
        _isLoggedInUser = YES;
        NSLog(@"is logged in user");
    }
    
    if (!screenWidth) screenWidth = self.view.frame.size.width;
    
    _profileControls = @[@"Find friends", @"Activity", @"Sign-out"];
    
    // table view
    UIActivityIndicatorView *behindTable = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    behindTable.alpha = 1;
    [behindTable startAnimating];
    self.tableView.backgroundView = behindTable;
    self.tableView.backgroundColor = _tung.bkgdGrayColor;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.scrollsToTop = YES;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0);
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 35, 0);
    
    // refresh control
	self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
    
    _hasUserData = [TungCommonObjects checkForUserData];
    
    [TungCommonObjects checkReachabilityWithCallback:^(BOOL reachable) {
        if (reachable) {
            if (_tung.sessionId && _tung.sessionId.length > 0) {
    			[self requestPageData];
            }
            else {
                [_tung getSessionWithCallback:^{
                    [self requestPageData];
                }];
            }
        }
        // unreachable
        else {
            UIAlertView *noReachabilityAlert = [[UIAlertView alloc] initWithTitle:@"No Connection" message:@"tung requires an internet connection" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
            [noReachabilityAlert setTag:49];
            [noReachabilityAlert show];
        }
    }];
    
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

}

- (void) viewDidAppear:(BOOL)animated {

    [super viewDidAppear:animated];
    
    _tung.ctrlBtnDelegate = self;
    _tung.viewController = self;

}
- (void) viewWillDisappear:(BOOL)animated {

    
    [super viewWillDisappear:animated];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) requestPageData {
    
    // make sure user has there own data saved
    if (!_hasUserData) {
        // restore logged in user data
        [_tung getProfileDataForUser:_tung.tungId withCallback:^(NSDictionary *jsonData) {
            if (jsonData != nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"user"]) {
                    NSLog(@"got user: %@", [responseDict objectForKey:@"user"]);
                    [TungCommonObjects saveUserWithDict:[responseDict objectForKey:@"user"]];
                    _hasUserData = YES;
                    _profiledUserData = [[responseDict objectForKey:@"user"] mutableCopy];
                    self.navigationItem.title = [_profiledUserData objectForKey:@"username"];
                    [self.tableView reloadData];
                    [self refreshFeed];
                }
            }
        }];
    }
    else {
    
        if (_isLoggedInUser) {
            _profiledUserData = [[_tung getLoggedInUserData] mutableCopy];
            [_profiledUserData setObject:@"" forKey:@"followingCount"];
            [_profiledUserData setObject:@"" forKey:@"followerCount"];
            self.navigationItem.title = [_profiledUserData objectForKey:@"username"];
            [self.tableView reloadData];
            // request profile just to get current follower/following counts
            [_tung getProfileDataForUser:_tung.tungId withCallback:^(NSDictionary *jsonData) {
                if (jsonData != nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"user"]) {
                        _profiledUserData = [[responseDict objectForKey:@"user"] mutableCopy];
                        [self.tableView reloadData];
            			[self refreshFeed];
                    }
                }
            }];
        }
        else {
            [_tung getProfileDataForUser:_profiledUserId withCallback:^(NSDictionary *jsonData) {
                if (jsonData != nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"user"]) {
                        _profiledUserData = [[responseDict objectForKey:@"user"] mutableCopy];
                        NSLog(@"profiled user data established");
                        //_tungStereo.profiledUserData = _profiledUserData;
                        // navigation bar title
                        self.navigationItem.title = [_profiledUserData objectForKey:@"username"];
                        [self.tableView reloadData];
                        
                        [self refreshFeed];
                    }
                    else if ([responseDict objectForKey:@"error"]) {
                        UIAlertView *profileErrorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:[responseDict objectForKey:@"error"] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [profileErrorAlert show];
                        // TODO: user not found, if user was deleted
                    }
                }
            }];
        }
    }
}

- (void) refreshFeed {
    /*
    [_tungStereo requestPostsNewerThan:mostRecent
                           orOlderThan:[NSNumber numberWithInt:0]
                              fromUser:_profiledUserId
                            orCategory:_profiledCategory
                        withSearchTerm:_searchTerm];
     */
}

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 49) [self refreshFeed]; // unreachable, retry
}

- (void) selectedProfileControlAtIndex:(NSInteger)index {
    long controlIndex = index - 2;

    switch (controlIndex) {
        case 0: { // find friends
            //[self performSegueWithIdentifier:@"presentDraftsView" sender:self];
            break;
        }
        case 1: {// activity
            
            break;
        }
        case 2: {// sign out
            UIActionSheet *signOutSheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"You are running v%@ of tung.", _tung.tung_version] delegate:_tung cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Sign out" otherButtonTitles:nil];
            [signOutSheet setTag:99];
            [signOutSheet showFromToolbar:self.navigationController.toolbar];
            break;
        }
    }
}
- (void) viewFollowers {
    NSLog(@"view followers");
    [self pushProfileListForTargetId:_profiledUserId andQuery:@"Followers"];
}
- (void) viewFollowing {
    NSLog(@"view following");
    if ([[_profiledUserData objectForKey:@"followingCount"] integerValue] > 0)
    	[self pushProfileListForTargetId:_profiledUserId andQuery:@"Following"];
}

- (void) pushProfileListForTargetId:(NSString *)target_id andQuery:(NSString *)query {
     ProfileListTableViewController *profileListView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileListView"];
     profileListView.target_id = target_id;
     profileListView.queryType = query;
     [self.navigationController pushViewController:profileListView animated:YES];
}


- (void) openProfileUrl {
    NSLog(@"open url %@", _profileURLString);
    NSURL *url = [NSURL URLWithString:_profileURLString];
    [[UIApplication sharedApplication] openURL:url];
}

- (void) editProfile {
    NSLog(@"edit profile");
    [self performSegueWithIdentifier:@"presentEditProfileView" sender:self];
}

- (void) followOrUnfollowUser {
    NSNumber *userFollowsStartingValue = [_profiledUserData objectForKey:@"userFollows"];
    NSNumber *followersStartingValue = [_profiledUserData objectForKey:@"followerCount"];
    BOOL follows = [userFollowsStartingValue boolValue];
    if (follows) {
        // unfollow
    	[_tung unfollowUserWithId:_profiledUserId withCallback:^(BOOL success) {
            if (!success) {// fail
                NSLog(@"error unfollowing user");
                [_profiledUserData setValue:userFollowsStartingValue forKey:@"userFollows"];
                [_profiledUserData setValue:followersStartingValue forKey:@"followerCount"];
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:1 inSection:0]; // follow cell
                [self.tableView beginUpdates];
                [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationNone];
                [self.tableView endUpdates];
            }
            else {
                NSLog(@"successfully unfollowed user");
            }
        }];
        [_profiledUserData setValue:[NSNumber numberWithInt:0] forKey:@"userFollows"];
        [_profiledUserData setValue:[NSNumber numberWithInt:[followersStartingValue intValue] -1] forKey:@"followerCount"];
    }
    else {
        // follow
        [_tung followUserWithId:_profiledUserId withCallback:^(BOOL success) {
            if (!success) {// fail
                NSLog(@"error following user");
                [_profiledUserData setValue:userFollowsStartingValue forKey:@"userFollows"];
                [_profiledUserData setValue:followersStartingValue forKey:@"followerCount"];
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:1 inSection:0]; // follow cell
                [self.tableView beginUpdates];
                [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationNone];
                [self.tableView endUpdates];
            }
            else {
                NSLog(@"success following user");
            }
        }];
        [_profiledUserData setValue:[NSNumber numberWithInt:1] forKey:@"userFollows"];
        [_profiledUserData setValue:[NSNumber numberWithInt:[followersStartingValue intValue] +1] forKey:@"followerCount"];
    }
    // GUI
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:1 inSection:0]; // follow cell
    [self.tableView beginUpdates];
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView endUpdates];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        // don't show the profile cell(s) until we have data
        if (_profiledUserData.count > 0)
            if (_isLoggedInUser)
            	return 2 + _profileControls.count;
        	else
                return 2;
        else
            return 0;
    }
    // clips
    else if (section == 1) {
        return 0; //return [_tungStereo.clipArray count];
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"--- cell %lu section %ld", (long)indexPath.row, (long)indexPath.section);
    
    if (indexPath.section == 0) {
        // Profile cell
        if (indexPath.row == 0) {
            NSLog(@"Drawing profile cell for %@", [_profiledUserData objectForKey:@"name"]);
            static NSString *profileCellIdentifier = @"ProfileCell";
            ProfileCell *cell = (ProfileCell *)[tableView dequeueReusableCellWithIdentifier:profileCellIdentifier];
            
            // scroll view
            CGRect scrollViewRect = CGRectMake(0, 0, screenWidth, 168);
            
            if (cell.profileScrollView == nil) {
                cell.profileScrollView = [[UIScrollView alloc] initWithFrame:scrollViewRect];
                cell.profileScrollView.pagingEnabled = YES;
                cell.profileScrollView.delegate = self;
                cell.profileScrollView.showsHorizontalScrollIndicator = NO;
                cell.profileScrollView.contentSize = CGSizeMake(scrollViewRect.size.width * 2, scrollViewRect.size.height);
                [cell addSubview:cell.profileScrollView];
                
                cell.scrollSubViewOne = [[UIView alloc] initWithFrame:scrollViewRect];
                [cell.profileScrollView addSubview:cell.scrollSubViewOne];
            }
            
            // large avatar
            if (cell.largeAvView == nil) {
                NSLog(@"largeAvView was nil");
                cell.largeAvView = [[LargeAvatarContainerView alloc] initWithFrame:CGRectMake(12, 20, 130, 130)];
                [cell.scrollSubViewOne addSubview:cell.largeAvView];
            }
            NSString *largeAvatarFilename = [[_profiledUserData objectForKey:@"large_av_url"] lastPathComponent];
            [[NSFileManager defaultManager] createDirectoryAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"/large/"] withIntermediateDirectories:YES attributes:nil error:nil];
            
            NSString *largeAvatarFilepath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"/large/%@", largeAvatarFilename]];
            //NSLog(@"large av file path: %@", largeAvatarFilepath);
            
            NSData *largeAvatarImageData;
            if ([[NSFileManager defaultManager] fileExistsAtPath:largeAvatarFilepath]) {
                largeAvatarImageData = [NSData dataWithContentsOfFile:largeAvatarFilepath];
                NSLog(@"	file was cached in temp dir. data size: %lu", (unsigned long)largeAvatarImageData.length);
            } else {
                largeAvatarImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString: [_profiledUserData objectForKey:@"large_av_url"]]];
                NSLog(@"	file will be downloaded: %@", [_profiledUserData objectForKey:@"large_av_url"]);
                NSLog(@"	data size: %lu", (unsigned long)largeAvatarImageData.length);
                [largeAvatarImageData writeToFile:largeAvatarFilepath atomically:YES];
            }
            cell.largeAvView.backgroundColor = [UIColor clearColor];
            UIImage *largeAvImage = [[UIImage alloc] initWithData:largeAvatarImageData];
            cell.largeAvView.avatar = largeAvImage;
            [cell.largeAvView setNeedsDisplay];
            
            // selected color
            /*
            UIView *bgColorView = [[UIView alloc] init];
            bgColorView.backgroundColor = [_tungObjects.mediumDarkCategoryColors objectAtIndex:selCat];
            [clipCell setSelectedBackgroundView:bgColorView];
             */
            
            // name
            int infoHeight = 26;
            CGFloat labelFrameWidth = scrollViewRect.size.width - 171;
            CGRect labelFrame = CGRectMake(157, 51, labelFrameWidth, 26);
            [cell.nameLabel removeFromSuperview];
            cell.nameLabel = nil;
            if (cell.nameLabel == nil) {
                cell.nameLabel = [[UILabel alloc] initWithFrame:labelFrame];
                cell.nameLabel.font = [UIFont systemFontOfSize:18];
                cell.nameLabel.textColor = [UIColor whiteColor];
                cell.nameLabel.adjustsFontSizeToFitWidth = YES;
                cell.nameLabel.text = [_profiledUserData objectForKey:@"name"];
            }
            // location
            [cell.locationLabel removeFromSuperview];
            cell.locationLabel = nil;
            if ([[_profiledUserData objectForKey:@"location"] length] > 0) {
                if (cell.locationLabel == nil) {
                    infoHeight += 26;
                    labelFrame.origin.y += 26;
                    cell.locationLabel = [[UILabel alloc] initWithFrame:labelFrame];
                    cell.locationLabel.font = [UIFont systemFontOfSize:15];
                    cell.locationLabel.textColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:.4];
                    cell.locationLabel.adjustsFontSizeToFitWidth = YES;
                }
                cell.locationLabel.text = [_profiledUserData objectForKey:@"location"];
            }
            
            // url
            NSString *url = [_profiledUserData objectForKey:@"url"];
            [cell.urlLabel removeFromSuperview];
            [cell.urlButton removeFromSuperview];
            cell.urlLabel = nil;
            cell.urlButton = nil;
            if ([url length] > 0) {
                if (cell.urlLabel == nil) {
                    _profileURLString = url;
                    infoHeight += 26;
                    labelFrame.origin.y += 26;
                    cell.urlLabel = [[UILabel alloc] initWithFrame:labelFrame];
                    cell.urlLabel.font = [UIFont systemFontOfSize:15];
                    cell.urlLabel.textColor = [UIColor colorWithWhite:1 alpha:.75];
                    cell.urlLabel.adjustsFontSizeToFitWidth = YES;
                    cell.urlButton = [UIButton buttonWithType:UIButtonTypeCustom];
                    cell.urlButton.frame = labelFrame;
                    [cell.urlButton addTarget:self action:@selector(openProfileUrl) forControlEvents:UIControlEventTouchUpInside];
                }
                cell.urlLabel.text = [TungCommonObjects cleanURLStringFromString:url];
            }
            
            // center labels vertically
            if (![cell.nameLabel isDescendantOfView:cell]) {
                int offset = (168-infoHeight)/2 - cell.nameLabel.frame.origin.y;
                CGRect newNameLabelFrame = cell.nameLabel.frame;
                newNameLabelFrame.origin.y += offset;
                cell.nameLabel.frame = newNameLabelFrame;
                CGRect newLocationLabelFrame = cell.locationLabel.frame;
                newLocationLabelFrame.origin.y += offset;
                cell.locationLabel.frame = newLocationLabelFrame;
                CGRect newUrlLabelFrame = cell.urlLabel.frame;
                newUrlLabelFrame.origin.y += offset;
                cell.urlLabel.frame = newUrlLabelFrame;
                cell.urlButton.frame = newUrlLabelFrame;
                [cell.scrollSubViewOne addSubview:cell.nameLabel];
                if ([[_profiledUserData objectForKey:@"location"] length] > 0) [cell.scrollSubViewOne addSubview:cell.locationLabel];
                if ([[_profiledUserData objectForKey:@"url"] length] > 0) {
            		[cell.scrollSubViewOne addSubview:cell.urlLabel];
                    [cell.scrollSubViewOne addSubview:cell.urlButton];
                }
            }
            
            // bio
            if ([[_profiledUserData objectForKey:@"bio"] length] > 0) {
                if (cell.scrollSubViewTwo == nil) {
                    
                    scrollViewRect.origin.x += scrollViewRect.size.width;
                    cell.scrollSubViewTwo = [[UIView alloc] initWithFrame:scrollViewRect];
                    [cell.profileScrollView addSubview:cell.scrollSubViewTwo];
                    
                    // STTweetLabel implementation
                    cell.bioLabel = [[STTweetLabel alloc] init];
                    cell.bioLabel.selectionColor = [UIColor clearColor];
                    NSDictionary *bioAttributes = @{
                                                    NSForegroundColorAttributeName:[UIColor whiteColor],
                                                    NSFontAttributeName: [UIFont systemFontOfSize:17]
                                                    };
                    [cell.bioLabel setAttributes:bioAttributes];
                    NSDictionary *hotwordAttributes = @{
                                                        NSForegroundColorAttributeName:[UIColor colorWithWhite:1 alpha:.6],
                                                        NSFontAttributeName: [UIFont systemFontOfSize:17]
                                                        };
                    [cell.bioLabel setAttributes:hotwordAttributes hotWord:STTweetHandle];
                    [cell.bioLabel setAttributes:hotwordAttributes hotWord:STTweetHashtag];
                    [cell.bioLabel setAttributes:hotwordAttributes hotWord:STTweetLink];
                    
                    /* TODO: FIX HOTWORDS
                    [cell.bioLabel setDetectionBlock:^(STTweetHotWord hotWord, NSString *string, NSString *protocol, NSRange range) {
                        NSArray *hotWords = @[@"Handle", @"Hashtag", @"Link"];
                        
                        [_tungStereo handleHotWordTapForType:hotWords[hotWord] andHotword:string];
                     
                    }];*/
                }
                [cell.bioLabel removeFromSuperview];
                // bio label text, size, position
                cell.bioLabel.text = [_profiledUserData objectForKey:@"bio"];
                cell.bioLabel.textAlignment = NSTextAlignmentCenter;
                CGFloat bioLabelMaxWidth = scrollViewRect.size.width - 30;
                CGSize bioLabelSize = [cell.bioLabel suggestedFrameSizeToFitEntireStringConstraintedToWidth:bioLabelMaxWidth];
                //NSLog(@"suggested bio label size: %@", NSStringFromCGSize(bioLabelSize));
                double yPos = (168 - bioLabelSize.height) / 2;
                double xPos = (scrollViewRect.size.width - bioLabelSize.width) / 2;
                CGPoint bioLabelPoint = CGPointMake(xPos, yPos);
                CGRect bioLabelFrame = {bioLabelPoint, bioLabelSize};
                cell.bioLabel.frame = bioLabelFrame;
                
                [cell.scrollSubViewTwo addSubview:cell.bioLabel];
            }
            else {
                
                cell.profileScrollView.contentSize = CGSizeMake(scrollViewRect.size.width, scrollViewRect.size.height);
                cell.profilePageControl.hidden = YES;
            }
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            // kill insets for iOS 8
            if ([[UIDevice currentDevice].systemVersion floatValue] >= 8) {
                cell.preservesSuperviewLayoutMargins = NO;
                [cell setLayoutMargins:UIEdgeInsetsZero];
            }
            // iOS 7 and later
            if ([cell respondsToSelector:@selector(setSeparatorInset:)])
                [cell setSeparatorInset:UIEdgeInsetsZero];
            
            return cell;
        }
        // Followers cell
        if (indexPath.row == 1) {
            NSLog(@"followers cell");
            static NSString *followersCellIdentifier = @"FollowersCell";
            FollowersCell *fCell = (FollowersCell *)[tableView dequeueReusableCellWithIdentifier:followersCellIdentifier];
            // following
            NSString *followingString = [TungCommonObjects formatNumberForCount:[_profiledUserData objectForKey:@"followingCount"]];
            [fCell.followingCountBtn setTitle:followingString forState:UIControlStateNormal];
            [fCell.followingCountBtn addTarget:self action:@selector(viewFollowing) forControlEvents:UIControlEventTouchUpInside];
            // followers
            [fCell.followerCountBtn setTitle:[TungCommonObjects formatNumberForCount:[_profiledUserData objectForKey:@"followerCount"]] forState:UIControlStateNormal];
            [fCell.followerCountBtn addTarget:self action:@selector(viewFollowers) forControlEvents:UIControlEventTouchUpInside];
            // button
            fCell.followBtn.backgroundColor = [UIColor clearColor];
            if (_isLoggedInUser) {
                [fCell.followBtn addTarget:self action:@selector(editProfile) forControlEvents:UIControlEventTouchUpInside];
            } else {
                [fCell.followBtn addTarget:self action:@selector(followOrUnfollowUser) forControlEvents:UIControlEventTouchUpInside];
                BOOL follows = [[_profiledUserData objectForKey:@"userFollows"] boolValue];
                if (follows) {
                	fCell.followBtn.buttonText = @"Following";
                    fCell.followBtn.isOn = YES;
                }
                else {
                    fCell.followBtn.buttonText = @"Follow";
                }
            }
            
            fCell.selectionStyle = UITableViewCellSelectionStyleNone;
            // kill insets for iOS 8
            if ([[UIDevice currentDevice].systemVersion floatValue] >= 8) {
                fCell.preservesSuperviewLayoutMargins = NO;
                [fCell setLayoutMargins:UIEdgeInsetsZero];
            }
            // iOS 7 and later
            if ([fCell respondsToSelector:@selector(setSeparatorInset:)])
                [fCell setSeparatorInset:UIEdgeInsetsZero];
            
            return fCell;
        }
        // Profile Control Cell
        else {
            NSLog(@"profile control cell");
            static NSString *controlCellIdentifier = @"ProfileControlCell";
            UITableViewCell *cCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:controlCellIdentifier];
            cCell.textLabel.textColor = _tung.tungColor;
            cCell.textLabel.text = [_profileControls objectAtIndex:indexPath.row -2];
            cCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cCell.backgroundColor = [UIColor whiteColor];
            /*
            // kill insets for iOS 8
            if ([[UIDevice currentDevice].systemVersion floatValue] >= 8) {
                cCell.preservesSuperviewLayoutMargins = NO;
                [cCell setLayoutMargins:UIEdgeInsetsZero];
            }
            // iOS 7 and later
            if ([cCell respondsToSelector:@selector(setSeparatorInset:)])
                [cCell setSeparatorInset:UIEdgeInsetsZero];
             */
            return cCell;
        }
    }
    // sound clip cells
    else  {
        /*
        NSLog(@"sound clip cell");
        static NSString *clipCellIdentifier = @"SoundClipCell";
        UITableViewCell *clipCell = [tableView dequeueReusableCellWithIdentifier:clipCellIdentifier];
        [_tungStereo configureSoundClipCell:clipCell forIndexPath:indexPath];
        return clipCell;
         */
        return nil;
    }
}

#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //NSLog(@"selected cell at row %ld", (long)[indexPath row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        if (indexPath.row > 1) {
            [self selectedProfileControlAtIndex:indexPath.row];
        }
    }
    else {
        /*
        _tungStereo.selectedClipIndex = indexPath.row;
        [_tungStereo playPause];
         */
    }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // stop playing clip that is scrolled out of view
    /*
    CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    if ([_tungStereo.player isPlaying] && indexPath.row == _tungStereo.activeClipIndex) {
        if (cellRect.origin.y < self.tableView.contentOffset.y || cellRect.origin.y > self.tableView.contentOffset.y + self.tableView.frame.size.height) {
            NSLog(@"stop because scrolled out of view");
            [_tungStereo stopPlayback];
        }
    }
     */
    
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 0) {
        if (_profiledUserData.count > 0) {
            if (indexPath.row == 0) {
                return 168;
            }
            else if (indexPath.row == 1) {
                return 61;
            }
            else {
                return 44;
            }
        }
        else {
            
            return 0;
        }
    }
    else {
        return 0; //return [_tungStereo determineSoundClipCellHeightForRowAtIndexPath:indexPath];
    }
}

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 1 && _profiledUserData.count > 0)
        return 44;
    else
        return 0;
}

-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if (section == 1) {
        
        UIToolbar *headerBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 44)];
        headerBar.translucent = YES;
        NSString *headerText = [self determineProfileTableHeader];
        _headerLabel = [[UIBarButtonItem alloc] initWithTitle:headerText style:UIBarButtonItemStylePlain target:self action:nil];
        _headerLabel.tintColor = [UIColor grayColor];
        [headerBar setItems:@[_headerLabel] animated:NO];
        return headerBar;
        
    } else {
        return nil;
    }
}

- (NSString *) determineProfileTableHeader {
    NSString *headerText;
    if (_stories.storiesArray.count > 0) {
        if (_isLoggedInUser) {
             headerText = @" My posts";
        } else {
            headerText = [NSString stringWithFormat:@" Posts by %@", [_profiledUserData objectForKey:@"username"]];
        }
    } else {
        if (_stories.queryExecuted) {
        	headerText = @" No posts yet.";
        } else {
            headerText = @" Getting posts...";
        }
    }
    return headerText;
}

-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {

    if (!_stories.noMoreItemsToGet && section == 1)
    	return 66.0;
    else if (_stories.noMoreItemsToGet && section == 2)
        return 66.0;
    else
        return 0;
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (_stories.noMoreItemsToGet && section == 2) {
        UILabel *noMoreLabel = [[UILabel alloc] init];
        noMoreLabel.text = @"That's everything.";
        noMoreLabel.textColor = [UIColor grayColor];
        noMoreLabel.textAlignment = NSTextAlignmentCenter;
        return noMoreLabel;
    } else {
        _loadMoreIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _stories.loadMoreIndicator = _loadMoreIndicator;
        return _loadMoreIndicator;
    }
}


#pragma mark - scroll view delegate methods
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.tableView) {
        // detect when user hits bottom of feed
        float bottomOffset = scrollView.contentSize.height - scrollView.frame.size.height;
        if (scrollView.contentOffset.y >= bottomOffset) {
            // request more posts if they didn't reach the end
            /*
            if (!_tungStereo.requestingMore && !_tungStereo.noMoreItemsToGet && _tungStereo.clipArray.count > 0) {
                _tungStereo.requestingMore = YES;
                _loadMoreIndicator.alpha = 1;
                [_loadMoreIndicator startAnimating];
                NSNumber *oldest = [[_tungStereo.clipArray objectAtIndex:_tungStereo.clipArray.count-1] objectForKey:@"time_secs"];
                [_tungStereo requestPostsNewerThan:[NSNumber numberWithInt:0]
                                       orOlderThan:oldest
                                          fromUser:_profiledUser
                                        orCategory:_profiledCategory
                                    withSearchTerm:_searchTerm];
            }
             */
        }
    }
    // profile cell scrollview
    else {
        ProfileCell *profileCell = (ProfileCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        float fractionalPage = (uint) scrollView.contentOffset.x / screenWidth;
        NSInteger page = lround(fractionalPage);
        profileCell.profilePageControl.currentPage = page;
    }
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UIViewController *destination = segue.destinationViewController;
    // info to pass to next view controller
    if ([[segue identifier] isEqualToString:@"presentDraftsView"]) {
    	[destination setValue:@"drafts" forKey:@"rootView"];
    }
    else if ([[segue identifier] isEqualToString:@"presentEditProfileView"]) {
        [destination setValue:@"editProfile" forKey:@"rootView"];
    }
}

- (IBAction)unwindToProfile:(UIStoryboardSegue*)sender {
}

@end
