//
//  FeedCell.h
//  Tung
//
//  Created by Jamie Perkins on 6/10/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AvatarContainerView.h"

@interface FeedCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UIImageView *albumArt;
@property (strong, nonatomic) IBOutlet UILabel *postedDateLabel;
@property (strong, nonatomic) IBOutlet UIButton *usernameButton;
@property (strong, nonatomic) IBOutlet UIButton *avatarButton;
@property (strong, nonatomic) IBOutlet AvatarContainerView *avatarContainerView;

@end
