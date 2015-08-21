//
//  EpisodeEntity.h
//  Tung
//
//  Created by Jamie Perkins on 8/7/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class PodcastEntity;

@interface EpisodeEntity : NSManagedObject

@property (nonatomic, retain) NSNumber * collectionId;
@property (nonatomic, retain) NSNumber * dataLength;
@property (nonatomic, retain) NSString * desc;
@property (nonatomic, retain) NSString * duration;
@property (nonatomic, retain) NSNumber * endByteOffset;
@property (nonatomic, retain) NSString * episodeImageUrl;
@property (nonatomic, retain) NSString * guid;
@property (nonatomic, retain) NSNumber * isRecommended;
@property (nonatomic, retain) NSDate * pubDate;
@property (nonatomic, retain) NSNumber * startByteOffset;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSNumber * trackPosition;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSString * shortlink;
@property (nonatomic, retain) PodcastEntity *podcast;

@end
