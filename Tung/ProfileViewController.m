//
//  ProfileViewController.m
//  Tung
//
//  Created by Jamie Perkins on 10/4/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import "ProfileViewController.h"
#import "ProfileHeaderView.h"
#import "AvatarContainerView.h"
#import "ProfileListTableViewController.h"
#import "BrowserViewController.h"
#import "IconButton.h"

@class TungCommonObjects;

@interface ProfileViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) TungStories *stories;
@property (strong, nonatomic) ProfileHeaderView *profileHeader;
@property UIBarButtonItem *tableHeaderLabel;
@property NSURL *urlToPass;

@property BOOL isLoggedInUser;
@property BOOL reachable;

@end

CGFloat screenWidth;

@implementation ProfileViewController

- (void) viewDidLoad {
    
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    _tung.ctrlBtnDelegate = self;
    
    // set defaults for required properties
    if (!_profiledUserId) _profiledUserId = _tung.tungId;
    
    // check if the profiled user is themself
    if ([_tung.tungId isEqualToString:_profiledUserId]) {
        _isLoggedInUser = YES;
        NSLog(@"is logged in user");
        
        self.navigationItem.title = @"My Profile";
        // sign out button
        IconButton *signOutInner = [[IconButton alloc] initWithFrame:CGRectMake(0, 0, 34, 34)];
        signOutInner.type = kIconButtonTypeSignOut;
        signOutInner.color = _tung.tungColor;
        [signOutInner addTarget:self action:@selector(confirmSignOut) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *signOutButton = [[UIBarButtonItem alloc] initWithCustomView:signOutInner];
        self.navigationItem.leftBarButtonItem = signOutButton;
    }
    
    if (!screenWidth) screenWidth = self.view.frame.size.width;
    
    self.definesPresentationContext = YES;
    
    // profile header
    _profileHeader = [[ProfileHeaderView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 228)];
	[self.view addSubview:_profileHeader];
    _profileHeader.translatesAutoresizingMaskIntoConstraints = NO;
    CGFloat topConstraint = 64;
    CGFloat headerViewHeight = 223;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_profileHeader attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:topConstraint]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_profileHeader attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    NSLayoutConstraint *profileHeaderHeight = [NSLayoutConstraint constraintWithItem:_profileHeader attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:headerViewHeight];
    [_profileHeader addConstraint:profileHeaderHeight];
    [_profileHeader addConstraint:[NSLayoutConstraint constraintWithItem:_profileHeader attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:self.view.frame.size.width]];
    
    _profileHeader.scrollView.delegate = self;
    _profileHeader.largeAvatarView.backgroundColor = [UIColor clearColor];
    _profileHeader.largeAvatarView.borderColor = [UIColor whiteColor];
    _profileHeader.largeAvatarView.hidden = YES;
    
    _profileHeader.basicInfoWebView.delegate = self;
    _profileHeader.bioWebView.delegate = self;
    [_profileHeader.basicInfoWebView setBackgroundColor:[UIColor clearColor]];
    [_profileHeader.bioWebView setBackgroundColor:[UIColor clearColor]];
    [_profileHeader.basicInfoWebView.scrollView setScrollEnabled:NO];
    [_profileHeader.bioWebView.scrollView setScrollEnabled:NO];
    
    [_profileHeader.followingCountBtn addTarget:self action:@selector(viewFollowing) forControlEvents:UIControlEventTouchUpInside];
    [_profileHeader.followerCountBtn addTarget:self action:@selector(viewFollowers) forControlEvents:UIControlEventTouchUpInside];
    [self determineTableHeaderText];
    
    // for feed
    _stories = [TungStories new];
    _stories.navController = [self navigationController];
    _stories.viewController = self;
    _stories.profiledUserId = _profiledUserId;
    // for animating header
    _stories.profileHeader = _profileHeader;
    _stories.profileHeaderHeight = profileHeaderHeight;
    
    _stories.feedTableViewController.edgesForExtendedLayout = UIRectEdgeNone;
    _stories.feedTableViewController.tableView.contentInset = UIEdgeInsetsMake(44, 0, -5, 0);
    [self addChildViewController:_stories.feedTableViewController];
    [self.view addSubview:_stories.feedTableViewController.view];
    
    _stories.feedTableViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_stories.feedTableViewController.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_profileHeader attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_stories.feedTableViewController.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_stories.feedTableViewController.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:-44]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_stories.feedTableViewController.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_stories.feedTableViewController.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_stories.feedTableViewController.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_stories.feedTableViewController.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
    //if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) self.edgesForExtendedLayout = UIRectEdgeBottom;
    
    // table header toolbar
    UIToolbar *headerBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    headerBar.clipsToBounds = YES;
    
    _tableHeaderLabel = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:self action:nil];
    _tableHeaderLabel.tintColor = _tung.tungColor;
    //UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    [headerBar setItems:@[_tableHeaderLabel] animated:NO];
    [self.view addSubview:headerBar];
    headerBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:headerBar attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_profileHeader attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [headerBar addConstraint:[NSLayoutConstraint constraintWithItem:headerBar attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:44]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:headerBar attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:headerBar.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:headerBar attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:headerBar.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
	// get data in viewDidAppear
    _tung.profileNeedsRefresh = [NSNumber numberWithBool:YES];
    
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _stories.screenWidth = self.view.bounds.size.width;
    
    // scroll view
    CGSize contentSize = _profileHeader.scrollView.contentSize;
    NSLog(@"scroll view content size: %@", NSStringFromCGSize(_profileHeader.scrollView.contentSize));
    contentSize.width = contentSize.width * 2;
    _profileHeader.scrollView.contentSize = contentSize;
    NSLog(@"scroll view NEW content size: %@", NSStringFromCGSize(contentSize));
    
    // watch request status so we can update table header
    [self addObserver:self forKeyPath:@"stories.requestStatus" options:NSKeyValueObservingOptionNew context:nil];
    
    if (_tung.feedNeedsRefresh.boolValue || _tung.profileNeedsRefresh) {
        [self requestPageData];
    }
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    @try {
    	[self removeObserver:self forKeyPath:@"stories.requestStatus"];
    }
    @catch (id exception) {}
    
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
	
    //if (object == _stories && [keyPath isEqualToString:@"requestStatus"]) {
    if ([keyPath isEqualToString:@"stories.requestStatus"]) {
        NSLog(@"stories request status changed: %@", _stories.requestStatus);
        [self determineTableHeaderText];
    }
}

#pragma mark - specific to Profile View

- (void) determineTableHeaderText {
    NSString *headerText;
    if ([_stories.requestStatus isEqualToString:@"finished"]) {
        if (_stories.storiesArray.count > 0) {
            if (_isLoggedInUser) {
                headerText = @" My activity";
            } else {
                headerText = [NSString stringWithFormat:@" %@'s activity", [_profiledUserData objectForKey:@"username"]];
            }
        } else {
            headerText = @" No activity yet.";
        }
    } else {
        headerText = @" Getting activity...";
    }
    _tableHeaderLabel.title =  headerText;
}

- (void) requestPageData {
    
        
    if (_isLoggedInUser) {
        _profiledUserData = [[_tung getLoggedInUserData] mutableCopy];
        if (_profiledUserData) {
            _profiledUserData = [[_tung getLoggedInUserData] mutableCopy];
            [self setUpProfileHeaderViewForData];
            // request profile just to get current follower/following counts
            [_tung getProfileDataForUser:_tung.tungId withCallback:^(NSDictionary *jsonData) {
                if (jsonData != nil) {
                    NSDictionary *responseDict = jsonData;
                    _tung.profileNeedsRefresh = [NSNumber numberWithBool:NO];
                    if ([responseDict objectForKey:@"user"]) {
                        _profiledUserData = [[responseDict objectForKey:@"user"] mutableCopy];
                        [self updateUserFollowingData];
                        [_stories refreshFeed:YES];
                    }
                }
            }];
        }
        else {
            // restore logged in user data
            [_tung getProfileDataForUser:_tung.tungId withCallback:^(NSDictionary *jsonData) {
                if (jsonData != nil) {
                    NSDictionary *responseDict = jsonData;
                    _tung.profileNeedsRefresh = [NSNumber numberWithBool:NO];
                    if ([responseDict objectForKey:@"user"]) {
                        NSLog(@"got user: %@", [responseDict objectForKey:@"user"]);
                        [TungCommonObjects saveUserWithDict:[responseDict objectForKey:@"user"]];
                        _profiledUserData = [[responseDict objectForKey:@"user"] mutableCopy];
                        [self setUpProfileHeaderViewForData];
                        [_stories refreshFeed:YES];
                    }
                }
            }];
        }
    }
    else {
        
        [_tung getProfileDataForUser:_profiledUserId withCallback:^(NSDictionary *jsonData) {
            if (jsonData != nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"user"]) {
                    _tung.profileNeedsRefresh = [NSNumber numberWithBool:NO];
                    _profiledUserData = [[responseDict objectForKey:@"user"] mutableCopy];
                    NSLog(@"profiled user data %@", _profiledUserData);
                    // navigation bar title
                    self.navigationItem.title = [_profiledUserData objectForKey:@"username"];
                    [self setUpProfileHeaderViewForData];
                    [_stories refreshFeed:YES];
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

- (void) setUpProfileHeaderViewForData {
    
    // basic info web view
    NSString *style = [NSString stringWithFormat:@"<style type=\"text/css\">body { margin:0; color:white; font: .9em/1.4em -apple-system, Helvetica; } a { color:rgba(255,255,255,.6); } .name { font-size:1.1em; } .location { color:rgba(0,0,0,.4) } table { width:100%%; height:100%%; border-spacing:0; border-collapse:collapse; border:none; } td { text-align:center; vertical-align:middle; }</style>\n"];
    NSString *basicInfoBody = [NSString stringWithFormat:@"<table><td><p><span class=\"name\">%@</span>", [_profiledUserData objectForKey:@"name"]];
    NSString *location = [_profiledUserData objectForKey:@"location"];
    if (location.length > 0) {
        basicInfoBody = [basicInfoBody stringByAppendingString:[NSString stringWithFormat:@"<br><span class=\"location\">%@</span>", location]];
    }
    NSString *url = [_profiledUserData objectForKey:@"url"];
    if (url.length > 0) {
        NSString *displayUrl = [TungCommonObjects cleanURLStringFromString:url];
        basicInfoBody = [basicInfoBody stringByAppendingString:[NSString stringWithFormat:@"<br><a href=\"%@\">%@</a>", url, displayUrl]];
    }
    basicInfoBody = [basicInfoBody stringByAppendingString:@"</p></td></table>"];
    NSString *webViewString = [NSString stringWithFormat:@"%@%@", style, basicInfoBody];
    [_profileHeader.basicInfoWebView loadHTMLString:webViewString baseURL:[NSURL URLWithString:@"desc"]];
    
    // bio
    NSString *bio = [_profiledUserData objectForKey:@"bio"];
    if (bio.length > 0) {
        NSString *bioBody = [NSString stringWithFormat:@"<table><td>%@", bio];
        NSString *bioWebViewString = [NSString stringWithFormat:@"%@%@</td></table>", style, bioBody];
        [_profileHeader.bioWebView loadHTMLString:bioWebViewString baseURL:[NSURL URLWithString:@"desc"]];
    }
    else {
        _profileHeader.pageControl.hidden = YES;
        _profileHeader.scrollView.scrollEnabled = NO;
    }
    
    // avatar
    NSString *largeAvatarsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"largeAvatars"];
    [[NSFileManager defaultManager] createDirectoryAtPath:largeAvatarsDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *largeAvatarFilename = [[_profiledUserData objectForKey:@"large_av_url"] lastPathComponent];
    NSString *largeAvatarFilepath = [largeAvatarsDir stringByAppendingPathComponent:largeAvatarFilename];
    NSData *largeAvatarImageData;
    if ([[NSFileManager defaultManager] fileExistsAtPath:largeAvatarFilepath]) {
        largeAvatarImageData = [NSData dataWithContentsOfFile:largeAvatarFilepath];
    } else {
        largeAvatarImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString: [_profiledUserData objectForKey:@"large_av_url"]]];
        [largeAvatarImageData writeToFile:largeAvatarFilepath atomically:YES];
    }
    NSLog(@"large av image data size: %lu", (unsigned long)largeAvatarFilename.length);
    UIImage *largeAvImage = [[UIImage alloc] initWithData:largeAvatarImageData];
    _profileHeader.largeAvatarView.hidden = NO;
    _profileHeader.largeAvatarView.avatar = largeAvImage;
    [_profileHeader.largeAvatarView setNeedsDisplay];
    
    [self updateUserFollowingData];

    
}

- (void) updateUserFollowingData {
    
    // following
    NSString *followingString;
    if ([_profiledUserData objectForKey:@"followingCount"]) {
    	followingString = [TungCommonObjects formatNumberForCount:[_profiledUserData objectForKey:@"followingCount"]];
        [_profileHeader.followingCountBtn setEnabled:YES];
    } else {
        followingString = @"";
        [_profileHeader.followingCountBtn setEnabled:NO];
    }
    [_profileHeader.followingCountBtn setTitle:followingString forState:UIControlStateNormal];
    
    // followers
    NSString *followerString;
    if ([_profiledUserData objectForKey:@"followerCount"]) {
        followerString = [TungCommonObjects formatNumberForCount:[_profiledUserData objectForKey:@"followerCount"]];
        [_profileHeader.followerCountBtn setEnabled:YES];
    } else {
        followerString = @"";
        [_profileHeader.followerCountBtn setEnabled:NO];
    }
    [_profileHeader.followerCountBtn setTitle:followerString forState:UIControlStateNormal];
    // button
    _profileHeader.editFollowBtn.backgroundColor = [UIColor clearColor];
    _profileHeader.editFollowBtn.on = NO;
    if (_isLoggedInUser) {
        _profileHeader.editFollowBtn.type = kPillTypeOnDark;
        _profileHeader.editFollowBtn.buttonText = @"Edit profile";
        _profileHeader.editFollowBtn.on = NO;
        [_profileHeader.editFollowBtn addTarget:self action:@selector(editProfile) forControlEvents:UIControlEventTouchUpInside];
        
    } else {
        _profileHeader.editFollowBtn.type = kPillTypeFollow;
        [_profileHeader.editFollowBtn addTarget:self action:@selector(followOrUnfollowUser) forControlEvents:UIControlEventTouchUpInside];
        if ([[_profiledUserData objectForKey:@"userFollows"] boolValue]) {
            _profileHeader.editFollowBtn.buttonText = @"Following";
            _profileHeader.editFollowBtn.on = YES;
        }
        else {
            _profileHeader.editFollowBtn.buttonText = @"Follow";
            _profileHeader.editFollowBtn.on = NO;
        }
    }
    [_profileHeader.editFollowBtn setNeedsDisplay];

}

- (void) viewFollowers {
    NSLog(@"view followers");
    if ([[_profiledUserData objectForKey:@"followerCount"] integerValue] > 0)
    	[self pushProfileListForTargetId:_profiledUserId andQuery:@"Followers"];
}
- (void) viewFollowing {
    NSLog(@"view following");
    if ([[_profiledUserData objectForKey:@"followingCount"] integerValue] > 0)
        [self pushProfileListForTargetId:_profiledUserId andQuery:@"Following"];
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
                [self updateUserFollowingData];
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
                [self updateUserFollowingData];
            }
            else {
                NSLog(@"success following user");
            }
        }];
        [_profiledUserData setValue:[NSNumber numberWithInt:1] forKey:@"userFollows"];
        [_profiledUserData setValue:[NSNumber numberWithInt:[followersStartingValue intValue] +1] forKey:@"followerCount"];
    }
    // GUI
    [self updateUserFollowingData];
}

- (void) pushProfileListForTargetId:(NSString *)target_id andQuery:(NSString *)query {
    ProfileListTableViewController *profileListView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileListView"];
    profileListView.target_id = target_id;
    profileListView.queryType = query;
    [self.navigationController pushViewController:profileListView animated:YES];
}

- (void) confirmSignOut {
    UIActionSheet *signOutSheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"You are running v%@ of tung.", _tung.tung_version] delegate:_tung cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Sign out" otherButtonTitles:nil];
    [signOutSheet setTag:99];
    [signOutSheet showFromToolbar:self.navigationController.toolbar];
}

#pragma mark - UIScrollView delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if (scrollView == _profileHeader.scrollView) {
        float fractionalPage = (uint) scrollView.contentOffset.x / screenWidth;
        NSInteger page = lround(fractionalPage);
        _profileHeader.pageControl.currentPage = page;
    }
    
}

#pragma mark - UIWebView delegate methods

-(BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    if ([request.URL.scheme isEqualToString:@"file"]) {
        return YES;
        
    } else {
        
        // open web browsing modal
        _urlToPass = request.URL;
        [self performSegueWithIdentifier:@"presentWebView" sender:self];
        
        return NO;
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UINavigationController *destination = segue.destinationViewController;
    
    if ([[segue identifier] isEqualToString:@"presentWebView"]) {
        BrowserViewController *browserViewController = (BrowserViewController *)destination;
        [browserViewController setValue:_urlToPass forKey:@"urlToNavigateTo"];
    }
    else if ([[segue identifier] isEqualToString:@"presentEditProfileView"]) {
        [destination setValue:@"editProfile" forKey:@"rootView"];
    }
    
}

@end
