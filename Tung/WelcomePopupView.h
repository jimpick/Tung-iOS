//
//  WelcomePopupView.h
//  Tung
//
//  Created by Jamie Perkins on 11/19/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TungMiscView.h"
#import "IconView.h"

@interface WelcomePopupView : UIView <UIScrollViewDelegate>

@property (strong, nonatomic) IBOutlet UIView *view;
@property (strong, nonatomic) IBOutlet TungMiscView *solidCircle;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;

@property (strong, nonatomic) IBOutlet UIView *subView0;
@property (strong, nonatomic) IBOutlet UILabel *header0;
@property (strong, nonatomic) IBOutlet UILabel *body0;
@property (strong, nonatomic) IBOutlet UIButton *button0;

@property (strong, nonatomic) IBOutlet UIView *subView1;
@property (strong, nonatomic) IBOutlet IconView *iconView1;
@property (strong, nonatomic) IBOutlet UILabel *header1;
@property (strong, nonatomic) IBOutlet UILabel *body1;
@property (strong, nonatomic) IBOutlet UIButton *button1;

@property (strong, nonatomic) IBOutlet UIView *subView2;
@property (strong, nonatomic) IBOutlet IconView *iconView2;
@property (strong, nonatomic) IBOutlet UILabel *header2;
@property (strong, nonatomic) IBOutlet UILabel *body2;
@property (strong, nonatomic) IBOutlet UIButton *button2;

@property (strong, nonatomic) IBOutlet UIView *subView3;
@property (strong, nonatomic) IBOutlet IconView *iconView3;
@property (strong, nonatomic) IBOutlet UILabel *header3;
@property (strong, nonatomic) IBOutlet UILabel *body3;
@property (strong, nonatomic) IBOutlet UIButton *button3;

@property (strong, nonatomic) IBOutlet UIView *subView4;
@property (strong, nonatomic) IBOutlet IconView *iconView4;
@property (strong, nonatomic) IBOutlet UILabel *header4;
@property (strong, nonatomic) IBOutlet UILabel *body4;
@property (strong, nonatomic) IBOutlet UIButton *button4;

@property (strong, nonatomic) IBOutlet UIView *iconScrollViewContainer;
@property (strong, nonatomic) IBOutlet UIScrollView *iconScrollView;
@property (strong, nonatomic) IBOutlet UIView *iconSubView1;
@property (strong, nonatomic) IBOutlet UIView *iconSubView2;
@property (strong, nonatomic) IBOutlet UIView *iconSubView3;
@property (strong, nonatomic) IBOutlet UIView *iconSubView4;
@property (strong, nonatomic) IBOutlet UIView *iconSubView0;

@property (strong, nonatomic) IBOutlet IconView *reverseIconView1;
@property (strong, nonatomic) IBOutlet IconView *reverseIconView2;
@property (strong, nonatomic) IBOutlet IconView *reverseIconView3;
@property (strong, nonatomic) IBOutlet IconView *reverseIconView4;


- (void) setContentSize;

@end
