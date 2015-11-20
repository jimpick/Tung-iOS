//
//  TungMiscView.m
//  Tung
//
//  Created by Jamie Perkins on 11/18/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import "TungMiscView.h"
#import "TungPodcastStyleKit.h"

@implementation TungMiscView

-(id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

-(id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    
    switch (_type) {
            
        case kMiscViewTypePopupWithArrowLeft:
            [TungPodcastStyleKit drawPopupWithArrowLeftWithFrame:rect];
            break;
        case kMiscViewTypePopupWithArrowRight:
            [TungPodcastStyleKit drawPopupWithArrowRightWithFrame:rect];
            break;
        case kMiscViewTypeCommentBkgdMine:
            [TungPodcastStyleKit drawCommentBkgdUserWithOuterFrame:rect];
            break;
        case kMiscViewTypeCommentBkgdTheirs:
            [TungPodcastStyleKit drawCommentBkgdWithOuterFrame:rect];
            break;
        case kMiscViewTypeSolidCircle:
            [TungPodcastStyleKit drawSolidCircleWithFrame:rect];
            break;
        default:
            break;
    }
}

@end
