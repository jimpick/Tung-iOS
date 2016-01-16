//
//  ShowHideControlsButton.h
//  Tung
//
//  Created by Jamie Perkins on 5/9/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    kShowHideButtonTypeShow,
    kShowHideButtonTypeHide
} ShowHideButtonType;

@interface ShowHideControlsButton : UIButton

@property ShowHideButtonType type;
@property UIViewController *viewController;

@end
