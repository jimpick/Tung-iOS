//
//  HeaderView.h
//  Tung
//
//  Created by Jamie Perkins on 5/3/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CircleButton.h"
#import "AppDelegate.h"

@interface HeaderView : UIView

@property (strong, nonatomic) IBOutlet UIView *view;
@property (strong, nonatomic) IBOutlet UIImageView *albumArt;
@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UILabel *subTitleLabel;
@property (strong, nonatomic) IBOutlet CircleButton *subscribeButton;
@property (strong, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (strong, nonatomic) IBOutlet CircleButton *largeButton;
@property NSLayoutConstraint *heightConstraint;
@property NSArray *keyColors;
@property BOOL isConstrained;

-(void) setUpHeaderViewForEpisodeMiniDict:(NSDictionary *)miniDict;
-(void) setUpHeaderViewForEpisode:(EpisodeEntity *)episodeEntity orPodcast:(PodcastEntity *)podcastEntity;
-(void) sizeAndConstrainHeaderViewInViewController:(UIViewController *)vc;

@end
