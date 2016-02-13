//
//  LogViewController.m
//  Tung
//
//  Created by Jamie Perkins on 2/13/16.
//  Copyright © 2016 Jamie Perkins. All rights reserved.
//

#import "LogViewController.h"
#import "UALogger.h"
#import "TungCommonObjects.h"

@interface LogViewController ()

@end

@implementation LogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSString *log = [UALogger applicationLog];
    _textView.text = log;
    NSRange range = NSMakeRange(_textView.text.length - 1, 1);
    [_textView scrollRangeToVisible:range];
    
    _toolbar.tintColor = [TungCommonObjects tungColor];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)doneAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
