//
//  EpisodeViewController.m
//  Tung
//
//  Created by Jamie Perkins on 5/6/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "EpisodeViewController.h"
#import "HeaderView.h"
#import "AppDelegate.h"
#import "BrowserViewController.h"
#import "DescriptionWebViewController.h"
#import "EpisodesTableViewController.h"
#import "CommentsTableViewController.h"
#import "CommentAndPostView.h"
#import "MainTabBarController.h"

#include <AudioToolbox/AudioToolbox.h>

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>

#define MAX_RECORD_TIME 29
#define MIN_RECORD_TIME 2
#define MAX_COMMENT_CHARS 220

@interface EpisodeViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) TungPodcast *podcast;
@property HeaderView *headerView;
@property CADisplayLink *onEnterFrame;
@property BOOL npControlsViewIsSetup;
@property BOOL npControlsViewIsVisible;
@property CircleButton *recommendButton;
@property CircleButton *recordButton;
@property CircleButton *playClipButton;
@property CircleButton *clipOkayButton;
@property CircleButton *commentButton;
@property CircleButton *speedButton;
@property UILabel *recommendLabel;
@property UILabel *commentLabel;
@property UILabel *recordingDurationLabel;
@property CommentAndPostView *commentAndPostView;
@property NSLayoutConstraint *commentViewTopLayoutConstraint;
@property BOOL clipConfirmActive;
@property BOOL keyboardActive;
@property BOOL searchActive;
@property BOOL clipHasPosted;
@property NSString *shareIntention;
@property NSString *shareTimestamp;

@property UIToolbar *switcherBar;
@property UISegmentedControl *switcher;
@property NSInteger switcherIndex;
@property DescriptionWebViewController *descriptionView;
@property EpisodesTableViewController *episodesView;
@property CommentsTableViewController *commentsView;
@property AVAudioPlayer *audioPlayer;
@property UILabel *nothingPlayingLabel;
@property NSURL *urlToPass;
@property BOOL lockPosbar;
@property BOOL posbarIsBeingDragged;

@property BOOL isRecording;
@property NSDate *recordStartTime;
@property CGFloat recordStartMarker;
@property CGFloat recordEndMarker;
@property BOOL totalTimeSet;
@property BOOL isNowPlayingView;
@property BOOL isFirstAppearance;

- (void) switchViews:(id)sender;
- (void) switchToViewAtIndex:(NSInteger)index;

@end

@implementation EpisodeViewController

CGFloat screenWidth;
CGFloat screenHeight;
CGFloat defaultHeaderHeight = 164;
CGFloat commentAndPostViewHeight = 123;

static NSString *kNewClipIntention = @"New clip";
static NSString *kNewCommentIntention = @"New comment";
static NSArray *playbackRateStrings;

UIActivityIndicatorView *backgroundSpinner;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _isFirstAppearance = YES;
    
    _tung = [TungCommonObjects establishTungObjects];
    _podcast = [TungPodcast new];
    
    screenWidth = self.view.frame.size.width;
    screenHeight = self.view.frame.size.height;
    
    // is this for now playing?
    if (_episodeMiniDict || _episodeEntity) {
        self.navigationItem.title = @"Episode";
        self.view.backgroundColor = [UIColor whiteColor];
    }
    else {
        _isNowPlayingView = YES;
        self.navigationItem.title = @"Now Playing";
        _episodeEntity = _tung.npEpisodeEntity;
        
        //[self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
        //[self.navigationController.navigationBar setBarTintColor:_episodeEntity.podcast.keyColor1];
        //[self.navigationController.navigationBar setBackgroundColor:_episodeEntity.podcast.keyColor1];
        
        //[self.navigationController.navigationBar setTitleTextAttributes:@{ NSForegroundColorAttributeName:_episodeEntity.podcast.keyColor1 }];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiateSearch)];
        
        self.view.backgroundColor = [TungCommonObjects bkgdGrayColor];
        
        // nothing playing?
        CGRect labelFrame = CGRectMake((screenWidth - 320)/2, (screenHeight - 64)/2, 320, 20);
        _nothingPlayingLabel = [[UILabel alloc] initWithFrame:labelFrame];
        _nothingPlayingLabel.text = @"Nothing is currently playing";
        _nothingPlayingLabel.textColor = [UIColor grayColor];
        _nothingPlayingLabel.textAlignment = NSTextAlignmentCenter;
    }
    
    // now playing controls
    _skipAheadBtn.type = kIconButtonTypeSkipAhead15;
    _skipAheadBtn.color = [TungCommonObjects tungColor];
    [_skipAheadBtn setNeedsDisplay];
    [_skipAheadBtn addTarget:_tung action:@selector(skipAhead15) forControlEvents:UIControlEventTouchUpInside];
    _skipBackBtn.type = kIconButtonTypeSkipBack15;
    _skipBackBtn.color = [TungCommonObjects tungColor];
    [_skipBackBtn setNeedsDisplay];
    [_skipBackBtn addTarget:_tung action:@selector(skipBack15) forControlEvents:UIControlEventTouchUpInside];
    
    _timeElapsedLabel.hidden = YES;
    _timeElapsedLabel.alpha = 0;
    _timeElapsedLabel.text = @"00:00:00";
    _skipAheadBtn.hidden = YES;
    _skipAheadBtn.alpha = 0;
    _skipBackBtn.hidden = YES;
    _skipBackBtn.alpha = 0;
    
    _hideControlsButton.type = kShowHideButtonTypeHide;
    _hideControlsButton.viewController = self;
    _showControlsButton.type = kShowHideButtonTypeShow;
    _showControlsButton.hidden = YES;
    
    [_posbar setThumbImage:[UIImage imageNamed:@"posbar-thumb.png"] forState:UIControlStateNormal];
    _posbar.minimumTrackTintColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0]; // .5
    _posbar.maximumTrackTintColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0]; // .2
    [_posbar addTarget:self action:@selector(posbarChanged:) forControlEvents:UIControlEventValueChanged];
    [_posbar addTarget:self action:@selector(posbarTouched:) forControlEvents:UIControlEventTouchDown];
    [_posbar addTarget:self action:@selector(posbarReleased:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    _posbar.value = 0;
    
    // file download progress
    _progressBar.trackTintColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:.15];
    _progressBar.progressTintColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:.3];
    _progressBar.progress = 0;
    /* make progress bar taller... doesn't round corners
     CGAffineTransform transform = CGAffineTransformMakeScale(1.0f, 2.0f);
     _progressBar.transform = transform;
     */
    
    // get keyboard height when keyboard is shown and will hide
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillAppear:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
    
    playbackRateStrings = @[@".75x", @"1.0x", @"1.5x", @"2.0x"];
    
    // share label
    _shareLabel.text = @"";
    _shareLabel.alpha = 0;
    _shareLabel.textColor = [TungCommonObjects tungColor];
    _totalTimeLabel.text = @"--:--:--";
    
    // for search controller
    self.definesPresentationContext = YES;
    _podcast.navController = [self navigationController];
    _podcast.delegate = self;
    
    // views
    _npControlsView.opacity = .4;
    _npControlsView.tintColor = [UIColor lightGrayColor];
    
    // header view
    _headerView = [[HeaderView alloc] initWithFrame:CGRectMake(0, 64, screenWidth, defaultHeaderHeight)];
    [self.view insertSubview:_headerView belowSubview:_npControlsView];
    _headerView.hidden = YES;
    
    // switcher bar
    _switcherBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 44)];
    _switcherBar.clipsToBounds = YES;
    _switcherBar.opaque = YES;
    _switcherBar.translucent = NO;
    _switcherBar.backgroundColor = [UIColor whiteColor];
    _switcherBar.hidden = YES;
    // set up segemented control
    NSArray *switcherItems = @[@"Description", @"Comments", @"Episodes"];
    _switcher = [[UISegmentedControl alloc] initWithItems:switcherItems];
    _switcher.tintColor = [UIColor lightGrayColor];
    _switcher.frame = CGRectMake(0, 0, screenWidth - 20, 28);
    [_switcher addTarget:self action:@selector(switchViews:) forControlEvents:UIControlEventValueChanged];
    UIBarButtonItem *switcherBarItem = [[UIBarButtonItem alloc] initWithCustomView:(UIView *)_switcher];
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    [_switcherBar setItems:@[flexSpace, switcherBarItem, flexSpace] animated:NO];
    [self.view insertSubview:_switcherBar belowSubview:_npControlsView];
    _switcherBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_switcherBar attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_headerView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [_switcherBar addConstraint:[NSLayoutConstraint constraintWithItem:_switcherBar attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:44]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_switcherBar attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_switcherBar.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_switcherBar attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_switcherBar.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    _switcherIndex = 0;

    
    CGFloat bottomConstraint = -44;
    
    // description
    _descriptionView = [self.storyboard instantiateViewControllerWithIdentifier:@"descWebView"];
    _descriptionView.edgesForExtendedLayout = UIRectEdgeNone;
    [self addChildViewController:_descriptionView];
    [self.view insertSubview:_descriptionView.view atIndex:1];
    _descriptionView.webView.delegate = self;
    _descriptionView.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_descriptionView.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_switcherBar attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_descriptionView.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_descriptionView.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:bottomConstraint]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_descriptionView.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_descriptionView.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_descriptionView.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_descriptionView.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
    // comments
    _commentsView = [self.storyboard instantiateViewControllerWithIdentifier:@"commentsTableView"];
    _commentsView.edgesForExtendedLayout = UIRectEdgeNone;
    [self addChildViewController:_commentsView];
    [self.view insertSubview:_commentsView.view atIndex:1];
    _commentsView.navController = self.navigationController;
    _commentsView.refreshControl = [UIRefreshControl new];
    [_commentsView.refreshControl addTarget:self action:@selector(refreshComments:) forControlEvents:UIControlEventValueChanged];
    _commentsView.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_commentsView.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_switcherBar attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_commentsView.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_commentsView.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:bottomConstraint]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_commentsView.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_commentsView.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_commentsView.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_commentsView.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    // episode view starts out hidden
    _commentsView.view.hidden = YES;
    _commentsView.commentsArray = [NSMutableArray new];
    // focused comment
    if (!_isNowPlayingView && _focusedEventId) {
        _switcherIndex = 1;
        _commentsView.focusedId = _focusedEventId;
    }
    
    // episode view
    _episodesView = [self.storyboard instantiateViewControllerWithIdentifier:@"episodesView"];
    _episodesView.edgesForExtendedLayout = UIRectEdgeNone;
    [self addChildViewController:_episodesView];
    [self.view insertSubview:_episodesView.view atIndex:1];
    _episodesView.navController = self.navigationController;
    _episodesView.refreshControl = [UIRefreshControl new];
    [_episodesView.refreshControl addTarget:self action:@selector(getNewestFeed) forControlEvents:UIControlEventValueChanged];
    _episodesView.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_switcherBar attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_episodesView.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:bottomConstraint]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_episodesView.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_episodesView.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    // episode view starts out hidden
    _episodesView.view.hidden = YES;
    
    // listen for for nowPlayingDidChange
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowPlayingDidChange) name:@"nowPlayingDidChange" object:nil];
    
    if (!_isNowPlayingView) {
        
        // episode view pushed from EpisodesTableViewController
        if (_episodeEntity) {
            [self setUpViewForEpisode:_episodeEntity];
        }
        // episode view pushed from StoriesTableViewController or notifications
        else {
            NSString *episodeId = [[_episodeMiniDict objectForKey:@"id"] objectForKey:@"$id"];
            NSString *collectionId = [_episodeMiniDict objectForKey:@"collectionId"];
            
            // check for episode entity
            _episodeEntity = [TungCommonObjects getEpisodeEntityFromEpisodeId:episodeId];
            
            if (_episodeEntity && _episodeEntity.title) {
                //NSLog(@"will set up view for complete episode entity: %@", _episodeEntity);
                [self setUpViewForEpisode:_episodeEntity];
            }
            else {
                //NSLog(@"will set up view for episode mini dict then request episode data");
                // no entity yet, request data
                [_backgroundSpinner startAnimating];
                [_headerView setUpHeaderViewForEpisodeMiniDict:_episodeMiniDict];
                [_headerView sizeAndConstrainHeaderViewInViewController:self];
                
                [_tung requestEpisodeInfoForId:episodeId andCollectionId:collectionId withCallback:^(BOOL success, NSDictionary *responseDict) {
                    [_backgroundSpinner stopAnimating];
                    NSDictionary *episodeDict = [responseDict objectForKey:@"episode"];
                    NSDictionary *podcastDict = [responseDict objectForKey:@"podcast"];
                    PodcastEntity *podcastEntity = [TungCommonObjects getEntityForPodcast:podcastDict save:NO];
                    _episodeEntity = [TungCommonObjects getEntityForEpisode:episodeDict withPodcastEntity:podcastEntity save:YES];
                    
                    [self setUpViewForEpisode:_episodeEntity];
                }];
            }
        }
    }
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.translucent = NO;
    if (_isNowPlayingView) {
        [self updateTimeElapsedAndPosbar];
        [self beginOnEnterFrame];
        if (!_tung.npViewSetupForCurrentEpisode) {
            [self setUpViewForWhateversPlaying];
        }
    }
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (_isFirstAppearance) {
        [self setupNowPlayingControls];
        _isFirstAppearance = NO;
    }
    
    // set up views
    if (_isNowPlayingView) {
        
        _tung.ctrlBtnDelegate = self;
        _tung.viewController = self;
        
        if (_npControlsBottomLayoutConstraint.constant < closedConstraint && _episodeEntity.isNowPlaying.boolValue) {
            [NSTimer scheduledTimerWithTimeInterval:.2 target:self selector:@selector(revealNowPlayingControls) userInfo:nil repeats:NO];
        }
        
    }
    else if (_episodeEntity.isNowPlaying.boolValue) {
        [NSTimer scheduledTimerWithTimeInterval:.2 target:self selector:@selector(revealNowPlayingControls) userInfo:nil repeats:NO];
    }
    
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_podcast.feedPreloadQueue cancelAllOperations];
    [_onEnterFrame invalidate];
    [markAsSeenTimer invalidate];
    
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    /*
    if (_isNowPlayingView && _podcast.searchController.active) {
        [_podcast.searchController setActive:NO];
        [self dismissPodcastSearch];
    }*/
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) beginOnEnterFrame {
    [_onEnterFrame invalidate];
    _onEnterFrame = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateView)];
    [_onEnterFrame addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

NSTimer *markAsSeenTimer;

- (void) switchViews:(id)sender {
    UISegmentedControl *switcher = (UISegmentedControl *)sender;
    
    switch (switcher.selectedSegmentIndex) {
        case 1: // show comments
            _commentsView.view.hidden = NO;
            _episodesView.view.hidden = YES;
            _descriptionView.view.hidden = YES;
            break;
        case 2: // show episode view
            _commentsView.view.hidden = YES;
            _episodesView.view.hidden = NO;
            [_tung savePositionForNowPlayingAndSync:NO];
            [_episodesView findEachEpisodesProgress];
            [_episodesView.tableView reloadData];
            markAsSeenTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:_episodesView selector:@selector(markNewEpisodesAsSeen) userInfo:nil repeats:NO];
            _descriptionView.view.hidden = YES;
            break;
        default: // show description
            _commentsView.view.hidden = YES;
            _descriptionView.view.hidden = NO;
            _episodesView.view.hidden = YES;
            break;
    }
    _switcherIndex = switcher.selectedSegmentIndex;
}

- (void) switchToViewAtIndex:(NSInteger)index {
    
    [_switcher setSelectedSegmentIndex:index];
    [self switchViews:_switcher];
}

#pragma mark - tungObjects/tungPodcasts delegate methods


- (void) initiateSearch {
    
    // in case sharing in progress, don't animate share view
    _searchActive = YES;
    
    [_podcast.searchController setActive:YES];
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"revealSearch"];
    
    self.navigationItem.titleView = _podcast.searchController.searchBar;
    [self.navigationItem setRightBarButtonItem:nil animated:YES];
    
    [_podcast.searchController.searchBar becomeFirstResponder];
    
}

-(void) dismissPodcastSearch {
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"hideSearch"];
    
    self.navigationItem.titleView = nil;
    UIBarButtonItem *searchBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiateSearch)];
    [self.navigationItem setRightBarButtonItem:searchBtn animated:YES];
    
}

-(void) nowPlayingDidChange {
    
    if (_isNowPlayingView) {
        _episodeEntity = _tung.npEpisodeEntity;
        [self setUpViewForWhateversPlaying];
        [self resetRecording];
        [self setPlaybackRateToOne];
    } else {
        [_episodesView.tableView reloadData];
        [_commentsView.tableView reloadData]; // for footer message change
        
        if (_episodeEntity.isNowPlaying.boolValue) {
            [self revealNowPlayingControls];
        }
    }
}

#pragma mark - Set up view

// if something's playing, setup view for it, else set up for nothing playing
- (void) setUpViewForWhateversPlaying {
    
    [_posbar setEnabled:NO];
    _posbar.value = 0;
    _totalTimeSet = NO;
        
    if (_tung.npEpisodeEntity && _tung.npEpisodeEntity.title) {
        
        self.view.backgroundColor = [UIColor whiteColor];
        // initialize views
        //CLS_LOG(@"setup view for now playing: %@", _tung.npEpisodeEntity.title);
        if ([_nothingPlayingLabel isDescendantOfView:self.view]) {
            [_nothingPlayingLabel removeFromSuperview];
        }
        
        [self setUpViewForEpisode:_tung.npEpisodeEntity];
        
        // scroll to main buttons
        [_buttonsScrollView scrollRectToVisible:buttonsScrollViewHomeRect animated:YES];
        
        // progress
        if (_tung.fileIsLocal) _progressBar.progress = 1;
        
    }
    else {
        // nothing playing
        [self setUpViewForNothingPlaying];
    }
    _tung.npViewSetupForCurrentEpisode = YES;

}

// show "nothing playing" label, etc.
- (void) setUpViewForNothingPlaying {
    
    if (![_nothingPlayingLabel isDescendantOfView:self.view]) [self.view addSubview:_nothingPlayingLabel];
    _headerView.hidden = YES;
    _timeElapsedLabel.hidden = YES;
    _skipAheadBtn.hidden = YES;
    _skipBackBtn.hidden = YES;
    _switcherBar.hidden = YES;
    _descriptionView.view.hidden = YES;
    _episodesView.view.hidden = YES;
    _commentsView.view.hidden = YES;
    self.view.backgroundColor = [TungCommonObjects bkgdGrayColor];
    
}

- (void) setUpViewForEpisode:(EpisodeEntity *)episodeEntity {
    
    //NSLog(@"set up view for episode: %@", [TungCommonObjects entityToDict:episodeEntity]);
    //NSLog(@"podcast: %@", [TungCommonObjects entityToDict:episodeEntity.podcast]);
    // set up header view
    [_headerView setUpHeaderViewForEpisode:episodeEntity orPodcast:nil];
    [_headerView sizeAndConstrainHeaderViewInViewController:self];
    [_headerView.subscribeButton addTarget:self action:@selector(subscribeToPodcastViaSender:) forControlEvents:UIControlEventTouchUpInside];
    
    if (_isNowPlayingView) {
        _headerView.largeButton.type = kCircleTypeSupport;
        [_headerView.largeButton setNeedsDisplay];
        [_headerView.largeButton addTarget:self action:@selector(supportButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    } else {
    	[_headerView.largeButton addTarget:self action:@selector(playEpisode) forControlEvents:UIControlEventTouchUpInside];
    }
    
    [_headerView.podcastButton addTarget:self action:@selector(pushPodcastDescription) forControlEvents:UIControlEventTouchUpInside];
    
    [self refreshRecommendAndSubscribeStatus];
    
    // switcher
    _switcherBar.hidden = NO;
    [self switchToViewAtIndex:_switcherIndex];
    _switcher.tintColor = episodeEntity.podcast.keyColor2;
    
    // COMMENTS
    [self refreshComments:YES];
    
    // episodes and description
    NSDictionary *feedDict = [TungPodcast retrieveAndCacheFeedForPodcastEntity:episodeEntity.podcast forceNewest:NO];
    
    _episodesView.tableView.backgroundView = nil;
    _episodesView.episodeArray = [[TungPodcast extractFeedArrayFromFeedDict:feedDict] mutableCopy];
    [_episodesView findEachEpisodesProgress];
    _episodesView.podcastEntity = episodeEntity.podcast;
    [_episodesView.tableView reloadData];
    
    // refresh description web view with description from feed
    NSInteger feedIndex = [TungCommonObjects getIndexOfEpisodeWithGUID:episodeEntity.guid inFeed:_episodesView.episodeArray];
    episodeEntity.desc = @"No description";
    if (feedIndex >= 0) {
        // assign missing episode entity properties from feed
        NSDictionary *epDict = [_episodesView.episodeArray objectAtIndex:feedIndex];
        if ([epDict objectForKey:@"enclosure"]) {
            NSDictionary *enclosureDict = [TungCommonObjects getEnclosureDictForEpisode:epDict];
            episodeEntity.dataLength = [NSNumber numberWithDouble:[[[enclosureDict objectForKey:@"el:attributes"] objectForKey:@"length"] doubleValue]];
        }
        if ([epDict objectForKey:@"itunes:duration"]) {
            NSString *formattedDuration = [TungCommonObjects formatDurationFromString:[epDict objectForKey:@"itunes:duration"]];
            episodeEntity.duration = formattedDuration;
            _headerView.subTitleLabel.text = [_headerView getSubtitleLabelTextForEntity:episodeEntity];
        }
        
        NSString *desc = [TungCommonObjects findEpisodeDescriptionWithDict:epDict];
        
        if (desc.length > 0) {
            episodeEntity.desc = desc;
        }
    }
    [self loadDescriptionWebViewStringForEntity:episodeEntity];
    
    // podcast description
    if (!episodeEntity.podcast.desc || episodeEntity.podcast.desc.length == 0) {
        episodeEntity.podcast.desc = [TungCommonObjects findPodcastDescriptionWithDict:feedDict];
    }
    
    // scroll to episode row if it's playing
    if (_isNowPlayingView) {
        NSIndexPath *activeRow = [NSIndexPath indexPathForItem:_tung.currentFeedIndex inSection:0];
        [_episodesView.tableView scrollToRowAtIndexPath:activeRow atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
    
    // now playing controls
    _timeElapsedLabel.text = [TungCommonObjects convertSecondsToTimeString:_episodeEntity.trackProgress.doubleValue];
    _posbar.value = _episodeEntity.trackPosition.floatValue;

}

- (void) supportButtonTapped {
    if (_tung.connectionAvailable.boolValue) {
        _urlToPass = [NSURL URLWithString:@"https://tung.fm/fundraising"];
        [self performSegueWithIdentifier:@"presentWebView" sender:self];
    } else {
        [_podcast showNoConnectionAlert];
    }
}

- (void) playEpisode {
    if (_episodeEntity.url.length > 0) {
        if (_headerView.largeButton.on) {
            // select Now Playing tab
            MainTabBarController *tabVC = (MainTabBarController *)self.parentViewController.parentViewController;
            tabVC.selectedIndex = 1;
            UIButton *btn = [[UIButton alloc] init];
            btn.tag = 1;
            [tabVC selectTab:btn];
            
        } else {
            [_tung queueAndPlaySelectedEpisode:_episodeEntity.url fromTimestamp:nil];
            _headerView.largeButton.on = YES;
            [_headerView.largeButton setNeedsDisplay];
            [_episodesView.tableView reloadData];
        }
    } else {
        UIAlertView *badXmlAlert = [[UIAlertView alloc] initWithTitle:@"Can't Play - No URL" message:@"Unfortunately, this feed is missing links to its content." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [badXmlAlert show];
    }
}

#pragma mark Comments view

- (void) refreshComments:(BOOL)fullRefresh {
    
    NSNumber *mostRecent = [NSNumber numberWithInt:0];
    
    /*if (!fullRefresh) {
        if (_commentsView.commentsArray.count > 0) {
            [_commentsView.refreshControl beginRefreshing];
            mostRecent = [[_commentsView.commentsArray objectAtIndex:0] objectForKey:@"time_secs"];
        } else { // if initial request timed out and they are trying again
            mostRecent = [NSNumber numberWithInt:0];
        }
    }*/
    [_commentsView requestCommentsForEpisodeEntity:_episodeEntity NewerThan:mostRecent orOlderThan:[NSNumber numberWithInt:0]];
}

#pragma mark - Episodes view

// for refreshControl
- (void) getNewestFeed {
    NSDictionary *feedDict = [TungPodcast retrieveAndCacheFeedForPodcastEntity:_episodeEntity.podcast forceNewest:YES];
    _episodesView.episodeArray = [[TungPodcast extractFeedArrayFromFeedDict:feedDict] mutableCopy];
    [_episodesView findEachEpisodesProgress];
    
    [_episodesView.refreshControl endRefreshing];
    
    [_episodesView.tableView reloadData];
    
}


#pragma mark Description web views

// uses this view as its webview delegate
- (void) loadDescriptionWebViewStringForEntity:(EpisodeEntity *)episodeEntity {
    // description style
    NSString *keyColor1HexString = [TungCommonObjects UIColorToHexString:episodeEntity.podcast.keyColor1];
    NSString *style = [NSString stringWithFormat:@"<style type=\"text/css\">body { margin:4px 13px; color:#666; font: .9em/1.4em -apple-system, Helvetica; } a { color:%@; } img { max-width:100%%; height:auto; } .endOfFile { margin:40px auto 30px; clear:both; width:60px; height:auto; display:block }</style>\n", keyColor1HexString];
    // description script:
    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"description" ofType:@"js"];
    NSURL *scriptUrl = [NSURL fileURLWithPath:scriptPath];
    NSString *script = [NSString stringWithFormat:@"<script type=\"text/javascript\" src=\"%@\"></script>\n", scriptUrl.path];
    // end-of-file indicator image
    NSString *tungEndOfFileLogoPath = [[NSBundle mainBundle] pathForResource:@"tung-end-of-file" ofType:@"png"];
    NSURL *tungEndOfFileLogoUrl = [NSURL fileURLWithPath:tungEndOfFileLogoPath];
    NSString *tungEndOfFileImg = [NSString stringWithFormat:@"<img class=\"endOfFile\" src=\"%@\">", tungEndOfFileLogoUrl];
    // description
    NSString *webViewString = [NSString stringWithFormat:@"%@%@%@%@", style, script, episodeEntity.desc, tungEndOfFileImg];
    //NSLog(@"webViewString: %@", webViewString);
    [_descriptionView.webView loadHTMLString:webViewString baseURL:[NSURL URLWithString:@"desc"]];
}

// pushes a new view which uses its own webview delegate
- (void) pushPodcastDescription {
    
    [_podcast pushPodcastDescriptionForEntity:_episodeEntity.podcast];
}

#pragma mark Subscribing

// toggle subscribe status
- (void) subscribeToPodcastViaSender:(id)sender {
    
    // only allow subscribing with network connection
    if (_tung.connectionAvailable) {
        
        if (!_episodeEntity.podcast) return;
        
        CircleButton *subscribeButton = (CircleButton *)sender;
        
        subscribeButton.subscribed = !subscribeButton.subscribed;
        [subscribeButton setNeedsDisplay];
        
        // subscribe
        if (subscribeButton.subscribed) {
            
            [_tung subscribeToPodcast:_episodeEntity.podcast withButton:subscribeButton];
            [_episodesView markNewEpisodesAsSeen];
        }
        // unsubscribe
        else {
            
            [_tung unsubscribeFromPodcast:_episodeEntity.podcast withButton:subscribeButton];
        }
    }
    else {
        [_podcast showNoConnectionAlert];
    }
}

#pragma mark Now Playing control view

- (void) refreshRecommendAndSubscribeStatus {
    
    // recommended status
    _recommendButton.recommended = _episodeEntity.isRecommended.boolValue;
    [_recommendButton setNeedsDisplay];
    _recommendLabel.text = (_episodeEntity.isRecommended.boolValue) ? @"Recommended" : @"Recommend";
    
    // subscribe status
    _headerView.subscribeButton.subscribed = _episodeEntity.podcast.isSubscribed.boolValue;
    [_headerView.subscribeButton setNeedsDisplay];
}

static float circleButtonDimension;
static CGRect buttonsScrollViewHomeRect;

- (void) setupNowPlayingControls {
    
    _npControlsViewIsVisible = YES;
    //CLS_LOG(@"set up now playing control view");
    if (!circleButtonDimension) circleButtonDimension = 45;
    
    // buttons scroll view
    CGRect scrollViewRect = _buttonsScrollView.frame;
    scrollViewRect.size.width = screenWidth;
    _buttonsScrollView.contentSize = CGSizeMake(scrollViewRect.size.width * 3, scrollViewRect.size.height);
    _buttonsScrollView.delegate = self;
    CGRect subViewRect = CGRectMake(0, 0, scrollViewRect.size.width, scrollViewRect.size.height);
    // record buttons
    UIView *recordSubView = [[UIView alloc] initWithFrame:subViewRect];
    [_buttonsScrollView addSubview:recordSubView];
    // main buttons
    subViewRect.origin.x += scrollViewRect.size.width;
    // set buttons scroll view home rect
    buttonsScrollViewHomeRect = subViewRect;
    UIView *buttonsSubView = [[UIView alloc] initWithFrame:subViewRect];
    [_buttonsScrollView addSubview:buttonsSubView];
    _buttonsScrollView.contentOffset = CGPointMake(subViewRect.size.width, 0);
    // extra buttons
    subViewRect.origin.x += scrollViewRect.size.width;
    UIView *extraButtonsSubView = [[UIView alloc] initWithFrame:subViewRect];
    [_buttonsScrollView addSubview:extraButtonsSubView];
    
    // main buttons
    CircleButton *newClipButton = [CircleButton new];
    newClipButton.type = kCircleTypeNewClip;
    [self setupCircleButton:newClipButton withWidth:circleButtonDimension andHeight:circleButtonDimension andSuperView:buttonsSubView];
    [newClipButton addTarget:self action:@selector(newClip) forControlEvents:UIControlEventTouchUpInside];
    UILabel *newClipLabel = [UILabel new];
    newClipLabel.text = @"New Clip";
    [self setupButtonLabel:newClipLabel withButtonDimension:circleButtonDimension andSuperView:buttonsSubView];
    
    _recommendButton = [CircleButton new];
    _recommendButton.type = kCircleTypeRecommend;
    [self setupCircleButton:_recommendButton withWidth:circleButtonDimension andHeight:circleButtonDimension andSuperView:buttonsSubView];
    [_recommendButton addTarget:self action:@selector(recommendEpisode) forControlEvents:UIControlEventTouchUpInside];
    _recommendLabel = [UILabel new];
    [self setupButtonLabel:_recommendLabel withButtonDimension:circleButtonDimension andSuperView:buttonsSubView];
    
    _commentButton = [CircleButton new];
    _commentButton.type = kCircleTypeComment;
    [self setupCircleButton:_commentButton withWidth:circleButtonDimension andHeight:circleButtonDimension andSuperView:buttonsSubView];
    [_commentButton addTarget:self action:@selector(newComment) forControlEvents:UIControlEventTouchUpInside];
    _commentLabel = [UILabel new];
    _commentLabel.text = @"Comment";
    [self setupButtonLabel:_commentLabel withButtonDimension:circleButtonDimension andSuperView:buttonsSubView];
    
    CircleButton *shareButton = [CircleButton new];
    shareButton.type = kCircleTypeShare;
    [self setupCircleButton:shareButton withWidth:circleButtonDimension andHeight:circleButtonDimension andSuperView:buttonsSubView];
    [shareButton addTarget:self action:@selector(getTextForShareSheet) forControlEvents:UIControlEventTouchUpInside];
    UILabel *shareLabel = [UILabel new];
    shareLabel.text = @"Share";
    [self setupButtonLabel:shareLabel withButtonDimension:circleButtonDimension andSuperView:buttonsSubView];

    // button and label constraints: distribute X positions
    [buttonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:newClipButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:buttonsSubView attribute:NSLayoutAttributeTrailing multiplier:.134 constant:1]];
    [buttonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:_recommendButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:buttonsSubView attribute:NSLayoutAttributeTrailing multiplier:.381 constant:1]];
    [buttonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:_commentButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:buttonsSubView attribute:NSLayoutAttributeTrailing multiplier:.622 constant:1]];
    [buttonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:shareButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:buttonsSubView attribute:NSLayoutAttributeTrailing multiplier:.865 constant:1]];
    
    [buttonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:newClipLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:buttonsSubView attribute:NSLayoutAttributeTrailing multiplier:.134 constant:1]];
    [buttonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:_recommendLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:buttonsSubView attribute:NSLayoutAttributeTrailing multiplier:.381 constant:1]];
    [buttonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:_commentLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:buttonsSubView attribute:NSLayoutAttributeTrailing multiplier:.622 constant:1]];
    [buttonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:shareLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:buttonsSubView attribute:NSLayoutAttributeTrailing multiplier:.865 constant:1]];
    
    // extra buttons subview
    CircleButton *websiteButton = [CircleButton new];
    websiteButton.type = kCircleTypeWebsite;
    [self setupCircleButton:websiteButton withWidth:circleButtonDimension andHeight:circleButtonDimension andSuperView:extraButtonsSubView];
    [websiteButton addTarget:self action:@selector(openPodcastWebsite) forControlEvents:UIControlEventTouchUpInside];
    UILabel *websiteLabel = [UILabel new];
    websiteLabel.text = @"Website";
    [self setupButtonLabel:websiteLabel withButtonDimension:circleButtonDimension andSuperView:extraButtonsSubView];
    
    _speedButton = [CircleButton new];
    _speedButton.type = kCircleTypeSpeed;
    [self setupCircleButton:_speedButton withWidth:circleButtonDimension andHeight:circleButtonDimension andSuperView:extraButtonsSubView];
    _speedButton.buttonText = [NSString stringWithFormat:@"%@",[playbackRateStrings objectAtIndex:_tung.playbackRateIndex]];
    [_speedButton addTarget:self action:@selector(toggleplaybackRate) forControlEvents:UIControlEventTouchUpInside];
    UILabel *speedLabel = [UILabel new];
    speedLabel.text = @"Speed";
    [self setupButtonLabel:speedLabel withButtonDimension:circleButtonDimension andSuperView:extraButtonsSubView];

    
    // button and label constraints: distribute X positions
    [extraButtonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:websiteButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:extraButtonsSubView attribute:NSLayoutAttributeTrailing multiplier:.134 constant:1]];
    [extraButtonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:websiteLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:extraButtonsSubView attribute:NSLayoutAttributeTrailing multiplier:.134 constant:1]];

    [extraButtonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:_speedButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:extraButtonsSubView attribute:NSLayoutAttributeTrailing multiplier:.381 constant:1]];
    [extraButtonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:speedLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:extraButtonsSubView attribute:NSLayoutAttributeTrailing multiplier:.381 constant:1]];

    
    // record subview
    _recordingDurationLabel = [UILabel new];
    _recordingDurationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    NSArray *durationDisplaySettings = @[
                                         @{ UIFontFeatureTypeIdentifierKey: @(6),
                                            UIFontFeatureSelectorIdentifierKey: @(1)
                                            },
                                         @{ UIFontFeatureTypeIdentifierKey: @(17),
                                            UIFontFeatureSelectorIdentifierKey: @(1)
                                            }];
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:41];
    UIFontDescriptor *originalDescriptor = [font fontDescriptor];
    UIFontDescriptor *durationDescriptor = [originalDescriptor fontDescriptorByAddingAttributes: @{ UIFontDescriptorFeatureSettingsAttribute: durationDisplaySettings }];
    UIFont *durationFont = [UIFont fontWithDescriptor: durationDescriptor size:0.0];
    _recordingDurationLabel.font = durationFont;
    _recordingDurationLabel.text = @":00";
    _recordingDurationLabel.textColor = [TungCommonObjects tungColor];
    [recordSubView addSubview:_recordingDurationLabel];
    [recordSubView addConstraint:[NSLayoutConstraint constraintWithItem:_recordingDurationLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:recordSubView attribute:NSLayoutAttributeTop multiplier:1 constant:1]];
    
    _recordButton = [CircleButton new];
    _recordButton.type = kCircleTypeRecord;
    [self setupCircleButton:_recordButton withWidth:(77 * circleButtonDimension) / 41 andHeight:circleButtonDimension andSuperView:recordSubView];
    [_recordButton addTarget:self action:@selector(toggleRecordState) forControlEvents:UIControlEventTouchUpInside];
    
    _playClipButton = [CircleButton new];
    _playClipButton.type = kCircleTypePlayClip;
    [self setupCircleButton:_playClipButton withWidth:circleButtonDimension andHeight:circleButtonDimension andSuperView:recordSubView];
    [_playClipButton addTarget:self action:@selector(togglePlayRecordedClip) forControlEvents:UIControlEventTouchUpInside];
    [_playClipButton setNeedsDisplay];
    
    _clipOkayButton = [CircleButton new];
    _clipOkayButton.type = kCircleTypeOkay;
    [self setupCircleButton:_clipOkayButton withWidth:circleButtonDimension andHeight:circleButtonDimension andSuperView:recordSubView];
    [_clipOkayButton addTarget:self action:@selector(toggleConfirmClip) forControlEvents:UIControlEventTouchUpInside];
    [_clipOkayButton setNeedsDisplay];
    
    CircleButton *cancelClipButton = [CircleButton new];
    cancelClipButton.type = kCircleTypeCancel;
    [self setupCircleButton:cancelClipButton withWidth:circleButtonDimension andHeight:circleButtonDimension andSuperView:recordSubView];
    [cancelClipButton addTarget:self action:@selector(cancelNewClip) forControlEvents:UIControlEventTouchUpInside];
    
    // distribute X positions
    [recordSubView addConstraint:[NSLayoutConstraint constraintWithItem:_recordingDurationLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:recordSubView attribute:NSLayoutAttributeTrailing multiplier:.1125 constant:1]];
    [recordSubView addConstraint:[NSLayoutConstraint constraintWithItem:_recordButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:recordSubView attribute:NSLayoutAttributeTrailing multiplier:.3438 constant:1]];
    [recordSubView addConstraint:[NSLayoutConstraint constraintWithItem:_playClipButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:recordSubView attribute:NSLayoutAttributeTrailing multiplier:.5656 constant:1]];
    [recordSubView addConstraint:[NSLayoutConstraint constraintWithItem:_clipOkayButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:recordSubView attribute:NSLayoutAttributeTrailing multiplier:.725 constant:1]];
    [recordSubView addConstraint:[NSLayoutConstraint constraintWithItem:cancelClipButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:recordSubView attribute:NSLayoutAttributeTrailing multiplier:.8844 constant:1]];
    
    
    [self resetRecording];
    
    // comment and post view
    _commentAndPostView = [[CommentAndPostView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, commentAndPostViewHeight)];
    [_npControlsView insertSubview:_commentAndPostView belowSubview:_progressBar];
    _commentAndPostView.hidden = YES;
    _commentAndPostView.alpha = 0;
    _commentAndPostView.commentTextView.delegate = self;
    _commentAndPostView.commentTextView.tintColor = [TungCommonObjects tungColor];
    [_commentAndPostView.postActivityIndicator stopAnimating];
    
    // button actions
    [_commentAndPostView.twitterButton addTarget:self action:@selector(toggleTwitterSharing:) forControlEvents:UIControlEventTouchUpInside];
    [_commentAndPostView.facebookButton addTarget:self action:@selector(toggleFacebookSharing:) forControlEvents:UIControlEventTouchUpInside];
    [_commentAndPostView.cancelButton addTarget:self action:@selector(toggleNewComment) forControlEvents:UIControlEventTouchUpInside];
    [_commentAndPostView.postButton addTarget:self action:@selector(post) forControlEvents:UIControlEventTouchUpInside];
    
    // constrain comment and post view
    _commentAndPostView.translatesAutoresizingMaskIntoConstraints = NO;
    _commentViewTopLayoutConstraint = [NSLayoutConstraint constraintWithItem:_commentAndPostView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_npControlsView attribute:NSLayoutAttributeTop multiplier:1 constant:80];
    [_npControlsView addConstraint:_commentViewTopLayoutConstraint];
    [_npControlsView addConstraint:[NSLayoutConstraint constraintWithItem:_commentAndPostView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_npControlsView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [_npControlsView addConstraint:[NSLayoutConstraint constraintWithItem:_commentAndPostView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_npControlsView attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    [_commentAndPostView addConstraint:[NSLayoutConstraint constraintWithItem:_commentAndPostView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:commentAndPostViewHeight]];
    
    [self refreshRecommendAndSubscribeStatus];
    
}

- (void) revealNowPlayingControls {
    
    _timeElapsedLabel.hidden = NO;
    _skipAheadBtn.hidden = NO;
    _skipBackBtn.hidden = NO;
    
    [self beginOnEnterFrame];
    
    [UIView animateWithDuration:.5
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         _npControlsBottomLayoutConstraint.constant = openConstraint;
                         _timeElapsedLabel.alpha = 1;
                         _skipAheadBtn.alpha = 1;
                         _skipBackBtn.alpha = 1;
                         [self.view layoutIfNeeded];
                     }
                     completion:^(BOOL completed) {
                         if (_isNowPlayingView) {
                             // prompt for notifications
                             SettingsEntity *settings = [TungCommonObjects settings];
                             if (!settings.hasSeenMentionsPrompt.boolValue && ![TungCommonObjects hasGrantedNotificationPermissions]) {
                                 UIAlertView *notifPermissionAlert = [[UIAlertView alloc] initWithTitle:@"User Mentions" message:@"Tung can notify you when someone mentions you in a comment, or when new episodes are released for podcasts you subscribe to. Would you like to receive notifications?" delegate:_tung cancelButtonTitle:nil otherButtonTitles:@"No", @"Yes", nil];
                                 [notifPermissionAlert setTag:21];
                                 [notifPermissionAlert show];
                             }
                         }
                     }];
    
}

- (void) setupCircleButton:(UIButton *)button withWidth:(CGFloat)width andHeight:(CGFloat)height andSuperView:(UIView *)superview {
    
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [superview addSubview:button];
    // button constraint: 1 pt from top
    [superview addConstraint:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:superview attribute:NSLayoutAttributeTop multiplier:1 constant:1]];
    // button constraint: width and height
    [button addConstraint:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:width]];
    [button addConstraint:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:height]];
    
}

- (void) setupButtonLabel:(UILabel *)label withButtonDimension:(CGFloat)dimension andSuperView:(UIView *)superview {
    
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [superview addSubview:label];
    label.textColor = [TungCommonObjects tungColor];
    label.font = [UIFont systemFontOfSize:11];
    label.textAlignment = NSTextAlignmentCenter;
    // button constraint: 10 pts from top
    [superview addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:superview attribute:NSLayoutAttributeTop multiplier:1 constant:1 + dimension + 2]];
    
}

- (void) toggleplaybackRate {
    
    if (_tung.playbackRateIndex < _tung.playbackRates.count - 1) {
        _tung.playbackRateIndex++;
    } else {
        _tung.playbackRateIndex = 0;
    }
    
    NSNumber *rate = [_tung.playbackRates objectAtIndex:_tung.playbackRateIndex];
    _speedButton.buttonText = [NSString stringWithFormat:@"%@", [playbackRateStrings objectAtIndex:_tung.playbackRateIndex]];
    [_speedButton setNeedsDisplay];
    
    CLS_LOG(@"set playback rate to %@", rate);
    [_tung.player setRate:rate.floatValue];
    [_tung.trackInfo setObject:[NSNumber numberWithFloat:rate.floatValue] forKey:MPNowPlayingInfoPropertyPlaybackRate];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:_tung.trackInfo];
    
    if ([_tung isPlaying]) [_tung setControlButtonStateToPause];
}

- (void) setPlaybackRateToOne {
    _tung.playbackRateIndex = 1;
    NSNumber *rate = [_tung.playbackRates objectAtIndex:_tung.playbackRateIndex];
    _speedButton.buttonText = [NSString stringWithFormat:@"%@", [playbackRateStrings objectAtIndex:_tung.playbackRateIndex]];
    [_tung.trackInfo setObject:[NSNumber numberWithFloat:rate.floatValue] forKey:MPNowPlayingInfoPropertyPlaybackRate];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:_tung.trackInfo];
    [_speedButton setNeedsDisplay];
    [_tung.player setRate:rate.floatValue];
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

- (void) openPodcastWebsite {
    // open web browsing modal
    if (_episodeEntity.podcast.website.length) {
        if (_tung.connectionAvailable.boolValue) {
            _urlToPass = [NSURL URLWithString:_episodeEntity.podcast.website];            
            [self performSegueWithIdentifier:@"presentWebView" sender:self];
        } else {
            [_podcast showNoConnectionAlert];
        }
    } else {
        CLS_LOG(@"no website");
        
        UIAlertView *noWebsiteAlert = [[UIAlertView alloc] initWithTitle:@"Bummer" message:@"This podcast doesn't have a website url in its feed." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [noWebsiteAlert show];
    }
}

#pragma mark - clip recording and playback methods

- (BOOL) trimAudioFrom:(CGFloat)startMarker to:(CGFloat)endMarker {

    CLS_LOG(@"//// trim audio from %f to %f", startMarker, endMarker);
    // input
//    NSString *audioFile = [NSString stringWithFormat:@"%@", _tung.streamer.outputFile];
//    //CLS_LOG(@"//// audio file to trim: %@", audioFile);
//    NSURL *audioFileUrl = [NSURL URLWithString:audioFile];
    
    NSURL *audioFileUrl = [_tung getEpisodeUrl:[_tung.playQueue objectAtIndex:0]];
    // test if input file has any bytes
    //NSData *audioURLData = [NSData dataWithContentsOfURL:audioFileUrl];
    //CLS_LOG(@"//// audio file data length: %lu", (unsigned long)audioURLData.length);
    // output
    NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"recording.m4a"];
    NSURL *outputFileUrl = [TungCommonObjects getClipFileURL];

    if (!audioFileUrl || !outputFileUrl) {
        CLS_LOG(@"//// ERROR no input or output file url");
    	return NO;
    }
    // delete recording file if exists.
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:outputFilePath error:nil];
    }
    
    AVAsset *asset = [AVAsset assetWithURL:audioFileUrl];

    AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
    if (exportSession == nil) {
        CLS_LOG(@"//// ERROR no export session");
    	return NO;
    }

    CMTime startTime = CMTimeMake((int)(floor(startMarker * 100)), 100);
    CMTime stopTime = CMTimeMake((int)(ceil(endMarker * 100)), 100);
    CMTimeRange exportTimeRange = CMTimeRangeFromTimeToTime(startTime, stopTime);

    exportSession.outputURL = outputFileUrl;
    exportSession.outputFileType = AVFileTypeAppleM4A;
    exportSession.timeRange = exportTimeRange;

    [exportSession exportAsynchronouslyWithCompletionHandler:^ {
        if (AVAssetExportSessionStatusCompleted == exportSession.status) {
            // It worked!
            CLS_LOG(@"//// audio export successful");
            dispatch_async(dispatch_get_main_queue(), ^{
            	[_playClipButton setEnabled:YES];
                [_clipOkayButton setEnabled:YES];
            });
        }
        else if (AVAssetExportSessionStatusFailed == exportSession.status) {
            // It failed...
            CLS_LOG(@"//// audio export failed with status: %ld", (long)exportSession.status);
        }
    }];

    return YES;
}

- (void) toggleRecordState {
    if (_tung.fileIsLocal) {
        // begin recording
        if (!_isRecording) {
            
            // if paused, start playing
            if (![_tung isPlaying]) [_tung playerPlay];
            // if rate not 1, set to 1
            if (_tung.player.rate != 1) [self setPlaybackRateToOne];
            
            CLS_LOG(@"start recording *****");
            _isRecording = YES;
            
            [_playClipButton setEnabled:NO];
            _recordButton.isRecording = YES;
            _recordStartTime = [NSDate date];
            _recordStartMarker = CMTimeGetSeconds(_tung.player.currentTime);
            
            // disable button scrolling
            [_buttonsScrollView setScrollEnabled:NO];
        }
        // stop recording
        else {
            long recordTime = fabs([_recordStartTime timeIntervalSinceNow]);
            if (recordTime >= MIN_RECORD_TIME) {
                CLS_LOG(@"STOP recording *****");
                _recordEndMarker = CMTimeGetSeconds(_tung.player.currentTime);
                _isRecording = NO;
                _recordButton.isRecording = NO;
                [_recordButton setEnabled:NO];
                [_tung playerPause];
                
                [_buttonsScrollView setScrollEnabled:YES];
                [self trimAudioFrom:_recordStartMarker to:_recordEndMarker];
            } else {
                // too short
                UIAlertView *tooShortAlert = [[UIAlertView alloc] initWithTitle:@"Too short" message:[NSString stringWithFormat:@"Clips must be at least %d seconds long", MIN_RECORD_TIME] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [tooShortAlert show];
            }
        }
        [_recordButton setNeedsDisplay];
    } else {
        
        UIAlertView *waitForDownloadAlert = [[UIAlertView alloc] initWithTitle:@"Hang on..." message:@"You can record as soon as this episode finishes downloading." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [waitForDownloadAlert show];
        
        if (!_tung.fileWillBeCached) {
            [_tung saveNowPlayingEpisodeInTempDirectory];
        }
    }
    
}

- (void) togglePlayRecordedClip {
    
    // stop
    if ([_audioPlayer isPlaying]) {
        [self stopPlayback];
        _playClipButton.isPlaying = NO;
    }
    // play
    else {
        [self playbackRecording];
        _playClipButton.isPlaying = YES;
    }
    [_playClipButton setNeedsDisplay];
}

- (void) resetRecording {
    //CLS_LOG(@"reset recording");
    
    if ([_audioPlayer isPlaying]) [_audioPlayer stop];
    _audioPlayer = nil;
    
    _clipHasPosted = NO;
    
    // can record
    [_recordButton setEnabled:YES];
    _recordingDurationLabel.text = @":00";
    [_playClipButton setEnabled:NO];
    _playClipButton.isPlaying = NO;
    [_clipOkayButton setEnabled:NO];
    
}

- (void) playbackRecording {

    // if we're streaming, best stop it.
    if ([_tung isPlaying]) [_tung controlButtonTapped];
    
    // create audio player
    NSURL *clipFileUrl = [TungCommonObjects getClipFileURL];
    NSData *clipData = [NSData dataWithContentsOfURL:clipFileUrl];
    CLS_LOG(@"play clip file with data length: %lu", (unsigned long)clipData.length);
    
    NSError *playbackError;
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:clipFileUrl error:&playbackError];
    
    if (_audioPlayer != nil) {
        _audioPlayer.delegate = self;
        // PLAY
        if ([_audioPlayer prepareToPlay] && [_audioPlayer play]) {
            CLS_LOG(@"audio play started playing. duration: %f", _audioPlayer.duration);
            
        } else {
            CLS_LOG(@"could not play recording");
            [self stopPlayback];
        }
    } else {
        CLS_LOG(@"failed to create audio player");
        CLS_LOG(@"%@", playbackError);
        [self stopPlayback];
    }
}

- (void) stopPlayback {
    
    if ([_audioPlayer isPlaying]) [_audioPlayer stop];
    //_audioPlayer = nil;
    _playClipButton.isPlaying = NO;
    [_playClipButton setNeedsDisplay];
    
}
- (void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    
    if (flag) {
        //CLS_LOG(@"audio player stopped successfully");
        [_clipOkayButton setEnabled:YES];
    }
    _recordingDurationLabel.text = [NSString stringWithFormat:@":%02ld", lroundf(_audioPlayer.duration)];
    [self stopPlayback];
}

- (void) audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    [self stopPlayback];
}
- (void) audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags {
    if (flags == AVAudioSessionInterruptionOptionShouldResume) {
        CLS_LOG(@"audio player end interruption");
    }
}

#pragma mark - manipulating the view


- (void) updateTimeElapsedAndPosbar {
    if (_tung.totalSeconds > 0) {
        float currentTimeSecs = CMTimeGetSeconds(_tung.player.currentTime);
        float val = currentTimeSecs / _tung.totalSeconds;
        _posbar.value = val;
        // time elapsed
        _timeElapsedLabel.text = [TungCommonObjects convertSecondsToTimeString:currentTimeSecs];
    }
}

- (void)updateView {
    
    // duration
    if (!_totalTimeSet && _tung.totalSeconds > 0) {
        _totalTimeLabel.text = [TungCommonObjects convertSecondsToTimeString:_tung.totalSeconds];
        _totalTimeSet = YES;
        [_posbar setEnabled:YES];
    }
    
    // posbar
    if (!_posbarIsBeingDragged) {
        
        [self updateTimeElapsedAndPosbar];
    
    }
    // record time/playing
    if (_isRecording) {
        
        long recordTime = lroundf(fabs([_recordStartTime timeIntervalSinceNow]));
        _recordingDurationLabel.text = [NSString stringWithFormat:@":%02ld", recordTime];
        
        // don't exceed max record time
        if (recordTime > MAX_RECORD_TIME) {
            // stop
            [self toggleRecordState];
            // vibrate
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            // max record time reached alert
            UIAlertView *maxTimeAlert = [[UIAlertView alloc] initWithTitle:@"Max time reached" message:nil delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [maxTimeAlert show];
        }
    }
    if (_audioPlayer && _audioPlayer.isPlaying) {
        
        _recordingDurationLabel.text = [NSString stringWithFormat:@":%02ld", lroundf(_audioPlayer.currentTime)];
    }
    // progress bar
    if (!_tung.fileIsLocal) {
        float buffered = _tung.trackData.length;
        float progress = 0;
        if (buffered > 0 && _tung.npEpisodeEntity.dataLength.doubleValue > 0) {
            progress = buffered / _tung.npEpisodeEntity.dataLength.doubleValue;
        }
        //CLS_LOG(@"buffered: %f, total: %f, progress: %f", buffered, _tung.npEpisodeEntity.dataLength.floatValue, progress);
        _progressBar.progress = progress;
    } else {
        _progressBar.progress = 1;
    }
    
}

- (void) newClip {
    [self toggleNewClipView];
}

- (void) cancelNewClip {
    
    if (_clipConfirmActive) {
        [self toggleNewClipView];
    }
    else {
        if (_playClipButton.enabled) {
            UIAlertView *cancelClipAlert = [[UIAlertView alloc] initWithTitle:@"Start over?" message:@"Your recording will be lost." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"Cancel", nil];
            cancelClipAlert.tag = 3;
            [cancelClipAlert show];
        } else {
            [self toggleNewClipView];
        }
    }
}

- (void) newComment {
    _shareIntention = kNewCommentIntention;
    if (_tung.totalSeconds > 0) {
    	_shareTimestamp = [TungCommonObjects convertSecondsToTimeString:CMTimeGetSeconds(_tung.player.currentTime)];
    } else {
        _shareTimestamp = [TungCommonObjects convertSecondsToTimeString:0];
    }
    _shareLabel.text = [NSString stringWithFormat:@"New comment @ %@", _shareTimestamp];
    _commentAndPostView.commentTextView.text = @"";
    [_commentAndPostView.postButton setEnabled:NO];
    [self toggleNewComment];
}

// show comment and post view with keyboard for sharing or new comment
- (void) toggleNewComment {
    
    if (_keyboardActive) {
        [_commentAndPostView.commentTextView resignFirstResponder];
    } else {
        _commentViewTopLayoutConstraint.constant = 20;
        [_commentAndPostView.commentTextView becomeFirstResponder];
        _commentAndPostView.cancelButton.hidden = NO;
    }
    
}

// toggles clipConfirm view state and scroll view
- (void) toggleNewClipView {
    //CLS_LOG(@"toggle new clip view. clipConfirmActive: %@", (_clipConfirmActive) ? @"YES" : @"NO");
    // dismiss comment and post view
    if (_clipConfirmActive) {
        if (_keyboardActive) {
            // resign keyboard
            if (_playClipButton.enabled) {
                [_clipOkayButton setEnabled:YES];
            }
            [_commentAndPostView.commentTextView resignFirstResponder];
            
        } else {
            // resign comment and post view
        	[self toggleConfirmClip];
        }
    }
    // toggle new clip
    else {
        CGSize scrollViewSize = _buttonsScrollView.frame.size;
        CGPoint currentPoint = _buttonsScrollView.contentOffset;
        CGPoint newPoint;
        
        if (currentPoint.x > 0) { // record new clip
            newPoint = CGPointMake(0,0);
        } else {
            // scroll to main buttons
            newPoint = CGPointMake(scrollViewSize.width,0);
        }
        CGRect scrollToRect = {newPoint, scrollViewSize};
        [_buttonsScrollView scrollRectToVisible:scrollToRect animated:YES];
    }
}

#pragma mark Posbar

- (void) posbarTouched:(UISlider *)slider {
    _posbarIsBeingDragged = YES;
}

- (void) posbarChanged:(UISlider *)slider {
    
    // display position as time elapsed value
    float secondsAtPosition = floorf(slider.value * _tung.totalSeconds);
    _timeElapsedLabel.text = [TungCommonObjects convertSecondsToTimeString:secondsAtPosition];
    
    // limit to preloaded amount
    if (_tung.fileWillBeCached && slider.value > _progressBar.progress) {
        slider.value = _progressBar.progress - 0.001;
    }
}
- (void) posbarReleased:(UISlider *)slider {
    
    _posbarIsBeingDragged = NO;
    
    int secs = floor(slider.value * _tung.totalSeconds);
    //CLS_LOG(@"seek to position %f - %d seconds", slider.value, secs);
    
    CMTime time = CMTimeMake((secs * 100), 100);

    // disable posbar and show spinner while player seeks
    if (_tung.fileIsStreaming) {
        // see if file is cached yet
        if (_tung.fileIsLocal) {
            [_tung replacePlayerItemWithLocalCopy];
        } else {
            [_posbar setEnabled:NO];
            //[_tung playerPause];
        }
    }
    [_tung.player seekToTime:time completionHandler:^(BOOL finished) {
        //CLS_LOG(@"finished seeking to time (%@)", (finished) ? @"yes" : @"no");
        [_tung.trackInfo setObject:[NSNumber numberWithFloat:CMTimeGetSeconds(time)] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:_tung.trackInfo];
        [_posbar setEnabled:YES];
    }];
    
}

#pragma mark Showing/Hiding controls

float dragStartPos;
float constraintStartPos;
static float closedConstraint = -211;
static float openConstraint = -99;
static float clipConfirmConstraint;
float totalAnimDuration = .3;
float animDuration = .3;
BOOL touchedInsideShowHideButton;
BOOL willHide;
UIViewAnimationOptions controlsEasing = UIViewAnimationOptionCurveEaseInOut;


- (void) toggleConfirmClip {
    
    
    if (!clipConfirmConstraint) clipConfirmConstraint = openConstraint + 70;
    
    if (_clipConfirmActive) {
        _shareIntention = nil;
        _shareTimestamp = nil;
        _posbar.hidden = NO;
        _hideControlsButton.hidden = NO;
    } else {
        _shareIntention = kNewClipIntention;
        _shareTimestamp = [TungCommonObjects convertSecondsToTimeString:_recordStartMarker];
        _shareLabel.text = [NSString stringWithFormat:@"New clip @ %@", _shareTimestamp];
        _commentViewTopLayoutConstraint.constant = 80;
        _commentAndPostView.hidden = NO;
        _commentAndPostView.cancelButton.hidden = YES;
        _buttonsScrollView.scrollEnabled = NO;
    }
    
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:.3
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         if (!_clipConfirmActive) { // show clip comment view
                             _npControlsBottomLayoutConstraint.constant = clipConfirmConstraint;
                             _posbar.alpha = 0;
                             _progressBar.alpha = 0;
                             _timeElapsedLabel.alpha = 0;
                             _totalTimeLabel.alpha = 0;
                             _skipAheadBtn.alpha = 0;
                             _skipBackBtn.alpha = 0;
                             _pageControl.alpha = 0;
                             _hideControlsButton.alpha = 0;
                             _commentAndPostView.alpha = 1;
                             _shareLabel.alpha = 1;
                         }
                         else { // hide clip comment view
                             _npControlsBottomLayoutConstraint.constant = openConstraint;
                             _posbar.alpha = 1;
                             _progressBar.alpha = 1;
                             _timeElapsedLabel.alpha = 1;
                             _skipAheadBtn.alpha = 1;
                             _skipBackBtn.alpha = 1;
                             _totalTimeLabel.alpha = 1;
                             _pageControl.alpha = 1;
                             _hideControlsButton.alpha = 1;
                             _commentAndPostView.alpha = 0;
                             _shareLabel.alpha = 0;
                         }
                         [self.view layoutIfNeeded];
                     }
                     completion:^(BOOL completed) {
                         if (_clipConfirmActive) {
                             _commentAndPostView.hidden = YES;
                             _buttonsScrollView.scrollEnabled = YES;
                             [self adjustNewClipViewForClipStatus];
                         } else {
                             _posbar.hidden = YES;
                             _hideControlsButton.hidden = YES;
                             [_clipOkayButton setEnabled:NO];
                         }
                         _clipConfirmActive = !_clipConfirmActive;
                     }];
}

- (void) adjustNewClipViewForClipStatus {
    if (_clipHasPosted) {
        // scroll to main buttons
        [_buttonsScrollView scrollRectToVisible:buttonsScrollViewHomeRect animated:YES];
        [self resetRecording];
    } else {
        if (_playClipButton.enabled) {
        	[_clipOkayButton setEnabled:YES];
        }
    }
}

- (IBAction)toggleNpControlsView:(id)sender {
    
    touchedInsideShowHideButton = NO;
    
    //CLS_LOG(@"animate close with curve: %lu and duration: %f", (unsigned long)controlsEasing, animDuration);
    willHide = NO;
    
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:animDuration
                          delay:0
                        options:controlsEasing
                     animations:^{
                         if (!_npControlsViewIsVisible) { // show controls
                             _npControlsBottomLayoutConstraint.constant = openConstraint;
                             _buttonsScrollView.alpha = 1;
                             _posbar.alpha = 1;
                             _progressBar.alpha = 1;
                             _hideControlsButton.alpha = 1;
                             _showControlsButton.alpha = 0;
                         }
                         else { // hide controls
                             if (_npControlsBottomLayoutConstraint.constant > openConstraint) {
                                 _npControlsBottomLayoutConstraint.constant = openConstraint;
                             }
                             else {
                                 _npControlsBottomLayoutConstraint.constant = closedConstraint;
                                 _buttonsScrollView.alpha = 0;
                                 _posbar.alpha = 0;
                                 _progressBar.alpha = 0;
                                 _hideControlsButton.alpha = 0;
                                 _showControlsButton.alpha = 1;
                                 willHide = YES;
                             }
                         }
                         [self.view layoutIfNeeded];
                     }
                     completion:^(BOOL completed) {
                         if (willHide) {
                             _buttonsScrollView.hidden = YES;
                             _showControlsButton.hidden = NO;
                             _hideControlsButton.hidden = YES;
                         } else {
                             _showControlsButton.hidden = YES;
                         }
                         _npControlsViewIsVisible = !_npControlsViewIsVisible;
                     }];
    
}

#pragma mark - Touch methods


- (IBAction)touchDownInShowHideControlsButton:(id)sender {
    touchedInsideShowHideButton = YES;
    animDuration = totalAnimDuration;
    
    // set drag start position
    if ([sender tag] == 1) { // show controls
        constraintStartPos = closedConstraint;
        dragStartPos = _npControlsView.frame.origin.y + 20;
        _buttonsScrollView.hidden = NO;
        _showControlsButton.hidden = YES;
        _hideControlsButton.hidden = NO;
    }
    else { // hide controls
        if (_clipConfirmActive) {
            constraintStartPos = clipConfirmConstraint;
        }
        else {
        	constraintStartPos = openConstraint;
        }
        dragStartPos = _npControlsView.frame.origin.y + 10;
    }
}


- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    // drag now playing controls
    if (touchedInsideShowHideButton) {
        
        UITouch *touch = [[event allTouches] anyObject];
        CGPoint touchLocation = [touch locationInView:self.view];
        
        controlsEasing = UIViewAnimationOptionCurveEaseOut;
        
        // un hide elements for alpha animation
        _showControlsButton.hidden = NO;
        _hideControlsButton.hidden = NO;
        _buttonsScrollView.hidden = NO;
        
        float diff = touchLocation.y - dragStartPos;
        
        float newConstraint = constraintStartPos - diff;
        
        // reduce drag distance when going past all the way open
        if (newConstraint > openConstraint) {
            float cDiff = newConstraint - openConstraint;
            float ratio = (cDiff < 200) ? cDiff/200 : 1;
            //CLS_LOG(@"ratio: %f", ratio);
            newConstraint = openConstraint + 100 * ratio;
        }
        // stop drag at bottom
        if (newConstraint < closedConstraint) newConstraint = closedConstraint;
        
        //CLS_LOG(@"drag controls with diff: %f to new constraint: %f", diff, newConstraint);
        _npControlsBottomLayoutConstraint.constant = newConstraint;
        
        // animate alpha of controls
        float total = openConstraint - closedConstraint;
        float prog = fabsf(newConstraint) - fabsf(openConstraint);
        //CLS_LOG(@"prog %f / total %f = decimal %f", prog, total, prog/total);
        float decimal = 1 - (prog / total);
        animDuration = fabsf((1-(fabsf(diff) / total)) * totalAnimDuration);
        //CLS_LOG(@"animation duration: %f", animDuration);
        //float decimal = fabsf(newConstraint) - fabsf(openConstraint) / (openConstraint - closedConstraint);
        //CLS_LOG(@"decimal: %f", decimal);
        float alpha = (decimal > 1) ? 1 : decimal;
        _buttonsScrollView.alpha = alpha;
        _posbar.alpha = alpha;
        _hideControlsButton.alpha = alpha;
        _showControlsButton.alpha = 1 - alpha;
    }

}

#pragma mark - text view delegate methods

- (void)textViewDidChange:(UITextView *)textView {
    
    // enable post button if there's text
    NSString *nonWhitespace = [textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (nonWhitespace.length > 0 && !_commentAndPostView.postButton.enabled) {
        [_commentAndPostView.postButton setEnabled:YES];
    }
    // count characters?
    //CLS_LOG(@"char count: %lu", (unsigned long)textView.text.length);
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
    
    // count characters?
    
    // fade out label
    [TungCommonObjects fadeOutView:_commentAndPostView.tapToCommentLabel];

}

- (void)textViewDidEndEditing:(UITextView *)textView {
    
    if ([_commentAndPostView.commentTextView.text isEqualToString:@""]) {
        [TungCommonObjects fadeInView:_commentAndPostView.tapToCommentLabel];
    } else {
        CLS_LOG(@"*** reached comment character limit ***");
    }

}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    // keep text limited to MAX_CAPTION_CHARS
    if (range.location >= MAX_COMMENT_CHARS) {
        return NO; // return NO to not change text
    } else {
        return YES;
    }
}

- (void) keyboardWillAppear:(NSNotification*)notification {
    if (_shareIntention && !_searchActive) {
        
        NSDictionary *keyboardInfo = [notification userInfo];
        NSValue *keyboardFrameBegin = [keyboardInfo valueForKey:UIKeyboardFrameBeginUserInfoKey];
        CGRect keyboardRectBegin = [keyboardFrameBegin CGRectValue];
        NSValue *keyboardFrameEnd = [keyboardInfo valueForKey:UIKeyboardFrameEndUserInfoKey];
        CGRect keyboardRectEnd = [keyboardFrameEnd CGRectValue];
        //CLS_LOG(@"keyboard will appear. %@", keyboardInfo);
        //CLS_LOG(@"keyboard will appear. rect begin: %@, rect end: %@", NSStringFromCGRect(keyboardRectBegin),NSStringFromCGRect(keyboardRectEnd));
        
        // keyboard changes height (switch to emoji, open auto complete
        if (_keyboardActive) {
            
            CGFloat diff = keyboardRectEnd.size.height - keyboardRectBegin.size.height;
            
            _npControlsBottomLayoutConstraint.constant += diff;
            [self.view layoutIfNeeded];
            
        }
        // keyboard appears
        else {
        
            // disable search
            [self.navigationItem.rightBarButtonItem setEnabled:NO];
            
            _commentAndPostView.hidden = NO;
            _buttonsScrollView.scrollEnabled = NO;
            
            [UIView beginAnimations:@"keyboard up" context:NULL];
            [UIView setAnimationDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
            [UIView setAnimationCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue]];
            [UIView setAnimationBeginsFromCurrentState:YES];
            [UIView setAnimationDelegate:self];
            [UIView setAnimationDidStopSelector:@selector(keyboardAnimationStopped:finished:context:)];
            // properties to animate
            _commentAndPostView.tapToCommentLabel.alpha = 0;
            _hideControlsButton.alpha = 0;
            _shareLabel.alpha = 1;
            // for new clip
            if ([_shareIntention isEqualToString:kNewClipIntention]) {
                _npControlsBottomLayoutConstraint.constant = clipConfirmConstraint + keyboardRectBegin.size.height - 44;
            }
            // for new comment
            else if ([_shareIntention isEqualToString:kNewCommentIntention]) {
                _npControlsBottomLayoutConstraint.constant = openConstraint + keyboardRectBegin.size.height - 44;
                _buttonsScrollView.alpha = 0;
                _posbar.alpha = 0;
                _progressBar.alpha = 0;
                _timeElapsedLabel.alpha = 0;
                _totalTimeLabel.alpha = 0;
                _pageControl.alpha = 0;
                _commentAndPostView.alpha = 1;
            }
            [self.view layoutIfNeeded];
            
            [UIView commitAnimations];
            
            _keyboardActive = YES;
        }
    }
}

//- (void) keyboardWillChangeFrame:(NSNotification*)notification {
//}

- (void) keyboardWillBeHidden:(NSNotification*)notification {
    
    if (_shareIntention && !_searchActive) {
        _hideControlsButton.hidden = NO;
        _buttonsScrollView.hidden = NO;
        _posbar.hidden = NO;
        //CLS_LOG(@"keyboard will be hidden");
        
        [UIView beginAnimations:@"keyboard down" context:NULL];
        [UIView setAnimationDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
        [UIView setAnimationCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue]];
        [UIView setAnimationBeginsFromCurrentState:YES];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(keyboardAnimationStopped:finished:context:)];
        // hide clip comment view

        _hideControlsButton.alpha = 1;
        _npControlsBottomLayoutConstraint.constant = openConstraint;
        _posbar.alpha = 1;
        _progressBar.alpha = 1;
        _timeElapsedLabel.alpha = 1;
        _totalTimeLabel.alpha = 1;
        _skipAheadBtn.alpha = 1;
        _skipBackBtn.alpha = 1;
        _pageControl.alpha = 1;
        _hideControlsButton.alpha = 1;
        _buttonsScrollView.alpha = 1;
        _commentAndPostView.alpha = 0;
        _shareLabel.alpha = 0;
        [self.view layoutIfNeeded];
        
        [UIView commitAnimations];
    }
    _searchActive = NO;
    _keyboardActive = NO;
}

- (void) keyboardAnimationStopped:(NSString *)animationId finished:(NSNumber *)finished context:(void *)context {
    //NSLog(@"keyboard animation stopped");
    // keyboard going up
    if ([animationId isEqualToString:@"keyboard up"]) {
        _hideControlsButton.hidden = YES;
        // for new comment
        if ([_shareIntention isEqualToString:kNewCommentIntention]) {
            _buttonsScrollView.hidden = YES;
        }
    }
    else if ([animationId isEqualToString:@"keyboard down"]) {
        _shareIntention = nil;
        _shareTimestamp = nil;
        _commentAndPostView.hidden = YES;
        _clipConfirmActive = NO;
        _buttonsScrollView.scrollEnabled = YES;
        
        [self adjustNewClipViewForClipStatus];
        // re-enable search
        [self.navigationItem.rightBarButtonItem setEnabled:YES];
        // reset posting
        [_commentAndPostView.postButton setEnabled:YES];
        [_commentAndPostView.postActivityIndicator stopAnimating];
        // for after comment/clip posted
        if ([_commentAndPostView.commentTextView.text isEqualToString:@""]) {
            _commentAndPostView.tapToCommentLabel.alpha = 1;
        }
    }
}

#pragma mark - Sharing

- (void) toggleTwitterSharing:(id)sender {
    
    CircleButton *btn = (CircleButton *)sender;
    
    btn.on = !btn.on;
    [btn setNeedsDisplay];
    
    if (btn.on) {
        if (![Twitter sharedInstance].sessionStore.session) {
            if (_keyboardActive) {
				[_commentAndPostView.commentTextView resignFirstResponder];
            }
            [[Twitter sharedInstance] logInWithCompletion:^(TWTRSession *session, NSError *error) {
                if (!session) {
                    NSLog(@"error: %@", [error localizedDescription]);
                    btn.on = NO;
                    [btn setNeedsDisplay];
                }
            }];
        }
    }
}

- (void) toggleFacebookSharing:(id)sender {
    CircleButton *btn = (CircleButton *)sender;
    
    btn.on = !btn.on;
    [btn setNeedsDisplay];
    
    if (btn.on) {
        
        if ([FBSDKAccessToken currentAccessToken]) {
            if (![[FBSDKAccessToken currentAccessToken] hasGranted:@"publish_actions"]) {
                [self getFacebookSharingPermissions];
            }
        }
        else {
            [self getFacebookSharingPermissions];
        }
     
    }
}

- (void) getFacebookSharingPermissions {
    FBSDKLoginManager *loginManager = [[FBSDKLoginManager alloc] init];
    [loginManager logInWithPublishPermissions:@[@"publish_actions"] fromViewController:self handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if (error) {
            NSString *alertText = [NSString stringWithFormat:@"\"%@\"", error];
            UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Facebook error" message:alertText delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [errorAlert show];
        }
        else if (result.isCancelled) {
            NSString *alertTitle = @"Tung was denied permission";
            NSString *alertText = @"Tung cannot currently post to Facebook because it was denied posting permission.";
            UIAlertView *fbAlert = [[UIAlertView alloc] initWithTitle:alertTitle
                                                              message:alertText
                                                             delegate:self
                                                    cancelButtonTitle:@"OK"
                                                    otherButtonTitles:nil];
            [fbAlert show];
        }
    }];
}


- (void) post {
    
    NSString *text = [_commentAndPostView.commentTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // post a comment
    // assumed to have text since otherwise post button is disabled
    if ([_shareIntention isEqualToString:kNewCommentIntention]) {
        
        [TungCommonObjects fadeOutView:_commentAndPostView.cancelButton];
        [_commentAndPostView.postButton setEnabled:NO];
        [_commentAndPostView.postActivityIndicator startAnimating];
        
        [_tung postComment:text atTime:_shareTimestamp onEpisode:_tung.npEpisodeEntity withCallback:^(BOOL success, NSDictionary *responseDict) {
            [_commentAndPostView.postActivityIndicator stopAnimating];
            [_commentAndPostView.postButton setEnabled:YES];
            [TungCommonObjects fadeInView:_commentAndPostView.cancelButton];
            if (success) {
                
                [self switchToViewAtIndex:1];
                [self refreshComments:YES];
                
                _commentAndPostView.commentTextView.text = @"";
                [self toggleNewComment];
                
                NSString *username = [[_tung getLoggedInUserData] objectForKey:@"username"];
                NSString *link = [NSString stringWithFormat:@"%@s/%@/%@", _tung.tungSiteRootUrl, _tung.npEpisodeEntity.shortlink, username];
                // tweet?
                if (_commentAndPostView.twitterButton.on) {
                    [_tung postTweetWithText:text andUrl:link];
                }
                // fb share?
                if (_commentAndPostView.facebookButton.on) {
                    [_tung postToFacebookWithText:text Link:link andEpisode:_tung.npEpisodeEntity];
                }
            }
            else {
                [self toggleNewComment];
                NSString *errorMsg = [responseDict objectForKey:@"error"];
                [self displayErrorAlertWithMessage:errorMsg];
            }
        }];
    }
    // post a clip
    else if ([_shareIntention isEqualToString:kNewClipIntention]) {
        
        [_commentAndPostView.postButton setEnabled:NO];
        [_commentAndPostView.postActivityIndicator startAnimating];
        
        [_tung postClipWithComment:text atTime:_shareTimestamp withDuration:[_recordingDurationLabel.text substringFromIndex:1] onEpisode:_tung.npEpisodeEntity withCallback:^(BOOL success, NSDictionary *responseDict) {
            [_commentAndPostView.postActivityIndicator stopAnimating];
            [_commentAndPostView.postButton setEnabled:YES];
            if (success) {
                if (text.length > 0) {
                    [self switchToViewAtIndex:1];
                	[self refreshComments:YES];
                }
                _clipHasPosted = YES;
                _commentAndPostView.commentTextView.text = @"";
                
	
                NSString *eventShortlink = [responseDict objectForKey:@"eventShortlink"];
                NSString *link = [NSString stringWithFormat:@"%@c/%@", _tung.tungSiteRootUrl, eventShortlink];
                // caption
                NSString *caption;
                if (text && text.length > 0) {
                    caption = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                } else {
                    caption = @"I just shared a podcast clip on #tung -";
                }
                
                // tweet?
                if (_commentAndPostView.twitterButton.on) {
                    [_tung postTweetWithText:caption andUrl:link];
                }
                // fb share?
                if (_commentAndPostView.facebookButton.on) {
                    [_tung postToFacebookWithText:text Link:link andEpisode:_tung.npEpisodeEntity];
                }
            }
            else {
                NSString *errorMsg = [responseDict objectForKey:@"error"];
                [self displayErrorAlertWithMessage:errorMsg];
            }
            
            [self toggleNewClipView];
        }];
    }
}
- (void) recommendEpisode {
    
    if (_tung.connectionAvailable) {
        _recommendButton.recommended = !_recommendButton.recommended;
        [_recommendButton setNeedsDisplay];
        _recommendLabel.text = (_recommendButton.recommended) ? @"Recommended" : @"Recommend";
        
        if (_recommendButton.recommended) {
            [_tung recommendEpisode:_tung.npEpisodeEntity withCallback:^(BOOL success, NSDictionary *responseDict) {
                if (!success) {
                    // failed to recommend
                    _recommendButton.recommended = NO;
                    [_recommendButton setNeedsDisplay];
                    _recommendLabel.text = @"Recommend";
                    NSString *errorMsg = [responseDict objectForKey:@"error"];
                    [self displayErrorAlertWithMessage:errorMsg];
                }
            }];
        }
        else {
            [_tung unRecommendEpisode:_tung.npEpisodeEntity];
        }
        _tung.npEpisodeEntity.isRecommended = [NSNumber numberWithBool:_recommendButton.recommended];
    }
    else {
        [_podcast showNoConnectionAlert];
    }
}

- (void) getTextForShareSheet {
    
    // if there's a story to share, share it
    if (_tung.npEpisodeEntity.shortlink) {
        [self openShareSheetForEntity:_tung.npEpisodeEntity];
    }
    // need to get episode shortlink
    else {
        __unsafe_unretained typeof(self) weakSelf = self;
        [_tung addEpisode:_tung.npEpisodeEntity withCallback:^{
            [weakSelf openShareSheetForEntity:weakSelf.tung.npEpisodeEntity];
        }];
    }
}

- (void) openShareSheetForEntity:(EpisodeEntity *)episodeEntity {
    
    NSDictionary *userDict = [_tung getLoggedInUserData];
    NSString *username = [userDict objectForKey:@"username"];
    NSString *text = [NSString stringWithFormat:@"Listening to %@ on #tung: %@e/%@/%@", episodeEntity.title, _tung.tungSiteRootUrl, episodeEntity.shortlink, username];
    
    UIActivityViewController *shareSheet = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];
    [self presentViewController:shareSheet animated:YES completion:nil];
}

- (void) displayErrorAlertWithMessage:(NSString *)message {
    UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:message delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [errorAlert show];
}


#pragma mark - Handle alerts / action sheets

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    CLS_LOG(@"dismissed alert with button index: %ld", (long)buttonIndex);
    
    // reset recording prompt
    if (alertView.tag == 3) {
        if (buttonIndex == 0) [self resetRecording];
    }
}

/* not used
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    CLS_LOG(@"dismissed actionSheet with button index: %ld", (long)buttonIndex);
    
}
*/

#pragma mark - scroll view delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {

    float fractionalPage = (uint) scrollView.contentOffset.x / screenWidth;
    NSInteger page = lround(fractionalPage);
    _pageControl.currentPage = page;
    
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UINavigationController *destination = segue.destinationViewController;
    
    if ([[segue identifier] isEqualToString:@"presentWebView"]) {
        BrowserViewController *browserViewController = (BrowserViewController *)destination;
        [browserViewController setValue:_urlToPass forKey:@"urlToNavigateTo"];
    }

}



@end
