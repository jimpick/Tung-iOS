//
//  FinishSignUpController.h
//  Tung
//
//  Created by Jamie Perkins on 5/15/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PillButton.h"

@interface FinishSignUpController : UIViewController <UIWebViewDelegate>

@property (strong, nonatomic) NSMutableDictionary *profileData;
@property (strong, nonatomic) NSMutableArray *usersToFollow;
@property (strong, nonatomic) IBOutlet UIWebView *termsNoticeWebView;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) IBOutlet PillButton *signUpButton;

- (IBAction)signUp:(id)sender;


@end
