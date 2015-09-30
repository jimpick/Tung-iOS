//
//  CircleButton.m
//  Tung
//
//  Created by Jamie Perkins on 5/7/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "CircleButton.h"
#import "TungPodcastStyleKit.h"

@implementation CircleButton

- (void)drawRect:(CGRect)rect {
    
    switch (_type) {
            
        case kCircleTypeSubscribe:
            if (rect.size.width > 0) {
                [TungPodcastStyleKit drawSubscribeButtonWithFrame:rect color:_color on:_subscribed down:self.highlighted];
            }
            //else {
            //    NSLog(@"bad rect");
            //}
            break;
            
        case kCircleTypeNewClip:
            [TungPodcastStyleKit drawClipButtonWithFrame:rect color:_color down:self.highlighted];
            break;
            
        case kCircleTypeRecommend:
            [TungPodcastStyleKit drawRecommendButtonWithFrame:rect on:_recommended down:self.highlighted];
            break;
            
        case kCircleTypeShare:
            [TungPodcastStyleKit drawShareButtonWithFrame:rect down:self.highlighted];
            break;
            
        case kCircleTypeWebsite:
            [TungPodcastStyleKit drawWebsiteButtonWithFrame:rect down:self.highlighted disabled:!self.enabled];
            break;
            
        case kCircleTypeRecord:
            [TungPodcastStyleKit drawClipRecordButtonWithFrame:rect on:_isRecording down:self.highlighted disabled:!self.enabled];
            break;
            
        case kCircleTypePlayClip:
            [TungPodcastStyleKit drawClipPlayButtonWithFrame:rect on:_isPlaying down:self.highlighted disabled:!self.enabled];
            break;
            
        case kCircleTypeCancel:
            [TungPodcastStyleKit drawClipCancelButtonWithFrame:rect down:self.highlighted disabled:!self.enabled];
            break;
            
        case kCircleTypeOkay:
            [TungPodcastStyleKit drawClipOkButtonWithFrame:rect down:self.highlighted disabled:!self.enabled];
            break;
            
        case kCircleTypeComment:
            [TungPodcastStyleKit drawCommentButtonWithFrame:rect on:_on down:self.highlighted disabled:!self.enabled];
            break;
            
        case kCircleTypeTwitter:
            [TungPodcastStyleKit drawTwitterButtonWithFrame:rect on:_on down:self.highlighted];
            break;
            
        case kCircleTypeFacebook:
            [TungPodcastStyleKit drawFacebookButtonWithFrame:rect on:_on down:self.highlighted];
            break;
            
        case kCircleTypeTextButton:
            [TungPodcastStyleKit drawPillTextbuttonWithFrame:rect down:self.highlighted disabled:!self.enabled buttonText:_buttonText];
            break;
            
        case kCircleTypeSpeed:
            [TungPodcastStyleKit drawSpeedButtonWithFrame:rect down:self.highlighted buttonText:_buttonText];
            break;
            
        case kCircleTypeSave:
            [TungPodcastStyleKit drawSaveButtonWithFrame:rect on:_on down:self.highlighted];
            break;
            
        default:
            [TungPodcastStyleKit drawClipButtonWithFrame:rect color:_color down:self.highlighted];
            break;
    }
}

-(void) setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self setNeedsDisplay];
}


@end
