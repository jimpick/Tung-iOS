//
//  PillButton.h
//  Tung
//
//  Created by Jamie Perkins on 5/7/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    kPillTypeOnWhite,
    kPillTypeFollow
} PillButtonType;

@interface PillButton : UIButton

@property PillButtonType type;
@property (copy) NSString *buttonText; // pill text button
@property BOOL on; // twitter/facebook

@end
