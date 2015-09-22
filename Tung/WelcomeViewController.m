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
    
    _working = NO;
    _firstAppearance = YES;
    
    _tung = [TungCommonObjects establishTungObjects];
    
    // check reachability
    [TungCommonObjects checkReachabilityWithCallback:^(BOOL reachable) {
        if (!reachable) {
            UIAlertView *noReachabilityAlert = [[UIAlertView alloc] initWithTitle:@"No Connection" message:@"Please make sure you have an internet connection before proceeding to sign-up or sign-in." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [noReachabilityAlert show];
        }
    }];
    
}

-(void)viewWillAppear:(BOOL)animated {
    
    _activityIndicator.alpha = 0;
    
}

-(void) viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    
    @try {
        [self removeObserver:self forKeyPath:@"tung.twitterAccountStatus"];
    }
    @catch (NSException *exception) {}
    @finally {}
}

-(void) viewDidLayoutSubviews {
    //NSLog(@"welcome - view did layout subviews");
    _endingLogoFrame = _logo.frame;
    
    if (_firstAppearance) {
        // starting logo frame is middle of the screen
        CGRect startingLogoFrame = _logo.frame;
        float screenHeight = [[UIScreen mainScreen]bounds].size.height;
        //NSLog(@"screen height: %f", screenHeight);
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
    
    //NSLog(@"welcome view did appear. First appearance:");
    //NSLog(_firstAppearance ? @"YES" : @"NO");
    
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
    
    //_btn_signUpWithFacebook.hidden = YES; // for now
    
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

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    
    if ([animationID isEqualToString:@"animate logo"]) {
        if ([finished boolValue]) {
            CGRect newLogoFrame = _logo.frame;
            NSLog(@"new logo frame %@", NSStringFromCGRect(newLogoFrame));
        }
    }}

#pragma mark - Signing in

- (void) loginRequestBegan {
    _activityIndicator.alpha = 1;
    [_activityIndicator startAnimating];
    _working = YES;
}

- (void) loginRequestEnded {
    
    _activityIndicator.alpha = 0;
    _working = NO;
}

- (IBAction)signUpWithTwitter:(id)sender {
    NSLog(@"sign up with twitter");
    if (!_working) {
        [self loginRequestBegan];
        
        if (!_tung.twitterAccountToUse) {
            // watch for account to get set or fail
            NSLog(@"add observer for tung.twitterAccountStatus");
            //NSKeyValueObservingOptions
            [self addObserver:self forKeyPath:@"tung.twitterAccountStatus" options:NSKeyValueObservingOptionNew context:nil];
            [_tung establishTwitterAccount];
        } else {
            NSLog(@"twitter account to use is already set");
            [self continueTwitterSignUpWithAccount:_tung.twitterAccountToUse];
        }
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSLog(@"----- value changed for key: %@, change: %@", keyPath, change);
    
    if ([keyPath isEqualToString:@"tung.twitterAccountStatus"]) {
        if ([_tung.twitterAccountStatus isEqualToString:@"failed"]) {
            [self loginRequestEnded];
        }
        else if ([_tung.twitterAccountStatus isEqualToString:@"success"]) {
            [self continueTwitterSignUpWithAccount:_tung.twitterAccountToUse];
        }
    }
}

- (void) continueTwitterSignUpWithAccount:(ACAccount *)account {
    
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
     
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@account/verify_credentials.json", _tung.twitterApiRootUrl]];
    SLRequest *verifyCredRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:requestURL parameters:nil];
    verifyCredRequest.account = account;
     
    [verifyCredRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        NSLog(@"Twitter HTTP response: %li", (long)[urlResponse statusCode]);
        //NSString *html = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        //NSLog(@"HTML: %@", html);
        if (error != nil) NSLog(@"Error: %@", error);
        
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
        
        if (jsonData != nil && error == nil) {
            NSDictionary *accountData = jsonData;
            //NSLog(@"%@", accountData);
            if ([accountData objectForKey:@"errors"]) {
                NSLog(@"Errors: %@", [accountData objectForKey:@"errors"]);
                error = nil;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_activityIndicator stopAnimating];
                    [accountStore renewCredentialsForAccount:account completion:^(ACAccountCredentialRenewResult renewResult, NSError *error) {
                        _working = NO;
                    }];
                });
                
            } else {
                
                // sanitize bio (remove urls)
                NSMutableString *bio = [[accountData objectForKey:@"description"] mutableCopy];
                NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
                [linkDetector replaceMatchesInString:bio options:0 range:NSMakeRange(0, [bio length]) withTemplate:@""];
                
                // make image big by removing "_normal"
                NSMutableString *avatarURL = [[accountData objectForKey:@"profile_image_url"] mutableCopy];
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(_normal)" options:0 error:nil];
                [regex replaceMatchesInString:avatarURL options:0 range:NSMakeRange(0, [avatarURL length]) withTemplate:@""];
                
                _profileData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    avatarURL, @"avatarURL",
                                    [accountData objectForKey:@"id"], @"twitter_id",
                                	[accountData objectForKey:@"screen_name"], @"username",
                                	[accountData objectForKey:@"screen_name"], @"twitter_username",
                                    [accountData objectForKey:@"name"], @"name",
                                    [accountData objectForKey:@"location"], @"location",
                                    bio, @"bio",
                                    [[accountData valueForKeyPath:@"entities.url.urls.expanded_url"] objectAtIndex:0], @"url", nil];
                
                NSLog(@"profile dictionary: %@", _profileData);
                _working = NO;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self getTokenWithCallback:^{
                    	[self signInOrSignUpUsing:@"twitter"];
                    }];
                });
            }
        }
    }];
}

- (IBAction)signUpWithFacebook:(id)sender {
    
    if (!_working) {
        
        [self loginRequestBegan];
        
        if (![FBSDKAccessToken currentAccessToken]) {
            
            FBSDKLoginManager *login = [[FBSDKLoginManager alloc] init];
            [login logInWithReadPermissions: @[@"public_profile", @"email", @"user_location", @"user_website", @"user_about_me"]
                         fromViewController:self
                                    handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
                                         if (error) {
                                             NSLog(@"fb - Process error: %@", error);
                                             NSString *alertText = [NSString stringWithFormat:@"\"%@\"", error];
                                             UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Facebook error" message:alertText delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                                             [errorAlert show];
                                             [self loginRequestEnded];
                                         }
                                         else if (result.isCancelled) {
                                             NSLog(@"fb - login cancelled");
                                             [self loginRequestEnded];
                                         }
                                         else {
                                             NSLog(@"fb - Logged in");
                                             if ([FBSDKAccessToken currentAccessToken]) {
                                                [self continueFacebookSignup];
                                             }
                                         }
             }];
        }
        else {
            [self continueFacebookSignup];
            
        }

        
        // OLD DEPRECATED FB SDK 3.X CODE
        /*
        // clear any active tokens
        [FBSession.activeSession closeAndClearTokenInformation];
        // get a new session token
        [FBSession openActiveSessionWithReadPermissions:@[@"public_profile", @"publish_actions", @"user_website", @"user_about_me"]
                                           allowLoginUI:YES
                                      completionHandler:^(FBSession *session, FBSessionState state, NSError *error) {
                                          // Retrieve the app delegate
                                          AppDelegate* appDelegate = [UIApplication sharedApplication].delegate;
                                          // Call the app delegate's sessionStateChanged:state:error method to handle session state changes
                                          [appDelegate sessionStateChanged:session state:state error:error];
                                          if (state == FBSessionStateOpen) {
                                              [self continueFacebookSignup];
                                          }
                                          else {
                                              //UIAlertView *fbLoginAlert = [[UIAlertView alloc] initWithTitle:@"Facebook login was cancelled" message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                                              //[fbLoginAlert show];
                                              _activityIndicator.alpha = 0;
                                              _working = NO;
                                          }
                                      }];*/

    }
}

- (void) continueFacebookSignup {
    
    NSDictionary *params = @{ @"fields": @"id,name,email,location,bio,website" };
    [[[FBSDKGraphRequest alloc] initWithGraphPath:@"me" parameters:params]
     startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
         if (!error) {
             NSLog(@"fetched user:%@", result);
             
             NSDictionary *fbUser = result;
             
             NSString *userImageURL = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=square&height=640&width=640", [fbUser objectForKey:@"id"]];
             _profileData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                             userImageURL, @"avatarURL",
                             [fbUser objectForKey:@"id"], @"facebook_id",
                             @"", @"username",
                             [fbUser objectForKey:@"name"], @"name",
                             [fbUser objectForKey:@"email"], @"email",
                             [[fbUser objectForKey:@"location"] objectForKey:@"name"], @"location",
                             [fbUser objectForKey:@"bio"], @"bio",
                             [fbUser objectForKey:@"website"], @"url", nil];
             NSLog(@"profile data: %@", _profileData);
             
             // continue...
             [self getTokenWithCallback:^{
                 [self signInOrSignUpUsing:@"facebook"];
             }];
         }
         else {
             NSLog(@"request for me error: %@", error);
         }
     }];
    
}

-(void) getTokenWithCallback:(void (^)(void))callback {
    NSLog(@"getting token");
    NSURL *getTokenRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@app/requestToken.php", _tung.apiRootUrl]];
    NSMutableURLRequest *getTokenRequest = [NSMutableURLRequest requestWithURL:getTokenRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [getTokenRequest setHTTPMethod:@"GET"];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:getTokenRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"value"]) {
                    _appToken = [responseDict objectForKey:@"value"];
                    NSLog(@"- got token: %@", _appToken);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // callback
                        callback();
                    });
                } 
            }
            else if ([data length] == 0 && error == nil) {
                NSLog(@"no response");
            }
            else if (error != nil) {
                //NSLog(@"Error: %@", error);
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"HTML: %@", html);
            }
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *connectionErrorAlert = [[UIAlertView alloc] initWithTitle:@"Connection error" message:[error localizedDescription] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [connectionErrorAlert show];
            });
        }
    }];
}


- (void) signInOrSignUpUsing:(NSString*)socialNetwork {

//	[self performSegueWithIdentifier:@"startSignUp" sender:self]; // comment me out
//} // comment me out
//- (void) someMethod:(NSString*)socialNetwork { // comment me out
    
    // check if user already has account
    NSLog(@"check for existing account using %@", socialNetwork);
    NSString *accountCheckURLString = [NSString stringWithFormat:@"%@users/account_check.php", _tung.apiRootUrl];
    NSDictionary *cred;
    if ([socialNetwork isEqualToString:@"twitter"]) {
        cred = @{ @"twitter_id": [_profileData objectForKey:@"twitter_id"],
                  @"app_token": _appToken};
    } else {
        cred = @{ @"facebook_id": [_profileData objectForKey:@"facebook_id"],
                  @"app_token": _appToken};
    }
    NSURL *accountCheckURL = [NSURL URLWithString:accountCheckURLString];
    NSMutableURLRequest *accountCheckRequest = [NSMutableURLRequest requestWithURL:accountCheckURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [accountCheckRequest setHTTPMethod:@"POST"];
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:cred];
    [accountCheckRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    NSLog(@"send request");
    [NSURLConnection sendAsynchronousRequest:accountCheckRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        if (jsonData != nil && error == nil) {
            NSDictionary *responseDict = jsonData;
            //NSLog(@"account check response: %@", responseDict);
            if ([responseDict objectForKey:@"user"]) {
                // "log in"
                NSLog(@"account exists. Logging in");
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    NSDictionary *userDict = [responseDict objectForKey:@"user"];
                    // construct token of id and token together
                    NSString *tungCred = [NSString stringWithFormat:@"%@:%@", [[userDict objectForKey:@"_id"] objectForKey:@"$id"], [userDict objectForKey:@"token"]];
                    // save cred to keychain
                    [TungCommonObjects saveKeychainCred:tungCred];
                    
                    // store user data
                    [TungCommonObjects saveUserWithDict:userDict];
                    NSLog(@"saved user data: %@", userDict);
                    
                    [self loginRequestEnded];
                
                    // show feed
                    UIViewController *feed = [self.storyboard instantiateViewControllerWithIdentifier:@"authenticated"];
                    [self presentViewController:feed animated:YES completion:^{}];
                    
                });
                
            } else {
                NSLog(@"account does not exist. Proceeding to sign-up");
                // proceed with sign-up
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self performSegueWithIdentifier:@"startSignUp" sender:self];
                });
            }
        }
        else if ([data length] == 0 && error == nil) {
            NSLog(@"no response");
        }
        else if (error != nil) {
            NSLog(@"Error: %@", error);
            NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"HTML: %@", html);
        }
    }];
}

#pragma mark - actionsheet methods

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    NSLog(@"button index: %ld", (long)buttonIndex);
    [self continueTwitterSignUpWithAccount:[_arrayOfAccounts objectAtIndex:buttonIndex]];
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
