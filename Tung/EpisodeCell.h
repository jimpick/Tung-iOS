//
//  EpisodeCell.h
//  Tung
//
//  Created by Jamie Perkins on 4/2/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IconView.h"
#import "TungMiscView.h"
#import "CircleButton.h"

@interface EpisodeCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UILabel *episodeTitle;
@property (strong, nonatomic) IBOutlet UILabel *airDate;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *leadingTitleConstraint;
@property (strong, nonatomic) IBOutlet IconView *iconView;
@property (strong, nonatomic) IBOutlet TungMiscView *episodeProgress;
@property (strong, nonatomic) IBOutlet CircleButton *saveWithProgressBtn;

@end
