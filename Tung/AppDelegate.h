//
//  AppDelegate.h
//  Tung
//
//  Created by Jamie Perkins on 2/4/14.
//  Copyright (c) 2014 inorganik produce. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <FacebookSDK/FacebookSDK.h>
#import "WelcomeViewController.h"
#import "PodcastEntity.h"
#import "EpisodeEntity.h"
#import "UserEntity.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) WelcomeViewController *welcomeViewController;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (strong, nonatomic) UINavigationController *navControl;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;
- (void)sessionStateChanged:(FBSession *)session state:(FBSessionState) state error:(NSError *)error;

@end
