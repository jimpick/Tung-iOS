//
//  BlurView.m
//  Tung
//
//  Created by Jamie Perkins on 7/13/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "BlurView.h"

@implementation BlurView


- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    // If we don't clip to bounds the toolbar draws a thin shadow on top
    [self setClipsToBounds:YES];
    
    if (![self toolbar]) {
        [self setToolbar:[[UIToolbar alloc] initWithFrame:[self bounds]]];
        [self.toolbar setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self insertSubview:[self toolbar] atIndex:0];
        
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_toolbar]|"
                                                                     options:0
                                                                     metrics:0
                                                                       views:NSDictionaryOfVariableBindings(_toolbar)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_toolbar]|"
                                                                     options:0
                                                                     metrics:0
                                                                       views:NSDictionaryOfVariableBindings(_toolbar)]];
    }
}
@end
