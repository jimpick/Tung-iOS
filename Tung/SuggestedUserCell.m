//
//  SuggestedUserCell.m
//  Tung
//
//  Created by Jamie Perkins on 5/7/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//

#import "SuggestedUserCell.h"
#import "TungCommonObjects.h"

@implementation SuggestedUserCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    _followBtn.type = kPillTypeFollow;
    _followBtn.backgroundColor = [UIColor clearColor];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (IBAction)followOrUnfollowUser:(id)sender {
    
    PillButton *btn = (PillButton *)sender;
    SuggestedUserCell *cell = (SuggestedUserCell *)[[sender superview] superview];
    
    NSDictionary *userInfo;
    if (btn.on) {
        // unfollow
        userInfo = @{ @"unfollowedUser": cell.userId,
                      @"sender": btn,
                      @"username": cell.username
                      };
    }
    else {
        // follow
        userInfo = @{ @"followedUser": cell.userId,
                      @"sender": btn
                      };
        btn.on = YES;
        [btn setNeedsDisplay];
    }
    
    
    NSNotification *followingChangedNotif = [NSNotification notificationWithName:@"followingSuggestedUserChanged" object:nil userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:followingChangedNotif];

}


@end
