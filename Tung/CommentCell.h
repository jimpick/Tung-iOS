//
//  CommentCell.h
//  Tung
//
//  Created by Jamie Perkins on 10/16/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CommentBkgdView.h"

@interface CommentCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UILabel *usernameLabel;
@property (strong, nonatomic) UILabel *commentLabel;
@property (strong, nonatomic) CommentBkgdView *commentBkgd;

@end
