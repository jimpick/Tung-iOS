//
//  IconView.h
//  Tung
//
//  Created by Jamie Perkins on 9/17/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    kIconTypeNone,
    kIconTypeNowPlaying,
    kIconTypeSave,
    kIconTypeQueue,
    kIconTypeRecommend,
    kIconTypeSubscribe,
    kIconTypeComment,
    kIconTypeClip,
    kIconTypeAdd,
    kIconTypeFeed,
    kIconTypeProfile
} IconType;

@interface IconView : UIView

@property (nonatomic) IconType type;
@property (copy) UIColor *color; 

@end
