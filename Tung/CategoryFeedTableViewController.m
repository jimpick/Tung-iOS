//
//  CategoryFeedTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 8/7/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "CategoryFeedTableViewController.h"
#import "tungCommonObjects.h"
#import "tungStereo.h"
#import "SoundClipCell.h"

@interface CategoryFeedTableViewController ()

@property (nonatomic, retain) tungCommonObjects *tungObjects;
@property (strong, nonatomic) tungStereo *tungStereo;

@property (strong, nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic, assign) BOOL feedRefreshed;
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;

@property (strong, nonatomic) UIBarButtonItem *btn_seekBack;
@property (strong, nonatomic) UIBarButtonItem *btn_loop;
@property (strong, nonatomic) UIBarButtonItem *btn_playPause;
@property (strong, nonatomic) UIBarButtonItem *btn_seekForward;

@property (nonatomic, assign) int selCat;

@end

@implementation CategoryFeedTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _tungObjects = [tungCommonObjects establishTungObjects];
    _tungObjects.viewController = self;
    
    _tungStereo = [[tungStereo alloc] init];
    _tungStereo.tableView = self.tableView;
    // pass info back to tungStereo
    _tungStereo.viewController = self;
    _tungStereo.profiledUser = _profiledUser;
    _tungStereo.profiledUserData = _profiledUserData;
    _tungStereo.profiledCategory = _profiledCategory;
    _tungStereo.searchTerm = _searchTerm;
    _tungStereo.clipSection = 0;
    
    // navigation title
    if (_profiledUser.length > 0) {
        self.navigationItem.title = [NSString stringWithFormat:@"%@/%@",[_profiledUserData objectForKey:@"username"],[_tungObjects.categoryHashtags objectAtIndex:_profiledCategory.intValue]];
    } else {
        self.navigationItem.title = [_tungObjects.categoryHashtags objectAtIndex:_profiledCategory.intValue];
    }
    // search button
    UIBarButtonItem *searchBarBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:_tungStereo action:@selector(pushSearchView)];
    [self.navigationItem setRightBarButtonItems:@[searchBarBtn]];
    
    // table view
    UIActivityIndicatorView *behindTable = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    behindTable.alpha = 1;
    [behindTable startAnimating];
    self.tableView.backgroundView = behindTable;
    self.tableView.backgroundColor = _tungObjects.bkgdGrayColor;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.scrollsToTop = YES;
    self.tableView.separatorColor = [UIColor whiteColor];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0);
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 35, 0);
    
    // refresh control
	self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
    _tungStereo.refreshControl = self.refreshControl;
    
    // set up toolbar
    _btn_seekBack = [_tungStereo generateStereoButtonWithImageName:@"btn-seek-back.png" andSelector:@selector(seekBack)];
    _btn_seekForward = [_tungStereo generateStereoButtonWithImageName:@"btn-seek-forward.png" andSelector:@selector(seekForwardWithDelay:)];
    _btn_loop = [[UIBarButtonItem alloc] initWithCustomView:_tungStereo.btn_loop_inner];
    _btn_playPause = [[UIBarButtonItem alloc] initWithCustomView:_tungStereo.btn_playPause_inner];
    
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil];
    fixedSpace.width = 120;
    UIBarButtonItem *fSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    [self setToolbarItems:@[_btn_seekBack, fSpace,
                            _btn_loop, fSpace,
                            fixedSpace, fSpace,
                            _btn_playPause, fSpace,
                            _btn_seekForward] animated:NO];
    self.navigationController.toolbar.clipsToBounds = YES;
    
    [self refreshFeed];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.titleTextAttributes = @{ NSForegroundColorAttributeName: [_tungObjects.categoryColors objectAtIndex:_profiledCategory.intValue]};
}

- (void) viewDidAppear:(BOOL)animated {

    [super viewDidAppear:animated];
    // set audio session
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: nil];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    // check for new posts
    if (!_feedRefreshed) [self refreshFeed];
}

- (void) viewWillDisappear:(BOOL)animated {
    _feedRefreshed = NO;
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
    if ([_tungStereo.player isPlaying]) [_tungStereo stopPlayback];
    
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) refreshFeed {
    
    [tungCommonObjects checkReachabilityWithCallback:^(BOOL reachable) {
        if (reachable) {
            _feedRefreshed = YES;
            if (_tungObjects.needsReload.boolValue) {
                NSLog(@"needed reload");
                _tungStereo.clipArray = [[NSMutableArray alloc] init];
            }
            NSNumber *mostRecent;
            if (_tungStereo.clipArray.count > 0) {
                NSLog(@"category feed: refresh feed");
                [self.refreshControl beginRefreshing];
                mostRecent = [[_tungStereo.clipArray objectAtIndex:0] objectForKey:@"time_secs"];
            } else {
                NSLog(@"category feed: get feed");
                mostRecent = [NSNumber numberWithInt:0];
            }
            [_tungStereo requestPostsNewerThan:mostRecent
                                   orOlderThan:[NSNumber numberWithInt:0]
                                      fromUser:_profiledUser
                                    orCategory:_profiledCategory
                                withSearchTerm:_searchTerm];
        }
        // unreachable
        else {
            UIAlertView *noReachabilityAlert = [[UIAlertView alloc] initWithTitle:@"No Connection" message:@"tung requires an internet connection" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
            [noReachabilityAlert setTag:49];
            [noReachabilityAlert show];
        }
    }];
}

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    if (alertView.tag == 49) [self refreshFeed];// unreachable, retry
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent {
    NSLog(@"received remove control event: %@", receivedEvent);
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        
        switch (receivedEvent.subtype) {
            case UIEventSubtypeRemoteControlPlay:
            case UIEventSubtypeRemoteControlPause:
            case UIEventSubtypeRemoteControlStop:
            case UIEventSubtypeRemoteControlTogglePlayPause:
                [_tungStereo playPause];
                break;
                
            case UIEventSubtypeRemoteControlPreviousTrack:
                [_tungStereo seekBack];
                break;
                
            case UIEventSubtypeRemoteControlNextTrack:
                [_tungStereo seekForwardWithDelay:0];
                break;
                
            default:
                break;
        }
    }
}

#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //NSLog(@"selected cell at row %ld", (long)[indexPath row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSUInteger row = [indexPath row];
    
    _tungStereo.selectedClipIndex = row;
    [_tungStereo playPause];
    
}
- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // stop playing clip that is scrolled out of view
    
    CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    if ([_tungStereo.player isPlaying] && indexPath.row == _tungStereo.activeClipIndex) {
        if (cellRect.origin.y < self.tableView.contentOffset.y || cellRect.origin.y > self.tableView.contentOffset.y + self.tableView.frame.size.height) {
            NSLog(@"stop because scrolled out of view");
            [_tungStereo stopPlayback];
        }
    }
    
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return [_tungStereo determineSoundClipCellHeightForRowAtIndexPath:indexPath];
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (_tungStereo.noMorePostsToGet && section == 1) {
        UILabel *noMoreLabel = [[UILabel alloc] init];
        noMoreLabel.text = @"That's everything... no more clips.";
        noMoreLabel.textColor = [UIColor grayColor];
        noMoreLabel.textAlignment = NSTextAlignmentCenter;
        return noMoreLabel;
    } else {
        _loadMoreIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _tungStereo.loadMoreIndicator = _loadMoreIndicator;
        return _loadMoreIndicator;
    }
}
-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (!_tungStereo.noMorePostsToGet && section == 0)
        return 66.0;
    else if (_tungStereo.noMorePostsToGet && section == 1)
        return 66.0;
    else
        return 0;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return [_tungStereo.clipArray count];
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"SoundClipCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    [_tungStereo configureSoundClipCell:cell forIndexPath:indexPath];
    return cell;

}

#pragma mark - scroll view delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if (scrollView == self.tableView) {
        // detect when user hits bottom of feed
        float bottomOffset = scrollView.contentSize.height - scrollView.frame.size.height;
        if (scrollView.contentOffset.y >= bottomOffset) {
            // request more posts if they didn't reach the end
            if (!_tungStereo.requestingMore && !_tungStereo.noMorePostsToGet && _tungStereo.clipArray.count > 0) {
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
        }
    }
}

#pragma mark - Navigation


@end
