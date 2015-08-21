//
//  NewRecordingViewController.h
//  Tung
//
//  Created by Jamie Perkins on 2/4/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface NewRecordingViewController : UIViewController <AVAudioPlayerDelegate, AVAudioRecorderDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

- (NSDictionary *) audioRecordingSettings;

- (IBAction)recordPadTouchDown:(id)sender;
- (IBAction)recordPadTouchUp:(id)sender;

- (IBAction)next:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)playPause:(id)sender;

@property (strong, nonatomic) IBOutlet UIImageView *playPauseIndicator;
@property (strong, nonatomic) IBOutlet UIImageView *tapPad;
@property (strong, nonatomic) IBOutlet UILabel *timeElapsedLabel;
@property (strong, nonatomic) IBOutlet UIView *progressBar;
@property (strong, nonatomic) IBOutlet UIToolbar *toolbar;
@property (strong, nonatomic) IBOutlet UISegmentedControl *recordMethodToggle;
@property (strong, nonatomic) IBOutlet UILabel *recordMethodLabel;

@end
