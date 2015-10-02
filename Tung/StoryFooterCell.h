//
//  StoryFooterCell.h
//  Tung
//
//  Created by Jamie Perkins on 10/2/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IconButton.h"

@interface StoryFooterCell : UITableViewCell

@property (strong, nonatomic) IBOutlet IconButton *optionsButton;
@property (strong, nonatomic) IBOutlet UILabel *viewAllLabel;

@end
