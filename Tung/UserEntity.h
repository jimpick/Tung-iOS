//
//  UserEntity.h
//  Tung
//
//  Created by Jamie Perkins on 7/30/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface UserEntity : NSManagedObject

@property (nonatomic, retain) NSString * tung_id;
@property (nonatomic, retain) NSString * username;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * email;
@property (nonatomic, retain) NSString * location;
@property (nonatomic, retain) NSString * bio;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSString * twitter_id;
@property (nonatomic, retain) NSString * twitter_username;
@property (nonatomic, retain) NSString * facebook_id;
@property (nonatomic, retain) NSString * small_av_url;
@property (nonatomic, retain) NSString * large_av_url;

@end
