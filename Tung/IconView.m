//
//  IconView.m
//  Tung
//
//  Created by Jamie Perkins on 9/17/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "IconView.h"
#import "TungPodcastStyleKit.h"

@implementation IconView


- (void)drawRect:(CGRect)rect {
    switch (_type) {
        case kIconTypeNone:
            break;
        case kIconTypeNowPlaying:
            [TungPodcastStyleKit drawNowPlayingIconWithFrame:rect color:_color];
            break;
        case kIconTypeQueue:
            [TungPodcastStyleKit drawQueueIconWithFrame:rect color:_color];
            break;
        case kIconTypeRecommend:
            [TungPodcastStyleKit drawRecommendIconWithFrame:rect color:_color];
            break;
        case kIconTypeSave:
            [TungPodcastStyleKit drawSaveIconWithFrame:rect color:_color];
            break;
        default:
            break;
    }
}


@end
