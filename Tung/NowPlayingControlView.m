//
//  NowPlayingControlView.m
//  Tung
//
//  Created by Jamie Perkins on 5/28/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "NowPlayingControlView.h"

@implementation NowPlayingControlView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    // forward touch event to view controller
    [[self.nextResponder nextResponder] touchesMoved:touches withEvent:event];
    
}

@end
