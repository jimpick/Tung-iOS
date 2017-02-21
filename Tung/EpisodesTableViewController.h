//
//  EpisodesTableViewController.h
//  Tung
//
//  Created by Jamie Perkins on 7/27/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TungCommonObjects.h"
#import "EpisodeCell.h"

@interface EpisodesTableViewController : UITableViewController <UISearchBarDelegate>

@property (strong, nonatomic) NSMutableArray *episodeArray;
@property (strong, nonatomic) NSMutableArray *filteredEpisodeArray;
@property (strong, nonatomic) PodcastEntity *podcastEntity;
@property (strong, nonatomic) NSIndexPath *focusedIndexPath;
@property BOOL noResults;
@property (strong, nonatomic) UINavigationController *navController;
@property (strong, nonatomic) IBOutlet UISearchBar *filterBar;

- (void) assignSavedPropertiesToEpisodeArray;
- (void) markNewEpisodesAsSeen;

@end
