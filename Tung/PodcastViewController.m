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
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) self.edgesForExtendedLayout = UIRectEdgeBottom;
    
    self.navigationItem.title = @"Podcast";
    self.navigationItem.rightBarButtonItem = nil;
    
    _podcast = [TungPodcast new];
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
    _episodesView.podcastEntity = _podcastEntity;
    
    NSLog(@"focused GUID: %@", _focusedGUID);
    [self addChildViewController:_episodesView];
    [self.view addSubview:_episodesView.view];
    
    _episodesView.refreshControl = [UIRefreshControl new];
    [_episodesView.refreshControl addTarget:self action:@selector(getNewestFeed) forControlEvents:UIControlEventValueChanged];

    _episodesView.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_headerView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_episodesView.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:-44]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_episodesView.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodesView.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_episodesView.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
    NSDictionary *feedDict = [TungPodcast retrieveAndCacheFeedForPodcastEntity:_podcastEntity forceNewest:NO];
    [self setUpViewForDict:feedDict];
    
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.navigationController.navigationBar.translucent = NO;
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
    NSDictionary *feedDict = [TungPodcast retrieveAndCacheFeedForPodcastEntity:_podcastEntity forceNewest:YES];
    _episodesView.episodeArray = [TungPodcast extractFeedArrayFromFeedDict:feedDict];
    
    [_episodesView.refreshControl endRefreshing];
    
    [_episodesView.tableView reloadData];
    
}

- (void) setUpViewForDict:(NSDictionary *)dict {
    // remove spinner
    _episodesView.tableView.backgroundView = nil;
    
    _episodesView.episodeArray = [TungPodcast extractFeedArrayFromFeedDict:dict];
    
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
    
    [_episodesView.tableView reloadData];
    
    if (_focusedGUID) {
        [_episodesView.tableView scrollToRowAtIndexPath:_episodesView.focusedIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }

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
            NSLog(@"subscribed to podcast");
            
            NSDate *dateSubscribed = [NSDate date];
            _podcastEntity.isSubscribed = [NSNumber numberWithBool:YES];
            _podcastEntity.dateSubscribed = dateSubscribed;
            
            [_tung subscribeToPodcast:_podcastEntity withButton:subscribeButton];
        }
        // unsubscribe
        else {
            NSLog(@"unsubscribe from podcast ");
            
            _podcastEntity.isSubscribed = [NSNumber numberWithBool:NO];
            NSLog(@"isSubscribted changed to %@", _podcastEntity.isSubscribed);
            _podcastEntity.dateSubscribed = nil;
            
            [_tung unsubscribeFromPodcast:_podcastEntity withButton:subscribeButton];
        }
        [TungCommonObjects saveContextWithReason:@"(un)subscribed to podcast"];
    }
    else {
        [_podcast showNoConnectionAlert];
    }
}


@end
