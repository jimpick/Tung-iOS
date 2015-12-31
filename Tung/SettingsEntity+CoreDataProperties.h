//
//  SettingsEntity+CoreDataProperties.h
//  Tung
//
//  Created by Jamie Perkins on 12/30/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "SettingsEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface SettingsEntity (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *hasSeenWelcomePopup;
@property (nullable, nonatomic, retain) NSNumber *hasSeenNewEpisodesPrompt;
@property (nullable, nonatomic, retain) NSNumber *numPodcastNotifications;
@property (nullable, nonatomic, retain) NSNumber *numProfileNotifications;
@property (nullable, nonatomic, retain) NSNumber *hasSeenMentionsPrompt;

@end

NS_ASSUME_NONNULL_END
