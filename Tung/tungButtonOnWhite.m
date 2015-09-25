//
//  tungButtonOnWhite.m
//  Tung
//
//  Created by Jamie Perkins on 8/28/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "tungButtonOnWhite.h"
#import "TungPodcastStyleKit.h"

@interface tungButtonOnWhite ()

@property BOOL isPressed;

@end

@implementation tungButtonOnWhite

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
    _buttonText = @"Sign-up!";
}

- (void)drawRect:(CGRect)rect
{
    [TungPodcastStyleKit drawTungButtonOnWhiteWithFrame:rect down:self.highlighted buttonText:_buttonText];
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
/*
-(void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    [self setNeedsDisplay];
}

-(void)setHighlighted:(BOOL)value {
    [super setHighlighted:value];
    [self setNeedsDisplay];
}

-(void)setSelected:(BOOL)value {
    [super setSelected:value];
    [self setNeedsDisplay];
}
*/
@end
