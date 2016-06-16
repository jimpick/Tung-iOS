//
//  StoryCountCell.h
//  Tung
//
//  Created by Jamie Perkins on 6/14/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IconView.h"

@interface StoryCountCell : UITableViewCell

@property (strong, nonatomic) IBOutlet IconView *recommendIcon;
@property (strong, nonatomic) IBOutlet UILabel *recommendCountLabel;
@property (strong, nonatomic) IBOutlet IconView *clipIcon;
@property (strong, nonatomic) IBOutlet UILabel *clipCountLabel;
@property (strong, nonatomic) IBOutlet IconView *commentIcon;
@property (strong, nonatomic) IBOutlet UILabel *commentCountLabel;
@property (strong, nonatomic) IBOutlet IconView *playCountIcon;
@property (strong, nonatomic) IBOutlet UILabel *playCountLabel;

@end
