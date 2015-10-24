//
//  CircleButton.h
//  Tung
//
//  Created by Jamie Perkins on 5/7/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    kCircleTypeSubscribe,
    kCircleTypeNewClip,
    kCircleTypeRecommend,
    kCircleTypeShare,
    kCircleTypeWebsite,
    kCircleTypeRecord,
    kCircleTypePlayClip,
    kCircleTypeCancel,
    kCircleTypeOkay,
    kCircleTypeComment,
    kCircleTypeTwitter,
    kCircleTypeFacebook,
    kCircleTypeTextButton,
    kCircleTypeSpeed,
    kCircleTypeSave,
    kCircleTypePlay
} CircleButtonType;

@interface CircleButton : UIButton

@property CircleButtonType type;
@property (copy) UIColor *color; // subscribe btn
@property (copy) NSString *buttonText; // pill text button
@property BOOL subscribed; // subscribe btn
@property BOOL recommended; // recommend btn
@property BOOL isRecording; // record btn
@property BOOL isPlaying; // play
@property BOOL on; // twitter/facebook

@end
