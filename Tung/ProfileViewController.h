//
//  ProfileViewController.h
//  Tung
//
//  Created by Jamie Perkins on 10/4/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TungCommonObjects.h"
#import "TungStories.h"

@interface ProfileViewController : UIViewController <ControlButtonDelegate, UIScrollViewDelegate, UIWebViewDelegate>

@property (strong, nonatomic) NSString *profiledUserId;
@property (strong, nonatomic) NSMutableDictionary *profiledUserData;

@end
