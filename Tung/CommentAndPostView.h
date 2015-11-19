//
//  CommentAndPostView.h
//  Tung
//
//  Created by Jamie Perkins on 8/5/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CircleButton.h"
#import "TungMiscView.h"

@interface CommentAndPostView : UIView

@property (strong, nonatomic) IBOutlet UIView *view;
@property (strong, nonatomic) IBOutlet TungMiscView *textAreaBkgdView;
@property (strong, nonatomic) IBOutlet CircleButton *twitterButton;
@property (strong, nonatomic) IBOutlet CircleButton *facebookButton;
@property (strong, nonatomic) IBOutlet CircleButton *postButton;
@property (strong, nonatomic) IBOutlet CircleButton *cancelButton;
@property (strong, nonatomic) IBOutlet UITextView *commentTextView;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *postActivityIndicator;
@property (strong, nonatomic) IBOutlet UILabel *tapToCommentLabel;
@end
