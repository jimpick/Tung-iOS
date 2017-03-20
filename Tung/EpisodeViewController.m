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
#import <CoreText/CoreText.h>

#include <AudioToolbox/AudioToolbox.h>

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>

typedef enum {
    kControlsStateOpen,
    kControlsStateClosed,
    kControlsStateNotPlayingOpen,
    kControlsStateNotPlayingClosed
} ControlsState;

@interface EpisodeViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) TungPodcast *tungPodcast;
@property HeaderView *headerView;
@property CADisplayLink *onEnterFrame;
@property ControlsState controlsState;
@property CircleButton *recommendButton;
@property CircleButton *recordButton;
@property CircleButton *playClipButton;
@property CircleButton *clipOkayButton;
@property CircleButton *commentButton;
@property CircleButton *speedButton;
@property CircleButton *saveButton;
@property UILabel *recommendLabel;
@property UILabel *commentLabel;
@property UILabel *recordingDurationLabel;
@property UILabel *saveLabel;
@property CommentAndPostView *commentAndPostView;
@property NSLayoutConstraint *commentViewTopLayoutConstraint;
@property BOOL clipConfirmActive;
@property BOOL keyboardActive;
@property BOOL searchActive;
@property BOOL clipHasPosted;
@property NSString *shareIntention;
@property NSString *shareTimestamp;
@property NSString *recordingDuration;
@property NSString *lastPlayingGuid;

@property UIToolbar *switcherBar;
@property UISegmentedControl *switcher;
@property NSInteger switcherIndex;
@property DescriptionWebViewController *descriptionView;
@property EpisodesTableViewController *episodesView;
@property CommentsTableViewController *commentsView;
@property AVAudioPlayer *audioPlayer;
@property UIView *nothingPlayingView;
@property NSString *urlStringToPass;
@property BOOL lockPosbar;
@property BOOL posbarIsBeingDragged;
@property UIBarButtonItem *tungBarButtonItem;

@property BOOL isRecording;
@property NSDate *recordStartTime;
@property CGFloat recordStartMarker;
@property CGFloat recordEndMarker;
@property BOOL totalTimeSet;
@property BOOL isNowPlayingView;
@property BOOL touchedInsideShowHideButton;

@property NSLayoutConstraint *descriptionViewBottomConstraint;
@property NSLayoutConstraint *commentsViewBottomConstraint;
@property NSLayoutConstraint *episodesViewBottomConstraint;

@property CGFloat defaultHeaderHeight;
@property CGFloat commentAndPostViewHeight;
@property CGSize screenSize;

- (void) switchViews:(id)sender;
- (void) switchToViewAtIndex:(NSInteger)index;
- (void) initiatePodcastSearch;

@end

@implementation EpisodeViewController

// static
static NSString *kNewClipIntention = @"New clip";
static NSString *kNewCommentIntention = @"New comment";
static NSArray *playbackRateStrings;

float controls_dragStartPos = NAN;
float controls_constraintStartPos = NAN;
static float controls_closedConstraint = -211.0;
static float controls_notPlayingConstraint = -145.0;
static float controls_openConstraint = -99.0;
static float controls_clipConfirmConstraint;
static float episodeSubviews_bottomConstraintNotPlaying = -147.0;
static float episodeSubviews_bottomConstraintPlaying = -80.0;
UIViewAnimationOptions controls_easing = UIViewAnimationOptionCurveEaseInOut;


- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    _tungPodcast = [TungPodcast new];
    
    _defaultHeaderHeight = 164;
    _commentAndPostViewHeight = 123;
    _screenSize = [TungCommonObjects screenSize];

    
    // is this for now playing?
    if (_episodeMiniDict || _episodeShortlink || _episodeEntity) {
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
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiatePodcastSearch)];
        
        // tung button
        IconButton *tungButtonInner = [[IconButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
        tungButtonInner.type = kIconButtonTypeTungLogoType;
        tungButtonInner.color = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];
        [tungButtonInner addTarget:self action:@selector(tungButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        _tungBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:tungButtonInner];
        self.navigationItem.leftBarButtonItem = _tungBarButtonItem;
        
        self.view.backgroundColor = [TungCommonObjects bkgdGrayColor];
        
        // nothing playing?
        UILabel *nothingPlayingLabel = [[UILabel alloc] init];
        nothingPlayingLabel.text = @"Nothing is currently playing.";
        nothingPlayingLabel.numberOfLines = 2;
        nothingPlayingLabel.textColor = [UIColor grayColor];
        nothingPlayingLabel.textAlignment = NSTextAlignmentCenter;
        CGFloat screenWidth = [TungCommonObjects screenSize].width;
        CGSize labelSize = [nothingPlayingLabel sizeThatFits:CGSizeMake(screenWidth, 400)];
        CGRect labelRect = CGRectMake(0, 0, screenWidth, labelSize.height);
        nothingPlayingLabel.frame = labelRect;
        
        CGFloat buttonHeight = 40;
        float yPos = labelSize.height;
        UIButton *searchPodcastsBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, yPos, screenWidth, buttonHeight)];
        [searchPodcastsBtn setTitle:@"Search podcasts" forState:UIControlStateNormal];
        [searchPodcastsBtn setTitleColor:[TungCommonObjects tungColor] forState:UIControlStateNormal];
        [searchPodcastsBtn addTarget:self action:@selector(initiatePodcastSearch) forControlEvents:UIControlEventTouchUpInside];
        
        yPos += buttonHeight;
        _nothingPlayingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, yPos)];
        [_nothingPlayingView addSubview:nothingPlayingLabel];
        [_nothingPlayingView addSubview:searchPodcastsBtn];
        _nothingPlayingView.hidden = YES;
        [self.view addSubview:_nothingPlayingView];
        _nothingPlayingView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_nothingPlayingView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_nothingPlayingView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        [_nothingPlayingView addConstraint:[NSLayoutConstraint constraintWithItem:_nothingPlayingView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:screenWidth]];
        [_nothingPlayingView addConstraint:[NSLayoutConstraint constraintWithItem:_nothingPlayingView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:yPos]];

    }
    
    // now playing controls
    _controlsView.opacity = .4;
    _controlsView.tintColor = [UIColor lightGrayColor];
    _controlsBottomLayoutConstraint.constant = controls_notPlayingConstraint;
    _controlsState = kControlsStateNotPlayingOpen;
    
    _buttonsScrollView.alpha = 1;
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
    _hideControlsButton.alpha = 1;
    _showControlsButton.type = kShowHideButtonTypeShow;
    _showControlsButton.viewController = self;
    _showControlsButton.alpha = 0;
    _showControlsButton.hidden = YES;
    
    [_posbar setThumbImage:[UIImage imageNamed:@"posbar-thumb.png"] forState:UIControlStateNormal];
    _posbar.minimumTrackTintColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0]; // .5
    _posbar.maximumTrackTintColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0]; // .2
    [_posbar addTarget:self action:@selector(posbarChanged:) forControlEvents:UIControlEventValueChanged];
    [_posbar addTarget:self action:@selector(posbarTouched:) forControlEvents:UIControlEventTouchDown];
    [_posbar addTarget:self action:@selector(posbarReleased:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    _posbar.value = 0;
    _posbar.alpha = 0;
    _posbar.hidden = YES;
    
    // file download progress
    _progressBar.trackTintColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:.15];
    _progressBar.progressTintColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:.3];
    _progressBar.progress = 0;
    _progressBar.alpha = 0;
    _progressBar.hidden = YES;
    
    playbackRateStrings = @[@".75x", @"1.0x", @"1.5x", @"2.0x"];
    
    // share label
    _shareLabel.text = @"";
    _shareLabel.alpha = 0;
    _shareLabel.textColor = [TungCommonObjects tungColor];
    _totalTimeLabel.text = @"--:--:--";
    
    // for search controller
    self.definesPresentationContext = YES;
    _tungPodcast.navController = [self navigationController];
    _tungPodcast.delegate = self;
    
    // header view
    _headerView = [[HeaderView alloc] initWithFrame:CGRectMake(0, 64, _screenSize.width, _defaultHeaderHeight)];
    [self.view insertSubview:_headerView belowSubview:_controlsView];
    [_headerView constrainHeaderViewInViewController:self];
    _headerView.hidden = YES;
    // respond when podcast art is updated
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshViewForArtChange:) name:@"podcastArtUpdated" object:nil];
    
    // switcher bar
    _switcherBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, _screenSize.width, 44)];
    _switcherBar.clipsToBounds = YES;
    _switcherBar.opaque = YES;
    _switcherBar.translucent = NO;
    _switcherBar.backgroundColor = [UIColor whiteColor];
    _switcherBar.hidden = YES;
    // set up segemented control
    NSArray *switcherItems = @[@"Description", @"Comments", @"Episodes"];
    _switcher = [[UISegmentedControl alloc] initWithItems:switcherItems];
    _switcher.tintColor = [UIColor lightGrayColor];
    _switcher.frame = CGRectMake(0, 0, _screenSize.width - 20, 28);
    [_switcher addTarget:self action:@selector(switchViews:) forControlEvents:UIControlEventValueChanged];
    UIBarButtonItem *switcherBarItem = [[UIBarButtonItem alloc] initWithCustomView:(UIView *)_switcher];
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    [_switcherBar setItems:@[flexSpace, switcherBarItem, flexSpace] animated:NO];
    [self.view insertSubview:_switcherBar belowSubview:_controlsView];
    _switcherBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_switcherBar attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_headerView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [_switcherBar addConstraint:[NSLayoutConstraint constraintWithItem:_switcherBar attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:44]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_switcherBar attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_switcherBar.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_switcherBar attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_switcherBar.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    _switcherIndex = 0;
    
    // description
    _descriptionView = [self.storyboard instantiateViewControllerWithIdentifier:@"descWebView"];
    _descriptionView.edgesForExtendedLayout = UIRectEdgeNone;
    [self addChildViewController:_descriptionView];
    [self.view insertSubview:_descriptionView.view atIndex:1];
    _descriptionView.webView.delegate = self;
    _descriptionView.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_descriptionView.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_switcherBar attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    _descriptionViewBottomConstraint = [NSLayoutConstraint constraintWithItem:_descriptionView.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_descriptionView.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:episodeSubviews_bottomConstraintNotPlaying];
    [self.view addConstraint:_descriptionViewBottomConstraint];
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
    _commentsViewBottomConstraint = [NSLayoutConstraint constraintWithItem:_commentsView.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_commentsView.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:episodeSubviews_bottomConstraintNotPlaying];
    [self.view addConstraint:_commentsViewBottomConstraint];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_commentsView.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_commentsView.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_commentsView.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_commentsView.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    // episode view starts out hidden
    _commentsView.view.hidden = YES;
    _commentsView.viewController = self;
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
    _episodesView.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_switcherBar attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    _episodesViewBottomConstraint = [NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_episodesView.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:episodeSubviews_bottomConstraintNotPlaying];
    [self.view addConstraint:_episodesViewBottomConstraint];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_episodesView.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_episodesView.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    // episode view starts out hidden
    _episodesView.view.hidden = YES;
    
    // listen for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowPlayingDidChange) name:@"nowPlayingDidChange" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveStatusChanged) name:@"saveStatusDidChange" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillAppear:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareView) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resignKeyboardIfActive) name:@"shouldResignKeyboard" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshSubscribeStatus:) name:@"refreshSubscribeStatus" object:nil];
    
    
    [self setupControls];
    
    if (!_isNowPlayingView) {
        
        // episode view pushed from EpisodesTableViewController
        if (_episodeEntity) {
            [self setUpViewForEpisode:_episodeEntity];
        }
        // episode view pushed from StoriesTableViewController or notifications
        else if (_episodeMiniDict) {
            NSString *episodeId = [[_episodeMiniDict objectForKey:@"id"] objectForKey:@"$id"];

            // check for episode entity
            _episodeEntity = [TungCommonObjects getEpisodeEntityFromEpisodeId:episodeId];
            
            if (_episodeEntity && _episodeEntity.title && _episodeEntity.podcast && _episodeEntity.podcast.feedUrl) {
                //NSLog(@"will set up view for complete episode entity: %@", _episodeEntity);
                [self setUpViewForEpisode:_episodeEntity];
            }
            else {
                //NSLog(@"will set up view for episode mini dict then request episode data");
                // no entity yet, request data
                [_headerView setUpHeaderViewForEpisodeMiniDict:_episodeMiniDict];
                
                [self getEpisodeInfoAndSetUpViewWithDict:_episodeMiniDict];
                
            }
        }
        else if (_episodeShortlink) {
            
            NSDictionary *dict = @{ @"shortlink":_episodeShortlink };
            
            [self getEpisodeInfoAndSetUpViewWithDict:dict];
            
        }
    }
}

- (void) getEpisodeInfoAndSetUpViewWithDict:(NSDictionary *)dict {
    
    [_backgroundSpinner startAnimating];
    [TungCommonObjects requestEpisodeInfoWithDict:dict andCallback:^(BOOL success, NSDictionary *responseDict) {
        [_backgroundSpinner stopAnimating];
        if (success) {
            NSDictionary *episodeDict = [responseDict objectForKey:@"episode"];
            NSDictionary *podcastDict = [responseDict objectForKey:@"podcast"];
            PodcastEntity *podcastEntity = [TungCommonObjects getEntityForPodcast:podcastDict save:NO];
            _episodeEntity = [TungCommonObjects getEntityForEpisode:episodeDict withPodcastEntity:podcastEntity save:YES];
            
            [self setUpViewForEpisode:_episodeEntity];
        }
        else {
            [TungCommonObjects simpleErrorAlertWithMessage:responseDict[@"error"]];
        }
    }];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.translucent = NO;
    [self prepareView];
}

- (void) prepareView {
    if (_isNowPlayingView || _episodeEntity.isNowPlaying.boolValue) {
        [self updateTimeElapsedAndPosbar];
        [self beginOnEnterFrame];
        if (_isNowPlayingView && !_tung.npViewSetupForCurrentEpisode) {
            [self setUpViewForWhateversPlaying];
        }
    }
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    _tung.viewController = self;
    
    // set up views
    if (_isNowPlayingView) {
        
        [self beginOnEnterFrame];
        //float thresholdConstant =
        if (_episodeEntity.isNowPlaying.boolValue) {
            [NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(animateControlsToOpen) userInfo:nil repeats:NO];
        }
        
    }
    else if (_episodeEntity.isNowPlaying.boolValue) {
        
        [self beginOnEnterFrame];
        [NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(animateControlsToOpen) userInfo:nil repeats:NO];
    }
    else {
        [NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(animateControlsToNotPlayingOpen) userInfo:nil repeats:NO];
    }
    
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_tungPodcast.feedPreloadQueue cancelAllOperations];
    [_onEnterFrame invalidate];
    [markAsSeenTimer invalidate];
    
    // remove extra observers
    if (!_isNowPlayingView) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"nowPlayingDidChange" object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"saveStatusDidChange" object:nil];
    }
    
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    /*
    if (_isNowPlayingView && _tungPodcast.searchController.active) {
        [_tungPodcast.searchController setActive:NO];
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
            [_episodesView assignSavedPropertiesToEpisodeArray];
            [_episodesView.tableView reloadData];
            markAsSeenTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:_episodesView selector:@selector(markNewEpisodesAsSeen) userInfo:nil repeats:NO];
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


- (void) initiatePodcastSearch {
    
    //NSLog(@"initiate podcast search");
    // in case sharing in progress, don't animate share view
    _searchActive = YES;
    
    [_tungPodcast.searchController setActive:YES];
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"revealSearch"];
    
    self.navigationItem.titleView = _tungPodcast.searchController.searchBar;
    [self.navigationItem setRightBarButtonItem:nil animated:YES];
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    
    [_tungPodcast.searchController.searchBar becomeFirstResponder];
    
}

-(void) dismissPodcastSearch {
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"hideSearch"];
    
    self.navigationItem.titleView = nil;
    UIBarButtonItem *searchBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiatePodcastSearch)];
    [self.navigationItem setRightBarButtonItem:searchBtn animated:YES];
    if (_isNowPlayingView) {
        [self.navigationItem setLeftBarButtonItem:_tungBarButtonItem animated:YES];
    }
    
}

#pragma mark - Handle notifications

-(void) nowPlayingDidChange {
    //NSLog(@"now playing did change - %@", _episodeEntity.title);
    _commentAndPostView.commentTextView.text = @"";
    
    if (_isNowPlayingView) {
        _episodeEntity = _tung.npEpisodeEntity;
        [self setUpViewForWhateversPlaying];
        [self resetRecording];
        [self setPlaybackRateToOne];
    } else {
        // episode view - episode either began or ended
        
        if (_episodeEntity.isNowPlaying.boolValue) {
            //JPLog(@"//////// nowPlayingDidChange: episode just started playing");
            [self animateControlsToOpen];
            _lastPlayingGuid = _episodeEntity.guid;
            
            [_episodesView.tableView reloadData];
            
            [self beginOnEnterFrame];
        }
        else if (_lastPlayingGuid && [_lastPlayingGuid isEqualToString:_episodeEntity.guid]) {
            //JPLog(@"//////// nowPlayingDidChange: episode is finished playing");
            
            [self animateControlsToNotPlayingOpen];
            _headerView.largeButton.on = NO;
            [_headerView.largeButton setNeedsDisplay];
            [_onEnterFrame invalidate];
            _progressBar.progress = 0;
            _posbar.value = 0;
            
            [_episodesView.tableView reloadData];
            
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC);
            dispatch_after(delay, dispatch_get_main_queue(), ^(void){
                [TungCommonObjects showBannerAlertForText:@"This episode ended. To see now playing, tap 🔈 in the bottom bar."];
            });
        }
    }
}

- (void) saveStatusChanged {
    _saveButton.on = _episodeEntity.isSaved.boolValue;
    _saveLabel.text = (_saveButton.on) ? @"Saved" : @"Save";
    [_saveButton setNeedsDisplay];
    
    if (!_saveButton.on) {
        _progressBar.progress = 0;
    }
}

- (void) refreshSubscribeStatus:(NSNotification *) notification {
    NSNumber *collectionId = [[notification userInfo] objectForKey:@"collectionId"];
    
    if (_episodeEntity && [collectionId isEqualToNumber:_episodeEntity.podcast.collectionId]) {
        _headerView.subscribeButton.subscribed = _episodeEntity.podcast.isSubscribed.boolValue;
        [_headerView.subscribeButton setNeedsDisplay];
    }
}

#pragma mark - Set up view

// if something's playing, setup view for it, else set up for nothing playing
- (void) setUpViewForWhateversPlaying {
    
    [_posbar setEnabled:NO];
    _posbar.value = 0;
    _totalTimeSet = NO;
        
    if (_tung.npEpisodeEntity && _tung.npEpisodeEntity.title) {
        _episodeEntity = _tung.npEpisodeEntity;
        
        self.view.backgroundColor = [UIColor whiteColor];
        // initialize views
        //JPLog(@"setup view for now playing: %@", _tung.npEpisodeEntity.title);
        _nothingPlayingView.hidden = YES;
        
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
    
    _nothingPlayingView.hidden = NO;
    _headerView.hidden = YES;
    _timeElapsedLabel.hidden = YES;
    _skipAheadBtn.hidden = YES;
    _skipBackBtn.hidden = YES;
    _switcherBar.hidden = YES;
    _descriptionView.view.hidden = YES;
    _episodesView.view.hidden = YES;
    _commentsView.view.hidden = YES;
    
    [_onEnterFrame invalidate];
    _progressBar.progress = 0;
    _posbar.value = 0;
    self.view.backgroundColor = [TungCommonObjects bkgdGrayColor];
    
}

- (void) setUpViewForEpisode:(EpisodeEntity *)episodeEntity {
    
    if (_isNowPlayingView) {
        [NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(animateControlsToOpen) userInfo:nil repeats:NO];
    }
    else if (episodeEntity.isNowPlaying.boolValue) {
        _lastPlayingGuid = episodeEntity.guid;
    }
    
    //JPLog(@"set up view for episode");
    //JPLog(@"podcast: %@", [TungCommonObjects entityToDict:episodeEntity.podcast]);
    
    // COMMENTS
    [_tung checkReachabilityWithCallback:^(BOOL reachable) {
        if (reachable) {
            [self refreshComments:YES];
        } else {
            [_commentsView.tableView reloadData];
        }
    }];
    
    // episodes and description
    NSDictionary *feedDict = [TungPodcast retrieveAndCacheFeedForPodcastEntity:episodeEntity.podcast forceNewest:NO reachable:_tung.connectionAvailable.boolValue];
    
    // set up header view
    [_headerView setUpHeaderViewForEpisode:episodeEntity orPodcast:nil];
    [_headerView.subscribeButton addTarget:self action:@selector(subscribeToPodcastViaSender:) forControlEvents:UIControlEventTouchUpInside];
    
    if (_isNowPlayingView) {
        //[_headerView setUpLargeButtonForEpisode:nil orPodcast:episodeEntity.podcast];
        _headerView.largeButton.hidden = YES;
    }
    
    [_headerView.largeButton addTarget:self action:@selector(largeButtonInHeaderTapped) forControlEvents:UIControlEventTouchUpInside];
    [_headerView.podcastButton addTarget:self action:@selector(pushPodcastDescription) forControlEvents:UIControlEventTouchUpInside];
    
    [self refreshRecommendAndSubscribeStatus];
    
    // switcher
    _switcherBar.hidden = NO;
    [self switchToViewAtIndex:_switcherIndex];
    _switcher.tintColor = (UIColor *)episodeEntity.podcast.keyColor2;
    
    _episodesView.tableView.backgroundView = nil;
    NSError *feedError;
    _episodesView.episodeArray = [[TungPodcast extractFeedArrayFromFeedDict:feedDict error:&feedError] mutableCopy];
    if (feedError) {
        [_episodesView.refreshControl endRefreshing];
        [TungCommonObjects simpleErrorAlertWithMessage:feedError.localizedDescription];
    }
    else {
        [_episodesView assignSavedPropertiesToEpisodeArray];
        _episodesView.podcastEntity = episodeEntity.podcast;
        [_episodesView.tableView reloadData];
    }
    
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

    
    // scroll to episode row if it's playing
    if (_isNowPlayingView) {
        NSIndexPath *activeRow = [NSIndexPath indexPathForItem:_tung.currentFeedIndex inSection:0];
        [_episodesView.tableView scrollToRowAtIndexPath:activeRow atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
    
    // now playing controls
    _timeElapsedLabel.text = [TungCommonObjects convertSecondsToTimeString:_episodeEntity.trackProgress.doubleValue];
    _posbar.value = _episodeEntity.trackPosition.floatValue;

}

- (void) refreshViewForArtChange:(NSNotification*)notification {
    NSLog(@"refresh view for art change");
    NSNumber *collectionId = [[notification userInfo] objectForKey:@"collectionId"];
    
    if (_episodeEntity && _episodeEntity.podcast.collectionId.doubleValue == collectionId.doubleValue) {
        
        [_headerView refreshHeaderViewForEntity:_episodeEntity.podcast];
        
        [_episodesView.tableView reloadData];
    }
}

- (void) playThisEpisode {
    
    [_tung queueAndPlaySelectedEpisode:_episodeEntity.url fromTimestamp:nil];
    [_headerView setUpLargeButtonForEpisode:_episodeEntity orPodcast:nil];
    [_episodesView.tableView reloadData];
}

- (void) largeButtonInHeaderTapped {
    
    /* magic button code
    if (_episodeEntity.isNowPlaying.boolValue) {
        // Magic button - customized?
        if (_episodeEntity.podcast.buttonLink && _episodeEntity.podcast.buttonLink.length) {
            if (_tung.connectionAvailable.boolValue) {
                _urlStringToPass = _episodeEntity.podcast.buttonLink;
                [self performSegueWithIdentifier:@"presentWebView" sender:self];
            } else {
                [TungCommonObjects showNoConnectionAlert];
            }
        }
        else {

            UIAlertController *magicButtonAlert = [UIAlertController alertControllerWithTitle:@"Yes, this button is magic!" message:@"If this is your podcast, you can customize this button - where it links, its emoji, and the text below it.\n 😎" preferredStyle:UIAlertControllerStyleAlert];
            [magicButtonAlert addAction:[UIAlertAction actionWithTitle:@"Meh" style:UIAlertActionStyleDefault handler:nil]];
            [magicButtonAlert addAction:[UIAlertAction actionWithTitle:@"Make it vanish" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                // show poof alert?
                SettingsEntity *settings = [TungCommonObjects settings];
                if (settings.hasSeenPoofAlert.boolValue) {
                    _episodeEntity.podcast.hideMagicButton = [NSNumber numberWithBool:YES];
                    [TungCommonObjects saveContextWithReason:@"user hid magic button"];
                    [_headerView setUpLargeButtonForEpisode:nil orPodcast:_episodeEntity.podcast];
                    
                } else {
                    UIAlertController *poofAlert = [UIAlertController alertControllerWithTitle:@"Poof! 💭" message:@"The magic button will vanish for this podcast until the podcaster customizes it." preferredStyle:UIAlertControllerStyleAlert];
                    [poofAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        _episodeEntity.podcast.hideMagicButton = [NSNumber numberWithBool:YES];
                        settings.hasSeenPoofAlert = [NSNumber numberWithBool:YES];
                        [TungCommonObjects saveContextWithReason:@"user hid magic button"];
                        [_headerView setUpLargeButtonForEpisode:nil orPodcast:_episodeEntity.podcast];
                    }]];
                    [self presentViewController:poofAlert animated:YES completion:nil];
                }
            }]];
            [magicButtonAlert addAction:[UIAlertAction actionWithTitle:@"Customize!" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                if (_tung.connectionAvailable.boolValue) {
                        // url unique to this podcast
                    _urlStringToPass = [NSString stringWithFormat:@"%@magic-button?id=%@", [TungCommonObjects tungSiteRootUrl], _episodeEntity.collectionId];
                    [self performSegueWithIdentifier:@"presentWebView" sender:self];
                    
                } else {
                    [TungCommonObjects showNoConnectionAlert];
                }

            }]];
            [self presentViewController:magicButtonAlert animated:YES completion:nil];
        }
        
    } */
    
    if (!_isNowPlayingView) {
        // play button
        if (_episodeEntity.url.length > 0) {
            if (_headerView.largeButton.on) {
                // select Now Playing tab
                MainTabBarController *tabVC = (MainTabBarController *)self.parentViewController.parentViewController;
                tabVC.selectedIndex = 1;
                UIButton *btn = [[UIButton alloc] init];
                btn.tag = 1;
                [tabVC selectTab:btn];
            } else {
                [self playThisEpisode];
            }

        } else {
            
            UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Can't Play - No URL" message:@"Unfortunately, this feed is missing links to its content." preferredStyle:UIAlertControllerStyleAlert];
            [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:errorAlert animated:YES completion:nil];
            
        }
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

#pragma mark Description web views

// uses this view as its webview delegate
- (void) loadDescriptionWebViewStringForEntity:(EpisodeEntity *)episodeEntity {
    // description style
    UIColor *keyColor1 = (UIColor *)episodeEntity.podcast.keyColor1;
    NSString *keyColor1HexString = [TungCommonObjects UIColorToHexString:keyColor1];
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
    NSString *webViewString = [NSString stringWithFormat:@"%@%@%@\n%@", style, script, episodeEntity.desc, tungEndOfFileImg];
    //NSLog(@"webViewString: %@", webViewString);
    [_descriptionView.webView loadHTMLString:webViewString baseURL:[NSURL URLWithString:@"desc"]];
}

// pushes a new view which uses its own webview delegate
- (void) pushPodcastDescription {
    
    [_tungPodcast pushPodcastDescriptionForEntity:_episodeEntity.podcast];
}

#pragma mark Subscribing

// toggle subscribe status
- (void) subscribeToPodcastViaSender:(id)sender {
    
    // only allow subscribing with network connection
    if (_tung.connectionAvailable.boolValue) {
        
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
        [TungCommonObjects showNoConnectionAlert];
    }
}

#pragma mark - Now Playing control view

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

- (void) setupControls {
    
    //JPLog(@"set up now playing control view");
    if (!circleButtonDimension) circleButtonDimension = 45;
    
    // buttons scroll view
    CGRect scrollViewRect = _buttonsScrollView.frame;
    scrollViewRect.size.width = _screenSize.width;
    _buttonsScrollView.contentSize = CGSizeMake(scrollViewRect.size.width * 3, scrollViewRect.size.height);
    _buttonsScrollView.delegate = self;
    _buttonsScrollView.scrollEnabled = NO;
    
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
    
    _saveButton = [CircleButton new];
    _saveButton.type = kCircleTypeSave;
    _saveButton.on = _episodeEntity.isSaved.boolValue;
    [self setupCircleButton:_saveButton withWidth:circleButtonDimension andHeight:circleButtonDimension andSuperView:extraButtonsSubView];
    [_saveButton addTarget:self action:@selector(saveButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    _saveLabel = [UILabel new];
    _saveLabel.text = (_saveButton.on) ? @"Saved" : @"Save";
    [self setupButtonLabel:_saveLabel withButtonDimension:circleButtonDimension andSuperView:extraButtonsSubView];
    
    // button and label constraints: distribute X positions
    [extraButtonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:websiteButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:extraButtonsSubView attribute:NSLayoutAttributeTrailing multiplier:.134 constant:1]];
    [extraButtonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:websiteLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:extraButtonsSubView attribute:NSLayoutAttributeTrailing multiplier:.134 constant:1]];

    [extraButtonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:_speedButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:extraButtonsSubView attribute:NSLayoutAttributeTrailing multiplier:.381 constant:1]];
    [extraButtonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:speedLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:extraButtonsSubView attribute:NSLayoutAttributeTrailing multiplier:.381 constant:1]];
    
    [extraButtonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:_saveButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:extraButtonsSubView attribute:NSLayoutAttributeTrailing multiplier:.622 constant:1]];
    [extraButtonsSubView addConstraint:[NSLayoutConstraint constraintWithItem:_saveLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:extraButtonsSubView attribute:NSLayoutAttributeTrailing multiplier:.622 constant:1]];

    // record subview
    _recordingDurationLabel = [UILabel new];
    _recordingDurationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    NSArray *durationDisplaySettings = @[ // vertically center colon
                                         @{ UIFontFeatureTypeIdentifierKey: @(35),
                                            UIFontFeatureSelectorIdentifierKey: @(6)
                                            },
                                         // open fours
                                         @{ UIFontFeatureTypeIdentifierKey: @(35),
                                            UIFontFeatureSelectorIdentifierKey: @(4)
                                            }];
    UIFont *font = [UIFont systemFontOfSize:41 weight:UIFontWeightThin];
    /* display font features
    NSArray *features = CFBridgingRelease(CTFontCopyFeatures((__bridge CTFontRef)font));
    if (features) {
        NSLog(@"%@: %@", font.fontName, features);
    }
    */
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
    [recordSubView addConstraint:[NSLayoutConstraint constraintWithItem:_recordingDurationLabel attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:recordSubView attribute:NSLayoutAttributeLeading multiplier:1 constant:15]];
    [recordSubView addConstraint:[NSLayoutConstraint constraintWithItem:_recordButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:recordSubView attribute:NSLayoutAttributeTrailing multiplier:.3438 constant:1]];
    [recordSubView addConstraint:[NSLayoutConstraint constraintWithItem:_playClipButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:recordSubView attribute:NSLayoutAttributeTrailing multiplier:.5656 constant:1]];
    [recordSubView addConstraint:[NSLayoutConstraint constraintWithItem:_clipOkayButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:recordSubView attribute:NSLayoutAttributeTrailing multiplier:.725 constant:1]];
    [recordSubView addConstraint:[NSLayoutConstraint constraintWithItem:cancelClipButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:recordSubView attribute:NSLayoutAttributeTrailing multiplier:.8844 constant:1]];
    
    
    [self resetRecording];
    
    // comment and post view
    _commentAndPostView = [[CommentAndPostView alloc] initWithFrame:CGRectMake(0, 0, _screenSize.width, _commentAndPostViewHeight)];
    [_controlsView insertSubview:_commentAndPostView belowSubview:_progressBar];
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
    _commentViewTopLayoutConstraint = [NSLayoutConstraint constraintWithItem:_commentAndPostView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_controlsView attribute:NSLayoutAttributeTop multiplier:1 constant:80];
    [_controlsView addConstraint:_commentViewTopLayoutConstraint];
    [_controlsView addConstraint:[NSLayoutConstraint constraintWithItem:_commentAndPostView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_controlsView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [_controlsView addConstraint:[NSLayoutConstraint constraintWithItem:_commentAndPostView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_controlsView attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    [_commentAndPostView addConstraint:[NSLayoutConstraint constraintWithItem:_commentAndPostView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:_commentAndPostViewHeight]];
    
    [self refreshRecommendAndSubscribeStatus];
    
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
    
    //JPLog(@"set playback rate to %@", rate);
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

- (void) saveButtonTapped {
    
    if (_episodeEntity.isSaved.boolValue) {
        [_tung showSavedInfoAlertForEpisode:_episodeEntity];
    }
    else {
        if (!_tung.fileWillBeCached) {
            // streaming; will not be cached
            [_tung cacheNowPlayingEpisodeAndMoveToSaved:YES];
            _saveButton.on = NO;
            _saveLabel.text = @"Downloading…";
        }
        else {
            if (_tung.fileIsLocal) {
                // already cached
                [_tung moveToSavedOrQueueDownloadForEpisode:_episodeEntity];
                _saveButton.on = YES;
                _saveLabel.text = @"Saved";
            }
            else {
                // currently downloading
                _tung.saveOnDownloadComplete = !_tung.saveOnDownloadComplete;
                _saveButton.on = !_saveButton.on;
                if (_tung.saveOnDownloadComplete) {
                	_saveLabel.text = @"Downloading…";
                }
                else {
                    // episode will continue to download, but it will only be cached.
                    // cancelling this download could jeopardize the data of the track
                    // if the file was streaming with a custom protocol.
                    _saveLabel.text = @"Save";
                    
                }
            }
        }
        [_saveButton setNeedsDisplay];
    }
}

- (void) tungButtonTapped {
    UIAlertController *thanksAlert = [UIAlertController alertControllerWithTitle:@"Thanks for using Tung!" message:@"Hope you're enjoying it 😎" preferredStyle:UIAlertControllerStyleAlert];
    [thanksAlert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil]];
    [thanksAlert addAction:[UIAlertAction actionWithTitle:@"Play random episode" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [_tung playRandomEpisode];
    }]];
    [thanksAlert addAction:[UIAlertAction actionWithTitle:@"Rate Tung" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // @"https://itunes.apple.com/us/app/tung.fm/id932939338"
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms-apps://itunes.apple.com/app/id932939338"]];
    }]];
    if ([TungCommonObjects iOSVersionFloat] >= 9.0) {
    	thanksAlert.preferredAction = [thanksAlert.actions objectAtIndex:2];
    }
    [self presentViewController:thanksAlert animated:YES completion:nil];
}

#pragma mark - UIWebView delegate methods

-(BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    if ([request.URL.scheme isEqualToString:@"file"]) {
    	return YES;
        
    } else {
        
        // open web browsing modal
        _urlStringToPass = request.URL.absoluteString;
        if (_tung.connectionAvailable.boolValue) {
        	[self performSegueWithIdentifier:@"presentWebView" sender:self];
        } else {
            [TungCommonObjects showNoConnectionAlert];
        }
        
        return NO;
    }
}

- (void) openPodcastWebsite {
    // open web browsing modal
    if (_episodeEntity.podcast.website.length) {
        if (_tung.connectionAvailable.boolValue) {
            _urlStringToPass = _episodeEntity.podcast.website;
            [self performSegueWithIdentifier:@"presentWebView" sender:self];
        } else {
            [TungCommonObjects showNoConnectionAlert];
        }
    } else {
        
        UIAlertController *noWebsiteAlert = [UIAlertController alertControllerWithTitle:@"Bummer" message:@"This podcast doesn't have a website url in its feed." preferredStyle:UIAlertControllerStyleAlert];
        [noWebsiteAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:noWebsiteAlert animated:YES completion:nil];
    }
}

#pragma mark - clip recording and playback methods

- (BOOL) trimAudioFrom:(CGFloat)startMarker to:(CGFloat)endMarker {

    //JPLog(@"//// trim audio from %f to %f", startMarker, endMarker);
    // input    
    NSURL *audioFileUrl = [_tung getStreamUrlForEpisodeEntity:_tung.npEpisodeEntity];
    // test if input file has any bytes
    //NSData *audioURLData = [NSData dataWithContentsOfURL:audioFileUrl];
    //JPLog(@"//// audio file data length: %lu", (unsigned long)audioURLData.length);
    // output
    NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"recording.m4a"];
    NSURL *outputFileUrl = [TungCommonObjects getClipFileURL];

    if (!audioFileUrl || !outputFileUrl) {
        JPLog(@"Error trimming audio: no input or output file url");
    	return NO;
    }
    // delete recording file if exists.
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:outputFilePath error:nil];
    }
    
    AVAsset *asset = [AVAsset assetWithURL:audioFileUrl];

    AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
    if (exportSession == nil) {
        JPLog(@"Error trimming audio no export session");
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
            //NSLog(@"//// audio export successful");
            dispatch_async(dispatch_get_main_queue(), ^{
            	[_playClipButton setEnabled:YES];
                [_clipOkayButton setEnabled:YES];
            });
        }
        else if (AVAssetExportSessionStatusFailed == exportSession.status) {
            // It failed...
            JPLog(@"Error trimming audio: audio export failed with status: %ld", (long)exportSession.status);
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
            
            //JPLog(@"start recording *****");
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
            float recordTime = fabs([_recordStartTime timeIntervalSinceNow]);
            if (recordTime >= MIN_RECORD_TIME) {
                //JPLog(@"STOP recording *****");
                _recordEndMarker = CMTimeGetSeconds(_tung.player.currentTime);
                _isRecording = NO;
                _recordButton.isRecording = NO;
                [_recordButton setEnabled:NO];
                [_tung playerPause];
                _recordingDuration = [NSString stringWithFormat:@"%02.0f", recordTime];
                
                [_buttonsScrollView setScrollEnabled:YES];
                [self trimAudioFrom:_recordStartMarker to:_recordEndMarker];
            } else {
                // too short
                UIAlertController *tooShortAlert = [UIAlertController alertControllerWithTitle:@"Too short" message:[NSString stringWithFormat:@"Clips must be at least %d seconds long", MIN_RECORD_TIME] preferredStyle:UIAlertControllerStyleAlert];
                [tooShortAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:tooShortAlert animated:YES completion:nil];
            }
        }
        [_recordButton setNeedsDisplay];
    } else {
        
        UIAlertController *waitAlert = [UIAlertController alertControllerWithTitle:@"Hang on..." message:@"You can record as soon as this episode finishes downloading." preferredStyle:UIAlertControllerStyleAlert];
        [waitAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:waitAlert animated:YES completion:nil];
        
        if ([_tung isPlaying]) {
            if (!_tung.fileWillBeCached) {
                [_tung cacheNowPlayingEpisodeAndMoveToSaved:NO];
            }
        }
        else {
            [_tung playerPlay];
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
    //JPLog(@"reset recording");
    
    if ([_audioPlayer isPlaying]) [_audioPlayer stop];
    _audioPlayer = nil;
    
    _clipHasPosted = NO;
    
    // can record
    [_recordButton setEnabled:YES];
    _recordingDurationLabel.text = @":00";
    _recordingDuration = nil;
    [_playClipButton setEnabled:NO];
    _playClipButton.isPlaying = NO;
    [_clipOkayButton setEnabled:NO];
    
}

- (void) playbackRecording {

    // if we're streaming, best stop it.
    if ([_tung isPlaying]) [_tung controlButtonTapped];
    
    // create audio player
    NSURL *clipFileUrl = [TungCommonObjects getClipFileURL];
    //NSData *clipData = [NSData dataWithContentsOfURL:clipFileUrl];
    //JPLog(@"play clip file with data length: %lu", (unsigned long)clipData.length);
    
    NSError *playbackError;
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:clipFileUrl error:&playbackError];
    
    if (_audioPlayer != nil) {
        _audioPlayer.delegate = self;
        // PLAY
        if ([_audioPlayer prepareToPlay] && [_audioPlayer play]) {
            //JPLog(@"audio play started playing. duration: %f", _audioPlayer.duration);
            
        } else {
            JPLog(@"Error: could not play recording");
            [self stopPlayback];
        }
    } else {
        JPLog(@"Error: failed to create audio player: %@", playbackError);
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
    
    if (flag && !_keyboardActive) {
        //JPLog(@"audio player stopped successfully");
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
        //JPLog(@"audio player end interruption");
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
            UIAlertController *maxAlert = [UIAlertController alertControllerWithTitle:@"Max time reached" message:nil preferredStyle:UIAlertControllerStyleAlert];
            [maxAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:maxAlert animated:YES completion:nil];
        }
    }
    if (_audioPlayer && _audioPlayer.isPlaying) {
        
        _recordingDurationLabel.text = [NSString stringWithFormat:@":%02ld", lroundf(_audioPlayer.currentTime)];
    }
    // progress bar
    if (!_tung.fileIsLocal) {
        float buffered = _tung.trackData.length;
        //JPLog(@"update view - buffered: %f, entity data length: %@", buffered, _tung.npEpisodeEntity.dataLength);
        float progress = 0;
        if (buffered > 0 && _tung.npEpisodeEntity.dataLength.doubleValue > 0) {
            progress = buffered / _tung.npEpisodeEntity.dataLength.doubleValue;
        }
        //JPLog(@"buffered: %f, total: %f, progress: %f", buffered, _tung.npEpisodeEntity.dataLength.floatValue, progress);
        _progressBar.progress = progress;
    } else {
        _progressBar.progress = 1;
    }
    
}

- (void) newClip {
    if (_episodeEntity.isNowPlaying.boolValue) {
    	[self toggleNewClipView];
    }
    else {
        NSString *alertTitle = nil;
        if (_tung.npEpisodeEntity) {
            alertTitle = @"A different episode is playing";
        }
        UIAlertController *notPlayingAlert = [UIAlertController alertControllerWithTitle:alertTitle message:@"Would you like to start playing this episode so you can record a clip?" preferredStyle:UIAlertControllerStyleAlert];
        [notPlayingAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [notPlayingAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            // play episode
            [self playThisEpisode];
            [self toggleNewClipView];
        }]];
        [self presentViewController:notPlayingAlert animated:YES completion:nil];
    }
}

- (void) cancelNewClip {
    
    if (_clipConfirmActive) {
        [self toggleNewClipView];
    }
    else {
        if (_playClipButton.enabled) {
            
            UIAlertController *cancelClipAlert = [UIAlertController alertControllerWithTitle:@"Start over?" message:@"Your recording will be lost." preferredStyle:UIAlertControllerStyleAlert];
            [cancelClipAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [cancelClipAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self resetRecording];
            }]];
            [self presentViewController:cancelClipAlert animated:YES completion:nil];
        } else {
            [self toggleNewClipView];
        }
    }
}

- (void) newComment {
    _shareIntention = kNewCommentIntention;
    _shareLabel.text = [NSString stringWithFormat:@"New comment @ %@", _timeElapsedLabel.text];
    //_commentAndPostView.commentTextView.text = @"";
    if (!_commentAndPostView.commentTextView.text.length) {
    	[_commentAndPostView.postButton setEnabled:NO];
    }
    [self toggleNewComment];
}

// show comment and post view with keyboard for sharing or new comment
- (void) toggleNewComment {
    
    // NOTE: it will appear nothing is happening unless you enable software keyboard (cmd+K)
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
    //JPLog(@"toggle new clip view. clipConfirmActive: %@", (_clipConfirmActive) ? @"YES" : @"NO");
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
    //JPLog(@"seek to position %f - %d seconds", slider.value, secs);
    
    CMTime time = CMTimeMake((secs * 100), 100);

    // disable posbar and show spinner while player seeks
    if (_tung.fileIsStreaming) {
        [_posbar setEnabled:NO];
    }
    
    [_tung.player seekToTime:time completionHandler:^(BOOL finished) {
        //JPLog(@"finished seeking to time (%@)", (finished) ? @"yes" : @"no");
        [_tung.trackInfo setObject:[NSNumber numberWithFloat:CMTimeGetSeconds(time)] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:_tung.trackInfo];
        [_posbar setEnabled:YES];
    }];
    
}

#pragma mark - Animating Controls

- (void) toggleConfirmClip {
    
    if (!controls_clipConfirmConstraint) controls_clipConfirmConstraint = controls_openConstraint + 70;
    
    if (_clipConfirmActive) {
        _shareIntention = nil;
        _shareTimestamp = nil;
        if (_controlsState != kControlsStateNotPlayingOpen) {
            _posbar.hidden = NO;
            _hideControlsButton.hidden = NO;
        }
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
                             _controlsBottomLayoutConstraint.constant = controls_clipConfirmConstraint;
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
                             if (_controlsState != kControlsStateNotPlayingOpen) {
                                 _controlsBottomLayoutConstraint.constant = controls_openConstraint;
                                 _posbar.alpha = 1;
                                 _progressBar.alpha = 1;
                                 _timeElapsedLabel.alpha = 1;
                                 _skipAheadBtn.alpha = 1;
                                 _skipBackBtn.alpha = 1;
                                 _totalTimeLabel.alpha = 1;
                                 _pageControl.alpha = 1;
                                 _hideControlsButton.alpha = 1;
                             }
                             else {
                                 _controlsBottomLayoutConstraint.constant = controls_notPlayingConstraint;
                             }
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

- (void) updateSubViewConstraintsForControlsState:(ControlsState)state {
    switch (state) {
        case kControlsStateNotPlayingOpen:
            _descriptionViewBottomConstraint.constant = episodeSubviews_bottomConstraintNotPlaying;
            _commentsViewBottomConstraint.constant = episodeSubviews_bottomConstraintNotPlaying;
            _episodesViewBottomConstraint.constant = episodeSubviews_bottomConstraintNotPlaying;
            break;
        default:
            _descriptionViewBottomConstraint.constant = episodeSubviews_bottomConstraintPlaying;
            _commentsViewBottomConstraint.constant = episodeSubviews_bottomConstraintPlaying;
            _episodesViewBottomConstraint.constant = episodeSubviews_bottomConstraintPlaying;
            break;
    }
}

- (IBAction)toggleControlsView:(id)sender {
    
    _touchedInsideShowHideButton = NO;
    controls_easing = UIViewAnimationOptionCurveEaseInOut;
    controls_dragStartPos = NAN;
    
    float openConstraint = (_controlsState == kControlsStateNotPlayingOpen || _controlsState == kControlsStateNotPlayingClosed) ? controls_notPlayingConstraint : controls_openConstraint;
    
    BOOL willHide = NO;
    if (_controlsBottomLayoutConstraint.constant <= openConstraint) {
        willHide = YES;
    }
    
    if (_episodeEntity.isNowPlaying.boolValue) {
        if (_controlsState != kControlsStateOpen) {
            [self animateControlsToOpen];
        }
        else {
            if (willHide) {
                [self animateControlsToClosed];
            }
            else {
                [self animateControlsToOpen];
            }
        }
    }
    else {
        if (_controlsState != kControlsStateNotPlayingOpen) {
            [self animateControlsToNotPlayingOpen];
        }
        else {
            if (willHide) {
                [self animateControlsToNotPlayingClosed];
            }
            else {
                [self animateControlsToNotPlayingOpen];
            }
        }
    }
    
}

- (void) animateControlsToOpen {
    
    _timeElapsedLabel.hidden = NO;
    _totalTimeLabel.hidden = NO;
    _skipAheadBtn.hidden = NO;
    _skipBackBtn.hidden = NO;
    _posbar.hidden = NO;
    _progressBar.hidden = NO;
    _hideControlsButton.hidden = NO;
    _buttonsScrollView.scrollEnabled = YES;
    _buttonsScrollView.hidden = NO;
    _pageControl.hidden = NO;
    
    [UIView animateWithDuration:.3
                          delay:0
         usingSpringWithDamping:.5
          initialSpringVelocity:.5
                        options:0//controls_easing
                     animations:^{
                         _controlsBottomLayoutConstraint.constant = controls_openConstraint;
                         [self updateSubViewConstraintsForControlsState:kControlsStateOpen];
                         _timeElapsedLabel.alpha = 1;
                         _skipAheadBtn.alpha = 1;
                         _skipBackBtn.alpha = 1;
                         _posbar.alpha = 1;
                         _progressBar.alpha = 1;
                         _hideControlsButton.alpha = 1;
                         _showControlsButton.alpha = 0;
                         _buttonsScrollView.alpha = 1;
                         [self.view layoutIfNeeded];
                     }
                     completion:^(BOOL completed) {
                         _controlsState = kControlsStateOpen;
                         _showControlsButton.hidden = YES;
                         
                         if (_isNowPlayingView) {
                             // prompt for notifications
                             SettingsEntity *settings = [TungCommonObjects settings];
                             if (!settings.hasSeenMentionsPrompt.boolValue && ![[UIApplication sharedApplication] isRegisteredForRemoteNotifications]) {
                                 [_tung promptForNotificationsForMentions];
                             }
                         }
                     }];
    
}
- (void) animateControlsToClosed {
    
    _showControlsButton.hidden = NO;
    
    //[self.view layoutIfNeeded];
    [UIView animateWithDuration:.2
                          delay:0
                        options:controls_easing
                     animations:^{
                         _controlsBottomLayoutConstraint.constant = controls_closedConstraint;
                         [self updateSubViewConstraintsForControlsState:kControlsStateClosed];
                         _buttonsScrollView.alpha = 0;
                         _posbar.alpha = 0;
                         _progressBar.alpha = 0;
                         _hideControlsButton.alpha = 0;
                         _showControlsButton.alpha = 1;
                         [self.view layoutIfNeeded];
                     }
                     completion:^(BOOL completed) {
                         _buttonsScrollView.hidden = YES;
                         _hideControlsButton.hidden = YES;
                         _controlsState = kControlsStateClosed;
                     }];

}

- (void) animateControlsToNotPlayingOpen {
    
    // scroll to main buttons and disable scrolling
    [_buttonsScrollView scrollRectToVisible:buttonsScrollViewHomeRect animated:YES];
    _buttonsScrollView.scrollEnabled = NO;
    _buttonsScrollView.hidden = NO;
    _hideControlsButton.hidden = NO;
    _pageControl.hidden = YES;
    _totalTimeLabel.hidden = YES;
    
    [UIView animateWithDuration:.3
                          delay:0
    	 usingSpringWithDamping:.5
          initialSpringVelocity:.5
                        options:0//controls_easing
                     animations:^{
                         _controlsBottomLayoutConstraint.constant = controls_notPlayingConstraint;
                         [self updateSubViewConstraintsForControlsState:kControlsStateNotPlayingOpen];
                         _buttonsScrollView.alpha = 1;
                         _hideControlsButton.alpha = 1;
                         _showControlsButton.alpha = 0;
                         _posbar.alpha = 0;
                         _progressBar.alpha = 0;
                         _timeElapsedLabel.alpha = 0;
                         _skipAheadBtn.alpha = 0;
                         _skipBackBtn.alpha = 0;
                         [self.view layoutIfNeeded];
                     }
                     completion:^(BOOL completed) {
                         _showControlsButton.hidden = YES;
                         _timeElapsedLabel.hidden = YES;
                         _skipAheadBtn.hidden = YES;
                         _skipBackBtn.hidden = YES;
                         _posbar.hidden = YES;
                         _progressBar.hidden = YES;
                         _controlsState = kControlsStateNotPlayingOpen;
                     }];
    
}

- (void) animateControlsToNotPlayingClosed {
    
    _showControlsButton.hidden = NO;
    
    [UIView animateWithDuration:.15
                          delay:0
                        options:controls_easing
                     animations:^{
                         _controlsBottomLayoutConstraint.constant = controls_closedConstraint;
                         [self updateSubViewConstraintsForControlsState:kControlsStateNotPlayingClosed];
                         _buttonsScrollView.alpha = 0;
                         _hideControlsButton.alpha = 0;
                         _showControlsButton.alpha = 1;
                         [self.view layoutIfNeeded];
                     }
                     completion:^(BOOL completed) {
                         _hideControlsButton.hidden = YES;
                         _buttonsScrollView.hidden = YES;
                         _controlsState = kControlsStateNotPlayingClosed;
                     }];
    
}

#pragma mark - Dragging controls


- (IBAction)touchDownInShowHideControlsButton:(id)sender {
    
    _touchedInsideShowHideButton = YES;
    controls_easing = UIViewAnimationOptionCurveEaseOut;
    // un hide elements for alpha animation
    _showControlsButton.hidden = NO;
    _hideControlsButton.hidden = NO;
    _buttonsScrollView.hidden = NO;
    
    // set drag start position
    if ([sender tag] == 1) { // show controls
        controls_constraintStartPos = controls_closedConstraint;
    }
    else { // hide controls
        if (_clipConfirmActive) {
            controls_constraintStartPos = controls_clipConfirmConstraint;
        }
        else {
            
            switch (_controlsState) {
                case kControlsStateOpen:
                    controls_constraintStartPos = controls_openConstraint;
                    break;
                case kControlsStateClosed:
                case kControlsStateNotPlayingClosed:
                    controls_constraintStartPos = controls_closedConstraint;
                    break;
                case kControlsStateNotPlayingOpen:
                    controls_constraintStartPos = controls_notPlayingConstraint;
                    break;
            }
        }
    }
}
/*
@t is the current time (or position) of the tween. This can be seconds or frames, steps, seconds, ms, whatever – as long as the unit is the same as is used for the total time [3].
@b is the beginning value of the property.
@c is the change between the beginning and destination value of the property.
@d is the total time of the tween.
easeOutExpo = function(t, b, c, d) {
    return c * (-Math.pow(2, -10 * t / d) + 1) * 1024 / 1023 + b;
};
 return (t==d) ? b+c : c * (-Math.pow(2, -10 * t/d) + 1) + b;
 */

- (CGFloat) easeOutExpoWithFrame:(CGFloat)frame start:(CGFloat)start change:(CGFloat)change total:(CGFloat)total {
    
    NSLog(@"easeOutExpo(%f, %f, %f, %f)", frame, start, change, total);
    float r = frame/total;
    float pow_val = powf(2.0, -10.0 * r);
    float result = change * (-pow_val + 1) + start;
    if (frame >= total) {
        return start + change;
    }
    else {
        return result;
    }
    
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    // drag now playing controls
    if (_touchedInsideShowHideButton) {
        
        UITouch *touch = [[event allTouches] anyObject];
        CGPoint touchLocation = [touch locationInView:self.view];
        if (isnan(controls_dragStartPos)) {
            controls_dragStartPos = touchLocation.y;
        }
        
        float diff = touchLocation.y - controls_dragStartPos;
        float newConstraint = controls_constraintStartPos - diff;
        float openConstraint = (_controlsState == kControlsStateNotPlayingOpen || _controlsState == kControlsStateNotPlayingClosed) ? controls_notPlayingConstraint : controls_openConstraint;
        
        // reduce drag distance when going past all the way open
        if (newConstraint > openConstraint) {
            float cDiff = newConstraint - openConstraint;
            if (cDiff > 100) cDiff = 100;
            float delta = cDiff/2;
            newConstraint = openConstraint + delta;
        }
        // stop drag at bottom
        else if (newConstraint < controls_closedConstraint) {
            newConstraint = controls_closedConstraint;
        }
        //NSLog(@"new constraint: %f", newConstraint);
        
        //JPLog(@"drag controls with diff: %f to new constraint: %f", diff, newConstraint);
        _controlsBottomLayoutConstraint.constant = newConstraint;
        
        // animate alpha of controls
        float total = openConstraint - controls_closedConstraint;
        float prog = fabsf(newConstraint) - fabsf(openConstraint);
        float decimal = 1 - (prog / total);
        //JPLog(@"prog %f / total %f = decimal %f", prog, total, prog/total);
        //JPLog(@"decimal: %f", decimal);
        float alpha = (decimal > 1) ? 1 : decimal;
        _buttonsScrollView.alpha = alpha;
        _hideControlsButton.alpha = alpha;
        _showControlsButton.alpha = 1 - alpha;
        _posbar.alpha = alpha;
        _progressBar.alpha = alpha;
        if (_controlsState == kControlsStateNotPlayingOpen || _controlsState == kControlsStateNotPlayingClosed) {
            _progressBar.alpha = alpha;
            _posbar.alpha = alpha;
        }
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
    //JPLog(@"char count: %lu", (unsigned long)textView.text.length);
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
        //JPLog(@"*** reached comment character limit ***");
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
        //JPLog(@"keyboard will appear. %@", keyboardInfo);
        //JPLog(@"keyboard will appear. rect begin: %@, rect end: %@", NSStringFromCGRect(keyboardRectBegin),NSStringFromCGRect(keyboardRectEnd));
        
        // keyboard changes height (switch to emoji, open auto complete)
        if (_keyboardActive) {
            
            CGFloat diff = keyboardRectEnd.size.height - keyboardRectBegin.size.height;
            
            _controlsBottomLayoutConstraint.constant += diff;
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
                _controlsBottomLayoutConstraint.constant = controls_clipConfirmConstraint + keyboardRectBegin.size.height - 44;
            }
            // for new comment
            else if ([_shareIntention isEqualToString:kNewCommentIntention]) {
                _controlsBottomLayoutConstraint.constant = controls_openConstraint + keyboardRectBegin.size.height - 44;
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
//    NSLog(@"keyboard will change frame");
//}

- (void) keyboardWillBeHidden:(NSNotification*)notification {
    //NSLog(@"keyboard will be hidden");
    if (_shareIntention && !_searchActive && (_controlsState == kControlsStateOpen || _controlsState == kControlsStateNotPlayingOpen)) {
        
        if (_controlsState == kControlsStateNotPlayingOpen) {
            _posbar.hidden = NO;
        }
        _hideControlsButton.hidden = NO;
        _buttonsScrollView.hidden = NO;
        //JPLog(@"keyboard will be hidden");
        
        [UIView beginAnimations:@"keyboard down" context:NULL];
        [UIView setAnimationDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
        [UIView setAnimationCurve:[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue]];
        [UIView setAnimationBeginsFromCurrentState:YES];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(keyboardAnimationStopped:finished:context:)];
        // hide clip comment view

        if (_controlsState == kControlsStateOpen) {
            _controlsBottomLayoutConstraint.constant = controls_openConstraint;
        	_posbar.alpha = 1;
        	_progressBar.alpha = 1;
            _timeElapsedLabel.alpha = 1;
            _totalTimeLabel.alpha = 1;
            _skipAheadBtn.alpha = 1;
            _skipBackBtn.alpha = 1;
            _pageControl.alpha = 1;
        }
        else {
            _controlsBottomLayoutConstraint.constant = controls_notPlayingConstraint;
        }
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
        if (_controlsState == kControlsStateNotPlayingOpen) {
        	_buttonsScrollView.scrollEnabled = YES;
        }
        
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

- (void) resignKeyboardIfActive {
    //NSLog(@"resign keyboard if active");
    [_commentAndPostView.commentTextView resignFirstResponder];
}

#pragma mark - Sharing

- (void) toggleTwitterSharing:(id)sender {
    
    CircleButton *btn = (CircleButton *)sender;
    
    btn.on = !btn.on;
    [btn setNeedsDisplay];
    
    _tung.sessionId = @""; // kill session for debug
    
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
            UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Facebook error" message:alertText preferredStyle:UIAlertControllerStyleAlert];
            [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:errorAlert animated:YES completion:nil];
        }
        else if (result.isCancelled) {
            NSString *alertTitle = @"You denied permission";
            NSString *alertText = @"Tung cannot currently post to Facebook because it was denied permission.";
            UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:alertTitle message:alertText preferredStyle:UIAlertControllerStyleAlert];
            [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:errorAlert animated:YES completion:nil];
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
        
        [_tung postComment:text atTime:_shareTimestamp onEpisode:_episodeEntity withCallback:^(BOOL success, NSDictionary *responseDict) {
            [_commentAndPostView.postActivityIndicator stopAnimating];
            [_commentAndPostView.postButton setEnabled:YES];
            [TungCommonObjects fadeInView:_commentAndPostView.cancelButton];
            if (success) {
                
                [self switchToViewAtIndex:1];
                [self refreshComments:YES];
                
                _commentAndPostView.commentTextView.text = @"";
                [self toggleNewComment];
                
                NSString *username = _tung.loggedInUser.username;
                NSString *link = [NSString stringWithFormat:@"%@e/%@/%@", [TungCommonObjects tungSiteRootUrl], _episodeEntity.shortlink, username];
                // tweet?
                if (_commentAndPostView.twitterButton.on) {
                    [_tung postTweetWithText:text andUrl:link];
                }
                // fb share?
                if (_commentAndPostView.facebookButton.on) {
                    [_tung postToFacebookWithText:text Link:link andEpisode:_episodeEntity];
                }
            }
            else {
                [self toggleNewComment];
                NSString *errorMsg = [responseDict objectForKey:@"error"];
                [TungCommonObjects simpleErrorAlertWithMessage:errorMsg];
            }
        }];
    }
    // post a clip
    else if ([_shareIntention isEqualToString:kNewClipIntention]) {
        
        [_commentAndPostView.postButton setEnabled:NO];
        [_commentAndPostView.postActivityIndicator startAnimating];
        //NSLog(@"post clip with duration: %@", _recordingDuration);
        [_tung postClipWithComment:text atTime:_shareTimestamp withDuration:_recordingDuration onEpisode:_episodeEntity withCallback:^(BOOL success, NSDictionary *responseDict) {
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
                NSString *link = [NSString stringWithFormat:@"%@c/%@", [TungCommonObjects tungSiteRootUrl], eventShortlink];
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
                    [_tung postToFacebookWithText:text Link:link andEpisode:_episodeEntity];
                }
            }
            else {
                NSString *errorMsg = [responseDict objectForKey:@"error"];
                [TungCommonObjects simpleErrorAlertWithMessage:errorMsg];
            }
            
            [self toggleNewClipView];
        }];
    }
}

- (void) recommendEpisode {
    
    if (_tung.connectionAvailable.boolValue) {
        _recommendButton.recommended = !_recommendButton.recommended;
        [_recommendButton setNeedsDisplay];
        _recommendLabel.text = (_recommendButton.recommended) ? @"Recommended" : @"Recommend";
        
        if (_recommendButton.recommended) {
            [_tung recommendEpisode:_episodeEntity withCallback:^(BOOL success) {
                if (!success) {
                    // failed to recommend
                    _recommendButton.recommended = NO;
                    [_recommendButton setNeedsDisplay];
                    _recommendLabel.text = @"Recommend";
                }
            }];
        }
        else {
            [_tung unRecommendEpisode:_episodeEntity withCallback:^(BOOL success) {
                if (!success) {
                    // failed to un-recommend
                    _recommendButton.recommended = YES;
                    [_recommendButton setNeedsDisplay];
                    _recommendLabel.text = @"Recommended";
                }
            }];
        }
    }
    else {
        [TungCommonObjects showNoConnectionAlert];
    }
}

- (void) getTextForShareSheet {
    
    // if there's a story to share, share it
    if (_episodeEntity.shortlink) {
        [self openShareSheetForEntity:_episodeEntity];
    }
    // need to get episode shortlink
    else {
        __unsafe_unretained typeof(self) weakSelf = self;
        [_tung addEpisode:_episodeEntity withCallback:^{
            [weakSelf openShareSheetForEntity:weakSelf.episodeEntity];
        }];
    }
}

- (void) openShareSheetForEntity:(EpisodeEntity *)episodeEntity {
    
    NSString *link = [NSString stringWithFormat:@"%@e/%@", [TungCommonObjects tungSiteRootUrl], episodeEntity.shortlink];
    //NSLog(@"shortlink: %@", episodeEntity.shortlink);
    
    NSURL *shareLink = [TungCommonObjects urlFromString:link];
    
    UIActivityViewController *shareSheet = [[UIActivityViewController alloc] initWithActivityItems:@[shareLink] applicationActivities:nil];
    [self presentViewController:shareSheet animated:YES completion:nil];
}

#pragma mark - scroll view delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {

    float fractionalPage = (uint) scrollView.contentOffset.x / _screenSize.width;
    NSInteger page = lround(fractionalPage);
    _pageControl.currentPage = page;
    
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UINavigationController *destination = segue.destinationViewController;
    
    if ([[segue identifier] isEqualToString:@"presentWebView"]) {
        BrowserViewController *browserViewController = (BrowserViewController *)destination;
        [browserViewController setValue:_urlStringToPass forKey:@"urlStringToNavigateTo"];
    }

}



@end
