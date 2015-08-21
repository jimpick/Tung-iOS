//
//  clipIcons.m
//  Tung
//
//  Created by Jamie Perkins on 10/20/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "clipIcons.h"
#import "TungStyleKit.h"

@interface clipIcons ()

@property NSString *type;

@end


@implementation clipIcons

- (void)drawRect:(CGRect)rect
{
    NSArray *types = @[@"playCount", @"like", @"echo"];
    NSUInteger intType = [types indexOfObject:_type];
    
    switch (intType) {
        case 0:
            [TungStyleKit drawIconOptionsWithFrame:rect];
            break;
    }
}

@end
