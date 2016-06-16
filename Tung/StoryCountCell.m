//
//  StoryCountCell.m
//  Tung
//
//  Created by Jamie Perkins on 6/14/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//

#import "StoryCountCell.h"

@implementation StoryCountCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    _recommendIcon.type = kIconTypeRecommend;
    _recommendIcon.color = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
    _clipIcon.type = kIconTypeClip;
    _clipIcon.color = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
    _commentIcon.type = kIconTypeComment;
    _commentIcon.color = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
    _playCountIcon.type = kIconTypePlayCount;
    _playCountIcon.color = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
