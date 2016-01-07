//
//  ClipProgressView.m
//  Tung
//
//  Created by Jamie Perkins on 10/6/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import "ClipProgressView.h"
#import "TungPodcastStyleKit.h"

@implementation ClipProgressView


- (void)drawRect:(CGRect)rect {
    if (rect.size.width > 0) {
    	[TungPodcastStyleKit drawClipProgressWithFrame:rect buttonText:_seconds arc:_arc];
    }
}

@end
