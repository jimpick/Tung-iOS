//
//  avatarAndLineLarge.m
//  Tung
//
//  Created by Jamie Perkins on 8/27/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "AvatarWithLineIntersect.h"

@implementation AvatarWithLineIntersect
{
	CGImageRef avImage;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // flip context so image appears right side up
    CGFloat height = self.bounds.size.height;
    // NSLog(@"drew AvatarWithLineIntersect view with height: %f", height);
    NSString *largeString;
    if (_large) {
        largeString = @"YES";
    } else {
        largeString = @"NO";
    }
    // NSLog(@"AvatarWithLineIntersect large? %@", largeString);
	CGContextTranslateCTM(context, 0.0, height);
	CGContextScaleCTM(context, 1.0, -1.0);
    // set line width and color
    CGContextSetLineWidth(context, 1.0);
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:87.0/255 green:90.0/255 blue:215.0/255 alpha:1].CGColor);
    
    // clipping arc
    if (_large) {
    	CGContextAddArc(context, 160.0, 64.0, 63.0, 240*M_PI/180, 300*M_PI/180, 1);
    } else {
        CGContextAddArc(context, 160.0, 48.0, 44.0, 240*M_PI/180, 300*M_PI/180, 1);
    }
	// Clip to the current path using the non-zero winding number rule.
	CGContextSaveGState(context);
	CGContextClip(context);
	// add image
    avImage = CGImageRetain(_avatar.CGImage);
    if (_large) {
    	CGContextDrawImage(context, CGRectMake(97.0, 1.0, 126.0, 126.0), avImage);
    } else {
        CGContextDrawImage(context, CGRectMake(116.0, 5.0, 88.0, 88.0), avImage);
    }
    // return to non-clipped drawing
	CGContextRestoreGState(context);
    // arc and line stroked
    if (_large) {
        CGContextAddArc(context, 160.0, 64.0, 63.0, 240*M_PI/180, 300*M_PI/180, 1);
        CGContextMoveToPoint(context, 15, 10);
        CGContextAddLineToPoint(context, 305, 10);
    } else {
        CGContextAddArc(context, 160.0, 48.0, 44.0, 240*M_PI/180, 300*M_PI/180, 1);
        CGContextMoveToPoint(context, 15, 10);
        CGContextAddLineToPoint(context, 305, 10);
    }
    // stroke
    CGContextStrokePath(context);
    
}


@end
