//
//  AppDelegate.m
//  Tung
//
//  Created by Jamie Perkins on 2/4/14.
//  Copyright (c) 2014 inorganik produce. All rights reserved.
//

#import "AppDelegate.h"
#import <Security/Security.h>
#import "TungCommonObjects.h"
#import "TungPodcast.h"
#import "MainTabBarController.h"

@implementation AppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

@synthesize navControl;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _tung = [TungCommonObjects establishTungObjects];

    BOOL isLoggedIn = (_tung.loggedInUser && _tung.loggedInUser.tung_id && _tung.loggedInUser.token);
    if (isLoggedIn) {
        // if user is registered for remote notifs, call below methods
        // bc "device token changes frequently" according to docs
        if ([[UIApplication sharedApplication] isRegisteredForRemoteNotifications]) {
            [[UIApplication sharedApplication] registerForRemoteNotifications];
            [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeBadge categories:nil]];
        }
    }
    
    // depending on if they have cred or not, show appropriate screen
    NSString *storyboardId = isLoggedIn ? @"authenticated" : @"welcome";
    self.window.rootViewController = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:storyboardId];
    
    // twitter
    [[Twitter sharedInstance] startWithConsumerKey:@"JwOEqvjaWbdEgMRXLJ86rPUf5" consumerSecret:@"XRoROyD7pM1PZ3Xt6CAg4yN4tVgQG8kavx6dmvQZsqJ9DI1cGt"];
    
    // fabric
    [Fabric with:@[CrashlyticsKit, [Twitter sharedInstance]]];
    
    // facebook
    [[FBSDKApplicationDelegate sharedInstance] application:application
                             didFinishLaunchingWithOptions:launchOptions];
    
    // background fetch
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    // local notification
    if (launchOptions[UIApplicationLaunchOptionsLocalNotificationKey] != nil) {
        UILocalNotification *notif = launchOptions[UIApplicationLaunchOptionsLocalNotificationKey];
        [self application:application didReceiveLocalNotification:notif];
    }
    // remote notification
    if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] != nil) {
        NSDictionary *userInfo = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
        [self application:application didReceiveRemoteNotification:userInfo];
    }

    //NSLog(@"application did finish launching with options");
    return YES;
}

#pragma mark - Background fetch

- (void) application:(UIApplication *)application performFetchWithCompletionHandler:(nonnull void (^)(UIBackgroundFetchResult))completionHandler {
    
    // get all subscribed podcasts and check for new episodes
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"PodcastEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isSubscribed == YES"];
    request.predicate = predicate;
    NSSortDescriptor *dateSort = [[NSSortDescriptor alloc] initWithKey:@"timeSubscribed" ascending:YES];
    request.sortDescriptors = @[dateSort];
    
    NSError *error;
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    
    if (result.count > 0) {
        
        NSInteger podcastsWithNewEpisodes = 0;
        NSMutableArray *podcastsWithNewEpisodesNotify = [NSMutableArray array];
        BOOL newEpisodesPlural = NO; // used for forming string of new episode(s) alert
    	
        for (int i = 0; i < result.count; i++) {
            PodcastEntity *podEntity = [result objectAtIndex:i];
            NSDictionary *feedDict = [TungPodcast retrieveAndCacheFeedForPodcastEntity:podEntity forceNewest:YES reachable:_tung.connectionAvailable.boolValue];
            NSArray *episodes = [TungPodcast extractFeedArrayFromFeedDict:feedDict];
            
            //NSLog(@"PODCAST: %@", podEntity.collectionName);
            
            // check if mostRecentEpisodeDate is established
            if (!podEntity.mostRecentEpisodeDate && episodes.count > 0) {
                //NSLog(@"- did not have mostRecentEpisodeDate established yet.");
                NSDate *mostRecent = [episodes[0] objectForKey:@"pubDate"];
                podEntity.mostRecentEpisodeDate = mostRecent;
                podEntity.mostRecentSeenEpisodeDate = mostRecent;
                [TungCommonObjects saveContextWithReason:@"updated most recent episode date for podcast entity"];
            }
            else {
                //NSLog(@"- mostRecentEpisodeDate: %@", podEntity.mostRecentEpisodeDate);
                NSDate *mostRecentForCompare = podEntity.mostRecentEpisodeDate;
                NSInteger numNewEpisodes = podEntity.numNewEpisodes.integerValue;
                BOOL newMostRecentSet = NO;
                
                for (int i = 0; i < episodes.count; i++) {
                    NSDate *pubDate = [episodes[i] objectForKey:@"pubDate"];
                    // check if episode is newer than entity's mostRecentEpisodeDate
                    if ([mostRecentForCompare compare:pubDate] == NSOrderedAscending) {
                        numNewEpisodes++;
                        // set most recent episode date
                        if (!newMostRecentSet) {
                            podEntity.mostRecentEpisodeDate = pubDate;
                            newMostRecentSet = YES;
                            podcastsWithNewEpisodes++;
                            if (podEntity.notifyOfNewEpisodes.boolValue) {
                                [podcastsWithNewEpisodesNotify addObject:podEntity.collectionName];
                            }
                        }
                    } else {
                        break;
                    }
                }
                if (numNewEpisodes > 1) newEpisodesPlural = YES;
                podEntity.numNewEpisodes = [NSNumber numberWithInteger:numNewEpisodes];
                [TungCommonObjects saveContextWithReason:@"updated most recent episode date for podcast entity"];
            }
        }
        //NSLog(@"background fetch result: NEW episodes");
        //NSLog(@"podcasts with new episodes: %@", podcastsWithNewEpisodes);
        if (podcastsWithNewEpisodes > 0) {
            
            // update number of subscribed podcasts with new episodes
            // in subscriptions badge:
            [_tung setBadgeNumber:[NSNumber numberWithInteger:podcastsWithNewEpisodes] forBadge:_tung.subscriptionsBadge];
            // and settings:
            SettingsEntity *settings = [TungCommonObjects settings];
            settings.numPodcastNotifications = [NSNumber numberWithInteger:podcastsWithNewEpisodes];
            [TungCommonObjects saveContextWithReason:@"number of new podcast notifications changed"];
            
            // if we should notify user of new episodes, build notification message string and notify
            if (podcastsWithNewEpisodesNotify.count > 0) {
                // build message string
                NSString *alertBody;
                if (podcastsWithNewEpisodesNotify.count == 1) {
                    NSString *episodesPlural = [NSString stringWithFormat:@"%@", (newEpisodesPlural) ? @"new episodes" : @"a new episode"];
                    alertBody = [NSString stringWithFormat:@"%@ has %@", [podcastsWithNewEpisodesNotify objectAtIndex:0], episodesPlural];
                }
                else if (podcastsWithNewEpisodesNotify.count == 2) {
                    alertBody = [NSString stringWithFormat:@"%@ and %@ have new episodes", [podcastsWithNewEpisodesNotify objectAtIndex:0], [podcastsWithNewEpisodesNotify objectAtIndex:1]];
                }
                else {
                    alertBody = [NSString stringWithFormat:@"%lu subscribed podcasts have new episodes", (unsigned long)podcastsWithNewEpisodesNotify.count];
                }
                _notif = [[UILocalNotification alloc] init];
                _notif.alertBody = alertBody;
                _notif.fireDate = [NSDate dateWithTimeIntervalSinceNow:0.0];
                _notif.timeZone = [[NSCalendar currentCalendar] timeZone];
                _notif.hasAction = YES;
                _notif.alertAction = @"view";
                _notif.userInfo = @{@"openTabIndex": [NSNumber numberWithInt:2]};
                _notif.applicationIconBadgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber + podcastsWithNewEpisodesNotify.count;
                [[UIApplication sharedApplication] scheduleLocalNotification:_notif];
            }
            //NSLog(@"background fetch result: NEW episodes");
            completionHandler(UIBackgroundFetchResultNewData);
        }
        else {
            //NSLog(@"background fetch result: NO new episodes");
            completionHandler(UIBackgroundFetchResultNoData);
        }
    }
    else {
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

#pragma mark - Local Notifications

- (void) application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    
    //NSLog(@"did receive local notification: %@", [notification userInfo]);
    
    if ([[notification userInfo] objectForKey:@"openTabIndex"]) {
        NSNumber *tabIndex = [[notification userInfo] objectForKey:@"openTabIndex"];
        // open tab if app isn't in foreground
        if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
            [self switchTabBarSelectionToTabIndex:tabIndex.integerValue];
        }
    }
    else if ([[notification userInfo] objectForKey:@"deleteEpisodeWithUrl"]) {
        NSString *urlString = [[notification userInfo] objectForKey:@"deleteEpisodeWithUrl"];
        //JPLog(@"received notification to delete episode with url: %@", urlString);
        [_tung deleteSavedEpisodeWithUrl:urlString confirm:NO];
    }
}

- (void) switchTabBarSelectionToTabIndex:(NSInteger)tabIndex {
    
    MainTabBarController *tabCtrl = (MainTabBarController *)self.window.rootViewController;
    // make sure it responds to selectTab:... could be WelcomeViewController
    if ([tabCtrl respondsToSelector:@selector(selectTab:)]) {
        tabCtrl.selectedIndex = 1;
        UIButton *btn = [[UIButton alloc] init];
        btn.tag = tabIndex;
        [tabCtrl selectTab:btn];
    }
}

#pragma mark - Remote Notifications

- (void) application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    
    NSMutableString *tokenAsString = [[NSMutableString alloc] initWithCapacity:deviceToken.length * 2];
    char *bytes = malloc(deviceToken.length);
    [deviceToken getBytes:bytes length:deviceToken.length];
    
    for (NSUInteger i = 0; i < deviceToken.length; i++) {
        char byte = bytes[i];
        [tokenAsString appendFormat:@"%02hhX", byte];
    }
    free(bytes);
    
    //NSLog(@"successfully registered for remote notifications. token: %@", tokenAsString);
    
    [self postDeviceToken:tokenAsString];
    
}

- (void) application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(nonnull NSError *)error {
    
    JPLog(@"FAILED to register for remote notifications with error: %@", error);
}

- (void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    
    //NSLog(@"did receive remote notification: %@", userInfo);
    
    if ([[userInfo objectForKey:@"aps"] objectForKey:@"openTabIndex"]) {
        NSNumber *tabIndex = [[userInfo objectForKey:@"aps"] objectForKey:@"openTabIndex"];
        // open tab if app isn't in foreground
        if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        	[self switchTabBarSelectionToTabIndex:tabIndex.integerValue];
        }
        
        // profile notification
        if (tabIndex.integerValue == 3) {
            
            // increment badge number
            NSNumber *badgeNumber = [[userInfo objectForKey:@"aps"] objectForKey:@"badge"];
    		
            SettingsEntity *settings = [TungCommonObjects settings];
            NSNumber *profileNotifs = [NSNumber numberWithInteger:settings.numProfileNotifications.integerValue + badgeNumber.integerValue];
            settings.numProfileNotifications = profileNotifs;
            [TungCommonObjects saveContextWithReason:@"number of new podcast notifications changed"];
            
            [_tung setBadgeNumber:profileNotifs forBadge:_tung.profileBadge];
            _tung.notificationsNeedRefresh = [NSNumber numberWithBool:YES];
        }
    }
    
}

- (void) postDeviceToken:(NSString *)token {
    NSURL *postDeviceTokenRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@app/post-device-token.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *postDeviceTokenRequest = [NSMutableURLRequest requestWithURL:postDeviceTokenRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [postDeviceTokenRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"tungId":_tung.loggedInUser.tung_id,
                             @"tungToken": _tung.loggedInUser.token,
                             @"deviceToken": token
                             };
    //NSLog(@"post device token with params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [postDeviceTokenRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:postDeviceTokenRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    //JPLog(@"%@", responseDict);
                    if ([responseDict objectForKey:@"error"]) {
                        // session expired
                        JPLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                    }
                    if ([responseDict objectForKey:@"success"]) {
                        JPLog(@"Successfully posted device token");
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                }
            });
        }
        else {
            JPLog(@"connection error: %@", error.localizedDescription);
        }
    }];
}


#pragma mark - Misc

- (void) applicationDidReceiveMemoryWarning:(UIApplication *)application {
    
    
}


#pragma mark - Changing state

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    //JPLog(@"application did enter background");
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    //JPLog(@"application will enter foreground");
    
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{

    //JPLog(@"Application did become active");
    [_tung checkForNowPlaying];
    // check reachability
    [_tung checkReachabilityWithCallback:nil];
    // if feed hasn't been fetched in the last 5 minutes
    [_tung checkFeedsLastFetchedTime];
    
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    JPLog(@"CRASH OR FORCE-QUIT - application will terminate"); // never appears in log
    [self saveContext];
}

#pragma mark - Facebook url handling

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    //JPLog(@"fb open url: %@, source application: %@, annotation: %@", url, sourceApplication, annotation);
    return [[FBSDKApplicationDelegate sharedInstance] application:application
                                                          openURL:url
                                                sourceApplication:sourceApplication
                                                       annotation:annotation
            ];
}


#pragma mark - Url scheme handling method

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    //JPLog(@"url recieved: %@", url);
    //NSLog(@"- query string: %@", [url query]);
    //NSLog(@"- host: %@", [url host]);
    //NSLog(@"- url path: %@", [url path]);
    //NSDictionary *dict = [self parseQueryString:[url query]];
    //NSLog(@"- query dict: %@", dict);
    return YES;
}

- (NSDictionary *)parseQueryString:(NSString *)query {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:6];
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    
    for (NSString *pair in pairs) {
        NSArray *elements = [pair componentsSeparatedByString:@"="];
        NSString *key = [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *val = [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [dict setObject:val forKey:key];
    }
    return dict;
}

#pragma mark - Core Data stack

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            JPLog(@"Unresolved save error %@, %@", error, [error userInfo]);
            //abort();
        }
    }
}

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"TungDataModel" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Tung.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    // automatic migration options
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        JPLog(@"Unresolved error %@, %@", error, [error userInfo]);
        //abort();
    }    
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
