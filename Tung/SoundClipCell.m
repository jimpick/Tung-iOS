//
//  SoundClipCell.m
//  Tung
//
//  Created by Jamie Perkins on 7/26/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "SoundClipCell.h"

@implementation SoundClipCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)awakeFromNib
{
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    // Configure the view for the selected state
}

@end
