//
//  SignUpButton.h
//  Tung
//
//  Created by Jamie Perkins on 10/23/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    kSignUpTypeTwitter,
    kSignUpTypeFacebook
} SignUpButtonType;

@interface SignUpButton : UIButton

@property SignUpButtonType type;

@end
