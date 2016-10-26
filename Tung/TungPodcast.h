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
#import "EpisodeEntity.h"

@protocol TungPodcastsDelegate <NSObject>

@required

-(void) dismissPodcastSearch;

@optional

-(void) xmlToDictionaryComplete:(NSDictionary *)dict;

@end


@interface TungPodcast : NSObject <UISearchBarDelegate, UISearchControllerDelegate, UITableViewDataSource, UITableViewDelegate>

@property id <TungPodcastsDelegate> delegate;

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

// feeds
+ (void) cacheFeed:(NSDictionary *)feed forEntity:(PodcastEntity *)entity;
+ (BOOL) saveFeedForEntity:(PodcastEntity *)entity;
+ (void) unsaveFeedForEntity:(PodcastEntity *)entity;
+ (NSDictionary*) retrieveCachedFeedForPodcastEntity:(PodcastEntity *)entity;
+ (NSDictionary *) retrieveAndCacheFeedForPodcastEntity:(PodcastEntity *)entity forceNewest:(BOOL)forceNewest reachable:(BOOL)reachable;
+ (NSDictionary *) requestAndConvertPodcastFeedDataWithFeedUrl:(NSString *)feedUrl;
+ (NSArray *) extractFeedArrayFromFeedDict:(NSDictionary *)feedDict error:(NSError **)error;

- (void) pushPodcastDescriptionForEntity:(PodcastEntity *)podcastEntity;

- (void) preloadPodcastArtForArray:(NSArray*)itemArray;
- (void) preloadFeedsWithLimit:(NSUInteger)limit;


@end
