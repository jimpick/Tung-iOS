//
//  ProfileEditorTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 10/29/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "ProfileEditorTableViewController.h"
#import "tungCommonObjects.h"

#define MAX_BIO_CHARS 120

@interface ProfileEditorTableViewController ()

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
@property (nonatomic, retain) tungCommonObjects *tungObjects;

@end

@implementation ProfileEditorTableViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    _tungObjects = [tungCommonObjects establishTungObjects];
    
    // table view
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = _tungObjects.bkgdGrayColor;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.scrollsToTop = YES;
    self.tableView.separatorColor = _tungObjects.tungColor;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
    self.tableView.bounces = NO;
    
    // get keyboard height when keyboard is shown and inset table
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidAppear:) name:UIKeyboardDidShowNotification object:nil];
    
    CGFloat screenWidth = [[UIScreen mainScreen]bounds].size.width;
    // input view toolbar
    _keyboardToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 44)];
    _keyboardToolbar.tintColor = _tungObjects.tungColor;
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
    _validationIndicator.image = [UIImage imageNamed:@"icon-check-green.png"];
    _validationIndicatorItem = [[UIBarButtonItem alloc] initWithCustomView:_validationIndicator];
    _fspace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    _keyboardToolbar.barStyle = UIBarStyleDefault;
    [_keyboardToolbar setItems:@[_backBarItem, _fspace, _keyboardLabelBarItem, _fspace, _nextBarItem]];
    
    // set up fields and pre-load fields with profile data
    NSLog(@"profile data: %@", _profileData);
    _field_username.text = [_profileData objectForKey:@"username"];
    _field_username.delegate = self;
    _field_username.inputAccessoryView = _keyboardToolbar;
    [_field_username addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    _field_name.text = [_profileData objectForKey:@"name"];
    _field_name.delegate = self;
    _field_name.inputAccessoryView = _keyboardToolbar;
    [_field_name addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    _field_location.text = [_profileData objectForKey:@"location"];
    _field_location.delegate = self;
    _field_location.inputAccessoryView = _keyboardToolbar;
    [_field_location addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    _field_url.text = [_profileData objectForKey:@"url"];
    _field_url.delegate = self;
    _field_url.inputAccessoryView = _keyboardToolbar;
    [_field_url addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    _field_phone.delegate = self;
    _field_phone.inputAccessoryView = _keyboardToolbar;
    [_field_phone addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
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
    
    // fields array
    _fields = @[_field_username, _field_name, _field_location, _field_bio, _field_url, _field_phone];
    // for hiding Bio label
    _prevHideBioLabel = NO;
    // errors dict
    _fieldErrors = [[NSMutableDictionary alloc] init];
    
    
    
}

- (void) keyboardDidAppear:(NSNotification*)notification {
    
    NSDictionary* keyboardInfo = [notification userInfo];
    NSValue* keyboardFrameBegin = [keyboardInfo valueForKey:UIKeyboardFrameBeginUserInfoKey];
    CGRect keyboardRect = [keyboardFrameBegin CGRectValue];
    NSLog(@"keyboard rect: %@", NSStringFromCGRect(keyboardRect));
    
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
            NSLog(@"registration errors");
            // alert error(s)
            NSArray *regErrors = [_registrationErrors allValues];
            NSString *regErrorsString = [regErrors componentsJoinedByString:@"\n"];
            UIAlertView *regErrorsAlert = [[UIAlertView alloc] initWithTitle:@"Oops!" message:regErrorsString delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [regErrorsAlert setTag:1];
            [regErrorsAlert show];
        }
    }
}
- (void) viewDidAppear:(BOOL)animated {
    
    _activeFieldIndex = 0;
    [[_fields objectAtIndex:_activeFieldIndex] becomeFirstResponder];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void) handleAvatar {
    
    // Avatar
    NSData *dataToResize = [[NSData alloc] initWithContentsOfURL: [NSURL URLWithString: [_profileData objectForKey:@"avatarURL"]]];
    UIImage *imageToResize = [[UIImage alloc] initWithData:dataToResize];
    NSLog(@"file size before resizing: %lu b", (unsigned long)[dataToResize length]);
    // resize to "large" size
    CGSize largeSize = CGSizeMake(640, 640);
    UIGraphicsBeginImageContext(largeSize);
    [imageToResize drawInRect: CGRectMake(0, 0,largeSize.width, largeSize.height)];
    UIImage* largeImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSData *largeAvatarImageData = UIImageJPEGRepresentation(largeImage, 0.5);
    NSLog(@"file size AFTER resizing large image: %lu b", (unsigned long)[largeAvatarImageData length]);
    // resize to small size
    CGSize smallSize = CGSizeMake(120, 120);
    UIGraphicsBeginImageContext(smallSize);
    [imageToResize drawInRect: CGRectMake(0, 0,smallSize.width, smallSize.height)];
    UIImage* smallImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSData *smallAvatarImageData = UIImageJPEGRepresentation(smallImage, 0.9);
    NSLog(@"file size AFTER resizing small image: %lu b", (unsigned long)[smallAvatarImageData length]);
    // save in temp folder and set profileData values
    NSString *largeAvatarFilename = @"large_avatar.jpg";
    NSString *smallAvatarFilename = @"small_avatar.jpg";
    NSString *pathToLargeAvatarImageData = [NSTemporaryDirectory() stringByAppendingPathComponent:largeAvatarFilename];
    NSString *pathToSmallAvatarImageData = [NSTemporaryDirectory() stringByAppendingPathComponent:smallAvatarFilename];
    BOOL wroteLargeFile = [largeAvatarImageData writeToFile:pathToLargeAvatarImageData atomically:YES];
    BOOL wroteSmallFile = [smallAvatarImageData writeToFile:pathToSmallAvatarImageData atomically:YES];
    if (wroteLargeFile && wroteSmallFile) {
        NSLog(@"successfully saved avatar in temp folder");
        [_profileData setValue:pathToLargeAvatarImageData forKey:@"pathToLargeAvatarImageData"];
        [_profileData setValue:pathToSmallAvatarImageData forKey:@"pathToSmallAvatarImageData"];
        [_profileData setValue:largeAvatarFilename forKey:@"largeAvatarFilename"];
        [_profileData setValue:smallAvatarFilename forKey:@"smallAvatarFilename"];
        [_profileData removeObjectForKey:@"avatarURL"];
    }
    // set image for avatar view
    NSLog(@"got Image Data");
    _largeAvatar.avatar = [[UIImage alloc] initWithData:largeAvatarImageData];
    _largeAvatar.useFilter = 0;
    _largeAvatar.borderColor = _tungObjects.tungColor;
    _largeAvatar.backgroundColor = [UIColor clearColor];
}

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    // registration errors alert
    if (alertView.tag == 1) {
        // go to page and field with error
        NSArray *fields = [_registrationErrors allKeys];
        NSString *activeFieldString = [fields objectAtIndex:0];
        NSLog(@"Error on %@", activeFieldString);
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
}

- (void)navigateFormFields:(id)sender {
    NSUInteger tag = 0;
    if ([sender tag]) {
        tag = [sender tag];
    }
    // back
    if (tag == 1) {
        NSLog(@"back. current active field: %lu", (unsigned long)_activeFieldIndex);
        if (_activeFieldIndex == 0) {
            [self back:nil];
        } else {
            _activeFieldIndex--;
        }
    }
    // next
    else {
        NSLog(@"next. current active field: %lu", (unsigned long)_activeFieldIndex);
        if (_activeFieldIndex == _fields.count - 1) {
            [self next:nil];
        } else {
            _activeFieldIndex++;
        }
    }
    
    NSLog(@"- new active field: %lu", (unsigned long)_activeFieldIndex);
    [self makeActiveFieldFirstResponder];
}

-(void)makeActiveFieldFirstResponder {
    [[_fields objectAtIndex:_activeFieldIndex] becomeFirstResponder];
    
    // scroll to active field
    NSIndexPath *activeFieldIndexPath = [NSIndexPath indexPathForRow:_activeFieldIndex + 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:activeFieldIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
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

-(void) performAppropriateValidationOnTextField:(UITextField *)textField {
    // validation
    switch (textField.tag) {
        case 0: // username
            [self validateUsernameField:textField];
            break;
        case 1: // name
            [self validateTextField:textField optional:NO];
            break;
        case 2: // location
            [self validateTextField:textField optional:YES];
            break;
        case 4: // url
            [self validateURLField:textField];
            break;
        case 5: // phone
            [self validatePhoneField:textField];
            break;
    }
}

-(void) validateUsernameField:(UITextField *)textField {
    if ([textField.text length] > 0) {
        NSRegularExpression *usernameRegex = [NSRegularExpression regularExpressionWithPattern:@"^[a-zA-Z0-9_]{1,15}$" options:0 error:nil];
        NSUInteger match = [usernameRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            // valid
            _validationIndicator.image = [UIImage imageNamed:@"icon-check-green.png"];
            [_fieldErrors removeObjectForKey:@"username"];
            // check availability
            [_usernameCheckTimer invalidate];
            _usernameCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(checkUsernameAvailability) userInfo:nil repeats:NO];
        } else {
            // invalid
            _validationIndicator.image = [UIImage imageNamed:@"icon-X-red.png"];
            [_fieldErrors setObject:@"Invalid username" forKey:@"username"];
        }
    } else {
        _validationIndicator.image = [UIImage imageNamed:@"icon-X-red.png"];
        [_fieldErrors setObject:@"A username is required" forKey:@"username"];
    }
    [_keyboardToolbar setItems:@[_backBarItem, _fspace, _validationIndicatorItem, _fspace, _nextBarItem] animated:YES];
}

-(void) checkUsernameAvailability {
    NSLog(@"username check");
    NSString *urlAsString = [NSString stringWithFormat:@"%@users/username_check.php?username=%@", _tungObjects.apiRootUrl, _field_username.text];
    NSURL *checkUsernameURL = [NSURL URLWithString:urlAsString];
    NSMutableURLRequest *checkUsernameRequest = [NSMutableURLRequest requestWithURL:checkUsernameURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [checkUsernameRequest setHTTPMethod:@"GET"];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:checkUsernameRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        if (jsonData != nil && error == nil) {
            NSDictionary *responseDict = jsonData;
            NSLog(@"responseDict: %@", responseDict);
            id usernameExistsId = [responseDict objectForKey:@"username_exists"];
            BOOL usernameExists = [usernameExistsId boolValue];
            if (usernameExists) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    _validationIndicator.image = [UIImage imageNamed:@"icon-X-red.png"];
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
        NSRegularExpression *textRegex = [NSRegularExpression regularExpressionWithPattern:@"^[a-zA-Z0-9\\,\\.\\s]{1,25}$" options:0 error:nil];
        NSUInteger match = [textRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            _validationIndicator.image = [UIImage imageNamed:@"icon-check-green.png"];
            [_fieldErrors removeObjectForKey:name];
        } else {
            _validationIndicator.image = [UIImage imageNamed:@"icon-X-red.png"];
            [_fieldErrors setObject:[NSString stringWithFormat:@"Invalid %@", name] forKey:name];
        }
        [_keyboardToolbar setItems:@[_backBarItem, _fspace, _validationIndicatorItem, _fspace, _nextBarItem] animated:YES];
    } else {
        if (!optional) {
            _validationIndicator.image = [UIImage imageNamed:@"icon-X-red.png"];
            [_keyboardToolbar setItems:@[_backBarItem, _fspace, _validationIndicatorItem, _fspace, _nextBarItem] animated:YES];
            [_fieldErrors setObject:[NSString stringWithFormat:@"A %@ is required", name] forKey:name];
        } else {
            [_keyboardToolbar setItems:@[_backBarItem, _fspace, _nextBarItem] animated:YES];
            [_fieldErrors removeObjectForKey:name];
        }
    }
}
-(void) validateURLField:(UITextField *)textField {
    if ([textField.text length] > 0) {
        NSString *urlRegexString = @"^(https?:\\/\\/)?([\\w\\-])+\\.{1}([a-zA-Z]{2,63})([\\/\\w-]*)*\\/?\\??([^#\\n\\r\\s]*)?#?([^\\n\\r\\s]*)$";
        // NSString *urlRegexString = @"(?:https?:\\/\\/)(?:[\\w]+\\.)([a-zA-Z\\.]{2,63})([\\/\\w\\.-]*)*\\/?";
        NSRegularExpression *urlRegex = [NSRegularExpression regularExpressionWithPattern:urlRegexString options:0 error:nil];
        NSUInteger match = [urlRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            _validationIndicator.image = [UIImage imageNamed:@"icon-check-green.png"];
            [_fieldErrors removeObjectForKey:@"URL"];
        } else {
            _validationIndicator.image = [UIImage imageNamed:@"icon-X-red.png"];
            [_fieldErrors setObject:@"Invalid URL" forKey:@"URL"];
        }
        [_keyboardToolbar setItems:@[_backBarItem, _fspace, _validationIndicatorItem, _fspace, _nextBarItem] animated:YES];
    } else {
        [_keyboardToolbar setItems:@[_backBarItem, _fspace, _nextBarItem] animated:YES];
        [_fieldErrors removeObjectForKey:@"URL"];
    }
}

-(void) validatePhoneField:(UITextField *)textField {
    // UIDataDetectorTypePhoneNumber
    if ([textField.text length] > 0) {
        NSRegularExpression *phoneRegex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]{10,19}$" options:0 error:nil];
        NSUInteger match = [phoneRegex numberOfMatchesInString:textField.text options:0 range:NSMakeRange(0, [textField.text length])];
        if (match > 0) {
            _validationIndicator.image = [UIImage imageNamed:@"icon-check-green.png"];
            [_fieldErrors removeObjectForKey:@"phone"];
        } else {
            _validationIndicator.image = [UIImage imageNamed:@"icon-X-red.png"];
            [_fieldErrors setObject:@"Invalid phone number" forKey:@"phone"];
        }
        [_keyboardToolbar setItems:@[_backBarItem, _fspace, _validationIndicatorItem, _fspace, _nextBarItem] animated:YES];
    } else {
        [_keyboardToolbar setItems:@[_backBarItem, _fspace, _nextBarItem] animated:YES];
        [_fieldErrors removeObjectForKey:@"phone"];
    }
}

#pragma mark - text view delegate methods

- (void)textViewDidChange:(UITextView *)textView {
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
            NSLog(@"hide bio label");
            [UIView animateWithDuration:0.2
                             animations:^{
                                 _label_bio.alpha = 0;
                             }
             ];
        } else {
            NSLog(@"show bio label");
            [UIView animateWithDuration:0.2
                             animations:^{
                                 _label_bio.alpha = 1;
                             }
             ];
        }
    }
    _prevHideBioLabel = hideBioLabel;
    
    // keep text limited to MAX_CHARS
    //NSLog(@"range.location: %lu", (unsigned long)range.location);
    if (range.location >= MAX_BIO_CHARS) {
        return NO; // return NO to not change text
    } else {
        return YES;
    }
}

- (void) formatKeyboardLabel:(UITextView *)textView {
    //NSLog(@"text length: %ld", (long)[textView.text length]);
    NSInteger remaining = MAX_BIO_CHARS-[textView.text length];
    _keyboardLabel.text = [NSString stringWithFormat:@"%ld", (long)remaining];
    if (remaining > 20) _keyboardLabel.textColor = [UIColor lightGrayColor];
    else if (remaining > 10) _keyboardLabel.textColor = [UIColor darkGrayColor];
    else if (remaining <= 10) _keyboardLabel.textColor = [UIColor orangeColor];
    
    [_keyboardToolbar setItems:@[_backBarItem, _fspace, _keyboardLabelBarItem, _fspace, _nextBarItem] animated:YES];
}

#pragma mark - navigation

- (IBAction)next:(id)sender {
    
    if ([_fieldErrors count] > 0) {
        // display error alert
        NSArray *errors = [_fieldErrors allValues];
        NSString *errorsString = [errors componentsJoinedByString:@"\n"];
        UIAlertView *errorsAlert = [[UIAlertView alloc] initWithTitle:@"Please correct the following" message:errorsString delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [errorsAlert show];
    } else {
        [self performSegueWithIdentifier:@"finishSignUp" sender:self];
    }
}

- (IBAction)back:(id)sender {
    [self performSegueWithIdentifier:@"unwindToWelcome" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UIViewController *destination = segue.destinationViewController;
    
    if ([[segue identifier] isEqualToString:@"finishSignUp"]) {
        // update profileData with user inputted values
        [_profileData setValue:_field_username.text forKey:@"username"];
        [_profileData setValue:_field_name.text forKey:@"name"];
        [_profileData setValue:_field_location.text forKey:@"location"];
        [_profileData setValue:_field_bio.text forKey:@"bio"];
        [_profileData setValue:_field_url.text forKey:@"url"];
        [_profileData setValue:_field_phone.text forKey:@"phone"];
        // set value
        [destination setValue:_profileData forKey:@"profileData"];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return 8;
}

/*
 - (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
 UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
 
 // Configure the cell...
 
 return cell;
 }
 */

@end
