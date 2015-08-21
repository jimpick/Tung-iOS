//
//  IconButton.h
//  Tung
//
//  Created by Jamie Perkins on 10/29/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    kIconTypePlayCount,
    kIconTypeLike,
    kIconTypeLikeSmall,
    kIconTypeEcho,
    kIconTypeEchoSmall,
    kIconTypeOptions,
    kIconTypeAddSmall
} IconButtonType;

@interface IconButton : UIButton

@property BOOL isOn;
@property BOOL isDisabled;
@property (nonatomic) IconButtonType type;

@end


