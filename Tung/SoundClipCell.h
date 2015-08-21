//
//  SoundClipCell.h
//  Tung
//
//  Created by Jamie Perkins on 7/26/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AvatarContainerView.h"
#import "PlayIndicatorView.h"
#import "STTweetLabel.h"
#import "IconButton.h"

@interface SoundClipCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property (strong, nonatomic) IBOutlet UIButton *usernameButton;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *usernameTopConstraint;
@property (strong, nonatomic) IBOutlet UIButton *avatarButton;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (strong, nonatomic) STTweetLabel *captionLabel;
@property (strong, nonatomic) UIImageView *captionBkgd;
@property (strong, nonatomic) IBOutlet IconButton *optionsButton;
@property (strong, nonatomic) IBOutlet IconButton *echoButton;
@property (strong, nonatomic) IBOutlet IconButton *likeButton;
@property (strong, nonatomic) IBOutlet IconButton *playCountIcon;
@property (strong, nonatomic) IBOutlet UILabel *playCountLabel;
@property (strong, nonatomic) IBOutlet UIButton *likeCountButton;
@property (strong, nonatomic) IBOutlet UIButton *echoCountButton;
@property (strong, nonatomic) IBOutlet IconButton *echoedByIcon;
@property (strong, nonatomic) IBOutlet UIButton *echoedByButton;
@property (weak, nonatomic) IBOutlet AvatarContainerView *avatarContainerView;
@property (weak, nonatomic) IBOutlet PlayIndicatorView *playIndicator;
@property (strong, nonatomic) IBOutlet UIToolbar *colorBar;

@end
