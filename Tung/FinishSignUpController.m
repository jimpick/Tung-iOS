//
//  FinishSignUpController.m
//  Tung
//
//  Created by Jamie Perkins on 5/15/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "FinishSignUpController.h"
#import "TungCommonObjects.h"
#import <Security/Security.h>
#import "AppDelegate.h"

//#import <FBSDKCoreKit/FBSDKCoreKit.h>

@class BrowserViewController;

@interface FinishSignUpController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) NSDictionary *registrationErrors;

@end

@implementation FinishSignUpController

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
    
    _tung = [TungCommonObjects establishTungObjects];
    _tung.viewController = self;
    
    // navigation bar
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tungNavBarLogo.png"]];
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 7) {
        self.navigationController.navigationBar.barTintColor = [UIColor whiteColor];
        self.navigationController.navigationBar.translucent = NO;
    } else {
        self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    }
    [self.navigationController setNavigationBarHidden:NO];
    
    _signUpButton.type = kPillTypeOnWhite;
    _signUpButton.buttonText = @"Finish";
    
    // terms notice
    NSString *path = [[NSBundle mainBundle] pathForResource:@"termsNotice" ofType:@"html"];
    NSURL *refURL = [NSURL fileURLWithPath:path];
    NSURLRequest *refURLRequest = [NSURLRequest requestWithURL:refURL];
    self.termsNoticeWebView.scrollView.scrollEnabled = NO;
    self.termsNoticeWebView.delegate = self;
    [self.termsNoticeWebView loadRequest:refURLRequest];

}

-(void)viewWillAppear:(BOOL)animated {
    
    self.activityIndicator.alpha = 0;
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

- (IBAction)signUp:(id)sender {
    // spin
    self.activityIndicator.alpha = 1;
    [self.activityIndicator startAnimating];
    
    // create requeset object
    NSURL *registerURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/register.php", _tung.apiRootUrl]];
    NSMutableURLRequest *registerRequest = [NSMutableURLRequest requestWithURL:registerURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [registerRequest setHTTPMethod:@"POST"];
    // add content type
    NSString *boundary = [TungCommonObjects generateHash];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [registerRequest addValue:contentType forHTTPHeaderField:@"Content-Type"];
    // add post body
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    // key value pairs
    [self.profileData setObject:@"iOS" forKey:@"source"];
    [body appendData:[TungCommonObjects generateBodyFromDictionary:self.profileData withBoundary:boundary]];
    
    // large avatar
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"large_avatar\"; filename=\"%@\"\r\n", [self.profileData objectForKey:@"largeAvatarFilename"]] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    NSURL *largeAvatarDataURL = [NSURL fileURLWithPath:[self.profileData objectForKey:@"pathToLargeAvatarImageData"]];
    NSData *largeAvatarData = [[NSData alloc] initWithContentsOfURL:largeAvatarDataURL];
    [body appendData:largeAvatarData];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    // small avatar
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"small_avatar\"; filename=\"%@\"\r\n", [self.profileData objectForKey:@"smallAvatarFilename"]] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    NSURL *smallAvatarDataURL = [NSURL fileURLWithPath:[self.profileData objectForKey:@"pathToSmallAvatarImageData"]];
    NSData *smallAvatarData = [[NSData alloc] initWithContentsOfURL:smallAvatarDataURL];
    [body appendData:smallAvatarData];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // end of body
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
     
    [registerRequest setHTTPBody:body];
    // set the content-length
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
    [registerRequest setValue:postLength forHTTPHeaderField:@"Content-Length"];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:registerRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        if (jsonData != nil && error == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
            	NSDictionary *responseDict = jsonData;
            	// errors?
            	if ([responseDict objectForKey:@"error"]) {
                
                	self.registrationErrors = [responseDict objectForKey:@"error"];
                    [self performSegueWithIdentifier:@"unwindToSignUp" sender:self];
            	}
        		// successful registration
            	else if ([responseDict objectForKey:@"success"]) {
                    JPLog(@"successful registration");
                    _tung.sessionId = [responseDict objectForKey:@"sessionId"];
                    _tung.connectionAvailable = [NSNumber numberWithInt:1];
                    [TungCommonObjects saveUserWithDict:[responseDict objectForKey:@"user"]];
                    
                    NSString *tungId = [[[responseDict objectForKey:@"user"] objectForKey:@"_id"] objectForKey:@"$id"];
                    
                    // construct token of id and token together
                    NSString *tungCred = [NSString stringWithFormat:@"%@:%@", tungId, [responseDict objectForKey:@"token"]];
                    // save cred to keychain
                    [TungCommonObjects saveKeychainCred:tungCred];
                    
                    // request to mutually follow all users
                    [_tung followAllUsersWithCallback:^(BOOL success, NSDictionary *response) {
                        if (success) {
                            JPLog(@"successfully followed all users: %@", response);
                            
                            // show feed
                            UIViewController *feed = [self.navigationController.storyboard instantiateViewControllerWithIdentifier:@"authenticated"];
                            [self presentViewController:feed animated:YES completion:^{}];
                            
                        } else {
                            JPLog(@"failed to follow all users: %@", response);
                            // something f'd up. sign out and try again
                            UIAlertView *followError = [[UIAlertView alloc] initWithTitle:@"Oops" message:@"Something went wrong... please try signing up again." delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                            followError.tag = 34;
                            [followError show];
                            
                            [_tung signOut];
                        }
                    }];
                    
                    // TODO: log fb activation...is this done automatically?
                    //[FBSDKAppEvents activateApp];
                
            	}
            });
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

#pragma mark - UIWebView delegate methods

-(BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    if ([request.URL.host isEqualToString:@"tung.fm"]) {
        [self performSegueWithIdentifier:@"presentTerms" sender:self];
        return NO;
    }
    else {
    	return YES;
    }
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UIViewController *destination = segue.destinationViewController;
    
    if ([[segue identifier] isEqualToString:@"unwindToSignUp"]) {
        // set value
    	[destination setValue:self.registrationErrors forKey:@"registrationErrors"];
    }
    if ([[segue identifier] isEqualToString:@"presentTerms"]) {
        [destination setValue:[NSURL URLWithString:@"https://tung.fm/tos"] forKey:@"urlToNavigateTo"];
    }
}


@end
