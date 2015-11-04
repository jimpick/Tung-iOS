//
//  AppDelegate.m
//  Tung
//
//  Created by Jamie Perkins on 2/4/14.
//  Copyright (c) 2014 inorganik produce. All rights reserved.
//

#import "AppDelegate.h"
#import <Security/Security.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import "TungCommonObjects.h"

@implementation AppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

@synthesize navControl;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    _tung = [TungCommonObjects establishTungObjects];
    
    BOOL isLoggedIn = NO;
    
    NSString *key = @"tung credentials";
    NSString *service = [[NSBundle mainBundle] bundleIdentifier];
    
    // look for tung cred in keychain
    
    NSDictionary *query = @{
                           (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
                           (__bridge id)kSecAttrService : service,
                           (__bridge id)kSecAttrAccount : key,
                           (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
                           (__bridge id)kSecAttrSynchronizable : (__bridge id)kCFBooleanTrue // iCloud sync
                           };
    CFDictionaryRef valueAttributes = NULL;
    OSStatus results = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&valueAttributes);
    NSDictionary *attributes = (__bridge_transfer NSDictionary *)valueAttributes;
    if (results == errSecSuccess) {
        NSString *creationDate = attributes[(__bridge id)kSecAttrCreationDate];
        CLS_LOG(@"Credentials found. Created on: %@", creationDate);
        isLoggedIn = YES;
    } else {
        CLS_LOG(@"No cred found. Code: %ld", (long)results);
    }
    
    // delete keychain value for cred
    /*
    CLS_LOG(@"deleting keychain cred");
    NSDictionary *deleteQuery = @{
                            (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService : service,
                            (__bridge id)kSecAttrAccount : key
                            };
    OSStatus foundExisting = SecItemCopyMatching((__bridge CFDictionaryRef)deleteQuery, NULL);
    if (foundExisting == errSecSuccess) {
        OSStatus deleted = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
        if (deleted == errSecSuccess) {
            CLS_LOG(@"successfully deleted cred");
            isLoggedIn = NO;
        }
     }
    */
    
    //isLoggedIn = NO; // DEV ONLY
    
    // depending on if they have cred or not, show appropriate screen
    NSString *storyboardId = isLoggedIn ? @"authenticated" : @"welcome";
    self.window.rootViewController = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:storyboardId];
    
    [Fabric with:@[CrashlyticsKit]];

    //return YES;
    return [[FBSDKApplicationDelegate sharedInstance] application:application
                                    didFinishLaunchingWithOptions:launchOptions];
}
/*
- (NSUInteger)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    
}
*/

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    CLS_LOG(@"Application did become active");
    [_tung checkForNowPlaying];
    
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

#pragma mark - Facebook url handling

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    //CLS_LOG(@"fb open url: %@, source application: %@, annotation: %@", url, sourceApplication, annotation);
    return [[FBSDKApplicationDelegate sharedInstance] application:application
                                                          openURL:url
                                                sourceApplication:sourceApplication
                                                       annotation:annotation
            ];
}


#pragma mark - Url scheme handling method

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    CLS_LOG(@"url recieved: %@", url);
    CLS_LOG(@"- query string: %@", [url query]);
    CLS_LOG(@"- host: %@", [url host]);
    CLS_LOG(@"- url path: %@", [url path]);
    NSDictionary *dict = [self parseQueryString:[url query]];
    CLS_LOG(@"- query dict: %@", dict);
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
            CLS_LOG(@"Unresolved error %@, %@", error, [error userInfo]);
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
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
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
        CLS_LOG(@"Unresolved error %@, %@", error, [error userInfo]);
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
