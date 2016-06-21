//
//  WelcomeViewController.h
//  Tung
//
//  Created by Jamie Perkins on 5/13/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SignUpButton.h"

@interface WelcomeViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIImageView *logo;
@property (strong, nonatomic) IBOutlet SignUpButton *btn_signUpWithTwitter;
@property (strong, nonatomic) IBOutlet SignUpButton *btn_signUpWithFacebook;

- (IBAction)signUpWithTwitter:(id)sender;
- (IBAction)signUpWithFacebook:(id)sender;

@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@end
