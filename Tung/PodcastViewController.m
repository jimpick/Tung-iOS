//
//  PodcastViewController.m
//  Tung
//
//  Created by Jamie Perkins on 4/28/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "PodcastViewController.h"
#import "TungPodcast.h"
#import "AppDelegate.h"
#import "EpisodesTableViewController.h"
#import "BrowserViewController.h"


@class TungCommonObjects;

@interface PodcastViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) TungPodcast *podcast;
@property (strong, nonatomic) PodcastEntity *podcastEntity;
@property HeaderView *headerView;
@property EpisodesTableViewController *episodesView;
@property BOOL needToRequestFeed;

@end

@implementation PodcastViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    _tung.ctrlBtnDelegate = self;
    
    self.edgesForExtendedLayout = UIRectEdgeBottom;
    
    self.navigationItem.title = @"Podcast";
    self.navigationItem.rightBarButtonItem = nil;
    
    _podcast = [TungPodcast new];
    _podcast.navController = [self navigationController];
    //NSLog(@"podcast dict: %@", _podcastDict);
    
    // get podcast entity
    _podcastEntity = [TungCommonObjects getEntityForPodcast:_podcastDict save:NO];
    
    // header view
    _headerView = [[HeaderView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 160)];
    [_headerView setUpHeaderViewForEpisode:nil orPodcast:_podcastEntity];
    [self.view addSubview:_headerView];
    
    // add child table view controller
    _episodesView = [self.storyboard instantiateViewControllerWithIdentifier:@"episodesView"];
    _episodesView.edgesForExtendedLayout = UIRectEdgeNone;
    _episodesView.podcastEntity = _podcastEntity; // for pushing episode view & track progress
    
    [self addChildViewController:_episodesView];
    [self.view addSubview:_episodesView.view];
    _episodesView.navController = self.navigationController;

    _episodesView.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_headerView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_episodesView.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:-44]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_episodesView.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_episodesView.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
    NSDictionary *feedDict = [TungPodcast retrieveAndCacheFeedForPodcastEntity:_podcastEntity forceNewest:NO reachable:_tung.connectionAvailable.boolValue];
    [self setUpViewForDict:feedDict];
    
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.navigationController.navigationBar.translucent = NO;
    
    [_episodesView markNewEpisodesAsSeen];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.translucent = YES;
}

// ControlButtonDelegate optional method
-(void) nowPlayingDidChange {
    [_episodesView.tableView reloadData];
}

// for refreshControl
- (void) getNewestFeed {
    NSDictionary *feedDict = [TungPodcast retrieveAndCacheFeedForPodcastEntity:_podcastEntity forceNewest:YES reachable:_tung.connectionAvailable.boolValue];
    _episodesView.episodeArray = [[TungPodcast extractFeedArrayFromFeedDict:feedDict] mutableCopy];
    [_episodesView assignSavedPropertiesToEpisodeArray];
    
    [_episodesView.refreshControl endRefreshing];
    
    [_episodesView.tableView reloadData];
    
}

- (void) setUpViewForDict:(NSDictionary *)dict {
    // remove spinner
    _episodesView.tableView.backgroundView = nil;
    
    _episodesView.episodeArray = [[TungPodcast extractFeedArrayFromFeedDict:dict] mutableCopy];
    [_episodesView assignSavedPropertiesToEpisodeArray];
    
    // find focused indexPath if focused GUID
    if (_focusedGUID) {
        for (int i = 0; i < _episodesView.episodeArray.count; i++) {
            if ([[[_episodesView.episodeArray objectAtIndex:i] objectForKey:@"guid"] isEqualToString:_focusedGUID]) {
                _episodesView.focusedIndexPath = [NSIndexPath indexPathForRow:i inSection:0];
            }
        }
    }
    [_episodesView.refreshControl endRefreshing];
    
    // update dict and entity with website and email
    if ([[dict objectForKey:@"channel"] objectForKey:@"link"]) {
        id website = [[dict objectForKey:@"channel"] objectForKey:@"link"];
        if ([website isKindOfClass:[NSString class]]) {
            [_podcastDict setObject:website forKey:@"website"];
            _podcastEntity.website = website;
        }
    }
    if ([[dict objectForKey:@"channel"] objectForKey:@"itunes:owner"] &&
        [[[dict objectForKey:@"channel"] objectForKey:@"itunes:owner"] objectForKey:@"itunes:email"]) {
        id email = [[[dict objectForKey:@"channel"] objectForKey:@"itunes:owner"] objectForKey:@"itunes:email"];
        if ([email isKindOfClass:[NSString class]]) {
            [_podcastDict setObject:email forKey:@"email"];
            _podcastEntity.email = email;
        }
    }
    // description
    NSString *descText = [TungCommonObjects findPodcastDescriptionWithDict:dict];
    _headerView.descriptionLabel.text = descText;
    _podcastEntity.desc = descText;
    
    [_headerView sizeAndConstrainHeaderViewInViewController:self];
    [_headerView.subscribeButton addTarget:self action:@selector(subscribeToPodcastViaSender:) forControlEvents:UIControlEventTouchUpInside];
    [_headerView.podcastButton addTarget:self action:@selector(pushPodcastDescription) forControlEvents:UIControlEventTouchUpInside];
    [_headerView.largeButton addTarget:self action:@selector(largeButtonInHeaderTapped) forControlEvents:UIControlEventTouchUpInside];
    
    [_episodesView.tableView reloadData];
    
    if (_focusedGUID) {
        [_episodesView.tableView scrollToRowAtIndexPath:_episodesView.focusedIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

- (void) largeButtonInHeaderTapped {
    
    // support button
    if (_tung.connectionAvailable.boolValue) {
        // url unique to this podcast
        NSString *fundraiseUrlString = [NSString stringWithFormat:@"%@fundraising?id=%@", _tung.tungSiteRootUrl, _podcastEntity.collectionId];
        BrowserViewController *webView = [self.storyboard instantiateViewControllerWithIdentifier:@"webView"];
        webView.urlToNavigateTo = [NSURL URLWithString:fundraiseUrlString];
        [self presentViewController:webView animated:YES completion:nil];
    } else {
        [_tung showNoConnectionAlert];
    }
}

// pushes a new view which uses its own webview delegate
- (void) pushPodcastDescription {
    
    [_podcast pushPodcastDescriptionForEntity:_podcastEntity];
}

#pragma mark Subscribing

// toggle subscribe status
- (void) subscribeToPodcastViaSender:(id)sender {
    
    // only allow subscribing with network connection
    if (_tung.connectionAvailable) {
        
        if (!_podcastEntity) return;
        
        CircleButton *subscribeButton = (CircleButton *)sender;
        
        subscribeButton.subscribed = !subscribeButton.subscribed;
        [subscribeButton setNeedsDisplay];
        
        // subscribe
        if (subscribeButton.subscribed) {
            
            [_tung subscribeToPodcast:_podcastEntity withButton:subscribeButton];
            [_episodesView markNewEpisodesAsSeen];
        }
        // unsubscribe
        else {
            
            [_tung unsubscribeFromPodcast:_podcastEntity withButton:subscribeButton];
        }
    }
    else {
        [_tung showNoConnectionAlert];
    }
}


@end
