//
//  EpisodeEntity+CoreDataProperties.m
//  Tung
//
//  Created by Jamie Perkins on 2/5/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "EpisodeEntity+CoreDataProperties.h"

@implementation EpisodeEntity (CoreDataProperties)

@dynamic collectionId;
@dynamic dataLength;
@dynamic desc;
@dynamic duration;
@dynamic episodeImageUrl;
@dynamic guid;
@dynamic id;
@dynamic isDownloadingForSave;
@dynamic isNowPlaying;
@dynamic isQueuedForSave;
@dynamic isRecommended;
@dynamic isSaved;
@dynamic pubDate;
@dynamic savedUntilDate;
@dynamic shortlink;
@dynamic title;
@dynamic trackPosition;
@dynamic trackProgress;
@dynamic url;
@dynamic podcast;

@end
