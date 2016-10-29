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
#import "FinishSignUpController.h"
#import "ProfileListTableViewController.h"

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
@property BOOL formIsForSignup;
@property BOOL formIsPristine;
@property BOOL usernameCheckUnderway;
@property BOOL checkedForPlatformFriends;
@property NSArray *suggestedUsersArray;

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
        _formIsForSignup = YES;
        _checkedForPlatformFriends = NO;
        self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tungNavBarLogo.png"]];
        self.navigationItem.rightBarButtonItem.title = @"Next";
        _refreshAvatarBtn.hidden = YES;
        [self createAvatarSizesAndSetAvatarWithCallback:nil];
        
    }
    else {
        // edit profile
        self.navigationItem.title = @"Edit Profile";
        _refreshAvatarBtn.hidden = NO;
        _profileData = [[TungCommonObjects entityToDict:_tung.loggedInUser] mutableCopy];
        _userEntity = [TungCommonObjects retrieveUserEntityForUserWithId:_tung.loggedInUser.tung_id];
        [self setAvatarFromExistingAvatar];
        // for checking if we need to save
        _formIsPristine = YES;
        [self adjustRightBarButtonForFormState];
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
    
    CGFloat screenWidth = [TungCommonObjects screenSize].width;
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
    //JPLog(@"profile data: %@", _profileData);
    if ([_profileData objectForKey:@"username"] != [NSNull null]) _field_username.text = [_profileData objectForKey:@"username"];
    _field_username.delegate = self;
    _field_username.inputAccessoryView = _keyboardToolbar;
    [_field_username addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    if ([_profileData objectForKey:@"name"] != [NSNull null]) _field_name.text = [_profileData objectForKey:@"name"];
    _field_name.delegate = self;
    _field_name.inputAccessoryView = _keyboardToolbar;
    [_field_name addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    if ([_profileData objectForKey:@"email"] != [NSNull null]) _field_email.text = [_profileData objectForKey:@"email"];
    _field_email.delegate = self;
    _field_email.inputAccessoryView = _keyboardToolbar;
    [_field_email addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    if ([_profileData objectForKey:@"location"] != [NSNull null]) _field_location.text = [_profileData objectForKey:@"location"];
    _field_location.delegate = self;
    _field_location.inputAccessoryView = _keyboardToolbar;
    [_field_location addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    if ([_profileData objectForKey:@"url"] != [NSNull null]) _field_url.text = [_profileData objectForKey:@"url"];
    _field_url.delegate = self;
    _field_url.inputAccessoryView = _keyboardToolbar;
    [_field_url addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    // bio - limit to MAX_BIO_CHARS
    NSString *trimmedBio;
    if ([_profileData objectForKey:@"bio"] != [NSNull null]) {
        if ([[_profileData objectForKey:@"bio"] length] > MAX_BIO_CHARS) {
            trimmedBio = [[_profileData objectForKey:@"bio"] substringToIndex:MAX_BIO_CHARS];
        } else {
            trimmedBio = [_profileData objectForKey:@"bio"];
        }
    } else {
        trimmedBio = @"";
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
    //JPLog(@"keyboard rect: %@", NSStringFromCGRect(keyboardRect));
    
    self.tableView.contentInset =  UIEdgeInsetsMake(0, 0, keyboardRect.size.height, 0);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    _usernameCheckUnderway = NO;
    [self validateAllFields];

    // registration errors from FinishSignUpController?
    if (_registrationErrors != NULL && [_registrationErrors count] > 0) {
        // go to page and field with error
        NSArray *fields = [_registrationErrors allKeys];
        NSString *activeFieldString = [fields objectAtIndex:0];
        //JPLog(@"Error on %@", activeFieldString);
        BOOL fieldError = YES;
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
        else {
            fieldError = NO;
        }
        // alert error(s)
        NSArray *regErrors = [_registrationErrors allValues];
        NSString *regErrorsString = [regErrors componentsJoinedByString:@"\n"];
        
        UIAlertController *errorsAlert = [UIAlertController alertControllerWithTitle:@"Oops!" message:regErrorsString preferredStyle:UIAlertControllerStyleAlert];
        [errorsAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^ (UIAlertAction * _Nonnull action) {
            if (fieldError) [self makeActiveFieldFirstResponder];
        }]];
        [self presentViewController:errorsAlert animated:YES completion:nil];
    }
}
- (void) viewWillDisappear:(BOOL)animated {
    [[_fields objectAtIndex:_activeFieldIndex] resignFirstResponder];
}

- (void) viewDidAppear:(BOOL)animated {
    
    _activeFieldIndex = 0;
    if (_formIsForSignup) {
    	[[_fields objectAtIndex:_activeFieldIndex] becomeFirstResponder];
        
        // preload platform friends for next page
        if (!_checkedForPlatformFriends) [self checkForPlatformFriends];
    }
}

- (BOOL)prefersStatusBarHidden
{
    if ([_purpose isEqualToString:@"signup"]) {
    	return YES;
    } else {
        return NO;
    }
}

- (IBAction)leftBarItem:(id)sender {
    
    [[_fields objectAtIndex:_activeFieldIndex] resignFirstResponder];
    if (_formIsForSignup)
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
        UIAlertController *errorsAlert = [UIAlertController alertControllerWithTitle:@"Please correct the following" message:errorsString preferredStyle:UIAlertControllerStyleAlert];
        [errorsAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:errorsAlert animated:YES completion:nil];
        
    } else {
        [[_fields objectAtIndex:_activeFieldIndex] resignFirstResponder];
        if (_formIsForSignup) {
            
            [self setProfileDataWithFormValues];
            
            //[self performSegueWithIdentifier:@"proceedToSuggestedUsers" sender:self];
            if ([_profileData objectForKey:@"twitterFriends"] || [_profileData objectForKey:@"facebookFriends"]) {
                // platform friends
                ProfileListTableViewController *profileListView = [self.storyboard instantiateViewControllerWithIdentifier:@"profileListView"];
                profileListView.profileData = _profileData;
                [self.navigationController pushViewController:profileListView animated:YES];
            }
            else {
                // finish sign-up
                FinishSignUpController *finishView = [self.storyboard instantiateViewControllerWithIdentifier:@"finishSignup"];
                finishView.profileData = _profileData;
                [self.navigationController pushViewController:finishView animated:YES];
            }
        }
        else {
            if (_formIsPristine) {
                [self dismissViewControllerAnimated:YES completion:nil];
            }
            else {
            	[self updateProfileData];
            }
        }
    }
}

- (void) setProfileDataWithFormValues {
    // update profileData with user inputted values
    [_profileData setValue:_field_username.text forKey:@"username"];
    [_profileData setValue:_field_name.text forKey:@"name"];
    [_profileData setValue:_field_email.text forKey:@"email"];
    [_profileData setValue:_field_location.text forKey:@"location"];
    [_profileData setValue:_field_bio.text forKey:@"bio"];
    [_profileData setValue:_field_url.text forKey:@"url"];
}

- (void) adjustRightBarButtonForFormState {
    
    if (_formIsForSignup) return;
    
    if (_formIsPristine) {
    	self.navigationItem.rightBarButtonItem.title = @"Done";
    } else {
        self.navigationItem.rightBarButtonItem.title = @"Save";
    }
}

// see if user has any friends on tung from the service they signed up with.
- (void) checkForPlatformFriends {
    
    _checkedForPlatformFriends = YES;
    
    if ([_profileData objectForKey:@"twitter_id"]) {
        
        [_tung findTwitterFriendsWithPage:[NSNumber numberWithInt:0] andCallback:^(BOOL success, NSDictionary *responseDict) {
            if (success) {
                //NSLog(@"responseDict: %@", responseDict);
                NSNumber *platformFriendsCount = [responseDict objectForKey:@"resultsCount"];
                if ([platformFriendsCount integerValue] > 0) {
                    [_profileData setObject:[responseDict objectForKey:@"results"] forKey:@"twitterFriends"];
                }
            }
        }];
        
    }
    else if ([_profileData objectForKey:@"facebook_id"]) {
        
        
        if ([FBSDKAccessToken currentAccessToken]) {
            
            NSString *tokenString = [[FBSDKAccessToken currentAccessToken] tokenString];
            [_tung findFacebookFriendsWithFacebookAccessToken:tokenString withCallback:^(BOOL success, NSDictionary *responseDict) {
                //NSLog(@"responseDict: %@", responseDict);
                NSNumber *platformFriendsCount = [responseDict objectForKey:@"resultsCount"];
                if ([platformFriendsCount integerValue] > 0) {
                    [_profileData setObject:[responseDict objectForKey:@"results"] forKey:@"facebookFriends"];
                }
                
            }];
        }
    }
    
}


#pragma mark - Update request

- (void) updateProfileData {
    
    JPLog(@"update profile data");
    
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
            
            [self setProfileDataWithFormValues];
            
            [TungCommonObjects saveUserWithDict:_profileData isLoggedInUser:YES];
            
            _tung.profileNeedsRefresh = [NSNumber numberWithBool:YES];
            _tung.feedNeedsRefetch = [NSNumber numberWithBool:YES];
            
            [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(leftBarItem:) userInfo:nil repeats:NO];
        }
        else if ([responseDict objectForKey:@"error"]) {
            JPLog(@"error updating user: %@", [responseDict objectForKey:@"error"]);
            self.navigationItem.title = @"Edit Profile";
            [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
        } else {
            JPLog(@"unknown error updating user: %@", responseDict);
            self.navigationItem.title = @"Edit Profile";
            [TungCommonObjects simpleErrorAlertWithMessage:@"An unknown error occurred"];
        }
    }];
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
    //JPLog(@"create avatar sizes and set avatar with callback");
    // Avatar
    NSData *dataToResize = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString: [_profileData objectForKey:@"avatarURL"]]];
    UIImage *imageToResize = [[UIImage alloc] initWithData:dataToResize];
    //JPLog(@"file size before resizing: %lu b", (unsigned long)[dataToResize length]);
    // resize to "large" size
    UIImage *largeImage = [TungCommonObjects image:imageToResize croppedAndScaledToSquareSizeWithDimension:640];
    NSData *largeAvatarImageData = UIImageJPEGRepresentation(largeImage, 0.7);
    //JPLog(@"file size AFTER resizing large image: %lu b", (unsigned long)[largeAvatarImageData length]);
    // resize to small size
    UIImage *smallImage = [TungCommonObjects image:imageToResize croppedAndScaledToSquareSizeWithDimension:120];
    NSData *smallAvatarImageData = UIImageJPEGRepresentation(smallImage, 0.9);
    //JPLog(@"file size AFTER resizing small image: %lu b", (unsigned long)[smallAvatarImageData length]);
    
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

- (IBAction)updateAvatarPrompt:(id)sender {
    
    NSString *account;
    if (_userEntity.facebook_id) {
        account = @"Facebook";
    }
    else {
        account = @"Twitter";
    }
    NSString *message = [NSString stringWithFormat:@"Your avatar will be changed to the one currently being used by your %@ account. Sound good?", account];
    UIAlertController *changeAvatarConfirm = [UIAlertController alertControllerWithTitle:@"Update Avatar?" message:message preferredStyle:UIAlertControllerStyleAlert];
    [changeAvatarConfirm addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:nil]];
    [changeAvatarConfirm addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        [self establishAccountForAvatarRequest];
    }]];
    [self presentViewController:changeAvatarConfirm animated:YES completion:nil];
}

- (void) establishAccountForAvatarRequest {
    //JPLog(@"establish account for avatar request");
    // spin
    _avatarActivityIndicator.hidden = NO;
    [_avatarActivityIndicator startAnimating];
    _working = YES;
    
    if (_tung.loggedInUser.facebook_id) {
        // Facebook
        NSString *avatarURL = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=square&height=640&width=640", _tung.loggedInUser.facebook_id];
        
        [_profileData setObject:avatarURL forKey:@"avatarURL"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self createAvatarSizesAndSetAvatarWithCallback:^(BOOL success) {
                if (success) {
                    [self updateAvatar];
                } else {
                    JPLog(@"error creating avatar sizes");
                }
            }];
        });
    }
    else {
        // Twitter
        [self getTwitterAvatar];
    }
}


- (void) getTwitterAvatar {
    
    //TWTRSession *session = [TWTRSessionStore session];
    NSString *twitterID = [Twitter sharedInstance].sessionStore.session.userID;
    TWTRAPIClient *client = [[TWTRAPIClient alloc] initWithUserID:twitterID];
    
    NSString *verifyCredEndpoint = @"https://api.twitter.com/1.1/account/verify_credentials.json";
    NSError *clientError;
    
    NSURLRequest *request = [[[Twitter sharedInstance] APIClient] URLRequestWithMethod:@"GET" URL:verifyCredEndpoint parameters:nil error:&clientError];
    
    if (request) {
        [client sendTwitterRequest:request completion:^(NSURLResponse *urlResponse, NSData *data, NSError *connectionError) {
            NSError *error;
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            NSDictionary *accountData = jsonData;
            if ([accountData objectForKey:@"errors"]) {
                JPLog(@"Error getting twitter avatar: %@", [accountData objectForKey:@"errors"]);
            }
            else {
                // make image big by removing "_normal"
                NSMutableString *avatarURL = [[accountData objectForKey:@"profile_image_url"] mutableCopy];
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(_normal)" options:0 error:nil];
                [regex replaceMatchesInString:avatarURL options:0 range:NSMakeRange(0, [avatarURL length]) withTemplate:@""];
                
                //JPLog(@"profile dictionary: %@", _profileData);
                
                [_profileData setObject:avatarURL forKey:@"avatarURL"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self createAvatarSizesAndSetAvatarWithCallback:^(BOOL success) {
                        if (success) {
                            [self updateAvatar];
                        } else {
                            JPLog(@"error creating avatar sizes");
                        }
                    }];
                });
            }
        }];
    }
    else {
        JPLog(@"Error: %@", clientError);
    }
    
}

// posts new avatar images to server
- (void) updateAvatar {
    //JPLog(@"update avatar request");
    // create request object
    NSURL *updateAvatarRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/update-avatar.php", [TungCommonObjects apiRootUrl]]];
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
            //JPLog(@"responseDict: %@", responseDict);
            // errors?
            if ([responseDict objectForKey:@"error"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        JPLog(@"SESSION EXPIRED");
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
                    
                    // replace old avatars in temp directory
                    [TungCommonObjects replaceCachedLargeAvatarWithDataAtUrlString:[_profileData objectForKey:@"large_av_url"]];
                    [TungCommonObjects replaceCachedSmallAvatarWithDataAtUrlString:[_profileData objectForKey:@"small_av_url"]];
                    // save
                    JPLog(@"saving new profile data: %@", _profileData);
                    [TungCommonObjects saveUserWithDict:_profileData isLoggedInUser:YES];
                    // set flags
                    _tung.feedNeedsRefresh = [NSNumber numberWithBool:YES];
                    _tung.profileFeedNeedsRefresh = [NSNumber numberWithBool:YES];
                    _tung.profileNeedsRefresh = [NSNumber numberWithBool:YES];
                });
            }
        }
        else if ([data length] == 0 && error == nil) {
            JPLog(@"no response");
        }
        else if (error != nil) {
            JPLog(@"Error: %@", error);
            NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            JPLog(@"HTML: %@", html);
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
        //JPLog(@"back. current active field: %lu", (unsigned long)_activeFieldIndex);
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
        //JPLog(@"next. current active field: %lu", (unsigned long)_activeFieldIndex);
        if (_activeFieldIndex == _fields.count - 1) {
            if ([_purpose isEqualToString:@"signup"])
                [self rightBarItem:nil];
        } else {
            _activeFieldIndex++;
        }
    }
    
    //JPLog(@"- new active field: %lu", (unsigned long)_activeFieldIndex);
    [self makeActiveFieldFirstResponder];
}

-(void)makeActiveFieldFirstResponder {
    [[_fields objectAtIndex:_activeFieldIndex] becomeFirstResponder];
    
    // scroll to active field
    NSIndexPath *activeFieldIndexPath = [NSIndexPath indexPathForRow:_activeFieldIndex + 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:activeFieldIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void) validateAllFields {
    // required fields
    if (_field_username.text.length == 0) [_fieldErrors setObject:@"A username is required" forKey:@"username"];
    if (_field_name.text.length == 0) [_fieldErrors setObject:@"Name is required" forKey:@"name"];
    if (_field_email.text.length == 0) [_fieldErrors setObject:@"Email is required" forKey:@"email"];
    if (_field_bio.text.length > MAX_BIO_CHARS) [_fieldErrors setObject:@"Bio can't exceed 160 characters" forKey:@"bio"];
    
    if ([_fieldErrors count] > 0) {
        return;
    } else {
        [self validateUsernameField:_field_username];
        [self validateTextField:_field_name optional:NO];
        [self validateEmailField:_field_email];
        [self validateTextField:_field_location optional:YES];
        [self validateURLField:_field_url];
    }
}


-(void) validateTextField:(UITextField *)textField {
    // validation
    BOOL valid = NO;
    switch (textField.tag) {
        case 0: // username
            valid = [self validateUsernameField:textField];
            break;
        case 1: // name
            valid = [self validateTextField:textField optional:NO];
            break;
        case 2: // email
            valid = [self validateEmailField:textField];
            break;
        case 3: // location
            valid = [self validateTextField:textField optional:YES];
            break;
        case 4: // bio
            break;
        case 5: // url
            valid = [self validateURLField:textField];
            break;
    }
    if (valid) {
        _validationIndicator.image = iconGreenCheck;
    } else {
        _validationIndicator.image = iconRedX;
    }
    [_keyboardToolbar setItems:@[_backBarItem, _fspace, _validationIndicatorItem, _fspace, _nextBarItem] animated:YES];
    [self enableOrDisableFieldNavButtons];
}
-(void) enableOrDisableFieldNavButtons {
    // if this is for editing profile
    if (!_formIsForSignup) {
        // if we are on the first field, disable last-field button
        if (_activeFieldIndex == 0) {
            _backBarItem.enabled = NO;
        } else {
            _backBarItem.enabled = YES;
        }
        // if we are on the last field, disable next-field button
        if (_activeFieldIndex == _fields.count - 1) {
            _nextBarItem.enabled = NO;
        } else {
            _nextBarItem.enabled = YES;
        }
    }
}

-(BOOL) validateUsernameField:(UITextField *)textField {
    if ([textField.text length] > 0) {
        NSRegularExpression *usernameRegex = [NSRegularExpression regularExpressionWithPattern:@"^[a-zA-Z0-9_]{1,15}$" options:0 error:nil];
        NSUInteger match = [usernameRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            // valid
            [_fieldErrors removeObjectForKey:@"username"];
            // check availability
            [_usernameCheckTimer invalidate];
            _usernameCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(checkUsernameAvailability) userInfo:nil repeats:NO];
            return YES;
        } else {
            // invalid
            [_fieldErrors setObject:@"Invalid username" forKey:@"username"];
            return NO;
        }
    } else {
        [_fieldErrors setObject:@"A username is required" forKey:@"username"];
        return NO;
    }
}

-(void) checkUsernameAvailability {
    // existing username is not invalid
    if (!_formIsForSignup && [_profileData objectForKey:@"username"] && [[_profileData objectForKey:@"username"] isEqualToString:_field_username.text]) {
        return;
    }
    if (_field_username.text.length && !_usernameCheckUnderway) {
        //NSLog(@"checking username: %@", _field_username.text);
        _usernameCheckUnderway = YES;
        NSString *urlAsString = [NSString stringWithFormat:@"%@users/username_check.php?username=%@", [TungCommonObjects apiRootUrl], _field_username.text];
        NSURL *checkUsernameURL = [NSURL URLWithString:urlAsString];
        NSMutableURLRequest *checkUsernameRequest = [NSMutableURLRequest requestWithURL:checkUsernameURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:5.0f];
        [checkUsernameRequest setHTTPMethod:@"GET"];
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [NSURLConnection sendAsynchronousRequest:checkUsernameRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            error = nil;
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            if (jsonData != nil && error == nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    _usernameCheckUnderway = NO;
                    NSDictionary *responseDict = jsonData;
                    //JPLog(@"responseDict: %@", responseDict);
                    id usernameExistsId = [responseDict objectForKey:@"username_exists"];
                    BOOL usernameExists = [usernameExistsId boolValue];
                    if (usernameExists) {
                            if (_activeFieldIndex == 0) _validationIndicator.image = iconRedX;
                            [_fieldErrors setObject:[NSString stringWithFormat:@"The username \"%@\" is taken", _field_username.text] forKey:@"username"];
                    }
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                	_usernameCheckUnderway = NO;
                });
            }
        }];
    }
}
-(BOOL) validateTextField:(UITextField *)textField optional:(BOOL)optional {
    // for validating either Name or Location
    NSString *name = @"";
    if (textField.tag == 1) name = @"name";
    else name = @"location";
    
    if ([textField.text length] > 0) {
        NSRegularExpression *textRegex = [NSRegularExpression regularExpressionWithPattern:@"^[\\w\\d \\,\\-\\.]{1,30}$" options:NSRegularExpressionCaseInsensitive error:nil];
        NSUInteger match = [textRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            [_fieldErrors removeObjectForKey:name];
            return YES;
        } else {
            [_fieldErrors setObject:[NSString stringWithFormat:@"Invalid %@", name] forKey:name];
            return NO;
        }
    } else {
        if (!optional) {
            [_fieldErrors setObject:[NSString stringWithFormat:@"A %@ is required", name] forKey:name];
            return NO;
        } else {
            [_fieldErrors removeObjectForKey:name];
            return YES;
        }
    }
}
-(BOOL) validateEmailField:(UITextField *)textField {
    if ([textField.text length] > 0) {
        NSString *emailRegexString = @"^[\\w\\d\\+\\.\\-]+@[a-zA-Z\\d\\.\\-]+\\.[a-zA-Z]{2,15}$";
        NSRegularExpression *emailRegex = [NSRegularExpression regularExpressionWithPattern:emailRegexString options:NSRegularExpressionCaseInsensitive error:nil];
        NSUInteger match = [emailRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            [_fieldErrors removeObjectForKey:@"email"];
            return YES;
        } else {
            [_fieldErrors setObject:@"Invalid Email" forKey:@"email"];
            return NO;
        }
    } else {
        [_fieldErrors setObject:@"Email is required" forKey:@"email"];
        return NO;
    }
}
-(BOOL) validateURLField:(UITextField *)textField {
    if ([textField.text length] > 0) {
        NSString *urlRegexString = @"^(https?:\\/\\/)?[a-zA-Z\\d\\.\\-]+\\.[a-zA-Z]{2,15}([\\/\\w-]*)*\\/?\\??([^#\\n\\r\\s]*)?#?([^\\n\\r\\s]*)$";
        NSRegularExpression *urlRegex = [NSRegularExpression regularExpressionWithPattern:urlRegexString options:NSRegularExpressionCaseInsensitive error:nil];
        NSUInteger match = [urlRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            [_fieldErrors removeObjectForKey:@"URL"];
            return YES;
        } else {
            NSLog(@"URL IS INVALID");
            [_fieldErrors setObject:@"Invalid URL" forKey:@"URL"];
            return NO;
        }
    } else {
        [_fieldErrors removeObjectForKey:@"URL"];
        return YES;
    }
}

// not used
-(BOOL) validatePhoneField:(UITextField *)textField {
    // UIDataDetectorTypePhoneNumber
    if ([textField.text length] > 0) {
        NSRegularExpression *phoneRegex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]{10,19}$" options:0 error:nil];
        NSUInteger match = [phoneRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            [_fieldErrors removeObjectForKey:@"phone"];
            return YES;
        } else {
            [_fieldErrors setObject:@"Invalid phone number" forKey:@"phone"];
            return NO;
        }
    } else {
        [_fieldErrors removeObjectForKey:@"phone"];
        return YES;
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
    [self validateTextField:textField];
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
    [self validateTextField:textField];
    _formIsPristine = NO;
    [self adjustRightBarButtonForFormState];
}

#pragma mark - text view delegate methods

- (void)textViewDidChange:(UITextView *)textView {
    _formIsPristine = NO;
    [self adjustRightBarButtonForFormState];
    
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
            JPLog(@"hide bio label");
            [UIView animateWithDuration:0.2
                             animations:^{
                                 _label_bio.alpha = 0;
                             }
             ];
        } else {
            JPLog(@"show bio label");
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
    //JPLog(@"text length: %ld", (long)[textView.text length]);
    NSInteger remaining = MAX_BIO_CHARS-[textView.text length];
    _keyboardLabel.text = [NSString stringWithFormat:@"%ld", (long)remaining];
    if (remaining > 20) _keyboardLabel.textColor = [UIColor lightGrayColor];
    else if (remaining > 10) _keyboardLabel.textColor = [UIColor darkGrayColor];
    else if (remaining <= 10) _keyboardLabel.textColor = [UIColor orangeColor];
    
    [_keyboardToolbar setItems:@[_backBarItem, _fspace, _keyboardLabelBarItem, _fspace, _nextBarItem] animated:YES];
}

#pragma mark - navigation


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

@end
