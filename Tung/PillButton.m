//
//  PillButton.m
//  Tung
//
//  Created by Jamie Perkins on 5/7/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "PillButton.h"
#import "TungPodcastStyleKit.h"

@implementation PillButton

- (void)drawRect:(CGRect)rect {
    
    switch (_type) {
            
        case kPillTypeOnWhite:
            [TungPodcastStyleKit drawTungButtonOnWhiteWithFrame:rect down:self.highlighted buttonText:_buttonText];
            break;
        case kPillTypeOnDark:
            [TungPodcastStyleKit drawPillButtonOnDarkWithFrame:rect down:self.highlighted buttonText:_buttonText];
            break;
        case kPillTypeFollow:
            [TungPodcastStyleKit drawFollowButtonWithFrame:rect on:_on down:self.highlighted];
            break;
            
        default:
            [TungPodcastStyleKit drawTungButtonOnWhiteWithFrame:rect down:self.highlighted buttonText:_buttonText];
            break;
    }
}

-(void) setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self setNeedsDisplay];
}


@end
