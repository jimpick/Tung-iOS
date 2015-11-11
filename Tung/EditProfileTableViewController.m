//
//  SignUpTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 10/17/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "EditProfileTableViewController.h"
#import "TungCommonObjects.h"
#import <Social/Social.h>
#import <FacebookSDK/FacebookSDK.h>
#import "AppDelegate.h"

#define MAX_BIO_CHARS 160

@interface EditProfileTableViewController ()

@property (strong, nonatomic) UILabel *keyboardLabel;
@property (strong, nonatomic) NSArray *fields;
@property (nonatomic, assign) NSUInteger activeFieldIndex;
@property (strong, nonatomic) UIToolbar *keyboardToolbar;
@property (strong, nonatomic) UIBarButtonItem *backBarItem;
@property (strong, nonatomic) UIBarButtonItem *nextBarItem;
@property (strong, nonatomic) UIBarButtonItem *fspace;
@property (strong, nonatomic) UIBarButtonItem *keyboardLabelBarItem;
@property (strong, nonatomic) UIBarButtonItem *validationIndicatorItem;
@property (strong, nonatomic) UIImageView *validationIndicator;
@property (nonatomic, assign) BOOL prevHideBioLabel;
@property (strong, nonatomic) NSMutableDictionary *fieldErrors;
@property (strong, nonatomic) NSTimer *usernameCheckTimer;
@property (nonatomic, retain) TungCommonObjects *tung;
@property (nonatomic, assign) BOOL working;
@property (strong, nonatomic) UserEntity *userEntity;

@end

@implementation EditProfileTableViewController

static UIImage *iconGreenCheck;
static UIImage *iconRedX;

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    
    iconGreenCheck = [UIImage imageNamed:@"icon-check-green.png"];
    iconRedX = [UIImage imageNamed:@"icon-X-red.png"];
    
    // purpose
    if ([_purpose isEqualToString:@"signup"]) {
        // signup
        self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tungNavBarLogo.png"]];
        self.navigationItem.rightBarButtonItem.title = @"Next";
        self.navigationItem.leftBarButtonItem.title = @"Back";
        _refreshAvatarBtn.hidden = YES;
        [self createAvatarSizesAndSetAvatarWithCallback:nil];
        
    } else {
        // edit profile
        self.navigationItem.title = @"Edit Profile";
        self.navigationItem.rightBarButtonItem.title = @"Save";
        self.navigationItem.leftBarButtonItem.title = @"Cancel";
        _refreshAvatarBtn.hidden = NO;
        _profileData = [[_tung getLoggedInUserData] mutableCopy];
        _userEntity = [TungCommonObjects retrieveUserEntityForUserWithId:_tung.tungId];
        [self setAvatarFromExistingAvatar];
    }
    // fields array
    _fields = @[_field_username, _field_name, _field_email, _field_location, _field_bio, _field_url];
    
    // navigation bar
    self.navigationController.navigationBar.barTintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.translucent = NO;
    
    // table view
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [TungCommonObjects bkgdGrayColor];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.scrollsToTop = YES;
    self.tableView.separatorColor = [TungCommonObjects tungColor];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
    self.tableView.bounces = NO;
    
    // get keyboard height when keyboard is shown and inset table
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidAppear:) name:UIKeyboardDidShowNotification object:nil];
    
    CGFloat screenWidth = self.view.bounds.size.width;
    // input view toolbar
    _keyboardToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 44)];
    _keyboardToolbar.tintColor = [TungCommonObjects tungColor];
    // bar button items
    _keyboardLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 44)];
    _keyboardLabel.textColor = [UIColor lightGrayColor];
    _keyboardLabel.textAlignment = NSTextAlignmentCenter;
    _keyboardLabelBarItem = [[UIBarButtonItem alloc] initWithCustomView:_keyboardLabel];
    _backBarItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"UIButtonBarArrowLeft.png"] style:UIBarButtonItemStylePlain target:self action:@selector(navigateFormFields:)];
    _backBarItem.tag = 1;
    _nextBarItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"UIButtonBarArrowRight.png"] style:UIBarButtonItemStylePlain target:self action:@selector(navigateFormFields:)];
    _nextBarItem.tag = 0;
    _validationIndicator = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 50, 44)];
    _validationIndicator.contentMode = UIViewContentModeCenter;
    _validationIndicator.image = iconGreenCheck;
    _validationIndicatorItem = [[UIBarButtonItem alloc] initWithCustomView:_validationIndicator];
    _fspace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    _keyboardToolbar.barStyle = UIBarStyleDefault;
    [_keyboardToolbar setItems:@[_backBarItem, _fspace, _keyboardLabelBarItem, _fspace, _nextBarItem]];
    
    // set up fields and pre-load fields with profile data
    //CLS_LOG(@"profile data: %@", _profileData);
    _field_username.text = [_profileData objectForKey:@"username"];
    _field_username.delegate = self;
    _field_username.inputAccessoryView = _keyboardToolbar;
    [_field_username addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    _field_name.text = [_profileData objectForKey:@"name"];
    _field_name.delegate = self;
    _field_name.inputAccessoryView = _keyboardToolbar;
    [_field_name addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    if ([_profileData objectForKey:@"email"]) _field_email.text = [_profileData objectForKey:@"email"];
    _field_email.delegate = self;
    _field_email.inputAccessoryView = _keyboardToolbar;
    [_field_email addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    _field_location.text = [_profileData objectForKey:@"location"];
    _field_location.delegate = self;
    _field_location.inputAccessoryView = _keyboardToolbar;
    [_field_location addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    _field_url.text = [_profileData objectForKey:@"url"];
    _field_url.delegate = self;
    _field_url.inputAccessoryView = _keyboardToolbar;
    [_field_url addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    // bio - limit to MAX_BIO_CHARS
    NSString *trimmedBio = @"";
    if ([[_profileData objectForKey:@"bio"] length] > MAX_BIO_CHARS) {
        trimmedBio = [[_profileData objectForKey:@"bio"] substringToIndex:MAX_BIO_CHARS];
    } else {
        trimmedBio = [_profileData objectForKey:@"bio"];
    }
    _field_bio.text = trimmedBio;
    _field_bio.delegate = self;
    _field_bio.inputAccessoryView = _keyboardToolbar;
    
    // for hiding Bio label
    _prevHideBioLabel = NO;
    // errors dict
    _fieldErrors = [[NSMutableDictionary alloc] init];
    
}

- (void) keyboardDidAppear:(NSNotification*)notification {
    
    NSDictionary* keyboardInfo = [notification userInfo];
    NSValue* keyboardFrameBegin = [keyboardInfo valueForKey:UIKeyboardFrameBeginUserInfoKey];
    CGRect keyboardRect = [keyboardFrameBegin CGRectValue];
    //CLS_LOG(@"keyboard rect: %@", NSStringFromCGRect(keyboardRect));
    
    self.tableView.contentInset =  UIEdgeInsetsMake(0, 0, keyboardRect.size.height, 0);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {

    // registration errors from FinishSignUpController?
    if (_registrationErrors != NULL) {
        if ([_registrationErrors count] > 0) {
            CLS_LOG(@"registration errors");
            // alert error(s)
            NSArray *regErrors = [_registrationErrors allValues];
            NSString *regErrorsString = [regErrors componentsJoinedByString:@"\n"];
            UIAlertView *regErrorsAlert = [[UIAlertView alloc] initWithTitle:@"Oops!" message:regErrorsString delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [regErrorsAlert setTag:1];
            [regErrorsAlert show];
        }
    }
}

- (void) viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:YES];
    @try {
        [self removeObserver:self forKeyPath:@"tung.twitterAccountStatus"];
    }
    @catch (NSException *exception) {}
    @finally {}
}

- (void) viewDidAppear:(BOOL)animated {
    
    _activeFieldIndex = 0;
    [[_fields objectAtIndex:_activeFieldIndex] becomeFirstResponder];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (IBAction)leftBarItem:(id)sender {
    
    if ([_purpose isEqualToString:@"signup"])
        [self performSegueWithIdentifier:@"unwindToWelcome" sender:self];
    else
        [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)rightBarItem:(id)sender {
    // required fields
    if (_field_username.text.length == 0) [_fieldErrors setObject:@"A username is required" forKey:@"username"];
    if (_field_name.text.length == 0) [_fieldErrors setObject:@"Name is required" forKey:@"name"];
    if (_field_email.text.length == 0) [_fieldErrors setObject:@"Email is required" forKey:@"email"];
    if (_field_bio.text.length > MAX_BIO_CHARS) [_fieldErrors setObject:@"Bio can't exceed 160 characters" forKey:@"bio"];
    // check for errors
    if ([_fieldErrors count] > 0) {
        // display error alert
        NSArray *errors = [_fieldErrors allValues];
        NSString *errorsString = [errors componentsJoinedByString:@"\n"];
        UIAlertView *errorsAlert = [[UIAlertView alloc] initWithTitle:@"Please correct the following" message:errorsString delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [errorsAlert show];
    } else {
        if ([_purpose isEqualToString:@"signup"]) {
            [self performSegueWithIdentifier:@"finishSignUp" sender:self];
        } else {
            [self updateProfileData];
        }
    }
}

#pragma mark - Update request

- (void) updateProfileData {
    
    CLS_LOG(@"update profile data");
    
    // make updates server-side
    self.navigationItem.title = @"Saving...";
    
    NSDictionary *updates = @{ @"name": _field_name.text,
                               @"username": _field_username.text,
                               @"email": _field_email.text,
                               @"location": _field_location.text,
                               @"bio": _field_bio.text,
                               @"url": _field_url.text };
    
    [_tung updateUserWithDictionary:updates withCallback:^(NSDictionary *responseDict) {
        if ([responseDict objectForKey:@"success"]) {
            self.navigationItem.title = @"Saved";
            // update profileData with user inputted values
            [_profileData setValue:_field_name.text forKey:@"name"];
            [_profileData setValue:_field_username.text forKey:@"username"];
            [_profileData setValue:_field_location.text forKey:@"location"];
            [_profileData setValue:_field_bio.text forKey:@"bio"];
            [_profileData setValue:_field_url.text forKey:@"url"];
            [_profileData setValue:_field_email.text forKey:@"email"];
            
            [TungCommonObjects saveUserWithDict:_profileData];
            
            _tung.profileNeedsRefresh = [NSNumber numberWithBool:YES];
            _tung.feedNeedsRefresh = [NSNumber numberWithBool:YES];
            
            [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(leftBarItem:) userInfo:nil repeats:NO];
        }
        else if ([responseDict objectForKey:@"error"]) {
            CLS_LOG(@"error updating user: %@", [responseDict objectForKey:@"error"]);
            self.navigationItem.title = @"Edit Profile";
            UIAlertView *updateProfileErrorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:[responseDict objectForKey:@"error"] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [updateProfileErrorAlert show];
        } else {
            CLS_LOG(@"unknown error updating user: %@", responseDict);
            self.navigationItem.title = @"Edit Profile";
            UIAlertView *updateProfileErrorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"An unknown error occurred." delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [updateProfileErrorAlert show];
        }
    }];
    
    CLS_LOG(@"save profile data: %@", _profileData);
}

#pragma mark - Avatar related

- (void) setAvatarFromExistingAvatar {
    
    NSString *avatarUrlString = [_profileData objectForKey:@"large_av_url"];
    NSData *largeAvatarImageData = [TungCommonObjects retrieveLargeAvatarDataWithUrlString:avatarUrlString];
    _largeAvatar.avatar = [[UIImage alloc] initWithData:largeAvatarImageData];
    _largeAvatar.useFilter = 0;
    _largeAvatar.borderColor = [TungCommonObjects tungColor];
    _largeAvatar.backgroundColor = [UIColor clearColor];
}

- (void) createAvatarSizesAndSetAvatarWithCallback:(void (^)(BOOL success))callback {
    CLS_LOG(@"create avatar sizes and set avatar with callback");
    // Avatar
    NSData *dataToResize = [[NSData alloc] initWithContentsOfURL: [NSURL URLWithString: [_profileData objectForKey:@"avatarURL"]]];
    UIImage *imageToResize = [[UIImage alloc] initWithData:dataToResize];
    //CLS_LOG(@"file size before resizing: %lu b", (unsigned long)[dataToResize length]);
    // resize to "large" size
    CGSize largeSize = CGSizeMake(640, 640);
    UIImage* largeImage = [self image:imageToResize scaledToFitSize:largeSize];
    NSData *largeAvatarImageData = UIImageJPEGRepresentation(largeImage, 0.5);
    //CLS_LOG(@"file size AFTER resizing large image: %lu b", (unsigned long)[largeAvatarImageData length]);
    // resize to small size
    CGSize smallSize = CGSizeMake(120, 120);
    UIImage* smallImage = [self image:imageToResize scaledToFitSize:smallSize];
    NSData *smallAvatarImageData = UIImageJPEGRepresentation(smallImage, 0.9);
    //CLS_LOG(@"file size AFTER resizing small image: %lu b", (unsigned long)[smallAvatarImageData length]);
    
    // save in temp folder and set profileData values
    NSString *largeAvatarFilename = @"large_avatar.jpg";
    NSString *smallAvatarFilename = @"small_avatar.jpg";
    NSString *pathToLargeAvatarImageData = [NSTemporaryDirectory() stringByAppendingPathComponent:largeAvatarFilename];
    NSString *pathToSmallAvatarImageData = [NSTemporaryDirectory() stringByAppendingPathComponent:smallAvatarFilename];
    BOOL wroteLargeFile = [largeAvatarImageData writeToFile:pathToLargeAvatarImageData atomically:YES];
    BOOL wroteSmallFile = [smallAvatarImageData writeToFile:pathToSmallAvatarImageData atomically:YES];
    if (wroteLargeFile && wroteSmallFile) {
        [_profileData setValue:pathToLargeAvatarImageData forKey:@"pathToLargeAvatarImageData"];
        [_profileData setValue:pathToSmallAvatarImageData forKey:@"pathToSmallAvatarImageData"];
        [_profileData setValue:largeAvatarFilename forKey:@"largeAvatarFilename"];
        [_profileData setValue:smallAvatarFilename forKey:@"smallAvatarFilename"];
        [_profileData removeObjectForKey:@"avatarURL"];
        if (callback) callback(YES);
    } else {
        if (callback) callback(NO);
    }
    // set image for avatar view
    _largeAvatar.avatar = [[UIImage alloc] initWithData:largeAvatarImageData];
    _largeAvatar.useFilter = 0;
    _largeAvatar.borderColor = [TungCommonObjects tungColor];
    _largeAvatar.backgroundColor = [UIColor clearColor];
    [_largeAvatar setNeedsDisplay];
}

- (UIImage *) image:(UIImage *)img scaledToSize:(CGSize)size {
    //create drawing context
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    //draw
    [img drawInRect:CGRectMake(0.0f, 0.0f, size.width, size.height)];
    //capture resultant image
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //return image
    return image;
}

- (UIImage *) image:(UIImage *)img scaledToFitSize:(CGSize)size {
    //calculate rect
    CGFloat aspect = img.size.width / img.size.height;
    if (size.width / aspect <= size.height) {
        return [self image:img scaledToSize:CGSizeMake(size.width, size.width / aspect)];
    }
    else {
        return [self image:img scaledToSize:CGSizeMake(size.height * aspect, size.height)];
    }
}

- (IBAction)updateAvatarPrompt:(id)sender {
    
    NSString *account;
    if (_userEntity.facebook_id) {
        account = @"Facebook";
    }
    else {
        account = @"Twitter";
    }
    NSString *message = [NSString stringWithFormat:@"Your avatar will be changed to the one currently being used by your %@ account. Sound good?", account];
    UIAlertView *changeAvatarConfirm = [[UIAlertView alloc] initWithTitle:@"Update Avatar?" message:message delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
    changeAvatarConfirm.tag = 79;
    [changeAvatarConfirm show];
}

- (void) establishAccountForAvatarRequest {
    CLS_LOG(@"establish account for avatar request");
    // spin
    _avatarActivityIndicator.hidden = NO;
    [_avatarActivityIndicator startAnimating];
    _working = YES;
    
    NSDictionary *userData = [_tung getLoggedInUserData];
    if ([[userData objectForKey:@"facebook_id"] integerValue] > 0) {
        // Facebook
        NSString *avatarURL = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=square&height=640&width=640", [userData objectForKey:@"facebook_id"]];
        
        [_profileData setObject:avatarURL forKey:@"avatarURL"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self createAvatarSizesAndSetAvatarWithCallback:^(BOOL success) {
                if (success) {
                    [self updateAvatar];
                } else {
                    CLS_LOG(@"error creating avatar sizes");
                }
            }];
        });

    }
    else if ([[userData objectForKey:@"twitter_id"] integerValue] > 0) {
        // Twitter
        if (_tung.twitterAccountToUse == NULL) {
            [self addObserver:self forKeyPath:@"tungObjects.twitterAccountStatus" options:NSKeyValueObservingOptionNew context:nil];
            [_tung establishTwitterAccount];
        }
        else {
            [self getTwitterAvatarUrl];
        }
    }
}

// wait for twitter account to be established, then request avatar url
-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    //CLS_LOG(@"----- value changed for key: %@, change: %@", keyPath, change);
    
    if ([keyPath isEqualToString:@"tung.twitterAccountStatus"]) {
        if ([_tung.twitterAccountStatus isEqualToString:@"failed"]) {
            [_avatarActivityIndicator stopAnimating];
            _working = NO;
        }
        else if ([_tung.twitterAccountStatus isEqualToString:@"success"]) {
            [self getTwitterAvatarUrl];
        }
    }
}

- (void) getTwitterAvatarUrl {
    CLS_LOG(@"get twitter avatar url");
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@account/verify_credentials.json", _tung.twitterApiRootUrl]];
    SLRequest *getAvatarRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:requestURL parameters:nil];
    getAvatarRequest.account = _tung.twitterAccountToUse;
    
    [getAvatarRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        //CLS_LOG(@"	Twitter HTTP response: %li", (long)[urlResponse statusCode]);
        //NSString *html = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        //CLS_LOG(@"HTML: %@", html);
        if (error != nil) CLS_LOG(@"Error: %@", error);
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
        if (jsonData != nil && error == nil) {
            NSDictionary *accountData = jsonData;
            //CLS_LOG(@"%@", accountData);
            if ([accountData objectForKey:@"errors"]) {
                CLS_LOG(@"Errors: %@", [accountData objectForKey:@"errors"]);
                error = nil;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_avatarActivityIndicator stopAnimating];
                    [accountStore renewCredentialsForAccount:_tung.twitterAccountToUse completion:^(ACAccountCredentialRenewResult renewResult, NSError *error) {
                        _working = NO;
                    }];
                });
            } else {
                // make image big by removing "_normal"
                NSMutableString *avatarURL = [[accountData objectForKey:@"profile_image_url"] mutableCopy];
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(_normal)" options:0 error:nil];
                [regex replaceMatchesInString:avatarURL options:0 range:NSMakeRange(0, [avatarURL length]) withTemplate:@""];
                
                CLS_LOG(@"profile dictionary: %@", _profileData);
                
                [_profileData setObject:avatarURL forKey:@"avatarURL"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self createAvatarSizesAndSetAvatarWithCallback:^(BOOL success) {
                        if (success) {
                            [self updateAvatar];
                        } else {
                            CLS_LOG(@"error creating avatar sizes");
                        }
                    }];
                });

            }
        }
    }];
}

// posts new avatar images to server
- (void) updateAvatar {
    CLS_LOG(@"update avatar request");
    // create request object
    NSURL *updateAvatarRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/update-avatar.php", _tung.apiRootUrl]];
    NSMutableURLRequest *updateAvatarRequest = [NSMutableURLRequest requestWithURL:updateAvatarRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [updateAvatarRequest setHTTPMethod:@"POST"];
    // add content type
    NSString *boundary = [TungCommonObjects generateHash];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [updateAvatarRequest addValue:contentType forHTTPHeaderField:@"Content-Type"];
    // add post body
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    // key value pairs
    NSDictionary *params = @{@"sessionId":_tung.sessionId};
    [body appendData:[TungCommonObjects generateBodyFromDictionary:params withBoundary:boundary]];
    // large avatar
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"large_avatar\"; filename=\"%@\"\r\n", [_profileData objectForKey:@"largeAvatarFilename"]] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    NSURL *largeAvatarDataURL = [NSURL fileURLWithPath:[_profileData objectForKey:@"pathToLargeAvatarImageData"]];
    NSData *largeAvatarData = [[NSData alloc] initWithContentsOfURL:largeAvatarDataURL];
    [body appendData:largeAvatarData];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    // small avatar
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"small_avatar\"; filename=\"%@\"\r\n", [_profileData objectForKey:@"smallAvatarFilename"]] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    NSURL *smallAvatarDataURL = [NSURL fileURLWithPath:[_profileData objectForKey:@"pathToSmallAvatarImageData"]];
    NSData *smallAvatarData = [[NSData alloc] initWithContentsOfURL:smallAvatarDataURL];
    [body appendData:smallAvatarData];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    // end of body
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [updateAvatarRequest setHTTPBody:body];
    // set the content-length
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
    [updateAvatarRequest setValue:postLength forHTTPHeaderField:@"Content-Length"];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:updateAvatarRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        if (jsonData != nil && error == nil) {
            NSDictionary *responseDict = jsonData;
            //CLS_LOG(@"responseDict: %@", responseDict);
            // errors?
            if ([responseDict objectForKey:@"error"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [_tung getSessionWithCallback:^{
                            [self updateAvatar];
                        }];
                    }
                });
            }
            // success
            else if ([responseDict objectForKey:@"success"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // stop spinner
                    [_avatarActivityIndicator stopAnimating];
                    _working = NO;
                    // unset temp profile data keys
                    [_profileData removeObjectForKey:@"pathToLargeAvatarImageData"];
                    [_profileData removeObjectForKey:@"pathToSmallAvatarImageData"];
                    [_profileData removeObjectForKey:@"largeAvatarFilename"];
                    [_profileData removeObjectForKey:@"smallAvatarFilename"];
                    // set new values
                    [_profileData setObject:[[responseDict objectForKey:@"success"] objectForKey:@"small_av_url"] forKey:@"small_av_url"];
                    [_profileData setObject:[[responseDict objectForKey:@"success"] objectForKey:@"large_av_url"] forKey:@"large_av_url"];
                    // save
                    CLS_LOG(@"saving new profile data: %@", _profileData);
                    [TungCommonObjects saveUserWithDict:_profileData];
                    // set "needs reload" flag
                    _tung.feedNeedsRefresh = [NSNumber numberWithBool:YES];
                });
            }
        }
        else if ([data length] == 0 && error == nil) {
            CLS_LOG(@"no response");
        }
        else if (error != nil) {
            CLS_LOG(@"Error: %@", error);
            NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            CLS_LOG(@"HTML: %@", html);
        }
        
    }];
}

#pragma mark - form fields

- (void)navigateFormFields:(id)sender {
    NSUInteger tag = 0;
    if ([sender tag]) {
        tag = [sender tag];
    }
    // back
    if (tag == 1) {
        _nextBarItem.enabled = YES;
        //CLS_LOG(@"back. current active field: %lu", (unsigned long)_activeFieldIndex);
        if (_activeFieldIndex == 0) {
            if ([_purpose isEqualToString:@"signup"])
                [self leftBarItem:nil];
        } else {
            _activeFieldIndex--;
        }
    }
    // next
    else {
        _backBarItem.enabled = YES;
        //CLS_LOG(@"next. current active field: %lu", (unsigned long)_activeFieldIndex);
        if (_activeFieldIndex == _fields.count - 1) {
            if ([_purpose isEqualToString:@"signup"])
                [self rightBarItem:nil];
        } else {
            _activeFieldIndex++;
        }
    }
    
    //CLS_LOG(@"- new active field: %lu", (unsigned long)_activeFieldIndex);
    [self makeActiveFieldFirstResponder];
}

-(void)makeActiveFieldFirstResponder {
    [[_fields objectAtIndex:_activeFieldIndex] becomeFirstResponder];
    
    // scroll to active field
    NSIndexPath *activeFieldIndexPath = [NSIndexPath indexPathForRow:_activeFieldIndex + 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:activeFieldIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}


-(void) performAppropriateValidationOnTextField:(UITextField *)textField {
    // validation
    switch (textField.tag) {
        case 0: // username
            [self validateUsernameField:textField];
            break;
        case 1: // name
            [self validateTextField:textField optional:NO];
            break;
        case 2: // email
            [self validateEmailField:textField];
            break;
        case 3: // location
            [self validateTextField:textField optional:YES];
            break;
        case 4: // url
            [self validateURLField:textField];
            break;
    }
    [self enableOrDisableFieldNavButtons];
}
-(void) enableOrDisableFieldNavButtons {
    // if we are on the first field and this is for editing profile, disable last-field button
    if (_activeFieldIndex == 1 && ![_purpose isEqualToString:@"signup"]) {
        _backBarItem.enabled = NO;
    } else {
        _backBarItem.enabled = YES;
    }
    // if we are on the last field and this is for editing profile, disable next-field button
    if (_activeFieldIndex == _fields.count - 1 && ![_purpose isEqualToString:@"signup"]) {
        _nextBarItem.enabled = NO;
    } else {
        _nextBarItem.enabled = YES;
    }
}

-(void) validateUsernameField:(UITextField *)textField {
    if ([textField.text length] > 0) {
        NSRegularExpression *usernameRegex = [NSRegularExpression regularExpressionWithPattern:@"^[a-zA-Z0-9_]{1,15}$" options:0 error:nil];
        NSUInteger match = [usernameRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            // valid
            _validationIndicator.image = iconGreenCheck;
            [_fieldErrors removeObjectForKey:@"username"];
            // check availability
            [_usernameCheckTimer invalidate];
            _usernameCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(checkUsernameAvailability) userInfo:nil repeats:NO];
        } else {
            // invalid
            _validationIndicator.image = iconRedX;
            [_fieldErrors setObject:@"Invalid username" forKey:@"username"];
        }
    } else {
        _validationIndicator.image = iconRedX;
        [_fieldErrors setObject:@"A username is required" forKey:@"username"];
    }
    [_keyboardToolbar setItems:@[_backBarItem, _fspace, _validationIndicatorItem, _fspace, _nextBarItem] animated:YES];
}

-(void) checkUsernameAvailability {
    //CLS_LOG(@"username check");
    // existing username is not invalid
    if ([_profileData objectForKey:@"username"]) {
        if ([[_profileData objectForKey:@"username"] isEqualToString:_field_username.text]) {
            return;
        }
    }
    NSString *urlAsString = [NSString stringWithFormat:@"%@users/username_check.php?username=%@", _tung.apiRootUrl, _field_username.text];
    NSURL *checkUsernameURL = [NSURL URLWithString:urlAsString];
    NSMutableURLRequest *checkUsernameRequest = [NSMutableURLRequest requestWithURL:checkUsernameURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [checkUsernameRequest setHTTPMethod:@"GET"];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:checkUsernameRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        if (jsonData != nil && error == nil) {
            NSDictionary *responseDict = jsonData;
            //CLS_LOG(@"responseDict: %@", responseDict);
            id usernameExistsId = [responseDict objectForKey:@"username_exists"];
            BOOL usernameExists = [usernameExistsId boolValue];
            if (usernameExists) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    _validationIndicator.image = iconRedX;
                    [_fieldErrors setObject:@"Username is taken" forKey:@"username"];
                });
            }
        }
    }];
}
-(void) validateTextField:(UITextField *)textField optional:(BOOL)optional {
    // for validating either Name or Location
    NSString *name = @"";
    if (textField.tag == 1) name = @"name";
    else name = @"location";
    
    if ([textField.text length] > 0) {
        NSRegularExpression *textRegex = [NSRegularExpression regularExpressionWithPattern:@"^[\\w\\d \\,\\-\\.]{1,30}$" options:NSRegularExpressionCaseInsensitive error:nil];
        NSUInteger match = [textRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            _validationIndicator.image = iconGreenCheck;
            [_fieldErrors removeObjectForKey:name];
        } else {
            _validationIndicator.image = iconRedX;
            [_fieldErrors setObject:[NSString stringWithFormat:@"Invalid %@", name] forKey:name];
        }
        [_keyboardToolbar setItems:@[_backBarItem, _fspace, _validationIndicatorItem, _fspace, _nextBarItem] animated:YES];
    } else {
        if (!optional) {
            _validationIndicator.image = iconRedX;
            [_keyboardToolbar setItems:@[_backBarItem, _fspace, _validationIndicatorItem, _fspace, _nextBarItem] animated:YES];
            [_fieldErrors setObject:[NSString stringWithFormat:@"A %@ is required", name] forKey:name];
        } else {
            [_keyboardToolbar setItems:@[_backBarItem, _fspace, _nextBarItem] animated:YES];
            [_fieldErrors removeObjectForKey:name];
        }
    }
}
-(void) validateEmailField:(UITextField *)textField {
    if ([textField.text length] > 0) {
        NSString *emailRegexString = @"^[\\w\\d\\+\\.\\-]+@[a-zA-Z\\d\\.\\-]+\\.[a-zA-Z]{2,15}$";
        NSRegularExpression *emailRegex = [NSRegularExpression regularExpressionWithPattern:emailRegexString options:NSRegularExpressionCaseInsensitive error:nil];
        NSUInteger match = [emailRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            _validationIndicator.image = iconGreenCheck;
            [_fieldErrors removeObjectForKey:@"email"];
        } else {
            _validationIndicator.image = iconRedX;
            [_fieldErrors setObject:@"Invalid Email" forKey:@"email"];
        }
    } else {
        _validationIndicator.image = iconRedX;
        [_fieldErrors setObject:@"Email is required" forKey:@"email"];
    }
    [_keyboardToolbar setItems:@[_backBarItem, _fspace, _validationIndicatorItem, _fspace, _nextBarItem] animated:YES];
}
-(void) validateURLField:(UITextField *)textField {
    if ([textField.text length] > 0) {
        NSString *urlRegexString = @"^(https?:\\/\\/)?[a-zA-Z\\d\\.\\-]+\\.[a-zA-Z]{2,15}([\\/\\w-]*)*\\/?\\??([^#\\n\\r\\s]*)?#?([^\\n\\r\\s]*)$";
        NSRegularExpression *urlRegex = [NSRegularExpression regularExpressionWithPattern:urlRegexString options:NSRegularExpressionCaseInsensitive error:nil];
        NSUInteger match = [urlRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            _validationIndicator.image = iconGreenCheck;
            [_fieldErrors removeObjectForKey:@"URL"];
        } else {
            _validationIndicator.image = iconRedX;
            [_fieldErrors setObject:@"Invalid URL" forKey:@"URL"];
        }
        [_keyboardToolbar setItems:@[_backBarItem, _fspace, _validationIndicatorItem, _fspace, _nextBarItem] animated:YES];
    } else {
        [_keyboardToolbar setItems:@[_backBarItem, _fspace, _nextBarItem] animated:YES];
        [_fieldErrors removeObjectForKey:@"URL"];
    }
}

-(void) validatePhoneField:(UITextField *)textField { // not used
    // UIDataDetectorTypePhoneNumber
    if ([textField.text length] > 0) {
        NSRegularExpression *phoneRegex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]{10,19}$" options:0 error:nil];
        NSUInteger match = [phoneRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            _validationIndicator.image = iconGreenCheck;
            [_fieldErrors removeObjectForKey:@"phone"];
        } else {
            _validationIndicator.image = iconRedX;
            [_fieldErrors setObject:@"Invalid phone number" forKey:@"phone"];
        }
        [_keyboardToolbar setItems:@[_backBarItem, _fspace, _validationIndicatorItem, _fspace, _nextBarItem] animated:YES];
    } else {
        [_keyboardToolbar setItems:@[_backBarItem, _fspace, _nextBarItem] animated:YES];
        [_fieldErrors removeObjectForKey:@"phone"];
    }
}
#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row <= _fields.count && indexPath.row > 0) {
        _activeFieldIndex = indexPath.row - 1;
        [self makeActiveFieldFirstResponder];
    }
    
}

#pragma mark - text field delegate methods

- (void) textFieldDidBeginEditing:(UITextField *)textField {
    _activeFieldIndex = textField.tag;
    [self performAppropriateValidationOnTextField:textField];
    // [self changeFirstResponderAndUpdateGUI];
}
- (void) textFieldDidEndEditing:(UITextField *)textField {
    // momentarily hide validation icon to indicate active field changing
    [_keyboardToolbar setItems:@[_backBarItem, _fspace, _nextBarItem] animated:YES];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    [self navigateFormFields:nil];
    return NO;
}

- (void)textFieldDidChange:(UITextField *)textField {
    // validate every keystroke
    [self performAppropriateValidationOnTextField:textField];
}

#pragma mark - text view delegate methods

- (void)textViewDidChange:(UITextView *)textView {
    if (textView.text.length <= MAX_BIO_CHARS && [_fieldErrors objectForKey:@"bio"]) {
        [_fieldErrors removeObjectForKey:@"bio"];
    }
    [self formatKeyboardLabel:textView];
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
    [self formatKeyboardLabel:textView];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    
    // hide Bio label if chars exceed certain limit
    BOOL hideBioLabel = NO;
    int rangeLimit = 100;
    if (range.location >= rangeLimit) hideBioLabel = YES;
    else hideBioLabel = NO;
    
    if (hideBioLabel != _prevHideBioLabel) {
        if (hideBioLabel) {
            CLS_LOG(@"hide bio label");
            [UIView animateWithDuration:0.2
                             animations:^{
                                 _label_bio.alpha = 0;
                             }
             ];
        } else {
            CLS_LOG(@"show bio label");
            [UIView animateWithDuration:0.2
                             animations:^{
                                 _label_bio.alpha = 1;
                             }
             ];
        }
    }
    _prevHideBioLabel = hideBioLabel;
    
    return YES; // always yes because user can paste past the character limit.
}

- (void) formatKeyboardLabel:(UITextView *)textView {
    //CLS_LOG(@"text length: %ld", (long)[textView.text length]);
    NSInteger remaining = MAX_BIO_CHARS-[textView.text length];
    _keyboardLabel.text = [NSString stringWithFormat:@"%ld", (long)remaining];
    if (remaining > 20) _keyboardLabel.textColor = [UIColor lightGrayColor];
    else if (remaining > 10) _keyboardLabel.textColor = [UIColor darkGrayColor];
    else if (remaining <= 10) _keyboardLabel.textColor = [UIColor orangeColor];
    
    [_keyboardToolbar setItems:@[_backBarItem, _fspace, _keyboardLabelBarItem, _fspace, _nextBarItem] animated:YES];
}

#pragma mark - navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    CLS_LOG(@"prepare for segue");
    UIViewController *destination = segue.destinationViewController;
    
    if ([[segue identifier] isEqualToString:@"finishSignUp"]) {
        // update profileData with user inputted values
        [_profileData setValue:_field_username.text forKey:@"username"];
        [_profileData setValue:_field_name.text forKey:@"name"];
        [_profileData setValue:_field_email.text forKey:@"email"];
        [_profileData setValue:_field_location.text forKey:@"location"];
        [_profileData setValue:_field_bio.text forKey:@"bio"];
        [_profileData setValue:_field_url.text forKey:@"url"];
        // set value
        [destination setValue:_profileData forKey:@"profileData"];
    }
}

- (IBAction)unwindToSignUp:(UIStoryboardSegue*)sender
{
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return 7;
}

#pragma mark - handle alerts

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    CLS_LOG(@"dismissed alert view with tag %ld and button index: %ld", (long)alertView.tag, (long)buttonIndex);
    // registration errors alert
    if (alertView.tag == 1) {
        // go to page and field with error
        NSArray *fields = [_registrationErrors allKeys];
        NSString *activeFieldString = [fields objectAtIndex:0];
        CLS_LOG(@"Error on %@", activeFieldString);
        
        if ([activeFieldString isEqualToString:@"username"]) {
            _activeFieldIndex = 0;
        }
        else if ([activeFieldString isEqualToString:@"name"]) {
            _activeFieldIndex = 1;
        }
        else if ([activeFieldString isEqualToString:@"location"]) {
            _activeFieldIndex = 2;
        }
        else if ([activeFieldString isEqualToString:@"bio"]) {
            _activeFieldIndex = 3;
        }
        else if ([activeFieldString isEqualToString:@"url"]) {
            _activeFieldIndex = 4;
        }
        else if ([activeFieldString isEqualToString:@"phone"]) {
            _activeFieldIndex = 5;
        }
        [self makeActiveFieldFirstResponder];
    }
    // change avatar
    if (alertView.tag == 79) {
        if (buttonIndex == 1) {
            [self establishAccountForAvatarRequest];
        }
    }
}

@end
