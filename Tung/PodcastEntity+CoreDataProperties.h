//
//  PodcastEntity+CoreDataProperties.h
//  Tung
//
//  Created by Jamie Perkins on 6/3/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "PodcastEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface PodcastEntity (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *artistName;
@property (nullable, nonatomic, retain) NSString *artworkUrl;
@property (nullable, nonatomic, retain) NSString *artworkUrlSSL;
@property (nullable, nonatomic, retain) NSNumber *collectionId;
@property (nullable, nonatomic, retain) NSString *collectionName;
@property (nullable, nonatomic, retain) NSString *desc;
@property (nullable, nonatomic, retain) NSString *email;
@property (nullable, nonatomic, retain) NSDate *feedLastCached;
@property (nullable, nonatomic, retain) NSString *feedUrl;
@property (nullable, nonatomic, retain) NSNumber *isSubscribed;
@property (nullable, nonatomic, retain) id keyColor1;
@property (nullable, nonatomic, retain) NSString *keyColor1Hex;
@property (nullable, nonatomic, retain) id keyColor2;
@property (nullable, nonatomic, retain) NSString *keyColor2Hex;
@property (nullable, nonatomic, retain) NSDate *mostRecentEpisodeDate;
@property (nullable, nonatomic, retain) NSDate *mostRecentSeenEpisodeDate;
@property (nullable, nonatomic, retain) NSNumber *notifyOfNewEpisodes;
@property (nullable, nonatomic, retain) NSNumber *numNewEpisodes;
@property (nullable, nonatomic, retain) NSNumber *timeSubscribed;
@property (nullable, nonatomic, retain) NSString *website;
@property (nullable, nonatomic, retain) NSString *artworkUrl600;
@property (nullable, nonatomic, retain) NSSet<EpisodeEntity *> *episodes;

@end

@interface PodcastEntity (CoreDataGeneratedAccessors)

- (void)addEpisodesObject:(EpisodeEntity *)value;
- (void)removeEpisodesObject:(EpisodeEntity *)value;
- (void)addEpisodes:(NSSet<EpisodeEntity *> *)values;
- (void)removeEpisodes:(NSSet<EpisodeEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
