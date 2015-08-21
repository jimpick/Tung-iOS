//
//  CommentAndPostView.m
//  Tung
//
//  Created by Jamie Perkins on 8/5/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "CommentAndPostView.h"

@implementation CommentAndPostView

-(id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [[NSBundle mainBundle] loadNibNamed:@"CommentAndPostView" owner:self options:nil];
        self.bounds = self.view.bounds;
        [self addSubview:self.view];
        
        // button setup
        _twitterButton.type = kCircleTypeTwitter;
        _facebookButton.type = kCircleTypeFacebook;
        _cancelButton.type = kCircleTypeCancel;
        _postButton.type = kCircleTypeTextButton;
        _postButton.buttonText = @"Post";
        
    }
    return self;
}

-(id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [[NSBundle mainBundle] loadNibNamed:@"HeaderView" owner:self options:nil];
        [self addSubview:self.view];
        
        // button setup
        _twitterButton.type = kCircleTypeTwitter;
        _facebookButton.type = kCircleTypeFacebook;
        _cancelButton.type = kCircleTypeCancel;
        _postButton.type = kCircleTypeTextButton;
        _postButton.buttonText = @"Post";
    }
    return self;
}

@end
