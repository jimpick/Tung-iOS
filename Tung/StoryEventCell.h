//
//  StoryEventCell.h
//  Tung
//
//  Created by Jamie Perkins on 10/1/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IconView.h"
#import "ClipProgressView.h"

@interface StoryEventCell : UITableViewCell

@property (strong, nonatomic) IBOutlet IconView *iconView;
@property (strong, nonatomic) IBOutlet UILabel *simpleEventLabel;
@property (strong, nonatomic) IBOutlet UIImageView *bkgdImage;
@property (strong, nonatomic) IBOutlet UILabel *eventDetailLabel;
@property (strong, nonatomic) IBOutlet UILabel *commentLabel;
@property (strong, nonatomic) IBOutlet ClipProgressView *clipProgress;

@end
