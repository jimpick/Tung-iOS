//
//  UserEntity+CoreDataProperties.h
//  Tung
//
//  Created by Jamie Perkins on 7/17/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "UserEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface UserEntity (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *bio;
@property (nullable, nonatomic, retain) NSString *email;
@property (nullable, nonatomic, retain) NSString *facebook_id;
@property (nullable, nonatomic, retain) NSString *large_av_url;
@property (nullable, nonatomic, retain) NSNumber *lastDataChange;
@property (nullable, nonatomic, retain) NSNumber *lastSeenNotification;
@property (nullable, nonatomic, retain) NSString *location;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSString *small_av_url;
@property (nullable, nonatomic, retain) NSString *tung_id;
@property (nullable, nonatomic, retain) NSString *twitter_id;
@property (nullable, nonatomic, retain) NSString *twitter_username;
@property (nullable, nonatomic, retain) NSString *url;
@property (nullable, nonatomic, retain) NSString *username;
@property (nullable, nonatomic, retain) NSNumber *isLoggedInUser;
@property (nullable, nonatomic, retain) NSString *token;

@end

NS_ASSUME_NONNULL_END
