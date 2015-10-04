//
//  PodcastViewController.h
//  Tung
//
//  Created by Jamie Perkins on 4/28/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TungCommonObjects.h"
#import "TungPodcast.h"
#import "CircleButton.h"
#import "HeaderView.h"

@interface PodcastViewController : UIViewController <ControlButtonDelegate>

@property (strong, nonatomic) NSMutableDictionary *podcastDict;
@property (strong, nonatomic) NSString *focusedGUID;

@end
