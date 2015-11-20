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
    kMiscViewTypeSolidCircle
} MiscViewType;

@interface TungMiscView : UIView

@property (nonatomic) MiscViewType type;

@end
