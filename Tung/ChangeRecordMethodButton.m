//
//  ChangeRecordMethodButton.m
//  Tung
//
//  Created by Jamie Perkins on 1/4/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "ChangeRecordMethodButton.h"
#import "TungStyleKit.h"

@implementation ChangeRecordMethodButton

- (void)drawRect:(CGRect)rect
{
    [TungStyleKit drawChangeRecordMethodWithFrame:rect on:_isOn];
}


@end
