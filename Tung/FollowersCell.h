//
//  FollowersCell.h
//  Tung
//
//  Created by Jamie Perkins on 10/27/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "followButton.h"

@interface FollowersCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UIButton *followingCountBtn;
@property (strong, nonatomic) IBOutlet UIButton *followerCountBtn;

@property (strong, nonatomic) IBOutlet followButton *followBtn;

@end
