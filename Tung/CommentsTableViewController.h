//
//  PodcastTableViewController.h
//  Tung
//
//  Created by Jamie Perkins on 7/27/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TungCommonObjects.h"
#import "CommentCell.h"
#import "CommentCellMine.h"
#import "EpisodeEntity.h"

@interface CommentsTableViewController : UITableViewController

@property (strong, nonatomic) NSMutableArray *commentsArray;
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;
@property (strong, nonatomic) EpisodeEntity *episodeEntity;

// request flags
@property (nonatomic, assign) BOOL requestingMore;
@property (nonatomic, assign) BOOL reachedEndOfPosts;
@property (nonatomic, assign) BOOL noResults;
@property (strong, nonatomic) NSString *requestStatus;

-(void) requestCommentsForEpisodeEntity:(EpisodeEntity *)episodeEntity
                              NewerThan:(NSNumber *)afterTime
                            orOlderThan:(NSNumber *)beforeTime;

@end
