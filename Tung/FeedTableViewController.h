//
//  FeedTableViewController.h
//  Tung
//
//  Created by Jamie Perkins on 8/7/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TungPodcast.h"
#import "TungCommonObjects.h"

@interface FeedTableViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, TungPodcastsDelegate, ControlButtonDelegate>

@end
