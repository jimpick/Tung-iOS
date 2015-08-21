//
//  SignUpTableViewController.h
//  Tung
//
//  Created by Jamie Perkins on 10/17/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AvatarContainerView.h"

@interface EditProfileTableViewController : UITableViewController <UITextViewDelegate, UITextFieldDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) NSMutableDictionary *profileData;
@property (strong, nonatomic) NSDictionary *registrationErrors;
@property (strong, nonatomic) NSString *purpose;

@property (strong, nonatomic) IBOutlet AvatarContainerView *largeAvatar;
@property (strong, nonatomic) IBOutlet UITextField *field_username;
@property (strong, nonatomic) IBOutlet UITextField *field_name;
@property (strong, nonatomic) IBOutlet UITextField *field_location;
@property (strong, nonatomic) IBOutlet UITextView *field_bio;
@property (strong, nonatomic) IBOutlet UITextField *field_url;
@property (strong, nonatomic) IBOutlet UITextField *field_phone;
@property (strong, nonatomic) IBOutlet UITextField *field_email;
@property (strong, nonatomic) IBOutlet UILabel *label_bio;
@property (strong, nonatomic) IBOutlet UIButton *refreshAvatarBtn;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *avatarActivityIndicator;

- (IBAction)leftBarItem:(id)sender;
- (IBAction)rightBarItem:(id)sender;
- (IBAction)updateAvatarPrompt:(id)sender;

@end
