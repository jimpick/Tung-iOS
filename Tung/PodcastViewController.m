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
#import "EpisodeTableViewController.h"


@class TungCommonObjects;

@interface PodcastViewController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) TungPodcast *podcast;
@property HeaderView *headerView;
@property EpisodeTableViewController *episodeView;
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
    NSLog(@"podcast dict: %@", _podcastDict);
    
    // get podcast entity
    _podcast.podcastEntity = [TungCommonObjects getEntityForPodcast:_podcastDict save:NO];
    
    // header view
    _headerView = [[HeaderView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 160)];
    [self.view addSubview:_headerView];
    [_podcast setUpHeaderView:_headerView forEpisode:nil orPodcast:YES];
    [_podcast sizeAndConstrainHeaderView:_headerView inViewController:self];
    
    // add child table view controller
    _episodeView = [self.storyboard instantiateViewControllerWithIdentifier:@"episodeView"];
    _episodeView.edgesForExtendedLayout = UIRectEdgeNone;
    if (_focusedGUID) _episodeView.focusedGUID = _focusedGUID;
    [self addChildViewController:_episodeView];
    [self.view addSubview:_episodeView.view];
    
    _episodeView.refreshControl = [UIRefreshControl new];
    [_episodeView.refreshControl addTarget:self action:@selector(getNewestFeed) forControlEvents:UIControlEventValueChanged];

    
    _episodeView.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodeView.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_headerView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodeView.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_episodeView.view.superview attribute:NSLayoutAttributeBottom multiplier:1 constant:-44]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodeView.view attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_episodeView.view.superview attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_episodeView.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_episodeView.view.superview attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    
    
    NSDictionary *cachedDict = [_tung retrieveCachedFeedForEntity:_podcast.podcastEntity];
    if (cachedDict) {
        [self setUpViewForDict:cachedDict cached:YES];
    }
    else {
        _needToRequestFeed = YES;
    }
    
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.navigationController.navigationBar.translucent = NO;
    // requesting can take a few seconds bc some feeds have many items,
    // request after view loads so spinner can be displayed
    if (_needToRequestFeed) [self getFeed:NO];
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
    [_episodeView.tableView reloadData];
}

// for refreshControl
- (void) getNewestFeed {
    [self getFeed:YES];
}

- (void) getFeed:(BOOL)forceNewest {
    
    NSDictionary *dict = [_podcast getFeedWithDict:_podcastDict forceNewest:forceNewest];
    
    if (dict) {
        //NSLog(@"podcast feed dict: %@", dict);
        [self setUpViewForDict:dict cached:NO];
        
    }
    else {
        NSLog(@"no dict - empty feed");
        _episodeView.noResults = YES;
        [_episodeView.tableView reloadData];
    }

}

- (void) setUpViewForDict:(NSDictionary *)dict cached:(BOOL)cached {
    // remove spinner
    _episodeView.tableView.backgroundView = nil;
    
    id item = [[dict objectForKey:@"channel"] objectForKey:@"item"];
    if ([item isKindOfClass:[NSArray class]]) {
        NSArray *array = item;
        _episodeView.episodeArray = [array mutableCopy];
    } else {
        _episodeView.episodeArray = [@[item] mutableCopy];
    }
    // cache the feed if we didn't pull it from cache
    if (!cached)
        [_tung cacheFeed:dict forEntity:_podcast.podcastEntity];
    
    [_episodeView.refreshControl endRefreshing];
    
    NSString *descText = [TungCommonObjects findPodcastDescriptionWithDict:dict];
    _headerView.descriptionLabel.text = descText;
    [_podcastDict setObject:descText forKey:@"desc"];
    
    [_podcast sizeAndConstrainHeaderView:_headerView inViewController:self];
    
    // update dict and entity with website and email
    if ([[dict objectForKey:@"channel"] objectForKey:@"link"]) {
        id website = [[dict objectForKey:@"channel"] objectForKey:@"link"];
        if ([website isKindOfClass:[NSString class]]) {
            [_podcastDict setObject:website forKey:@"website"];
            if (_podcast.podcastEntity) _podcast.podcastEntity.website = website;
        }
    }
    if ([[dict objectForKey:@"channel"] objectForKey:@"itunes:owner"] &&
        [[[dict objectForKey:@"channel"] objectForKey:@"itunes:owner"] objectForKey:@"itunes:email"]) {
        id email = [[[dict objectForKey:@"channel"] objectForKey:@"itunes:owner"] objectForKey:@"itunes:email"];
        if ([email isKindOfClass:[NSString class]]) {
            [_podcastDict setObject:email forKey:@"email"];
            if (_podcast.podcastEntity) _podcast.podcastEntity.email = email;
        }
    }
    // description: prefer encoded content, fallback to description
    if (_podcast.podcastEntity) _podcast.podcastEntity.desc = descText;
    [TungCommonObjects saveContextWithReason:@"got podcast description"];
    
    _episodeView.podcastDict = _podcastDict;
    
    _episodeView.noResults = _podcast.noResults;
    [_episodeView.tableView reloadData];
    
    if (_focusedGUID) {
        [_episodeView.tableView scrollToRowAtIndexPath:_episodeView.focusedIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }

}

@end
