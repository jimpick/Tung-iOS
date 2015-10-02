//
//  IconButton.m
//  Tung
//
//  Created by Jamie Perkins on 10/29/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "IconButton.h"
#import "TungPodcastStyleKit.h"

@implementation IconButton


- (void)drawRect:(CGRect)rect
{
    switch (_type) {
        case kIconButtonTypeOptions:
            [TungPodcastStyleKit drawOptionsIconWithFrame:rect color:_color];
            break;
        case kIconButtonTypeQueue:
            [TungPodcastStyleKit drawQueueIconWithFrame:rect color:_color];
            break;
        case kIconButtonTypeSave:
            [TungPodcastStyleKit drawSaveIconWithFrame:rect color:_color];
            break;
            
        default:
            [TungPodcastStyleKit drawOptionsIconWithFrame:rect color:_color];
            break;
    }
}


@end
