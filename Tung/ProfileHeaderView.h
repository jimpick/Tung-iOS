//
//  ProfileHeaderView.h
//  Tung
//
//  Created by Jamie Perkins on 10/4/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AvatarContainerView.h"
#import "PillButton.h"

@interface ProfileHeaderView : UIView
@property (strong, nonatomic) IBOutlet UIView *view;
@property (strong, nonatomic) IBOutlet UIButton *followingCountBtn;
@property (strong, nonatomic) IBOutlet UIButton *followerCountBtn;
@property (strong, nonatomic) IBOutlet PillButton *editFollowBtn;

@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet UIPageControl *pageControl;
@property (strong, nonatomic) IBOutlet AvatarContainerView *largeAvatarView;
@property (strong, nonatomic) IBOutlet UIWebView *basicInfoWebView;
@property (strong, nonatomic) IBOutlet UIView *scrollSubViewOne;
@property (strong, nonatomic) IBOutlet UIView *scrollSubViewTwo;
@property (strong, nonatomic) IBOutlet UIWebView *bioWebView;

@property (strong, nonatomic) IBOutlet NSLayoutConstraint *scrollSubView1Height;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *scrollSubView2Height;

@property BOOL contentSizeSet;

@end
