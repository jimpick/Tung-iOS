//
//  LogViewController.h
//  Tung
//
//  Created by Jamie Perkins on 2/13/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LogViewController : UIViewController
@property (strong, nonatomic) IBOutlet UITextView *textView;
@property (strong, nonatomic) IBOutlet UIToolbar *toolbar;
- (IBAction)doneAction:(id)sender;

@end
