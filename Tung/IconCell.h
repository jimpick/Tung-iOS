//
//  IconCell.h
//  Tung
//
//  Created by Jamie Perkins on 5/25/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IconView.h"

@interface IconCell : UITableViewCell

@property (strong, nonatomic) IBOutlet IconView *iconView;
@property (strong, nonatomic) IBOutlet UILabel *titleLabel;

@end
