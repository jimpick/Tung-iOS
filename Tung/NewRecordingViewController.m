//
//  NewRecordingViewController.m
//  Tung
//
//  Created by Jamie Perkins on 2/4/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "NewRecordingViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>
#import "tungCommonObjects.h"

#define MAX_RECORD_TIME 15

@interface NewRecordingViewController ()

@property (nonatomic) double progressBarWidth;
@property (strong, nonatomic) CADisplayLink *onEnterFrame;
@property (strong, nonatomic) NSNumberFormatter *format;
@property (nonatomic, assign) BOOL timeLimitReached;
@property (nonatomic, assign) BOOL recordingPermissionGranted;
@property (strong, nonatomic) NSString *pathToRecordingFile;
@property (strong, nonatomic) UIProgressView *playProgress;
@property (strong, nonatomic) UIBarButtonItem *btn_startOver;
@property (strong, nonatomic) UIBarButtonItem *fspace;
@property (nonatomic, assign) CGFloat screenWidth;
@property (nonatomic, retain) tungCommonObjects *tungObjects;
@property (strong, nonatomic) NSMutableDictionary *appData;

- (void)updateView;
- (void)playbackRecording;
- (void)stopPlayback;
- (void)initializeRecorder;
- (void)setProgBarWidth:(double)progress;

@end

@implementation NewRecordingViewController

static BOOL enforceMinimum = YES; // enforce min 2 sec record time - turn off for dev

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _screenWidth = [[UIScreen mainScreen]bounds].size.width;
    
    _tungObjects = [tungCommonObjects establishTungObjects];
    
    _appData = [tungCommonObjects getSavedAppData];
    
    // use character alternates for timeElapsed label
    NSArray *timerDisplaySettings = @[
                                      @{ UIFontFeatureTypeIdentifierKey: @(6),
                                        UIFontFeatureSelectorIdentifierKey: @(1)
                                     },
                                      @{ UIFontFeatureTypeIdentifierKey: @(17),
                                        UIFontFeatureSelectorIdentifierKey: @(1)
                                        }];
    
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-UltraLight" size:64];
    
    UIFontDescriptor *originalDescriptor = [font fontDescriptor];
    UIFontDescriptor *timerDescriptor =[originalDescriptor fontDescriptorByAddingAttributes: @{ UIFontDescriptorFeatureSettingsAttribute: timerDisplaySettings }];
    UIFont *timerFont = [UIFont fontWithDescriptor: timerDescriptor size:0.0];
    _timeElapsedLabel.font = timerFont;
    _timeElapsedLabel.textAlignment = NSTextAlignmentLeft;
    
    // timer
    _timeLimitReached = NO;
    
    // time elapsed number formatter
    _format = [[NSNumberFormatter alloc] init];
	[_format setMinimumIntegerDigits:2];
	[_format setMinimumFractionDigits:1];
    
    // set up playProgress
    _playProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _playProgress.trackTintColor = [UIColor colorWithRed:255.0/255.0f green:255.0/255.0f blue:255.0/255.0f alpha:.5];
    _playProgress.progressTintColor = _tungObjects.tungColor;
    CGRect playProgressFrame = CGRectMake(20, 21, _screenWidth - 40, 2);
    _playProgress.frame = playProgressFrame;
    _playProgress.progress = 0;
    _playProgress.alpha = 0;
    [_toolbar addSubview:_playProgress];
    
    // set up toolbar
    _btn_startOver = [[UIBarButtonItem alloc] initWithTitle:@"Start Over" style:UIBarButtonItemStylePlain target:self action:@selector(startOver:)];
    [_btn_startOver setEnabled:NO];
    _fspace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    [_toolbar setItems:@[_fspace, _btn_startOver, _fspace] animated:YES];
    
    // record progress bar
    _progressBarWidth = 0;

    NSLog(@"system version: %f", [[[UIDevice currentDevice] systemVersion] floatValue]);
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8) {
        if (_screenWidth < 414) {
            _tapPad.image = [UIImage imageNamed:@"tapPad@2x.png"];
        } else {
            _tapPad.image = [UIImage imageNamed:@"tapPad@3x.png"];
        }
    }
    
    // record method toggle
    _recordMethodToggle.tintColor = _tungObjects.tungColor;
    [_recordMethodToggle addTarget:self action:@selector(recordMethodChanged) forControlEvents:UIControlEventValueChanged];
    // set saved value
    if ([_appData objectForKey:@"recordMethod"]) {
        _recordMethodToggle.selectedSegmentIndex = [[_appData objectForKey:@"recordMethod"] integerValue];
        [self recordMethodChanged];
    }
    
    // record permission
    _recordingPermissionGranted = NO;
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) {
                NSLog(@"recording permission granted");
                _recordingPermissionGranted = YES;
                [self initializeRecorder];
            }
            else {
                NSLog(@"recording permission not granted");
                UIAlertView *micPermissionAlert = [[UIAlertView alloc] initWithTitle:@"Cannot Record" message:@"Tung does not have access to your microphone. To give tung access, go to Settings > Privacy > Microphone and enable access for tung." delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                micPermissionAlert.tag = 3;
                [micPermissionAlert show];
            }
        });
    }];
    
    // disable device sleep
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    // set audio session to record
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryRecord error: nil];
    
    // below commented out bc AudioSessionSetProperty is deprecated
    // it was necessary to change the sound route for the PlayAndRecord session type bc otherwise it plays audio through mic
    // instead, session is set to one or the other depending on user actions
    
    /*
    NSError *setCategoryErr = nil;
    NSError *activationErr  = nil;
    
    //Set the general audio session category
    
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayAndRecord error: &setCategoryErr];
    
    //Make the default sound route for the session use the speaker
    UInt32 doChangeDefaultRoute = 1;
    AudioSessionSetProperty (kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, sizeof (doChangeDefaultRoute), &doChangeDefaultRoute);
    
    //Activate the customized audio session
    [[AVAudioSession sharedInstance] setActive: YES error: &activationErr];
    
    if (setCategoryErr || activationErr)
        NSLog(@"%@ --OR-- %@", setCategoryErr, activationErr);
    */


}

-(void) viewDidLayoutSubviews {
    // set progress bar width
    CGRect newProgressBarFrame = _progressBar.frame;
    newProgressBarFrame.size.width = _progressBarWidth;
    [_progressBar setFrame:newProgressBarFrame];
}

- (void)viewWillDisappear:(BOOL)animated {
    
    // stop recording
    if ([_audioRecorder isRecording]) {
        [_audioRecorder stop];
    }
    // stop playing audio
    if ([_audioPlayer isPlaying]) {
        [_audioPlayer stop];
    }
    // re-enable sleep
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)recordMethodChanged {
    if (_recordMethodToggle.selectedSegmentIndex == 0) {
        [_appData setObject:[NSNumber numberWithInt:0] forKey:@"recordMethod"];
        _recordMethodLabel.text = @"Tap and hold to record";
    } else {
        [_appData setObject:[NSNumber numberWithInt:1] forKey:@"recordMethod"];
        _recordMethodLabel.text = @"Tap to start recording";
    }
    [tungCommonObjects saveAppData:_appData];
}


- (void)updateView { // ----------------------------------- UPDATE VIEW
    
    // recording
    if ([_audioRecorder isRecording]) {
        
        //NSLog(@"current record time: %f",_audioRecorder.currentTime);
        // don't let recording exceed max record time
        if (_audioRecorder.currentTime >= MAX_RECORD_TIME) {
            NSLog(@"max record time reached: %f", _audioRecorder.currentTime);
            _timeLimitReached = YES;
            // stop
            [self stopRecording];
            // vibrate
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            // set label text to MAX_RECORD_TIME, otherwise it shows X.9
            _timeElapsedLabel.text = [NSString stringWithFormat:@":%@", [_format stringFromNumber:[NSNumber numberWithInt:MAX_RECORD_TIME]]];
            [self setProgBarWidth:1];
        } else {
            // set label text
            _timeElapsedLabel.text = [NSString stringWithFormat:@":%@", [_format stringFromNumber:[NSNumber numberWithDouble:floor(_audioRecorder.currentTime*10)/10]]];
            
            // set progress bar width
            double percentRecorded = _audioRecorder.currentTime / MAX_RECORD_TIME;
            [self setProgBarWidth:percentRecorded];
        }
    }
    // playing
    else if ([_audioPlayer isPlaying]) {
        _playProgress.progress = _audioPlayer.currentTime / _audioPlayer.duration;
    }
    
}

- (void)setProgBarWidth:(double)progress {
    CGRect newProgressBarFrame = _progressBar.frame;
    _progressBarWidth = _screenWidth * progress;
    newProgressBarFrame.size.width = _progressBarWidth;
    [_progressBar setFrame:newProgressBarFrame];
}

#pragma mark audio - recording methods

- (void)initializeRecorder {
    NSLog(@"initialize recorder");
    
    if (_audioRecorder != nil) _audioRecorder = nil;
    
    // recording file path (temp)
    _pathToRecordingFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"newTung.lpcm"];
    // delete recording file if exists.
    if ([[NSFileManager defaultManager] fileExistsAtPath:_pathToRecordingFile]) {
        [[NSFileManager defaultManager] removeItemAtPath:_pathToRecordingFile error:nil];
    }
    
    NSURL *audioRecordingURL = [NSURL fileURLWithPath:_pathToRecordingFile];
    
    NSError *error =  nil;
    _audioRecorder = [[AVAudioRecorder alloc] initWithURL:audioRecordingURL settings:[self audioRecordingSettings] error:&error];
    
    if (_audioRecorder != nil) {
        
        _audioRecorder.delegate = self;
        [_audioRecorder prepareToRecord];
        
    } else {
        NSLog(@"failed to create instance of audio recorder");
        NSLog(@"%@", error);
    }
}

- (IBAction)recordPadTouchDown:(id)sender {
    
    if (_recordMethodToggle.selectedSegmentIndex == 0 && !_timeLimitReached && ![_audioPlayer isPlaying]) {
        // start recording
        [self startRecording];
    }
}

- (IBAction)recordPadTouchUp:(id)sender {
    
    // tap and hold
    if (_recordMethodToggle.selectedSegmentIndex == 0) {
        // pause recording
        if (!_timeLimitReached && [_audioRecorder isRecording])
            [self stopRecording];
    }
    // tap on tap off
    else {
        // start stop
        if ([_audioRecorder isRecording]) {
            [self stopRecording];
        } else {
            [self startRecording];
        }
    }
    //UISegmentControl
}

- (void) startRecording {
    // set audio session if necessary
    if (![[[AVAudioSession sharedInstance] category] isEqualToString:@"AVAudioSessionCategoryRecord"])
        [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryRecord error: nil];
    
    // hide playPauseIndicator
    [self fadeOutImageView:_playPauseIndicator];
    
    // start over button
    [_btn_startOver setEnabled:YES];
    
    // record
    NSLog(@"start/resume recording");
    //NSLog(@"filepath: %@", _pathToRecordingFile);
    [_audioRecorder record];
    
    if ([_audioRecorder isRecording]) {
        NSLog(@"RECORDING");
        // begin "onEnterFrame"
        _onEnterFrame = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateView)];
        [_onEnterFrame addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    }
}

// called from recordPadTouchUp, if recording time exceeds MAX_RECORD_TIME, and inturruption
- (void) stopRecording {
    
    NSLog(@"recording paused");
    // stop recording
    [_audioRecorder pause];
    
    // display playPauseIndicator
    [self fadeInImageView:_playPauseIndicator];
    
    // stop "onEnterFrame"
    [_onEnterFrame invalidate];
}

// only called if
- (void) audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    
    if (flag) {
    	NSLog(@"......successfully stopped recording");
    }
}

- (NSDictionary *) audioRecordingSettings {
    
    NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
    
    //[settings setValue:[NSNumber numberWithInteger:kAudioFormatAppleLossless] forKey:AVFormatIDKey]; // m4a
    //[settings setValue:[NSNumber numberWithInteger:kAudioFormatMPEGLayer3] forKey:AVFormatIDKey]; // mp3
    // mp3 and m4a do not allow the recording to stop and start again.
    [settings setValue:[NSNumber numberWithInteger:kAudioFormatLinearPCM] forKey:AVFormatIDKey]; // lpcm
    [settings setValue:[NSNumber numberWithFloat:44100.0f] forKey:AVSampleRateKey];
    [settings setValue:[NSNumber numberWithInteger:2] forKey:AVNumberOfChannelsKey];
    [settings setValue:[NSNumber numberWithInteger:AVAudioQualityHigh] forKey:AVEncoderAudioQualityKey];
    return [NSDictionary dictionaryWithDictionary:settings];
}

- (void) audioRecorderBeginInterruption:(AVAudioRecorder *)recorder {
    
    [self stopRecording];
}

- (void) audioRecorderEndInterruption:(AVAudioRecorder *)recorder withOptions:(NSUInteger)flags {
    
    if (flags == AVAudioSessionInterruptionOptionShouldResume) {
        NSLog(@"safe to resume recording");
    }
}

#pragma mark - audio playback methods


- (IBAction)playPause:(id)sender {
    // stop
    if ([_audioPlayer isPlaying]) {
        [self stopPlayback];
    }
    // play
    else {
        [self playbackRecording];
        [_playPauseIndicator setImage:[UIImage imageNamed:@"btn-stop-large.png"]];
        [_toolbar setItems:@[] animated:YES];
        [self fadeInImageView:_playProgress];
    }
}

- (void) playbackRecording {
    
    // set audio session if necessary
    if (![[[AVAudioSession sharedInstance] category] isEqualToString:@"AVAudioSessionCategoryPlayback"])
        [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: nil];
    
    NSError *readingError = nil;
    NSData *fileData = [NSData dataWithContentsOfFile:_pathToRecordingFile options:NSDataReadingMapped error:&readingError];
    
    // create audio player
    NSError *playbackError;
    _audioPlayer = [[AVAudioPlayer alloc] initWithData:fileData error:&playbackError];
    
    if (_audioPlayer != nil) {
        _audioPlayer.delegate = self;
        // PLAY
        if ([_audioPlayer prepareToPlay] && [_audioPlayer play]) {
            NSLog(@"started playing recording");
            NSLog(@"audio player duration: %f", _audioPlayer.duration);
            // begin "onEnterFrame"
            _onEnterFrame = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateView)];
            [_onEnterFrame addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            
        } else {
            NSLog(@"could not play recording");
        }
    } else {
        NSLog(@"failed to create audio player");
        NSLog(@"%@", playbackError);
    }
}

- (void) stopPlayback {
    
    if ([_audioPlayer isPlaying]) [_audioPlayer stop];
    // reset GUI
    [_playPauseIndicator setImage:[UIImage imageNamed:@"btn-play-large.png"]];
    _playProgress.progress = 0;
    [self fadeOutImageView:_playProgress];
    [_toolbar setItems:@[_fspace, _btn_startOver, _fspace] animated:YES];
    // stop "onEnterFrame"
    [_onEnterFrame invalidate];
    _audioPlayer = nil;

}

- (void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
   
    if (flag) {
        NSLog(@"audio player stopped successfully");
    } else {
        NSLog(@"audio player did not stop");
    }
    [self stopPlayback];
}

- (void) audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    [self stopPlayback];
}
- (void) audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags {
    if (flags == AVAudioSessionInterruptionOptionShouldResume) {
        NSLog(@"audio player end interruption");
    }
}

#pragma mark - handle alerts

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    // start over recording
    if (alertView.tag == 1) {
        if (buttonIndex == 1) { // start over
            
            // delete recording and re-initialize recorder;
            [_audioRecorder deleteRecording];
            [self initializeRecorder];
            // reset timeElapsed
            _timeLimitReached = NO;// set label text
            _timeElapsedLabel.text = [NSString stringWithFormat:@":%@", [_format stringFromNumber:[NSNumber numberWithInt:0]]];
            // reset progress bar
            CGRect newProgressBarFrame = _progressBar.frame;
            _progressBarWidth = 0;
            newProgressBarFrame.size.width = 0;
            [_progressBar setFrame:newProgressBarFrame];
            // disable toolbar buttons
            [_btn_startOver setEnabled:NO];
            // hide playPauseIndicator
            [self fadeOutImageView:_playPauseIndicator];

        }
    }
    // cancel new recording
    if (alertView.tag == 2) {
        if (buttonIndex == 1) {
            // delete recording
            [_audioRecorder deleteRecording];
            // dismiss new recording window
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
    // tung does not have microphone permission
    if (alertView.tag == 3) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - animation methods

- (void)fadeInImageView:(UIView *)view {
    
    [UIView beginAnimations:@"fade in" context:nil];
    [UIView setAnimationDuration:0.2];
    view.alpha = 1;
    [UIView commitAnimations];
    
}
- (void)fadeOutImageView:(UIView *)view {
    
    [UIView beginAnimations:@"fade out" context:nil];
    [UIView setAnimationDelegate:self];
    // on complete
    // [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
    [UIView setAnimationDuration:0.2];
    view.alpha = 0;
    [UIView commitAnimations];
    
}
- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    
    if ([finished boolValue]) {
        // do something
    }
}

#pragma mark - tool bar

- (IBAction)startOver:(id)sender {
    if ([_audioRecorder isRecording]) [self stopRecording];
    
    UIAlertView *startOverAlert = [[UIAlertView alloc] initWithTitle:@"Are you sure?" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Yes", nil];
    [startOverAlert setTag:1];
    [startOverAlert show];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([_audioRecorder isRecording]) [self stopRecording];
    
    UIViewController *destination = segue.destinationViewController;
    // info to pass to next view controller
    if ([[segue identifier] isEqualToString:@"toCollectionView"]) {
    	NSMutableDictionary *recordingInfoDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys: _pathToRecordingFile, @"pathToRecordingFile", nil];
    	[destination setValue:recordingInfoDictionary forKey:@"recordingInfoDictionary"];
    }
}

- (IBAction)unwindToNewRecording:(UIStoryboardSegue*)sender {
    
}

#pragma mark - nav bar

- (IBAction)next:(id)sender {
    
    if (enforceMinimum && _audioRecorder.currentTime < 2.0) {
        // alert that recordings must be >= 2 secs
        UIAlertView *minimumTimeAlert = [[UIAlertView alloc] initWithTitle:@"Too Short" message:@"Your recording must be at least \n2 seconds long. Record a little more." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [minimumTimeAlert show];
    } else {
        // segue to next view
        [self performSegueWithIdentifier:@"toCollectionView" sender:self];
    }
}

- (IBAction)cancel:(id)sender {
    if ([_audioRecorder isRecording]) [self stopRecording];
    if (_audioRecorder != nil) {
        if (_audioRecorder.currentTime > 0) {
            // warn that recording will be lost
            UIAlertView *cancelRecordingAlert = [[UIAlertView alloc] initWithTitle:@"Cancel Recording" message:@"Are you sure? The current recording will be lost." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
            [cancelRecordingAlert setTag:2];
            [cancelRecordingAlert show];
            
        } else {
            // dismiss new recording window
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    } else {
        // dismiss new recording window
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
