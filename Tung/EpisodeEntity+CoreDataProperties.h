//
//  EpisodeEntity+CoreDataProperties.h
//  Tung
//
//  Created by Jamie Perkins on 10/8/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "EpisodeEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface EpisodeEntity (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *collectionId;
@property (nullable, nonatomic, retain) NSNumber *dataLength;
@property (nullable, nonatomic, retain) NSString *desc;
@property (nullable, nonatomic, retain) NSString *duration;
@property (nullable, nonatomic, retain) NSString *episodeImageUrl;
@property (nullable, nonatomic, retain) NSString *guid;
@property (nullable, nonatomic, retain) NSString *id;
@property (nullable, nonatomic, retain) NSNumber *isRecommended;
@property (nullable, nonatomic, retain) NSDate *pubDate;
@property (nullable, nonatomic, retain) NSString *shortlink;
@property (nullable, nonatomic, retain) NSString *title;
@property (nullable, nonatomic, retain) NSNumber *trackPosition;
@property (nullable, nonatomic, retain) NSNumber *trackProgress;
@property (nullable, nonatomic, retain) NSString *url;
@property (nullable, nonatomic, retain) PodcastEntity *podcast;

@end

NS_ASSUME_NONNULL_END
