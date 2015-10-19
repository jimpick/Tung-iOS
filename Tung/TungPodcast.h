//
//  tungPodcasts.h
//  Tung
//
//  Created by Jamie Perkins on 3/16/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//
/*
 - manage podcast entity
 - manage podcast dictionary
 - manage podcast search and search table
 - manage feed request and parsing
*/

#import <Foundation/Foundation.h>
#import "JPXMLtoDictionary.h"
#import "HeaderView.h"
#import "PodcastEntity.h"
#import "EpisodeEntity.h"

@class TungCommonObjects;

@protocol TungPodcastsDelegate <NSObject>

@required

-(void) dismissPodcastSearch;

@optional

-(void) xmlToDictionaryComplete:(NSDictionary *)dict;

@end


@interface TungPodcast : NSObject <UISearchBarDelegate, UISearchControllerDelegate, UITableViewDataSource, UITableViewDelegate>

@property id <TungPodcastsDelegate> delegate;
@property (nonatomic, retain) TungCommonObjects *tung;

// search
@property (strong, nonatomic) NSMutableArray *podcastArray;
@property (strong, nonatomic) NSTimer *searchTimer;
@property UISearchController *searchController;
@property UITableViewController *searchTableViewController;
@property (strong, nonatomic) UINavigationController *navController;
@property (nonatomic, assign) BOOL noResults;
@property (nonatomic, assign) BOOL queryExecuted;

// podcast view
@property UIColor *keyColor;
@property (strong, nonatomic) NSData *feedData;
@property (nonatomic, assign) NSInteger limit;
@property (nonatomic, assign) NSInteger page;
@property (strong, nonatomic) NSFetchedResultsController *resultsController;
@property NSOperationQueue *feedPreloadQueue;
@property PodcastEntity *podcastEntity;

// instance methods
+ (NSDictionary *) getFeedWithDict:(NSDictionary *)podcastDict forceNewest:(BOOL)forceNewest;
+ (NSDictionary *) retrieveAndConvertPodcastFeedDataFromDict:(NSDictionary *)podcastDict;
+ (NSDictionary *) requestAndConvertPodcastFeedDataFromDict:(NSDictionary *)podcastDict;
+ (NSArray *) extractFeedArrayFromFeedDict:(NSDictionary *)feedDict;
- (void) preloadPodcastArtForArray:(NSArray*)itemArray;
- (void) preloadFeedsWithLimit:(NSUInteger)limit;

- (void) setUpHeaderView:(HeaderView *)headerView forEpisode:(EpisodeEntity *)episodeEntity orPodcast:(BOOL)forPodcast;
- (void) sizeAndConstrainHeaderView:(HeaderView *)headerView inViewController:(UIViewController *)vc;
- (void) subscribeToPodcastViaSender:(id)sender;
- (void) configureEpisodeCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath;
- (void) showNoConnectionAlert;


@end
