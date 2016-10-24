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
    
    if (rect.size.width > 0) {
        switch (_type) {
                
            case kCircleTypeSubscribe:
                [TungPodcastStyleKit drawSubscribeButtonWithFrame:rect color:_color on:_subscribed down:self.highlighted];
                break;
                
            case kCircleTypeNewClip:
                [TungPodcastStyleKit drawClipButtonWithFrame:rect down:self.highlighted];
                break;
                
            case kCircleTypeRecommend:
                [TungPodcastStyleKit drawRecommendButtonWithFrame:rect on:_recommended down:self.highlighted];
                break;
                
            case kCircleTypeShare:
                [TungPodcastStyleKit drawShareButtonWithFrame:rect down:self.highlighted];
                break;
                
            case kCircleTypeShareOnDark:
                [TungPodcastStyleKit drawShareButtonOnDarkWithFrame:rect down:self.highlighted];
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
                
            case kCircleTypeTextButton: // used for Post button
                [TungPodcastStyleKit drawPillTextbuttonWithFrame:rect down:self.highlighted disabled:!self.enabled buttonText:_buttonText];
                break;
                
            case kCircleTypeSpeed:
                [TungPodcastStyleKit drawSpeedButtonWithFrame:rect down:self.highlighted buttonText:_buttonText];
                break;
                
            case kCircleTypeSave:
                [TungPodcastStyleKit drawSaveButtonWithFrame:rect on:_on down:self.highlighted];
                break;
                
            case kCircleTypeSaveWithProgress:
                [TungPodcastStyleKit drawSaveWithProgressWithFrame:rect on:_on arc:_arc queued:_queued];
                break;
                
            case kCircleTypePlay:
                [TungPodcastStyleKit drawPlayButtonWithFrame:rect color:_color on:_on down:self.highlighted];
                break;
                
            case kCircleTypeSupport:
                [TungPodcastStyleKit drawSupportButtonWithFrame:rect down:self.highlighted];
                break;
                
            case kCircleTypeMagic:
                [TungPodcastStyleKit drawMagicButtonWithFrame:rect down:self.highlighted buttonText:_buttonText subtitle:_buttonSubtitle];
                break;
                
            default:
                [TungPodcastStyleKit drawClipButtonWithFrame:rect down:self.highlighted];
                break;
        }
    }
}

-(void) setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self setNeedsDisplay];
}


@end
