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
    
    if (_forOnboarding) {
        
        if (btn.on) {
            // unfollow
            [cell.usersToFollow removeObject:cell.userId];
        }
        else {
            // follow
            if (![_usersToFollow containsObject:cell.userId]) {
                [_usersToFollow addObject:cell.userId];
            }
        }
    }
    else {
    
        
        if (btn.on) {
            // unfollow
            [_tung unfollowUserWithId:cell.userId withCallback:^(BOOL success) {
                if (success) {
                    _tung.feedNeedsRefetch = [NSNumber numberWithBool:YES]; // following changed
                    _tung.profileNeedsRefresh = [NSNumber numberWithBool:YES]; // following count changed
                }
                else {
                    btn.on = YES;
                    [btn setNeedsDisplay];
                }
            }];
        }
        else {
            // follow
            [_tung followUserWithId:cell.userId withCallback:^(BOOL success) {
                if (success) {
                    _tung.profileNeedsRefresh = [NSNumber numberWithBool:YES]; // following count changed
                    _tung.feedNeedsRefresh = [NSNumber numberWithBool:YES]; // following changed
                }
                else {
                    btn.on = NO;
                    [btn setNeedsDisplay];
                }
            }];
        }
    }
    
    btn.on = !btn.on;
    [btn setNeedsDisplay];
}

@end
