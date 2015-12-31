//
//  SubscriptionViewCell.h
//  Tung
//
//  Created by Jamie Perkins on 5/1/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TungMiscView.h"

@interface SubscriptionViewCell : UICollectionViewCell

@property (strong, nonatomic) IBOutlet UIImageView *artImageView;
@property (strong, nonatomic) IBOutlet TungMiscView *badge;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *badgeWidthContstraint;

@end
