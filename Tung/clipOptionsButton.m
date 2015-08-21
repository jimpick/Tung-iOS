//
//  clipOptionsButton.m
//  Tung
//
//  Created by Jamie Perkins on 9/22/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "clipOptionsButton.h"
#import "TungStyleKit.h"


@implementation clipOptionsButton

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
}

- (void)drawRect:(CGRect)rect
{
    
    [TungStyleKit drawClipOptionsButtonWithPressed:_isPressed];
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