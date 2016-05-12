//
//  SuggestedUsersTableViewController.h
//  Tung
//
//  Created by Jamie Perkins on 5/10/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TungCommonObjects.h"

@interface SuggestedUsersTableViewController : UITableViewController


@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) NSArray *usersArray;
@property (strong, nonatomic) NSMutableDictionary *profileData;

@end
