//
//  IconButton.h
//  Tung
//
//  Created by Jamie Perkins on 10/29/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    kIconButtonTypeSave,
    kIconButtonTypeOptions,
    kIconButtonTypeQueue,
    kIconButtonTypeSignOut,
    kIconButtonTypeProfileSearch,
    kIconButtonTypeSkipBack15,
    kIconButtonTypeSkipAhead15,
    kIconButtonTypeSettings,
    kIconButtonTypeFindFriends
} IconButtonType;

@interface IconButton : UIButton

@property (nonatomic) IconButtonType type;
@property (copy) UIColor *color;

@end


