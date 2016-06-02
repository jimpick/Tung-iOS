//
//  SettingsEntity+CoreDataProperties.m
//  Tung
//
//  Created by Jamie Perkins on 5/31/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "SettingsEntity+CoreDataProperties.h"

@implementation SettingsEntity (CoreDataProperties)

@dynamic feedLastFetched;
@dynamic hasSeenEpisodeExpirationAlert;
@dynamic hasSeenMentionsPrompt;
@dynamic hasSeenNewEpisodesPrompt;
@dynamic hasSeenWelcomePopup;
@dynamic numPodcastNotifications;
@dynamic numProfileNotifications;

@end
