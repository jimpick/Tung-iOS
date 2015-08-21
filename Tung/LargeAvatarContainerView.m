//
//  LargeAvatarContainerView.m
//  Tung
//
//  Created by Jamie Perkins on 7/29/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "LargeAvatarContainerView.h"

@implementation LargeAvatarContainerView
{
	CGImageRef avImage;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // initialization
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    // set line width and color
    CGContextSetLineWidth(context, 1.0);
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    // flip context so image appears right side up
    CGFloat height = self.bounds.size.height;
    CGContextTranslateCTM(context, 0.0, height);
    CGContextScaleCTM(context, 1.0, -1.0);
    // clipping circle
    CGContextAddEllipseInRect(context, CGRectMake(1.0, 1.0, 128.0, 128.0));
    // Clip to the current path using the non-zero winding number rule.
    CGContextSaveGState(context);
    CGContextClip(context);
    // add image
    avImage = CGImageRetain(self.avatar.CGImage);
    CGContextDrawImage(context, CGRectMake(1.0, 1.0, 128.0, 128.0), avImage);
    // return to non-clipped drawing
    CGContextRestoreGState(context);
    // outline circle
    CGContextAddEllipseInRect(context, CGRectMake(1.0, 1.0, 128.0, 128.0));
    // stroke
    CGContextStrokePath(context);
}

@end
