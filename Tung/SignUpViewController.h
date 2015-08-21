//
//  SignUpViewController.h
//  Tung
//
//  Created by Jamie Perkins on 4/27/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AvatarWithLineIntersect.h"
#import "HorizontalLine.h"

@interface SignUpViewController : UIViewController <UIScrollViewDelegate, UITextViewDelegate, UITextFieldDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) NSMutableDictionary *profileData;
@property (strong, nonatomic) NSDictionary *registrationErrors;

@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet UIView *page1;
@property (strong, nonatomic) IBOutlet UIView *page2;
@property (strong, nonatomic) AvatarWithLineIntersect *avatarWithLine;
@property (strong, nonatomic) IBOutlet HorizontalLine *page1line1;
@property (strong, nonatomic) IBOutlet HorizontalLine *page2line1;
@property (strong, nonatomic) IBOutlet HorizontalLine *page2line2;

@property (strong, nonatomic) IBOutlet UITextField *field_username;
@property (strong, nonatomic) IBOutlet UITextField *field_name;
@property (strong, nonatomic) IBOutlet UITextField *field_location;
@property (strong, nonatomic) UITextView *field_bio;
@property (strong, nonatomic) IBOutlet UITextField *field_URL;
@property (strong, nonatomic) IBOutlet UILabel *label_bio;
@property (strong, nonatomic) IBOutlet UILabel *label_location;

- (IBAction)back:(id)sender;
- (IBAction)next:(id)sender;

@end
