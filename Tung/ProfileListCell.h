//
//  ProfileListCell.h
//  Tung
//
//  Created by Jamie Perkins on 11/5/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AvatarContainerView.h"
#import "IconView.h"

@interface ProfileListCell : UITableViewCell

@property (strong, nonatomic) IBOutlet AvatarContainerView *avatarContainerView;
@property (strong, nonatomic) IBOutlet UIButton *avatarButton;
@property (strong, nonatomic) IBOutlet UIButton *usernameButton;
@property (strong, nonatomic) IBOutlet UILabel *subLabel;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *subLabelLeadingConstraint;
@property (strong, nonatomic) IBOutlet IconView *iconView;

@end
