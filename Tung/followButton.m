//
//  followButton.m
//  Tung
//
//  Created by Jamie Perkins on 10/28/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "followButton.h"
#import "TungStyleKit.h"

@implementation followButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

-(void) awakeFromNib {
    [super awakeFromNib];
    _buttonText = @"Edit Profile";
}

- (void)drawRect:(CGRect)rect
{
    [TungStyleKit drawFollowButtonWithFrame:rect pressed:_isPressed buttonText:_buttonText on:_isOn];
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    _isPressed = YES;
    [self setNeedsDisplay];
}

- (void) setHighlighted:(BOOL)highlighted {
    
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self sendActionsForControlEvents:UIControlEventTouchUpInside];
    _isPressed = NO;
    [self setNeedsDisplay];
}

@end
