//
//  TextAreaBkgdView.m
//  Tung
//
//  Created by Jamie Perkins on 8/5/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "TextAreaBkgdView.h"
#import "TungPodcastStyleKit.h"

@implementation TextAreaBkgdView


- (void)drawRect:(CGRect)rect {
    [TungPodcastStyleKit drawTextAreaBkgdWithFrame:rect];
    
    self.backgroundColor = [UIColor clearColor];
}

@end
