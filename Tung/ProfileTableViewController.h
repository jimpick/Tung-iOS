//
//  ProfileTableViewController.h
//  Tung
//
//  Created by Jamie Perkins on 8/7/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "TungCommonObjects.h"
#import "LargeAvatarContainerView.h"

@interface ProfileTableViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, UIAlertViewDelegate, ControlButtonDelegate>

@property (strong, nonatomic) NSString *profiledUserId;
@property (strong, nonatomic) NSMutableDictionary *profiledUserData;

@end
