//
//  CommentCell.m
//  Tung
//
//  Created by Jamie Perkins on 10/16/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import "CommentCell.h"

@implementation CommentCell

- (void)awakeFromNib {
    // Initialization code
    [super awakeFromNib];
    
    _usernameBtn.titleLabel.adjustsFontSizeToFitWidth = YES;
    _usernameBtn.titleLabel.minimumScaleFactor = 0.6f;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
