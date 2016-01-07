//
//  SubscriptionViewCell.m
//  Tung
//
//  Created by Jamie Perkins on 5/1/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "SubscriptionViewCell.h"
#import "AppDelegate.h"
#import "TungCommonObjects.h"

@implementation SubscriptionViewCell

- (IBAction)changeNotifySetting:(id)sender {
    
    UISwitch *notifySwitch = (UISwitch *)sender;
    SubscriptionViewCell *cell = (SubscriptionViewCell *)[[[[sender superview] superview] superview] superview];
    NSDictionary *pDict = @{@"collectionId":cell.collectionId};
    PodcastEntity *podEntity = [TungCommonObjects getEntityForPodcast:pDict save:NO];
    
    
    if (notifySwitch.on) {
        podEntity.notifyOfNewEpisodes = [NSNumber numberWithBool:YES];
        
        if (![TungCommonObjects hasGrantedNotificationPermissions]) {
            TungCommonObjects *tung = [TungCommonObjects establishTungObjects];
            UIAlertView *notifsAreDisabled = [[UIAlertView alloc] initWithTitle:@"Turn notifications on?" message:@"Notifications are currently disabled. Would you like to enable them?" delegate:tung cancelButtonTitle:nil otherButtonTitles:@"No", @"Yes", nil];
            notifsAreDisabled.tag = 20;
            [notifsAreDisabled show];
        } else {
            // post notification so banner alert can be shown
            NSString *message = [NSString stringWithFormat:@"You will now receive alerts when new episodes of %@ are available.", podEntity.collectionName];
            NSNotification *notif = [NSNotification notificationWithName:@"notifyPrefChanged" object:nil userInfo:@{@"message":message}];
            [[NSNotificationCenter defaultCenter] postNotification:notif];
        }
    } else {
        podEntity.notifyOfNewEpisodes = [NSNumber numberWithBool:NO];
        // post notification so banner alert can be shown
        NSString *message = [NSString stringWithFormat:@"You will no longer receive alerts for %@.", podEntity.collectionName];
        NSNotification *notif = [NSNotification notificationWithName:@"notifyPrefChanged" object:nil userInfo:@{@"message":message}];
        [[NSNotificationCenter defaultCenter] postNotification:notif];
    }
    
    [TungCommonObjects saveContextWithReason:[NSString stringWithFormat:@"changed notify preference for podcast: %@", podEntity.collectionName]];
    
}

@end
