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
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (IBAction)followOrUnfollowUser:(id)sender {
    
    PillButton *btn = (PillButton *)sender;
    ProfileListCell *cell = (ProfileListCell *)[[sender superview] superview];
    NSString *userId = [cell.profileDict objectForKey:@"id"];
    
    if (btn.on) {
        // unfollow
        [_tung unfollowUserWithId:userId withCallback:^(BOOL success) {
            if (!success) {// fail
                btn.on = YES;
                [btn setNeedsDisplay];
            }
            else {
                _tung.profileNeedsRefresh = [NSNumber numberWithBool:YES]; // following count changed
            }
        }];
    }
    else {
        // follow
        [_tung followUserWithId:userId withCallback:^(BOOL success) {
            if (!success) {// fail
                btn.on = NO;
                [btn setNeedsDisplay];
            }
            else {
                _tung.profileNeedsRefresh = [NSNumber numberWithBool:YES]; // following count changed
            }
        }];
    }
    // GUI
    btn.on = !btn.on;
    [btn setNeedsDisplay];
}

@end
