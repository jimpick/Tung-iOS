//
//  MainTabBarController.m
//  Tung
//
//  Created by Jamie Perkins on 12/31/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "MainTabBarController.h"
#import "TungNavController.h"
#import "TungCommonObjects.h"

@interface MainTabBarController ()

@property (strong, nonatomic) TungNavController *feedView;
@property (strong, nonatomic) TungNavController *nowPlayingView;
@property (strong, nonatomic) TungNavController *subscriptionsView;
@property (strong, nonatomic) TungNavController *profileView;

@property (nonatomic, retain) TungCommonObjects *tung;

@property (strong, nonatomic) UIButton *feedInnerBtn;
@property (strong, nonatomic) UIButton *subscribesInnerBtn;
@property (strong, nonatomic) UIButton *nowPlayingInnerBtn;
@property (strong, nonatomic) UIButton *profileInnerBtn;

@property (strong, nonatomic) NSArray *activeButtonImages;
@property (strong, nonatomic) NSArray *inactiveButtonImages;
@property (strong, nonatomic) NSArray *innerButtons;

@end

@implementation MainTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _tung = [TungCommonObjects establishTungObjects];
    
    CGSize screenSize = [TungCommonObjects screenSize];
    
    // set view controllers
    self.feedView = [self.storyboard instantiateViewControllerWithIdentifier:@"feedNavController"];
    self.nowPlayingView = [self.storyboard instantiateViewControllerWithIdentifier:@"npNavController"];
    self.subscriptionsView = [self.storyboard instantiateViewControllerWithIdentifier:@"subscribeNavController"];
    self.profileView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileNavController"];
    
    self.viewControllers = @[self.feedView, self.nowPlayingView, self.subscriptionsView, self.profileView];
    
    // hide default tab bar and set up toolbar
    self.tabBar.hidden = YES;
    UIToolbar *toolbar = [UIToolbar new];
    toolbar.translucent = NO;
    toolbar.frame = CGRectMake(0, screenSize.height - 44, screenSize.width, 44);
    //NSLog(@"toolbar frame: %@", NSStringFromCGRect(toolbar.frame));
    toolbar.clipsToBounds = YES;
    _activeButtonImages = @[@"tabBar-feed.png", @"tabBar-nowPlaying.png", @"tabBar-subscriptions.png", @"tabBar-profile.png"];
    _inactiveButtonImages = @[@"tabBar-feed-inactive.png", @"tabBar-nowPlaying-inactive.png", @"tabBar-subscriptions-inactive.png", @"tabBar-profile-inactive.png"];
    
    _feedInnerBtn = [self generateTabBarInnerButtonWithIndex:0];
    UIBarButtonItem *feedBarBtn = [[UIBarButtonItem alloc] initWithCustomView:_feedInnerBtn];
    _nowPlayingInnerBtn = [self generateTabBarInnerButtonWithIndex:1];
    UIBarButtonItem *nowPlayingBarBtn = [[UIBarButtonItem alloc] initWithCustomView:_nowPlayingInnerBtn];
    _subscribesInnerBtn = [self generateTabBarInnerButtonWithIndex:2];
    UIBarButtonItem *subscribesBarBtn = [[UIBarButtonItem alloc] initWithCustomView:_subscribesInnerBtn];
    _profileInnerBtn = [self generateTabBarInnerButtonWithIndex:3];
    UIBarButtonItem *profileBarBtn = [[UIBarButtonItem alloc] initWithCustomView:_profileInnerBtn];
    _innerButtons = @[_feedInnerBtn, _nowPlayingInnerBtn, _subscribesInnerBtn, _profileInnerBtn];
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil];
    fixedSpace.width = screenSize.width * .25;
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    [toolbar setItems:@[feedBarBtn, flexSpace,
                        nowPlayingBarBtn, flexSpace,
                        fixedSpace, flexSpace,
                        subscribesBarBtn, flexSpace,
                        profileBarBtn
                        ] animated:NO];
    [self.view addSubview:toolbar];
    //NSLog(@"view frame: %@", NSStringFromCGRect(self.view.frame));
    
    // control button shadow
    UIImageView *btn_player_shadow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"btn-player-shadow.png"]];
    int shadow_x = (screenSize.width - 116) / 2 ;
    int shadow_y = screenSize.height - 77;
    btn_player_shadow.frame = CGRectMake(shadow_x, shadow_y, 116, 77);
    [self.view insertSubview:btn_player_shadow aboveSubview:self.view];
    
    // control button
    _tung.btn_player = [UIButton buttonWithType:UIButtonTypeCustom];
    int x = (screenSize.width - 76) / 2 ;
    int y = screenSize.height - 63;
    _tung.btn_player.frame = CGRectMake(x, y, 76, 63);
    [_tung.btn_player setBackgroundImage:[UIImage imageNamed:@"btn-player-bkgd.png"] forState:UIControlStateNormal];
    [_tung.btn_player setBackgroundImage:[UIImage imageNamed:@"btn-player-bkgd-down.png"] forState:UIControlStateHighlighted];
    [_tung.btn_player setImage:[UIImage imageNamed:@"btn-player-play.png"] forState:UIControlStateNormal];
    [_tung.btn_player setImage:[UIImage imageNamed:@"btn-player-play-down.png"] forState:UIControlStateHighlighted];
    [_tung.btn_player setContentMode:UIViewContentModeCenter];
    [_tung.btn_player addTarget:_tung action:@selector(controlButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    // buffering indicator
    _tung.btnActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    int indicator_x = (screenSize.width - 37) / 2 ;
    int indicator_y = screenSize.height - 45;
    _tung.btnActivityIndicator.frame = CGRectMake(indicator_x, indicator_y, 37, 37);
    // add views
    [self.view insertSubview:_tung.btn_player aboveSubview:self.view];
    [self.view insertSubview:_tung.btnActivityIndicator aboveSubview:_tung.btn_player];
    
    [_tung checkForNowPlaying];
    
    // custom tab bar badges
    CGFloat badgeY = screenSize.height - 40;
    CGPoint subscriptionsBadgeCenter = CGPointMake(screenSize.width * 0.76, badgeY);
    CGPoint profileBadgeCenter = CGPointMake(screenSize.width * 0.94, badgeY);
    CGRect badgeFrame = CGRectMake(0, 0, 22, 22);
    SettingsEntity *settings = [TungCommonObjects settings];
    
    _tung.subscriptionsBadge = [[TungMiscView alloc] initWithFrame:badgeFrame];
    _tung.subscriptionsBadge.type = kMiscViewTypeSmallBadge;
    [self.view addSubview:_tung.subscriptionsBadge];
    _tung.subscriptionsBadge.center = subscriptionsBadgeCenter;
    [_tung setBadgeNumber:settings.numPodcastNotifications forBadge:_tung.subscriptionsBadge];
    
    _tung.profileBadge = [[TungMiscView alloc] initWithFrame:badgeFrame];
    _tung.profileBadge.type = kMiscViewTypeSmallBadge;
    [self.view addSubview:_tung.profileBadge];
    _tung.profileBadge.center = profileBadgeCenter;
    [_tung setBadgeNumber:settings.numProfileNotifications forBadge:_tung.profileBadge];
    
    // initial view controller
    self.selectedIndex = 0;
    [self setSelectedViewController:self.viewControllers[0]];
    
}

-(UIButton *) generateTabBarInnerButtonWithIndex:(NSUInteger)index {
    
    //NSLog(@"generate button w index: %lu and image: %@", (unsigned long)index, [_inactiveButtonImages objectAtIndex:index]);
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, 38, 44);
    //btn.backgroundColor = [UIColor orangeColor];
    [btn setImage:[UIImage imageNamed:[_inactiveButtonImages objectAtIndex:index]] forState:UIControlStateNormal];
    [btn setContentMode:UIViewContentModeCenter];
    [btn setTag:index];
    [btn addTarget:self action:@selector(selectTab:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)selectTab:(id)sender {
    NSUInteger index = [sender tag];
    self.selectedIndex = index;
    //NSLog(@"select tab: %lu", (unsigned long)index);
    [self setSelectedViewController:[self.viewControllers objectAtIndex:index]];
}

- (void) setSelectedViewController:(UIViewController *)selectedViewController {
    
    // make button selected based on self.selectedIndex;
    for (int i = 0; i < _innerButtons.count; i++) {
        if (i == self.selectedIndex) {
            [[_innerButtons objectAtIndex:i] setImage:[UIImage imageNamed:[_activeButtonImages objectAtIndex:i]] forState:UIControlStateNormal];
        } else {
            [[_innerButtons objectAtIndex:i] setImage:[UIImage imageNamed:[_inactiveButtonImages objectAtIndex:i]] forState:UIControlStateNormal];
        }
    }
    // pop to root if tapped the same controller twice
    if (self.selectedViewController == selectedViewController) {
        [(UINavigationController *)self.selectedViewController popToRootViewControllerAnimated:YES];
    }
    [super setSelectedViewController:selectedViewController];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}

- (BOOL)shouldAutorotate {
    return YES;
}


#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}
#else
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}
#endif

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UIViewController *destination = segue.destinationViewController;
    // info to pass to next view controller
    if ([[segue identifier] isEqualToString:@"presentRecordingView"]) {
        [destination setValue:@"record" forKey:@"rootView"];
    }
}

@end
