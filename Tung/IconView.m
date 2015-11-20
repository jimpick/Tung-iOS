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

-(id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _color = [TungPodcastStyleKit tungColor];
    }
    return self;
}

-(id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _color = [TungPodcastStyleKit tungColor];
    }
    return self;
}

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
        case kIconTypeSubscribe:
            [TungPodcastStyleKit drawSubscribeIconSolidWithFrame:rect color:_color];
            break;
        case kIconTypeComment:
            [TungPodcastStyleKit drawCommentIconWithFrame:rect color:_color];
            break;
        case kIconTypeClip:
            [TungPodcastStyleKit drawClipIconWithFrame:rect color:_color];
            break;
        case kIconTypeAdd:
            [TungPodcastStyleKit drawAddCircleIconWithFrame:rect color:_color];
            break;
        case kIconTypeFeed:
            [TungPodcastStyleKit drawFeedIconWithFrame:rect color:_color];
            break;
        case kIconTypeProfile:
            [TungPodcastStyleKit drawProfileIconWithFrame:rect color:_color];
            break;
        default:
            break;
    }
}


@end
