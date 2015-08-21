//
//  ProfileCell.h
//  Tung
//
//  Created by Jamie Perkins on 8/12/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LargeAvatarContainerView.h"
#import "STTweetLabel.h"

@interface ProfileCell : UITableViewCell

@property (strong, nonatomic) UIScrollView *profileScrollView;
@property (strong, nonatomic) IBOutlet UIPageControl *profilePageControl;
@property (strong, nonatomic) LargeAvatarContainerView *largeAvView;
@property (strong, nonatomic) UIView *scrollSubViewOne;
@property (strong, nonatomic) UIView *scrollSubViewTwo;
@property (strong, nonatomic) UILabel *nameLabel;
@property (strong, nonatomic) UILabel *locationLabel;
@property (strong, nonatomic) UILabel *urlLabel;
@property (strong, nonatomic) UIButton *urlButton;
@property (strong, nonatomic) STTweetLabel *bioLabel;

@end
