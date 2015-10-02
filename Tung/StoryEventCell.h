//
//  StoryEventCell.h
//  Tung
//
//  Created by Jamie Perkins on 10/1/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IconView.h"

@interface StoryEventCell : UITableViewCell

@property (strong, nonatomic) IBOutlet IconView *iconView;
@property (strong, nonatomic) IBOutlet UILabel *eventLabel;
@property (strong, nonatomic) IBOutlet UIView *clipProgress;

@end
