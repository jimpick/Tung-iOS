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


@class BrowserViewController;

@interface FinishSignUpController ()

@property (nonatomic, retain) TungCommonObjects *tung;
@property (strong, nonatomic) NSDictionary *registrationErrors;

@end

@implementation FinishSignUpController


- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    _tung.viewController = self;
    
    // navigation bar
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tungNavBarLogo.png"]];
    self.navigationController.navigationBar.barTintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.translucent = NO;

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
    
//    if (_usersToFollow) {
//        NSLog(@"received users to follow: %@", _usersToFollow);
//    }

}

- (void) viewWillAppear:(BOOL)animated {
    
    _activityIndicator.alpha = 0;
    _activityIndicator.hidesWhenStopped = YES;
    self.navigationController.navigationBar.topItem.title = @"Back";
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
    _activityIndicator.alpha = 1;
    [_activityIndicator startAnimating];
    
    // create request object
    NSURL *registerURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/register.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *registerRequest = [NSMutableURLRequest requestWithURL:registerURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [registerRequest setHTTPMethod:@"POST"];
    // add content type
    NSString *boundary = [TungCommonObjects generateHash];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [registerRequest addValue:contentType forHTTPHeaderField:@"Content-Type"];
    // add post body
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    // don't send huge list of platform friends
    if ([_profileData objectForKey:@"twitterFriends"]) {
        [_profileData removeObjectForKey:@"twitterFriends"];
    }
    else if ([_profileData objectForKey:@"facebookFriends"]) {
        [_profileData removeObjectForKey:@"facebookFriends"];
    }
    // post data
    [_profileData setObject:@"iOS" forKey:@"source"];
    [_profileData setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] forKey:@"iOS_version"];
    if (_usersToFollow.count) {
    	[_profileData setObject:[_usersToFollow componentsJoinedByString:@","] forKey:@"usersToFollow"];
    }
    [body appendData:[TungCommonObjects generateBodyFromDictionary:_profileData withBoundary:boundary]];
    //JPLog(@"post _profileData: %@", _profileData);
    
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
     
    [registerRequest setHTTPBody:body];
    // set the content-length
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
    [registerRequest setValue:postLength forHTTPHeaderField:@"Content-Length"];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:registerRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        
        if (error == nil) {
        
        	id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        	if (jsonData != nil && error == nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_activityIndicator stopAnimating];
                    NSDictionary *responseDict = jsonData;
                    //JPLog(@"registration response: %@", responseDict);
                    // errors?
                    if ([responseDict objectForKey:@"error"]) {
                    
                        self.registrationErrors = [responseDict objectForKey:@"error"];
                        [self performSegueWithIdentifier:@"unwindToSignUp" sender:self];
                    }
                    // successful registration
                    else if ([responseDict objectForKey:@"success"]) {
                        
                        //NSLog(@"successful registration %@", responseDict);
                        _tung.sessionId = [responseDict objectForKey:@"sessionId"];
                        _tung.connectionAvailable = [NSNumber numberWithBool:YES];
                        
                        NSMutableDictionary *loggedUserDict = [[responseDict objectForKey:@"user"] mutableCopy];
                        [loggedUserDict setObject:[responseDict objectForKey:@"token"] forKey:@"token"];
                        _tung.loggedInUser = [TungCommonObjects saveUserWithDict:loggedUserDict isLoggedInUser:YES];
                        
                        // show feed
                        UIViewController *feed = [self.navigationController.storyboard instantiateViewControllerWithIdentifier:@"authenticated"];
                        [self presentViewController:feed animated:YES completion:^{}];
                    
                    }
                });
            }
            // errors
            else if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_activityIndicator stopAnimating];
                    
                    JPLog(@"Error registering: %@", error.localizedDescription);
                    [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"HTML: %@", html);
                });
            }
        }
        else {
            // errors
            dispatch_async(dispatch_get_main_queue(), ^{
                [_activityIndicator stopAnimating];
                JPLog(@"Error registering: %@", error.localizedDescription);
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
            });
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
        [destination setValue:[NSURL URLWithString:@"https://tung.fm/tos"] forKey:@"urlStringToNavigateTo"];
    }
}


@end
