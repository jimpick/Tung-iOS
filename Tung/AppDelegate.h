//
//  AppDelegate.h
//  Tung
//
//  Created by Jamie Perkins on 2/4/14.
//  Copyright (c) 2014 inorganik produce. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PodcastEntity.h"
#import "EpisodeEntity.h"
#import "UserEntity.h"
#import "SettingsEntity.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import <TwitterKit/TwitterKit.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import "JPLogRecorder.h"

@class TungCommonObjects;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, retain) TungCommonObjects *tung;

@property (strong, nonatomic) UINavigationController *navControl;

@property (strong, nonatomic) UILocalNotification *notif;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;
- (void) switchTabBarSelectionToTabIndex:(NSInteger)tabIndex;
- (NSDictionary *) getAppKeysDictionary;

@end
