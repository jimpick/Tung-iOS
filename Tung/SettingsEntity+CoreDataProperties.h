//
//  SettingsEntity+CoreDataProperties.h
//  Tung
//
//  Created by Jamie Perkins on 10/31/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "SettingsEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface SettingsEntity (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *hasSeenFeedDemo;
@property (nullable, nonatomic, retain) NSNumber *hasSeenNowPlayingDemo;
@property (nullable, nonatomic, retain) NSNumber *hasSeenSubscriptionsDemo;
@property (nullable, nonatomic, retain) NSNumber *hasSeenProfileDemo;
@property (nullable, nonatomic, retain) NSNumber *trainingWheelsOn;

@end

NS_ASSUME_NONNULL_END
