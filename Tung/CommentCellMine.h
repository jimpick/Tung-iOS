//
//  CommentCell.h
//  Tung
//
//  Created by Jamie Perkins on 10/16/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TungMiscView.h"

@interface CommentCellMine : UITableViewCell
@property (strong, nonatomic) IBOutlet UILabel *timestampLabel;
@property (strong, nonatomic) IBOutlet UILabel *commentLabel;
@property (strong, nonatomic) IBOutlet TungMiscView *commentBkgd;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *commentBkgdWidthConstraint;

@end
