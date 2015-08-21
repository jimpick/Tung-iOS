//
//  AvatarContainerView.h
//  Tung
//
//  Created by Jamie Perkins on 7/29/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AvatarContainerView : UIView

@property (nonatomic, strong) UIImage *avatar;
@property (nonatomic, assign) NSNumber *useFilter;
@property (nonatomic, strong) UIColor *borderColor;

@end
