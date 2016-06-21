//
//  EpisodeViewController.h
//  Tung
//
//  Created by Jamie Perkins on 5/6/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TungCommonObjects.h"
#import "TungPodcast.h"
#import "CircleButton.h"
#import "ShowHideControlsButton.h"
#import "FXBlurView.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "IconButton.h"

@interface EpisodeViewController : UIViewController <TungPodcastsDelegate, AVAudioPlayerDelegate, UIWebViewDelegate, UITextViewDelegate, UIScrollViewDelegate>

@property (strong, nonatomic) IBOutlet FXBlurView *npControlsView;
@property (strong, nonatomic) IBOutlet UISlider *posbar;
@property (strong, nonatomic) IBOutlet UILabel *timeElapsedLabel;
@property (strong, nonatomic) IBOutlet UILabel *totalTimeLabel;
@property (strong, nonatomic) IBOutlet UIScrollView *buttonsScrollView;
@property (strong, nonatomic) IBOutlet ShowHideControlsButton *hideControlsButton;
@property (strong, nonatomic) IBOutlet ShowHideControlsButton *showControlsButton;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *npControlsBottomLayoutConstraint;
@property (strong, nonatomic) IBOutlet UILabel *shareLabel;
@property (strong, nonatomic) IBOutlet UIProgressView *progressBar;
@property (strong, nonatomic) IBOutlet UIPageControl *pageControl;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *backgroundSpinner;

@property (strong, nonatomic) EpisodeEntity *episodeEntity;
@property (strong, nonatomic) NSString *focusedEventId;
@property (strong, nonatomic) NSDictionary *episodeMiniDict;
@property (strong, nonatomic) IBOutlet IconButton *skipAheadBtn;
@property (strong, nonatomic) IBOutlet IconButton *skipBackBtn;

- (IBAction)toggleNpControlsView:(id)sender;
- (IBAction)touchDownInShowHideControlsButton:(id)sender;

@end
