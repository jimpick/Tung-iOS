//
//  LogViewController.m
//  Tung
//
//  Created by Jamie Perkins on 2/13/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//

#import "LogViewController.h"
#import "JPLogRecorder.h"
#import "TungCommonObjects.h"

@interface LogViewController ()

@end

@implementation LogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSString *log = [JPLogRecorder logArrayAsString];
    _textView.text = log;
    
    _toolbar.tintColor = [TungCommonObjects tungColor];
}

- (void) viewWillAppear:(BOOL)animated {
    
    [_textView scrollRectToVisible:CGRectMake(0, 0, [TungCommonObjects screenSize].width, [TungCommonObjects screenSize].height) animated:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)doneAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
