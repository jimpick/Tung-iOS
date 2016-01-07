//
//  BannerAlert.m
//  Tung
//
//  Created by Jamie Perkins on 1/6/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//

#import "BannerAlert.h"
#import "TungCommonObjects.h"

@implementation BannerAlert

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (void) sizeBannerAndSetText:(NSString *)text forWidth:(CGFloat)width {
    
    [self.layer setCornerRadius:18.0];
    self.backgroundColor = [UIColor whiteColor];
    
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:15];
    label.numberOfLines = 0;
    label.text = text;
    label.textColor = [TungCommonObjects tungColor];
    label.textAlignment = NSTextAlignmentCenter;
    
    CGSize labelSize = [label sizeThatFits:CGSizeMake(width - 50, 100)];
    label.frame = CGRectMake(10, 15, width - 50, labelSize.height);
    
    self.frame = CGRectMake(0, 0, width - 30, labelSize.height + 30);
    
    [self addSubview:label];
    
}

@end
