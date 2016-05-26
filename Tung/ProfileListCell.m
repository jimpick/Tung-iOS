//
//  ProfileListCell.m
//  Tung
//
//  Created by Jamie Perkins on 11/5/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "ProfileListCell.h"

@class TungCommonObjects;

@implementation ProfileListCell

- (void)awakeFromNib {
    // Initialization code
    _tung = [TungCommonObjects establishTungObjects];
    
    _followBtn.type = kPillTypeFollow;
    _followBtn.backgroundColor = [UIColor clearColor];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (IBAction)followOrUnfollowUser:(id)sender {
    
    PillButton *btn = (PillButton *)sender;
    ProfileListCell *cell = (ProfileListCell *)[[sender superview] superview];
    
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
    
    NSNotification *followingChangedNotif = [NSNotification notificationWithName:@"followingChanged" object:nil userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:followingChangedNotif];
}

@end
