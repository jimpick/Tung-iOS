//
//  PostViewController.m
//  Tung
//
//  Created by Jamie Perkins on 4/4/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "PostViewController.h"
#import "CategoryCollectionController.h"
#import "tungCommonObjects.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import "tungStereo.h"
#import "AppDelegate.h"

#define MAX_CAPTION_CHARS 220

@interface PostViewController ()

@property (copy, nonatomic) NSString *pathToConvertedFile;
@property (strong, nonatomic) NSNumber *selectedCategory;
@property (strong, nonatomic) CADisplayLink *onEnterFrame;
@property (strong, nonatomic) UIPickerView *categoryPicker;
@property (strong, nonatomic) UILabel *keyboardLabel;
@property (nonatomic, retain) tungCommonObjects *tungObjects;
@property (nonatomic, retain) tungStereo *tungStereo;

@property (strong, nonatomic) NSString *tungId;
@property (strong, nonatomic) NSString *tungPassword;
@property (strong, nonatomic) NSMutableDictionary *userData;

@property (nonatomic, assign) BOOL working;

@property (nonatomic, assign) CGRect startingCaptionTextViewFrame;
@property (nonatomic, assign) CGRect startingCaptionBkgdViewFrame;
@property (nonatomic, assign) CGRect startingCaptionArrowFrame;

-(void) playbackRecording;
-(void) stopPlayback;
-(void) updateView;
-(void) formatKeyboardLabel:(UITextView *)textView;
-(void) saveAsDraft;
-(void) postTweetWithTungShortLink:(NSString *)shortLink;

@end

@implementation PostViewController

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
    
    _tungObjects = [tungCommonObjects establishTungObjects];
    _tungObjects.viewController = self;
    
    _tungStereo = [[tungStereo alloc] init];
    _tungStereo.viewController = self;
    
    _playProgress.progress = 0;
    
    // load user data
    _userData = [[tungCommonObjects getSavedUserData] mutableCopy];
	
    // extract contents of dictionary and path to recorded file
    //NSLog(@"recording info dictionary: %@", self.recordingInfoDictionary);
    _selectedCategory = [self.recordingInfoDictionary objectForKey:@"selectedCategory"];
    _pathToConvertedFile = [self.recordingInfoDictionary objectForKey:@"convertedFile"];
    
    [self conformUItoSelectedCategory];
    
    // create audio player
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: nil];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    // file size
    NSError *attributesError;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_pathToConvertedFile error:&attributesError];
    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
    NSLog(@"draft file size: %@ b", fileSizeNumber);
    
    NSError *readingError = nil;
    NSData *fileData = [NSData dataWithContentsOfFile:_pathToConvertedFile options:NSDataReadingMapped error:&readingError];
    if (readingError) NSLog(@"reading error: %@", readingError);
    NSLog(@"data length: %lu", (unsigned long)fileData.length);
    
    NSError *playbackError;
    self.audioPlayer = [[AVAudioPlayer alloc] initWithData:fileData error:&playbackError];
    self.audioPlayer.delegate = self;
    NSLog(@"audio player duration: %f", self.audioPlayer.duration);
    
    // format duration label
    NSArray *durationDisplaySettings = @[
                                         @{ UIFontFeatureTypeIdentifierKey: @(6),
                                            UIFontFeatureSelectorIdentifierKey: @(1)
                                            },
                                         @{ UIFontFeatureTypeIdentifierKey: @(17),
                                            UIFontFeatureSelectorIdentifierKey: @(1)
                                            }];
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:41];
    UIFontDescriptor *originalDescriptor = [font fontDescriptor];
    UIFontDescriptor *durationDescriptor = [originalDescriptor fontDescriptorByAddingAttributes: @{ UIFontDescriptorFeatureSettingsAttribute: durationDisplaySettings }];
    UIFont *durationFont = [UIFont fontWithDescriptor: durationDescriptor size:0.0];
    self.durationLabel.font = durationFont;
    
    NSString *durationLabel = [_tungObjects.durationFormatter stringFromNumber:[NSNumber numberWithDouble:self.audioPlayer.duration]];
    [self.durationLabel setText:[NSString stringWithFormat:@":%@", durationLabel]];
    NSNumber *durationNumber = [NSNumber numberWithDouble:round(self.audioPlayer.duration * 10)/10];
    [self.recordingInfoDictionary setObject:durationNumber forKey:@"duration"];
    NSLog(@"rounded duration: %@", durationNumber);
    
    // change category picker view
    self.categoryPicker = [[UIPickerView alloc] init];
    self.categoryPicker.delegate = self;
    self.categoryPicker.dataSource = self;
    self.categoryPicker.showsSelectionIndicator = YES;
    [self.categoryPicker selectRow:[_selectedCategory integerValue] inComponent:0 animated:NO];
    
    // input view toolbar
    UIToolbar *keyboardToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    _keyboardLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 160, 44)];
    _keyboardLabel.text = [NSString stringWithFormat:@"%u", MAX_CAPTION_CHARS];
    _keyboardLabel.textColor = [UIColor lightGrayColor];
    UIBarButtonItem *keyboardLabelBarItem = [[UIBarButtonItem alloc] initWithCustomView:_keyboardLabel];
    UIBarButtonItem *doneEditing = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissInputView)];
    [doneEditing setTintColor:_tungObjects.tungColor];
    UIBarButtonItem *fspace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    keyboardToolbar.barStyle = UIBarStyleDefault;
    [keyboardToolbar setItems:@[keyboardLabelBarItem, fspace, doneEditing]];
    
    // category text field
    self.categoryTextField.delegate = self;
    self.categoryTextField.inputView = self.categoryPicker;
    self.categoryTextField.inputAccessoryView = keyboardToolbar;
    
    // set up captionTextView
    if ([[self.recordingInfoDictionary objectForKey:@"captionText"] length] > 0) {
        self.captionTextView.text = [self.recordingInfoDictionary objectForKey:@"captionText"];
        self.tapToAddCaptionLabel.hidden = YES;
    }
    self.captionTextView.delegate = self;
    self.captionTextView.inputAccessoryView = keyboardToolbar;
    
    UIImage *captionBkgdImage = [[UIImage imageNamed:@"caption-bkgd.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(15, 16, 15, 16)];
    [self.captionBkgd setImage:captionBkgdImage];
    
    // shareToTable
    [self.shareToTable setSeparatorColor:_tungObjects.tungColor];
    self.facebookShareToggle.on = NO;
    self.twitterShareToggle.on = NO;
    self.facebookShareToggle.onTintColor = _tungObjects.facebookColor;
    self.fbShareControl.tintColor = _tungObjects.facebookColor;
    self.twitterShareToggle.onTintColor = _tungObjects.twitterColor;
    
}
-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    NSLog(@"VIEW WILL APPEAR");
    
}
-(void) viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    
    @try {
        [self removeObserver:self forKeyPath:@"tungObjects.twitterAccountStatus"];
    }
    @catch (NSException *exception) {}
    @finally {}
    
    [self stopPlayback];
    self.audioPlayer = nil;
    [self.recordingInfoDictionary setObject:self.captionTextView.text forKey:@"captionText"];
    [self.categoryCollectionController updateSelectedCategory:_selectedCategory];
}

-(void) viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
//    NSLog(@"VIEW DID LAYOUT SUBVIEWS");
//    NSLog(@"starting frame: %@ for anchorPoint: %@", NSStringFromCGRect(self.captionTextView.frame), NSStringFromCGPoint(self.captionTextView.layer.anchorPoint));
}

- (void)conformUItoSelectedCategory {
    NSLog(@"conform UI to selected category");
    // make UI conform to selected category
    [self.soundView setBackgroundColor:[_tungObjects.categoryColors objectAtIndex:[_selectedCategory integerValue]]];
    self.categoryTextField.text = [_tungObjects.categoryHashtags objectAtIndex:[_selectedCategory integerValue]];
    _playProgress.progressTintColor = [_tungObjects.darkCategoryColors objectAtIndex:[_selectedCategory integerValue]];
}

- (void) dismissInputView {
    [self.captionTextView resignFirstResponder];
    [self.categoryTextField resignFirstResponder];
}

- (void)updateView {
    
    if ([self.audioPlayer isPlaying]) {
        // progress bar
        _playProgress.progress = self.audioPlayer.currentTime / self.audioPlayer.duration;
        // duration label countdown
        double remaining = self.audioPlayer.duration - self.audioPlayer.currentTime;
        NSString *remainingString = [NSString stringWithFormat:@":%@",[_tungObjects.durationFormatter stringFromNumber:[NSNumber numberWithDouble:remaining]]];
        //NSLog(@"%f, %@", remaining, remainingString);
        [self.durationLabel setText:remainingString];
    } 
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

- (void)saveAsDraft {

    // create filename with today's date and time
    NSDate *today = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
    NSString *todayFormatted = [dateFormatter stringFromDate:today];
    NSString *soundFilename = [NSString stringWithFormat:@"%@.m4a", todayFormatted];
    NSLog(@"filename: %@.m4a",soundFilename);
    // create "drafts" and "draftsMeta" folders
    NSArray *folders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSError *writeError;
    NSString *draftsPath = [NSString stringWithFormat:@"%@/drafts", [folders objectAtIndex:0]];
    [[NSFileManager defaultManager] createDirectoryAtPath:draftsPath withIntermediateDirectories:NO attributes:nil error:&writeError];
    NSString *draftsMetaPath = [NSString stringWithFormat:@"%@/draftsMeta", [folders objectAtIndex:0]];
    [[NSFileManager defaultManager] createDirectoryAtPath:draftsMetaPath withIntermediateDirectories:NO attributes:nil error:&writeError];
    NSString *draftDestinationPath = [draftsPath stringByAppendingPathComponent:soundFilename];
    // save draft
    NSError *readingError = nil;
    NSData *draftData = [NSData dataWithContentsOfFile:_pathToConvertedFile options:NSDataReadingMapped error:&readingError];
    if ([draftData writeToFile:draftDestinationPath atomically:YES]) NSLog(@"successfully saved sound file");
    // save meta data
    NSDictionary *metaData = @{@"convertedFile": soundFilename, @"selectedCategory": _selectedCategory, @"captionText": self.captionTextView.text};
    NSString *metaDataFilename = [NSString stringWithFormat:@"%@.txt", todayFormatted];
    NSString *draftMetaDataDestinationPath = [draftsMetaPath stringByAppendingPathComponent:metaDataFilename];
    if ([metaData writeToFile:draftMetaDataDestinationPath atomically:YES]) NSLog(@"successfully saved sound meta data");
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
}
- (IBAction)post:(id)sender {
    
    if (!_working) {
        _working = YES;
        // show spinner
        self.btn_post.buttonText = @"";
        self.spinner.hidden = NO;
        [self.spinner startAnimating];

        // prepare data
        NSDictionary *newTungPostData = @{@"sessionId": _tungObjects.sessionId,
                                          @"caption": self.captionTextView.text,
                                          @"duration": [self.recordingInfoDictionary objectForKey:@"duration"],
                                          @"category": [self.recordingInfoDictionary objectForKey:@"selectedCategory"]};
        
        NSLog(@"data to post: \n%@", newTungPostData);
        
        // create request object
        NSURL *postURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@tungs/new_tung.php", _tungObjects.apiRootUrl]];
        NSMutableURLRequest *postRequest = [NSMutableURLRequest requestWithURL:postURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:15.0f];
        [postRequest setHTTPMethod:@"POST"];
        // add content type
        NSString *boundary = [tungCommonObjects generateHash];
        NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
        [postRequest addValue:contentType forHTTPHeaderField:@"Content-Type"];
        // add post body
        NSMutableData *body = [NSMutableData data];
        [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        // key value pairs
        [body appendData:[tungCommonObjects generateBodyFromDictionary:newTungPostData withBoundary:boundary]];
        
        // tung recording
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"recording\"; filename=\"new_tung.m4a\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: audio/m4a\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        NSURL *recordingDataURL = [NSURL fileURLWithPath:[self.recordingInfoDictionary objectForKey:@"convertedFile"]];
        NSData *recordingData = [[NSData alloc] initWithContentsOfURL:recordingDataURL];
        [body appendData:recordingData];
        [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        
        // end of body
        [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        
        [postRequest setHTTPBody:body];
        // set the content-length
        NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
        [postRequest setValue:postLength forHTTPHeaderField:@"Content-Length"];
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        NSLog(@"make post request");
        [NSURLConnection sendAsynchronousRequest:postRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                NSLog(@"responseDict: %@", responseDict);
                // errors?
                if ([responseDict objectForKey:@"error"]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        _working = NO;
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            NSLog(@"SESSION EXPIRED");
                            [_tungObjects getSessionWithCallback:^{
                                // re-post
                                [self post:nil];
                            }];
                        } else {
                            // hide spinner and restore button title
                            self.btn_post.buttonText = @"Post";
                            self.spinner.hidden = YES;
                            
                            UIAlertView *errorUploadingAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:[responseDict objectForKey:@"error"] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                            [errorUploadingAlert show];
                        }
                    });
                }

                // successful upload
                else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSLog(@"successful upload");
                        _working = NO;
                        
                        // if from drafts, delete draft
                        NSString *draftFilename = [self.recordingInfoDictionary objectForKey:@"draftFilename"];
                        if ([draftFilename length] > 0) [self deleteDraftWithFilename:draftFilename];
                        
                        // tweet
                        if (self.twitterShareToggle.on) {
                            [self postTweetWithTungShortLink:[responseDict objectForKey:@"shortlink"]];
                        }
                        // facebook
                        if (self.facebookShareToggle.on) {
                            
                            BOOL tagFriends = NO;
                            if (self.fbShareControl.selectedSegmentIndex == 1) tagFriends = YES;
                            // check session in case it has changed since they turned on facebook sharing
                            if (FBSession.activeSession.state == FBSessionStateOpen
                                || FBSession.activeSession.state == FBSessionStateOpenTokenExtended) {
                                // post
                                [self postToFacebookWithTungShortLink:[responseDict objectForKey:@"shortlink"] tag:tagFriends];
                                
                            } else {
                                [FBSession openActiveSessionWithReadPermissions:@[@"public_profile", @"publish_actions"]
                                                                   allowLoginUI:YES
                                                              completionHandler:
                                 ^(FBSession *session, FBSessionState state, NSError *error) {
                                     // Retrieve the app delegate
                                     AppDelegate* appDelegate = [UIApplication sharedApplication].delegate;
                                     // Call the app delegate's sessionStateChanged:state:error method to handle session state changes
                                     [appDelegate sessionStateChanged:session state:state error:error];
                                     if (state == FBSessionStateOpen) {
                                         // post
                                         [self postToFacebookWithTungShortLink:[responseDict objectForKey:@"shortlink"] tag:tagFriends];

                                     } else {
                                         NSLog(@"turned off facebook sharing bc: no active session");
                                         [self fadeOutImageView:self.facebookShareIcon];
                                         [self.facebookShareToggle setOn:NO animated:YES];
                                         [self.tableView beginUpdates];
                                         [self.tableView endUpdates];
                                     }
                                 }];
                            }
                        } else {
                            // show spinner and restore button title
                            self.btn_post.buttonText = @"Post";
                            self.spinner.hidden = YES;
                            // show feed
                            [self dismissViewControllerAnimated:YES completion:nil];
                        }
                    });
                }
            }
            else if ([data length] == 0 && error == nil) {
                _working = NO;
                NSLog(@"no response");
            }
            else if (error != nil) {
                _working = NO;
                //NSLog(@"Error: %@", error);
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"HTML: %@", html);
            }
            
        }];
    } else {
        NSLog(@"working");
    }
}

- (void) deleteDraftWithFilename: (NSString *)filename {
    NSString *name = [filename stringByDeletingPathExtension];
    NSLog(@"attempting to delete %@", name);
    NSArray *folders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *draftDestPath = [NSString stringWithFormat:@"%@/drafts/%@.m4a", [folders objectAtIndex:0], name];
    NSString *draftMetaDestPath = [NSString stringWithFormat:@"%@/draftsMeta/%@.txt", [folders objectAtIndex:0], name];
    NSError *error = nil;
    if ([[NSFileManager defaultManager] removeItemAtPath:draftDestPath error:&error]) {
        NSLog(@"deleted used draft at %@", draftDestPath);
    } else {
        NSLog(@"error deleting sound file: %@", error);
    }
    if ([[NSFileManager defaultManager] removeItemAtPath:draftMetaDestPath error:&error]) {
        NSLog(@"deleted used draft meta at %@", draftMetaDestPath);
    } else {
        NSLog(@"error deleting meta file: %@", error);
    }
}

#pragma mark - sharing

/*
 A note about users and their social network IDs:
 
 DB is not updated w/ a user's OTHER social network ID bc: if you update an account that was created with twitter with a facebook id,
 there could be another account created with the facebook id, then there would be two accounts with the same fb id.
 Could also happen the other way around with an account created with fb id.
 */

- (IBAction)toggleFacebookSharing:(id)sender {
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
    
    if ([sender isOn]) {
    	[self fadeInImageView:self.facebookShareIcon];
        // check facebook session
        NSLog(@"checking FB session state....");
        //NSLog(@"facebook session state at toggle: %lu", FBSession.activeSession.state);
        // the state if someone has already logged in with fb in a past session
        if (FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {
            NSLog(@"fb session state created token loaded.");
            [FBSession.activeSession openWithCompletionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                if (FBSession.activeSession.state == FBSessionStateOpen) {
                	[self checkForFacebookSharingPermissions];
                }
            }];
        }
        // the state if they've logged in this session
        else if (FBSession.activeSession.state == FBSessionStateOpen
            || FBSession.activeSession.state == FBSessionStateOpenTokenExtended) {
            // check for permissions
            NSLog(@"facebook session already open");
            [self checkForFacebookSharingPermissions];
            
        } else {
            NSLog(@"open new facebook session");
            // clear any active session
            [FBSession.activeSession closeAndClearTokenInformation];
            // request new session
            [FBSession openActiveSessionWithReadPermissions:@[@"public_profile", @"publish_actions"]
                                               allowLoginUI:YES
                                          completionHandler:
             ^(FBSession *session, FBSessionState state, NSError *error) {
                 // Retrieve the app delegate
                 AppDelegate* appDelegate = [UIApplication sharedApplication].delegate;
                 // Call the app delegate's sessionStateChanged:state:error method to handle session state changes
                 [appDelegate sessionStateChanged:session state:state error:error];
                 // debug: state can be open, but not equal to FBSessionStateOpen
                 
                 if (state == FBSessionStateOpen) {
                     // check for permissions
                     [self checkForFacebookSharingPermissions];
                 } else {
                     
                     NSLog(@"turned off facebook sharing bc: no active session");
                     [self fadeOutImageView:self.facebookShareIcon];
                     [self.facebookShareToggle setOn:NO animated:YES];
                     [self.tableView beginUpdates];
                     [self.tableView endUpdates];
                 }
             }];
        }
    } else {
    	[self fadeOutImageView:self.facebookShareIcon];
    }
}

- (IBAction)toggleTwitterSharing:(id)sender {
    if ([sender isOn]) {
    	[self fadeInImageView:self.twitterShareIcon];
        // watch for if account fails to get set
        [self addObserver:self forKeyPath:@"tungObjects.twitterAccountStatus" options:NSKeyValueObservingOptionNew context:nil];
        [_tungObjects establishTwitterAccount];
    } else {
    	[self fadeOutImageView:self.twitterShareIcon];
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSLog(@"----- value changed for key: %@, change: %@", keyPath, change);
    
    if ([keyPath isEqualToString:@"tungObjects.twitterAccountStatus"]) {
        if ([_tungObjects.twitterAccountStatus isEqualToString:@"failed"]) {
            [self fadeOutImageView:self.twitterShareIcon];
            [self.twitterShareToggle setOn:NO animated:YES];
        }
    }
}

- (void) postTweetWithTungShortLink:(NSString *)shortLink {
    
    // post tweet
    NSString *tweet;
    if ([self.captionTextView.text length] > 0) {
        NSString *caption = [self.captionTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        tweet = [NSString stringWithFormat:@"%@ %@s/%@", caption, _tungObjects.tungSiteRootUrl, shortLink];
    } else {
        NSString *caption = @"Just posted a sound clip on tung:";
        NSString *categoryHashtag = [_tungObjects.categoryHashtags objectAtIndex:[_selectedCategory integerValue]];
        tweet = [NSString stringWithFormat:@"%@ %@s/%@ %@", caption, _tungObjects.tungSiteRootUrl, shortLink, categoryHashtag];
    }
    NSLog(@"Attempting to post tweet: %@", tweet);
    NSDictionary *tweetParams = @{@"status": tweet};
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@statuses/update.json", _tungObjects.twitterApiRootUrl]];
    SLRequest *postTweetRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:requestURL parameters:tweetParams];
    postTweetRequest.account = _tungObjects.twitterAccountToUse;
    NSLog(@"posting tweet with account: %@", _tungObjects.twitterAccountToUse.username);
    [postTweetRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        long responseCode =  (long)[urlResponse statusCode];
        if (responseCode == 200) NSLog(@"tweet posted");
        
        //NSLog(@"Twitter HTTP response: %li", responseCode);
        if (error != nil) {
            //NSLog(@"Error: %@", error);
            NSString *html = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            NSLog(@"HTML: %@", html);
        }
    }];
}

- (void) postToFacebookWithTungShortLink:(NSString *)shortLink tag:(BOOL)tag {
    
    NSString *name;
    NSArray *firstAndLastName = [[_userData objectForKey:@"name"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if ([self.captionTextView.text length] > 0) {
        name = [self.captionTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    } else {
        name = [NSString stringWithFormat:@"A sound recorded by %@", [firstAndLastName objectAtIndex:0]];
    }
    
    NSString *caption = [_tungObjects.categoryHashtags objectAtIndex:[_selectedCategory integerValue]];
    NSString *link = [NSString stringWithFormat:@"%@s/%@", _tungObjects.tungSiteRootUrl, shortLink];
    NSString *description = [NSString stringWithFormat:@"%@ second sound clip recorded by %@", [self.recordingInfoDictionary objectForKey:@"duration"], [_userData objectForKey:@"name"]];
    NSString *image = [NSString stringWithFormat:@"%@assets/img/thumbs/clip-thumb-%ld.png", _tungObjects.tungSiteRootUrl, [_selectedCategory longValue]+1];
    
    // Put together the dialog parameters
    NSMutableDictionary *linkParams = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   name, @"name",
                                   caption, @"caption",
                                   description, @"description",
                                   link, @"link",
                                   image, @"picture",
                                   nil];

    FBLinkShareParams *dialogParams = [[FBLinkShareParams alloc] init];
    dialogParams.link = [NSURL URLWithString:link];
    dialogParams.name = name;
    dialogParams.caption = caption;
    dialogParams.linkDescription = description;
    dialogParams.picture = [NSURL URLWithString:image];
    
    
    if (tag) {
        // post and tag friends
        if ([FBDialogs canPresentShareDialogWithParams:dialogParams]) {
            // Present the share dialog via native FB app
            
            NSLog(@"post to facebook and tag friends with params: %@", dialogParams);
            [FBDialogs presentShareDialogWithLink:dialogParams.link
                                          handler:^(FBAppCall *call, NSDictionary *results, NSError *error) {
                                              // show feed regardless
                                              
                                              [self dismissViewControllerAnimated:YES completion:nil];
                                              if (error) {
                                                  NSLog(@"Error publishing story: %@", error.description);
                                              } else {
                                                  // Success
                                                  NSLog(@"result %@", results);
                                              }
                                          }];
        } else {
            // Present the web feed dialog
            [FBWebDialogs presentFeedDialogModallyWithSession:nil
                                                   parameters:linkParams
                                                      handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
                                                          // show feed regardless
                                                          [self dismissViewControllerAnimated:YES completion:nil];
                                                          if (error) {
                                                              NSLog(@"Error publishing story: %@", error.description);
                                                          } else {
                                                              if (result == FBWebDialogResultDialogNotCompleted) {
                                                                  // User cancelled.
                                                                  NSLog(@"User cancelled.");
                                                              } else {
                                                                  // Handle the publish feed callback
                                                                  NSDictionary *urlParams = [self parseURLParams:[resultURL query]];
                                                                  if (![urlParams valueForKey:@"post_id"]) {
                                                                      // User cancelled.
                                                                      NSLog(@"User cancelled.");
                                                                      
                                                                  } else {
                                                                      // User clicked the Share button
                                                                      NSString *result = [NSString stringWithFormat: @"Posted story, id: %@", [urlParams valueForKey:@"post_id"]];
                                                                      NSLog(@"result %@", result);
                                                                  }
                                                              }
                                                          }
                                                      }];
        }
    }
    else {
        // just post
        NSLog(@"post to facebook with params: %@", linkParams);
        [FBRequestConnection startWithGraphPath:@"/me/feed"
                                     parameters:linkParams
                                     HTTPMethod:@"POST"
                              completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                                  if (!error) {
                                      // Link posted successfully to Facebook
                                      NSLog(@"Posted to facebook successfully: %@", result);
                                      // show feed
                                      [self dismissViewControllerAnimated:YES completion:nil];
                                  } else {
                                      // error
                                      NSLog(@"Error posting to fb: %@", error.description);
                                  }
                              }];
    }
}
// A function for parsing URL parameters returned by the FB Feed Dialog.
- (NSDictionary*) parseURLParams:(NSString *)query {
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    for (NSString *pair in pairs) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        NSString *val =
        [kv[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        params[kv[0]] = val;
    }
    return params;
}

- (void) checkForFacebookSharingPermissions {
    NSLog(@"Check for publish permissions");
    if ([FBSession.activeSession.permissions indexOfObject:@"publish_actions"] == NSNotFound){
        NSLog(@"making permission check request");
        [FBRequestConnection startWithGraphPath:@"/me/permissions"
                              completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                                  if (!error){
                                      NSArray *permissions = [result objectForKey:@"data"];
                                      BOOL permissionGranted = NO;
                                      for (NSDictionary *permission in permissions) {
                                          if ([[permission objectForKey:@"permission"] isEqualToString:@"publish_actions"] &&
                                              [[permission objectForKey:@"status"] isEqualToString:@"granted"])
                                              permissionGranted = YES;
                                      }
                                      
                                      if (!permissionGranted) {
                                          // Publish permissions not found, ask for publish_actions
                                          [self requestFacebookSharingPermissions];;
                                      }
                                      else {
                                          NSLog(@"sharing permissions granted.");
                                      }
                                  } else {
                                      // error
                                      NSLog(@"turned off facebook sharing bc: unable to check for permissions: %@", error);
                                      [self fadeOutImageView:self.facebookShareIcon];
                                      [self.facebookShareToggle setOn:NO animated:YES];
                                      [self.tableView beginUpdates];
                                      [self.tableView endUpdates];
                                  }
                              }];
    }
    else {
        NSLog(@"sharing permissions granted.");
    }
}

- (void) requestFacebookSharingPermissions {
	NSLog(@"Request publish_actions");
	[FBSession.activeSession requestNewPublishPermissions:[NSArray arrayWithObject:@"publish_actions"]
                                          defaultAudience:FBSessionDefaultAudienceFriends
                                        completionHandler:^(FBSession *session, NSError *error) {
                                            __block NSString *alertText;
                                            __block NSString *alertTitle;
                                            if (!error) {
                                                if ([FBSession.activeSession.permissions indexOfObject:@"publish_actions"] == NSNotFound){
                                                    // Permission not granted, tell the user tung cannot publish
                                                    alertTitle = @"tung was denied permission";
                                                    alertText = @"tung cannot currently post to Facebook because it was denied sharing permission.";
                                                    UIAlertView *fbAlert = [[UIAlertView alloc] initWithTitle:alertTitle
                                                                                message:alertText
                                                                               delegate:self
                                                                      cancelButtonTitle:@"OK"
                                                                      otherButtonTitles:nil];
                                                    [fbAlert setTag:2];
                                                    [fbAlert show];
                                                } else {
                                                    NSLog(@"fb sharing permission granted.");
                                                }
                                            } else {
                                                NSLog(@"turned off facebook sharing bc: error requesting facebook permissions: %@", error);
                                                [self fadeOutImageView:self.facebookShareIcon];
                                                [self.facebookShareToggle setOn:NO animated:YES];
                                                [self.tableView beginUpdates];
                                                [self.tableView endUpdates];
                                                
                                            }
                                        }];
}

/*
 not used for the same reason as updateUserWithDictionary. 
 FB token is cached anyway, if need be it will be renewed.
 */
- (void) requestFacebookId {
    
    [[FBRequest requestForMe] startWithCompletionHandler:^(FBRequestConnection *connection, NSDictionary<FBGraphUser> *fbUser, NSError *error) {
        if (error) {
            // Handle error
            NSLog(@"request for me error: %@", error);
        }
        else {
            NSLog(@"fbUser: %@", fbUser);
            [_userData setObject:[fbUser objectForKey:@"id"] forKey:@"facebook_id"];
            [tungCommonObjects saveUserData:_userData];
        }
    }];
}

- (IBAction)cancel:(id)sender {
    if ([self.recordingInfoDictionary objectForKey:@"draftFilename"]) {
        [self performSegueWithIdentifier:@"unwindToDrafts" sender:self];
    } else {
        UIActionSheet *cancelSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Don't save" otherButtonTitles:@"Save draft", nil];
        cancelSheet.tag = 1;
        [cancelSheet showInView:self.view];
    }
}

#pragma mark - audio playback methods

- (IBAction)playPause:(id)sender {
    // stop
    if ([self.audioPlayer isPlaying]) {
        [self stopPlayback];
    }
    // play
    else {
        [self playbackRecording];
    }
}


- (void) playbackRecording {
    // PLAY
    if ([self.audioPlayer prepareToPlay] && [self.audioPlayer play]) {
        // show stop button
        [self.playPauseIndicator setImage:[UIImage imageNamed:@"btn-stop-med.png"]];
        // begin "onEnterFrame"
        self.onEnterFrame = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateView)];
        [self.onEnterFrame addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    } else {
        NSLog(@"could not play recording");
    }
}

- (void) stopPlayback {
    
    if ([self.audioPlayer isPlaying]) [self.audioPlayer stop];
    
    [self.audioPlayer setCurrentTime:0];
    // reset GUI
    [self.durationLabel setText:[NSString stringWithFormat:@":%@",[_tungObjects.durationFormatter stringFromNumber:[NSNumber numberWithDouble:self.audioPlayer.duration]]]];
    _playProgress.progress = 0;
    [self.playPauseIndicator setImage:[UIImage imageNamed:@"btn-play-med.png"]];
    // stop "onEnterFrame"
    [self.onEnterFrame invalidate];
    
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

#pragma mark - picker view delegate/data source methods

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [_tungObjects.categories objectAtIndex:row];
}

// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [_tungObjects.categories count];
}

#pragma mark - text view delegate methods

- (void)textViewDidChange:(UITextView *)textView {
    [self formatKeyboardLabel:textView];
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
    [self formatKeyboardLabel:textView];
    // fade out other elements
    [self fadeOutImageView:self.tapToAddCaptionLabel];
    [self fadeOutImageView:self.categoryTextField];
    [self fadeOutImageView:self.playPauseIndicator];
    [self fadeOutImageView:self.durationLabel];
    [self fadeOutImageView:_playProgress];
    
    // starting frames
    _startingCaptionTextViewFrame = self.captionTextView.frame;
    _startingCaptionBkgdViewFrame = self.captionBkgd.frame;
    _startingCaptionArrowFrame = self.captionArrow.frame;
    
    // grow text view and background image
    [UIView beginAnimations:@"grow text view" context:nil];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
    [UIView setAnimationDuration:0.3];
    CGRect enlargedTextViewFrame = CGRectMake(20, 20, self.captionTextView.frame.size.width, 136);
    self.captionTextView.frame = enlargedTextViewFrame;
    CGRect enlargedBkgdImageViewFrame = CGRectMake(15, 20, self.captionBkgd.frame.size.width, 144);
    self.captionBkgd.frame = enlargedBkgdImageViewFrame;
    CGRect movedArrowImageViewFrame = CGRectMake(38, 1, 28, 19);
    self.captionArrow.frame = movedArrowImageViewFrame;
    self.captionArrow.alpha = 0;
    [UIView commitAnimations];
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    if ([self.captionTextView.text isEqualToString:@""]) {
        [self fadeInImageView:self.tapToAddCaptionLabel];
    }
    // grow text view and background image
    [UIView beginAnimations:@"shrink text view" context:nil];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
    [UIView setAnimationDuration:0.2];
    
    self.captionTextView.frame = _startingCaptionTextViewFrame;
    self.captionBkgd.frame = _startingCaptionBkgdViewFrame;
    self.captionArrow.frame = _startingCaptionArrowFrame;
    
    self.captionArrow.alpha = 1;
    [UIView commitAnimations];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    // keep text limited to MAX_CAPTION_CHARS
    if (range.location >= MAX_CAPTION_CHARS) {
    	return NO; // return NO to not change text
    } else {
    	return YES;
    }
}

- (void) formatKeyboardLabel:(UITextView *)textView {
    
    NSInteger remaining = MAX_CAPTION_CHARS-[textView.text length];
    _keyboardLabel.text = [NSString stringWithFormat:@"%ld", (long)remaining];
    if (remaining > 20) _keyboardLabel.textColor = [UIColor lightGrayColor];
    else if (remaining > 10) _keyboardLabel.textColor = [UIColor darkGrayColor];
    else if (remaining > 0) _keyboardLabel.textColor = [UIColor redColor];
}

#pragma mark - text field delegate methods

- (void) textFieldDidBeginEditing:(UITextField *)textField {
    _keyboardLabel.textColor = [UIColor lightGrayColor];
    _keyboardLabel.text = @"Change category";
}
- (void) textFieldDidEndEditing:(UITextField *)textField {
    NSInteger selection = [self.categoryPicker selectedRowInComponent:0];
    _selectedCategory = [NSNumber numberWithInteger:selection];
    self.categoryTextField.text = [_tungObjects.categoryHashtags objectAtIndex:selection];
    [self conformUItoSelectedCategory];
}

#pragma mark - animation methods

- (void)fadeInImageView:(UIView *)view {
    [UIView animateWithDuration:0.2 animations:^{
                     	view.alpha = 1;
                     }
     ];
    
}
- (void)fadeOutImageView:(UIView *)view {
    [UIView animateWithDuration:0.2 animations:^{
                         view.alpha = 0;
                     }
     ];
    
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    
    if ([animationID isEqualToString:@"grow text view"]) {
        if ([finished boolValue]) {
            self.btn_playPause.hidden = YES;
        }
    }
    if ([animationID isEqualToString:@"shrink text view"]) {
        if ([finished boolValue]) {
            self.btn_playPause.hidden = NO;
            // fade in elements
            [self fadeInImageView:self.categoryTextField];
            [self fadeInImageView:self.playPauseIndicator];
            [self fadeInImageView:self.durationLabel];
            [self fadeInImageView:_playProgress];
        }
    }
}

#pragma mark - table delegate methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    float screenHeight = [[UIScreen mainScreen]bounds].size.height;
    float shareToggleHeight = 60;
    float openShareToggleHeight = 104;
    float postBtnCellHeight = screenHeight - 343;
    float shrunkPostBtnCellHeight = screenHeight - 387;
    
    // twitter sharing cell
    if (indexPath.row == 0) {
        return shareToggleHeight;
    }
    // facebook sharing cell
    else if (indexPath.row == 1) {
        if ([self.facebookShareToggle isOn]) {
            return openShareToggleHeight;
            //return shareToggleHeight;
        }
        else {
            return shareToggleHeight;
        }
    }
    // post btn cell
    else {
        if ([self.facebookShareToggle isOn]) {
            //NSLog(@"shrunk post button cell height (%f)", shrunkPostBtnCellHeight);
            return shrunkPostBtnCellHeight;
        }
        else {
            //NSLog(@"post button cell height (%f)", postBtnCellHeight);
            return postBtnCellHeight;
        }
    }
}

#pragma mark - actionsheet methods

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    if (actionSheet.tag == 1) {
        // don't save
        if (buttonIndex == 0) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        // save as draft
        else if (buttonIndex == 1) {
            [self saveAsDraft];
        }
    }
    // twitter account choice
    else if (actionSheet.tag == 2) {
        _working = NO;
        _tungObjects.twitterAccountToUse = [_tungObjects.arrayOfTwitterAccounts objectAtIndex:buttonIndex];
        NSLog(@"chose account with username: %@", _tungObjects.twitterAccountToUse.username);
        [_userData setObject:_tungObjects.twitterAccountToUse.username forKey:@"twitter_username"];
        NSLog(@"updated user data: %@", _userData);
        [tungCommonObjects saveUserData:_userData];
    }
}

#pragma mark - alertview methods

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    // no twitter access alert
    if (alertView.tag == 1) {
        // turn off twitter sharing
        [self.twitterShareToggle setOn:NO animated:YES];
        [self fadeOutImageView:self.twitterShareIcon];
    }
    if (alertView.tag == 2) {
        // turn off facebook sharing
        [self fadeOutImageView:self.facebookShareIcon];
        [self.facebookShareToggle setOn:NO animated:YES];
        [self.tableView beginUpdates];
        [self.tableView endUpdates];
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    [self stopPlayback];
//    UIViewController *destination = segue.destinationViewController;
//    // info to pass to next view controller
//    if ([[segue identifier] isEqualToString:@"toCollectionView"]) {
//        NSMutableDictionary *recordingInfoDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys: self.pathToRecordingFile, @"pathToRecordingFile", nil];
//        [destination setValue:recordingInfoDictionary forKey:@"recordingInfoDictionary"];
//    }
}

@end
