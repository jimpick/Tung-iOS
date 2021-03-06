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


- (void)drawRect:(CGRect)rect {
	if (rect.size.width > 0) {
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
            case kIconButtonTypeSignOut:
                [TungPodcastStyleKit drawExitIconWithFrame:rect color:_color];
                break;
            case kIconButtonTypeProfileSearch:
                [TungPodcastStyleKit drawProfileSearchIconWithFrame:rect color:_color];
                break;
            case kIconButtonTypeSkipBack15:
                [TungPodcastStyleKit drawSkipBack15IconWithFrame:rect color:_color];
                break;
            case kIconButtonTypeSkipAhead15:
                [TungPodcastStyleKit drawSkipAhead15IconWithFrame:rect color:_color];
                break;
            case kIconButtonTypeSettings:
                [TungPodcastStyleKit drawSettingsIconWithFrame:rect color:_color];
                break;
            case kIconButtonTypeFindFriends:
                [TungPodcastStyleKit drawFindFriendsIconWithFrame:rect color:_color];
                break;
            case kIconButtonTypeTungLogoType:
                [TungPodcastStyleKit drawTungLogotypeWithFrame:rect color:_color];
                break;
            case kIconButtonTypeCheckmark:
                [TungPodcastStyleKit drawCheckmarkIconWithFrame:rect color:_color];
                break;
            default:
                break;
        }
    }
}


@end
