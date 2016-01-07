//
//  SignUpButton.m
//  Tung
//
//  Created by Jamie Perkins on 10/23/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import "SignUpButton.h"
#import "TungPodcastStyleKit.h"

@implementation SignUpButton

- (void)drawRect:(CGRect)rect {
    if (rect.size.width > 0) {
        switch (_type) {
                
            case kSignUpTypeTwitter:
                [TungPodcastStyleKit drawSignUpWithTwitterWithFrame:rect down:self.highlighted];
                break;
                
            default:
                [TungPodcastStyleKit drawSignUpWithFacebookWithFrame:rect down:self.highlighted];
                break;
        }
    }
}

-(void) setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self setNeedsDisplay];
}

@end
