//
//  SuggestedUserCell.h
//  Tung
//
//  Created by Jamie Perkins on 5/7/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AvatarContainerView.h"
#import "IconView.h"
#import "PillButton.h"

@interface SuggestedUserCell : UITableViewCell

@property (strong, nonatomic) IBOutlet AvatarContainerView *avatarContainerView;
@property (strong, nonatomic) IBOutlet UILabel *usernameLabel;
@property (strong, nonatomic) IBOutlet UILabel *subLabel;
@property (strong, nonatomic) IBOutlet PillButton *followBtn;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet IconView *iconView;
@property (strong, nonatomic) IBOutlet UILabel *mostReccdLabel;
@property (strong, nonatomic) IBOutlet UILabel *youLabel;

@property (strong, nonatomic) NSString *userId;
@property (strong, nonatomic) NSString *username;

- (IBAction)followOrUnfollowUser:(id)sender;

@end


/*
 @property (strong, nonatomic) IBOutlet AvatarContainerView *avatarContainerView;
 @property (strong, nonatomic) IBOutlet UIButton *avatarButton;
 @property (strong, nonatomic) IBOutlet UILabel *usernameLabel;
 @property (strong, nonatomic) IBOutlet UILabel *subLabel;
 @property (strong, nonatomic) IBOutlet NSLayoutConstraint *subLabelLeadingConstraint;
 @property (strong, nonatomic) IBOutlet IconView *iconView;
 @property (strong, nonatomic) IBOutlet PillButton *followBtn;
 @property (strong, nonatomic) NSDictionary *profileDict;
*/