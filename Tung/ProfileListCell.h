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
#import "PillButton.h"
#import "TungCommonObjects.h"

@interface ProfileListCell : UITableViewCell

@property (nonatomic, retain) TungCommonObjects *tung;

@property (strong, nonatomic) IBOutlet AvatarContainerView *avatarContainerView;
@property (strong, nonatomic) IBOutlet UIButton *avatarButton;
@property (strong, nonatomic) IBOutlet UILabel *usernameLabel;
@property (strong, nonatomic) IBOutlet UILabel *subLabel;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *subLabelLeadingConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *followBtnTrailingConstraint;
@property (strong, nonatomic) IBOutlet IconView *iconView;
@property (strong, nonatomic) IBOutlet IconView *smallIconView;
@property (strong, nonatomic) IBOutlet PillButton *followBtn;
@property (strong, nonatomic) IBOutlet UILabel *youLabel;

@property (strong, nonatomic) NSDictionary *profileDict;
@property (strong, nonatomic) NSString *userId;
@property (strong, nonatomic) NSString *username;
@property (strong, nonatomic) NSMutableArray *usersToFollow;

- (IBAction)followOrUnfollowUser:(id)sender;

@end
