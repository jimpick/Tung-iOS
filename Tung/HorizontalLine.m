//
//  horizontalLine.m
//  Tung
//
//  Created by Jamie Perkins on 8/27/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "HorizontalLine.h"

@implementation HorizontalLine

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
    // set line width and color
    CGContextSetLineWidth(context, 1.0);
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:1 green:1 blue:1 alpha:.5].CGColor);
    // line
    CGContextMoveToPoint(context, 12, 1);
    CGContextAddLineToPoint(context, rect.size.width - 12, 1);
    // stroke
    CGContextStrokePath(context);
    
}

@end
