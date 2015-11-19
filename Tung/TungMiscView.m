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

- (void)drawRect:(CGRect)rect {
    
    switch (_type) {
            
        case kMiscViewTypeTextAreaBkgd:
            [TungPodcastStyleKit drawTextAreaBkgdWithFrame:rect];
            break;
        case kMiscViewTypePopup:
            [TungPodcastStyleKit drawPopupWithFrame:rect];
            break;
        case kMiscViewTypeCommentBkgdMine:
            [TungPodcastStyleKit drawCommentBkgdUserWithOuterFrame:rect];
            break;
        case kMiscViewTypeCommentBkgdTheirs:
            [TungPodcastStyleKit drawCommentBkgdWithOuterFrame:rect];
            break;
        default:
            break;
    }
    
    self.backgroundColor = [UIColor clearColor];
}

@end
