//
//  WelcomeViewController.m
//  Tung
//
//  Created by Jamie Perkins on 5/13/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "WelcomeViewController.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import <QuartzCore/QuartzCore.h>
#import <Security/Security.h>
#import "TungCommonObjects.h"

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>

#import "AppDelegate.h"

@interface WelcomeViewController ()

@property (nonatomic, assign) BOOL firstAppearance;
@property (nonatomic, strong) NSMutableDictionary *profileData;
@property (nonatomic, strong) NSArray *arrayOfAccounts;
@property (nonatomic, retain) TungCommonObjects *tung;
@property (nonatomic, assign) CGRect endingLogoFrame;
@property (nonatomic, strong) NSString *appToken;

@end

@implementation WelcomeViewController

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
    
    _firstAppearance = YES;
    
    _btn_signUpWithTwitter.type = kSignUpTypeTwitter;
    _btn_signUpWithFacebook.type = kSignUpTypeFacebook;
    
    _tung = [TungCommonObjects establishTungObjects];
    
    // check reachability
    [_tung checkReachabilityWithCallback:^(BOOL reachable) {
        if (!reachable) {
            [_tung showNoConnectionAlert];
        }
    }];
    
}

-(void) viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
}

-(void) viewDidLayoutSubviews {
    //JPLog(@"welcome - view did layout subviews");
    _endingLogoFrame = _logo.frame;
    
    if (_firstAppearance) {
        // starting logo frame is middle of the screen
        CGRect startingLogoFrame = _logo.frame;
        float screenHeight = [[UIScreen mainScreen]bounds].size.height;
        //JPLog(@"screen height: %f", screenHeight);
        if (screenHeight > 667) { // iPhone 6 Plus
            startingLogoFrame.origin.y = 736/2 - 124/2;
        }
        else if (screenHeight > 568) { // iPhone 6
            startingLogoFrame.origin.y = 667/2 - 124/2;
        }
        else if (screenHeight > 480) { // 4 inch
            startingLogoFrame.origin.y = 568/2 - 124/2;
        }
        else { // 3.5 inch
            startingLogoFrame.origin.y = 480/2 - 124/2;
        }
        [_logo setFrame:startingLogoFrame];
    }
}

-(void)viewDidAppear:(BOOL)animated {
    
    //JPLog(@"welcome view did appear. First appearance:");
    //JPLog(_firstAppearance ? @"YES" : @"NO");
    
    if (_firstAppearance) {
        _firstAppearance = NO;
        
        [UIView animateWithDuration:.5
                              delay:0.2
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_logo setFrame:_endingLogoFrame];
                         }
                         completion:nil
        ];
    }
    
    [UIView animateWithDuration:.5
                          delay:0.7
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         _btn_signUpWithTwitter.alpha = 1;
                         _btn_signUpWithFacebook.alpha = 1;
                     }
                     completion:nil
    ];

}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
/* not used
- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    
    if ([animationID isEqualToString:@"animate logo"]) {
        if ([finished boolValue]) {
            CGRect newLogoFrame = _logo.frame;
            JPLog(@"new logo frame %@", NSStringFromCGRect(newLogoFrame));
        }
    }
}*/

#pragma mark - Signing in

- (void) loginRequestBegan {
    _activityIndicator.alpha = 1;
    [_activityIndicator startAnimating];
    
    [_btn_signUpWithFacebook setEnabled:NO];
    [_btn_signUpWithTwitter setEnabled:NO];
}

- (void) loginRequestEnded {
    _activityIndicator.alpha = 0;
    
    [_btn_signUpWithFacebook setEnabled:YES];
    [_btn_signUpWithTwitter setEnabled:YES];
}


- (IBAction)signUpWithTwitter:(id)sender {

    JPLog(@"sign-in/up with twitter");
    
    [self loginRequestBegan];
    
    [[Twitter sharedInstance] logInWithCompletion:^(TWTRSession *session, NSError *error) {
        if (session) {
            JPLog(@"signed in as %@", [session userName]);
            
            TWTROAuthSigning *oauthSigning = [[TWTROAuthSigning alloc] initWithAuthConfig:[Twitter sharedInstance].authConfig authSession:[Twitter sharedInstance].session];
            NSDictionary *authHeaders = [oauthSigning OAuthEchoHeadersToVerifyCredentials];
            [_tung verifyCredWithTwitterOauthHeaders:authHeaders withCallback:^(BOOL success, NSDictionary *responseDict) {
                if (success) {
                    [self loginRequestEnded];
                    
                    // user exists
                    if ([responseDict objectForKey:@"sessionId"]) {
                        JPLog(@"user exists. signing in...");
                        _tung.sessionId = [responseDict objectForKey:@"sessionId"];
                        _tung.connectionAvailable = [NSNumber numberWithInt:1];
                        UserEntity *loggedUser = [TungCommonObjects saveUserWithDict:[responseDict objectForKey:@"user"]];
                        //JPLog(@"logged in user: %@", [TungCommonObjects entityToDict:loggedUser]);
                        NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                        
                        JPLog(@"lastDataChange (server): %@, lastDataChange (local): %@", lastDataChange, loggedUser.lastDataChange);
                        if (lastDataChange.floatValue > loggedUser.lastDataChange.floatValue) {
                            JPLog(@"needs restore. ");
                            [_tung restorePodcastDataSinceTime:loggedUser.lastDataChange];
                        }
                        
                        // construct token of id and token together and save to keychain
                        NSString *tungId = [[[responseDict objectForKey:@"user"] objectForKey:@"_id"] objectForKey:@"$id"];
                        NSString *tungCred = [NSString stringWithFormat:@"%@:%@", tungId, [responseDict objectForKey:@"token"]];
                        [TungCommonObjects saveKeychainCred:tungCred];
                        
                        // show feed
                        UIViewController *feed = [self.storyboard instantiateViewControllerWithIdentifier:@"authenticated"];
                        [self presentViewController:feed animated:YES completion:^{}];
                        
                    }
                    // user is new
                    else {
                        
                        NSDictionary *twitterProfile = [responseDict objectForKey:@"twitterProfile"];
                        JPLog(@"user is new.");
                        // sanitize bio (remove urls)
                        NSMutableString *bio = [[twitterProfile objectForKey:@"description"] mutableCopy];
                        NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
                        [linkDetector replaceMatchesInString:bio options:0 range:NSMakeRange(0, [bio length]) withTemplate:@""];
                        
                        // make image hi-res by removing "_normal"
                        NSMutableString *avatarURL = [[twitterProfile objectForKey:@"profile_image_url"] mutableCopy];
                        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(_normal)" options:0 error:nil];
                        [regex replaceMatchesInString:avatarURL options:0 range:NSMakeRange(0, [avatarURL length]) withTemplate:@""];
                        
                        _profileData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        avatarURL, @"avatarURL",
                                        [twitterProfile objectForKey:@"id"], @"twitter_id",
                                        [twitterProfile objectForKey:@"screen_name"], @"username",
                                        [twitterProfile objectForKey:@"screen_name"], @"twitter_username",
                                        [twitterProfile objectForKey:@"name"], @"name",
                                        [twitterProfile objectForKey:@"location"], @"location",
                                        bio, @"bio",
                                        [twitterProfile objectForKey:@"url"], @"url", nil];
                        
                        // proceed to sign-up
                        [self performSegueWithIdentifier:@"startSignUp" sender:self];
                    }

                }
                else {
                    [self loginRequestEnded];
                    UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:[responseDict objectForKey:@"error"] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                    [errorAlert show];
                }
            }];
            
        } else {
            NSLog(@"error: %@", [error localizedDescription]);
            [self loginRequestEnded];
        }
    }];
}


- (IBAction)signUpWithFacebook:(id)sender {
    
    JPLog(@"sign-in/up with facebook");
    [self loginRequestBegan];
    
    FBSDKLoginManager *login = [[FBSDKLoginManager alloc] init];
    [login logInWithReadPermissions: @[@"public_profile", @"email", @"user_location", @"user_website", @"user_about_me"]
                 fromViewController:self
                            handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
                                 if (error) {
                                     JPLog(@"fb - Process error: %@", error);
                                     NSString *alertText = [NSString stringWithFormat:@"\"%@\"", error];
                                     UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Facebook error" message:alertText delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                                     [errorAlert show];
                                     [self loginRequestEnded];
                                 }
                                 else if (result.isCancelled) {
                                     JPLog(@"fb - login cancelled");
                                     [self loginRequestEnded];
                                 }
                                 else {
                                     JPLog(@"fb - Logged in");
                                     if ([FBSDKAccessToken currentAccessToken]) {
                                         NSString *tokenString = [[FBSDKAccessToken currentAccessToken] tokenString];
                                         //NSLog(@"fb access token: %@", tokenString);
                                         [_tung verifyCredWithFacebookAccessToken:tokenString withCallback:^(BOOL success, NSDictionary *responseDict) {
                                             if (success) {
                                                 [self loginRequestEnded];
                                                 
                                                 // user exists
                                                 if ([responseDict objectForKey:@"sessionId"]) {
                                                     
                                                     JPLog(@"user exists. signing in...");
                                                     _tung.sessionId = [responseDict objectForKey:@"sessionId"];
                                                     _tung.connectionAvailable = [NSNumber numberWithInt:1];
                                                     UserEntity *loggedUser = [TungCommonObjects saveUserWithDict:[responseDict objectForKey:@"user"]];
                                                     //JPLog(@"logged in user: %@", [TungCommonObjects entityToDict:loggedUser]);
                                                     NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                                                     
                                                     JPLog(@"lastDataChange (server): %@, lastDataChange (local): %@", lastDataChange, loggedUser.lastDataChange);
                                                     if (lastDataChange.floatValue > loggedUser.lastDataChange.floatValue) {
                                                         JPLog(@"needs restore. ");
                                                         [_tung restorePodcastDataSinceTime:loggedUser.lastDataChange];
                                                     }
                                                     
                                                     NSString *tungId = [[[responseDict objectForKey:@"user"] objectForKey:@"_id"] objectForKey:@"$id"];
                                                     
                                                     // construct token of id and token together
                                                     NSString *tungCred = [NSString stringWithFormat:@"%@:%@", tungId, [responseDict objectForKey:@"token"]];
                                                     // save cred to keychain
                                                     [TungCommonObjects saveKeychainCred:tungCred];
                                                     
                                                     // show feed
                                                     UIViewController *feed = [self.storyboard instantiateViewControllerWithIdentifier:@"authenticated"];
                                                     [self presentViewController:feed animated:YES completion:^{}];
                                                     
                                                 }
                                                 // user is new
                                                 else {
                                                     
                                                     NSDictionary *facebookProfile = [responseDict objectForKey:@"facebookProfile"];
                                                     JPLog(@"user is new.");
                                                     
                                                     NSString *userImageURL = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=square&height=640&width=640", [facebookProfile objectForKey:@"id"]];
                                                     _profileData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                                     userImageURL, @"avatarURL",
                                                                     [facebookProfile objectForKey:@"id"], @"facebook_id",
                                                                     @"", @"username",
                                                                     [facebookProfile objectForKey:@"name"], @"name",
                                                                     [facebookProfile objectForKey:@"email"], @"email",
                                                                     [facebookProfile objectForKey:@"location"], @"location",
                                                                     [facebookProfile objectForKey:@"bio"], @"bio",
                                                                     [facebookProfile objectForKey:@"website"], @"url", nil];
                                                     
                                                     // proceed to sign-up
                                                     [self performSegueWithIdentifier:@"startSignUp" sender:self];
                                                 }

                                             }
                                             else {
                                                 
                                                 [self loginRequestEnded];
                                                 UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:[responseDict objectForKey:@"error"] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                                                 [errorAlert show];
                                             }
                                         }];
                                     }
                                 }
     }];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
   
    UIViewController *destination = segue.destinationViewController;

    if ([[segue identifier] isEqualToString:@"startSignUp"]) {
    	[[destination.childViewControllers objectAtIndex:0] setValue:_profileData forKey:@"profileData"];
        [[destination.childViewControllers objectAtIndex:0] setValue:@"signup" forKey:@"purpose"];
    }
    
}

- (IBAction)unwindToWelcome:(UIStoryboardSegue*)sender
{
}



@end
