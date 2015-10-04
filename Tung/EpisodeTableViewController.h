//
//  PodcastTableViewController.h
//  Tung
//
//  Created by Jamie Perkins on 7/27/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TungCommonObjects.h"
#import "EpisodeCell.h"

@interface EpisodeTableViewController : UITableViewController

@property (strong, nonatomic) NSArray *episodeArray;
@property (strong, nonatomic) NSMutableDictionary *podcastDict;
@property (strong, nonatomic) NSString *focusedGUID;
@property (strong, nonatomic) NSIndexPath *focusedIndexPath;
@property BOOL noResults;

@end
