//
//  AvatarContainerView.m
//  Tung
//
//  Created by Jamie Perkins on 7/29/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "AvatarContainerView.h"

@implementation AvatarContainerView
{
	CGImageRef avImage;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // initialization
        _borderColor = [UIColor whiteColor];
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    // make size fit rect
    CGRect avatarRect = CGRectMake(1, 1, rect.size.width - 2, rect.size.height - 2);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CIContext *ciContext = [CIContext contextWithOptions:nil];
    //CGContextClearRect(context, rect);
    // set line width and color
    CGContextSetLineWidth(context, 1.0);
    CGContextSetStrokeColorWithColor(context, _borderColor.CGColor);
    // flip context so image appears right side up
    CGFloat height = self.bounds.size.height;
    CGContextTranslateCTM(context, 0.0, height);
    CGContextScaleCTM(context, 1.0, -1.0);
    // clipping circle
    CGContextAddEllipseInRect(context, avatarRect);
    // Clip to the current path using the non-zero winding number rule.
    CGContextSaveGState(context);
    CGContextClip(context);
    // add image
    avImage = CGImageRetain(self.avatar.CGImage);
    
    if (_useFilter > 0) {
        CIImage *image = [CIImage imageWithCGImage:avImage];
        // desaturate
        CIFilter *desaturateFilter = [CIFilter filterWithName:@"CIColorControls"];
        [desaturateFilter setDefaults];
        [desaturateFilter setValue:image forKey:kCIInputImageKey];
        [desaturateFilter setValue:[NSNumber numberWithInt:0] forKey:kCIInputSaturationKey];
        CIImage *blackAndWhite = [desaturateFilter valueForKey:kCIOutputImageKey];
        
        // colorize with false color
        CIFilter *colorizeFilter = [CIFilter filterWithName:@"CIFalseColor"];
        [colorizeFilter setValue:blackAndWhite forKey:kCIInputImageKey];
        CIColor *tungPurple = [CIColor colorWithRed:87.0/255 green:90.0/255 blue:215.0/255];
        CIColor *white = [CIColor colorWithRed:1 green:1 blue:1];
        [colorizeFilter setValue:tungPurple forKey:@"inputColor0"];
        [colorizeFilter setValue:white forKey:@"inputColor1"];
        CIImage *result = [colorizeFilter valueForKey:kCIOutputImageKey];
        
        CGRect extent = [result extent];
        CGImageRef cgImage = [ciContext createCGImage:result fromRect:extent];
        CGContextDrawImage(context, avatarRect, cgImage);
        
    }
    else {
    	CGContextDrawImage(context, avatarRect, avImage);
    }
    // return to non-clipped drawing
    CGContextRestoreGState(context);
    // outline circle
    CGContextAddEllipseInRect(context, avatarRect);
    // stroke
    CGContextStrokePath(context);
}

- (BOOL) pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return NO;
}

@end
