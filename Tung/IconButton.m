//
//  IconButton.m
//  Tung
//
//  Created by Jamie Perkins on 10/29/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "IconButton.h"
#import "TungStyleKit.h"

@implementation IconButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        _type = kIconTypePlayCount;
    }
    return self;
}

-(void) awakeFromNib {
    [super awakeFromNib];
}

- (void)drawRect:(CGRect)rect
{
    switch (_type) {
        case kIconTypePlayCount: {
            [TungStyleKit drawIconPlayCountWithFrame:rect];
            break;
        }
        case kIconTypeLike: {
            [TungStyleKit drawIconLikeWithFrame:rect on:_isOn];
            break;
        }
        case kIconTypeLikeSmall: {
            [TungStyleKit drawIconLikeSmallWithFrame:rect];
            break;
        }
        case kIconTypeEcho: {
            [TungStyleKit drawIconEchoWithFrame:rect on:_isOn disabled:_isDisabled];
            break;
        }
        case kIconTypeEchoSmall: {
            [TungStyleKit drawIconEchoSmallWithFrame:rect];
            break;
        }
        case kIconTypeOptions: {
            [TungStyleKit drawIconOptionsWithFrame:rect];
            break;
        }
        case kIconTypeAddSmall: {
            [TungStyleKit drawIconAddSmallWithFrame:rect];
            break;
        }
        default: {
            [TungStyleKit drawIconPlayCountWithFrame:rect];
            break;
        }
    }
}


@end
