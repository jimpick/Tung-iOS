//
//  TungMiscView.h
//  Tung
//
//  Created by Jamie Perkins on 11/18/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    kMiscViewTypePopupWithArrowLeft,
    kMiscViewTypePopupWithArrowRight,
    kMiscViewTypeCommentBkgdMine,
    kMiscViewTypeCommentBkgdTheirs,
    kMiscViewTypeSolidCircle,
    kMiscViewTypeEpisodeProgress,
    kMiscViewTypeSubscribeBadge
} MiscViewType;

@interface TungMiscView : UIView

@property (nonatomic) MiscViewType type;
@property (copy) UIColor *color; // episode progress
@property (nonatomic) CGFloat progress; // episode progress
@property (copy) NSString *text;

@end
