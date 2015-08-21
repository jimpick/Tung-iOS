//
//  postButton.m
//  Tung
//
//  Created by Jamie Perkins on 9/2/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "postButton.h"
#import "TungStyleKit.h"

@interface postButton ()

@property BOOL isPressed;

@end

@implementation postButton

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
    _buttonText = @"Post";
}

- (void)drawRect:(CGRect)rect
{
    [TungStyleKit drawPostButtonWithFrame:rect pressed:_isPressed postButtonText:_buttonText];
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    _isPressed = YES;
    [self setNeedsDisplay];
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self sendActionsForControlEvents:UIControlEventTouchUpInside];
    _isPressed = NO;
    [self setNeedsDisplay];
}


@end
