//
//  PodcastResultCell.h
//  Tung
//
//  Created by Jamie Perkins on 3/17/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PodcastResultCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UIImageView *podcastArtImageView;
@property (strong, nonatomic) UILabel *podcastTitle;
@property (strong, nonatomic) UILabel *podcastArtist;
@property (strong, nonatomic) IBOutlet UILabel *releaseDateLabel;
@property (strong, nonatomic) UIImageView *accessory;

@end
