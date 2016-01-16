//
//  ShowHideControlsButton.m
//  Tung
//
//  Created by Jamie Perkins on 5/9/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "ShowHideControlsButton.h"
#import "TungPodcastStyleKit.h"

@implementation ShowHideControlsButton

- (void)drawRect:(CGRect)rect {
    
    switch (_type) {
            
        case kShowHideButtonTypeHide:
            [TungPodcastStyleKit drawHideControlsButtonWithFrame:rect];
            break;
            
        case kShowHideButtonTypeShow:
            [TungPodcastStyleKit drawShowControlsButtonWithFrame:rect];
            break;
            
        default:
            [TungPodcastStyleKit drawHideControlsButtonWithFrame:rect];
            break;
    }
    
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    // forward touch events to NowPlayingControlView
    [_viewController touchesMoved:touches withEvent:event];
    
}


@end
