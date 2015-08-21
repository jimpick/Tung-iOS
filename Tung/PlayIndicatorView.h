//
//  PlayIndicatorView.h
//  Tung
//
//  Created by Jamie Perkins on 9/22/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PlayIndicatorView : UIView

@property (nonatomic) NSNumber *state;

-(void) setState:(NSNumber *)state;

@end
