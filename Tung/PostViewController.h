//
//  PostViewController.h
//  Tung
//
//  Created by Jamie Perkins on 4/4/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "CategoryCollectionController.h"
#import <FacebookSDK/FacebookSDK.h>
#import "postButton.h"

@interface PostViewController : UITableViewController <AVAudioPlayerDelegate, UITextViewDelegate, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UIActionSheetDelegate>

@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@property (strong, nonatomic) NSMutableDictionary *recordingInfoDictionary;
@property (strong, nonatomic) IBOutlet postButton *btn_post;
@property (strong, nonatomic) IBOutlet UIButton *btn_playPause;
@property (strong, nonatomic) IBOutlet UIView *soundView;
@property (strong, nonatomic) IBOutlet UILabel *durationLabel;
@property (strong, nonatomic) IBOutlet UIProgressView *playProgress;
@property (strong, nonatomic) IBOutlet UIImageView *playPauseIndicator;
@property (strong, nonatomic) IBOutlet UITextView *captionTextView;
@property (strong, nonatomic) IBOutlet UIImageView *captionBkgd;
@property (strong, nonatomic) IBOutlet UIImageView *captionArrow;
@property (strong, nonatomic) IBOutlet UILabel *tapToAddCaptionLabel;
@property (strong, nonatomic) IBOutlet UITextField *categoryTextField;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (strong, nonatomic) IBOutlet UITableView *shareToTable;
@property (strong, nonatomic) IBOutlet UISwitch *facebookShareToggle;
@property (strong, nonatomic) IBOutlet UISwitch *twitterShareToggle;
@property (strong, nonatomic) IBOutlet UILabel *facebookShareLabel;
@property (strong, nonatomic) IBOutlet UILabel *twitterShareLabel;
@property (strong, nonatomic) IBOutlet UIImageView *facebookShareIcon;
@property (strong, nonatomic) IBOutlet UIImageView *twitterShareIcon;
@property (strong, nonatomic) IBOutlet UITableViewCell *postButtonCell;
@property (strong, nonatomic) IBOutlet UISegmentedControl *fbShareControl;

@property (nonatomic, readwrite) CategoryCollectionController *categoryCollectionController;

- (IBAction)playPause:(id)sender;
- (IBAction)post:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)toggleFacebookSharing:(id)sender;
- (IBAction)toggleTwitterSharing:(id)sender;

@end
