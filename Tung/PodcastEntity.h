//
//  PodcastEntity.h
//  Tung
//
//  Created by Jamie Perkins on 9/9/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class EpisodeEntity;

@interface PodcastEntity : NSManagedObject

@property (nonatomic, retain) NSString * artistName;
@property (nonatomic, retain) NSString * artworkUrl600;
@property (nonatomic, retain) NSNumber * collectionId;
@property (nonatomic, retain) NSString * collectionName;
@property (nonatomic, retain) NSDate * dateSubscribed;
@property (nonatomic, retain) NSString * desc;
@property (nonatomic, retain) NSString * email;
@property (nonatomic, retain) NSDate * feedLastCached;
@property (nonatomic, retain) NSString * feedUrl;
@property (nonatomic, retain) NSNumber * isSubscribed;
@property (nonatomic, retain) id keyColor1;
@property (nonatomic, retain) NSString * keyColor1Hex;
@property (nonatomic, retain) id keyColor2;
@property (nonatomic, retain) NSString * keyColor2Hex;
@property (nonatomic, retain) NSString * website;
@property (nonatomic, retain) NSString * artworkUrlSSL;
@property (nonatomic, retain) NSSet *episodes;
@end

@interface PodcastEntity (CoreDataGeneratedAccessors)

- (void)addEpisodesObject:(EpisodeEntity *)value;
- (void)removeEpisodesObject:(EpisodeEntity *)value;
- (void)addEpisodes:(NSSet *)values;
- (void)removeEpisodes:(NSSet *)values;

@end
