//
//  PlayIndicatorView.m
//  Tung
//
//  Created by Jamie Perkins on 9/22/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "PlayIndicatorView.h"
#import "TungStyleKit.h"



@implementation PlayIndicatorView

-(void) awakeFromNib {
    [super awakeFromNib];
    _state = [NSNumber numberWithInt:0]; // not yet played
}

- (void)drawRect:(CGRect)rect
{
    if (_state.intValue == 1) { // playing
        [TungStyleKit drawIconPlayingWithFrame:rect];
    }
    if (_state.intValue == 2) { // played
        [TungStyleKit drawIconPlayedWithFrame:rect];
    }
}
-(void) setState:(NSNumber *)state {
    _state = state;
    [self setNeedsDisplay];
}

@end
