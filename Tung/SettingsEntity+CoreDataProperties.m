//
//  SettingsEntity+CoreDataProperties.m
//  Tung
//
//  Created by Jamie Perkins on 12/30/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "SettingsEntity+CoreDataProperties.h"

@implementation SettingsEntity (CoreDataProperties)

@dynamic hasSeenWelcomePopup;
@dynamic hasSeenNewEpisodesPrompt;
@dynamic numPodcastNotifications;
@dynamic numProfileNotifications;
@dynamic hasSeenMentionsPrompt;

@end
