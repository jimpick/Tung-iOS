//
//  TungPodcastStyleKit.h
//  Tung
//
//  Created by Jamie Perkins on 6/21/16.
//  Copyright (c) 2016 Inorganik Produce, Inc. All rights reserved.
//
//  Generated by PaintCode (www.paintcodeapp.com)
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface TungPodcastStyleKit : NSObject

// Colors
+ (UIColor*)tungColor;
+ (UIColor*)twitterBlue;
+ (UIColor*)facebookBlue;
+ (UIColor*)tungColorMediumLight;
+ (UIColor*)green;

// Drawing Methods
+ (void)drawSubscribeIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawDonateIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawRecommendIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawCommentIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawClipIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawQueueIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawSaveIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawCancelIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawCheckmarkIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawShareIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawWebsiteIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawPlayIconWithColor: (UIColor*)color;
+ (void)drawStopIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawRecordIconWithColor: (UIColor*)color;
+ (void)drawSubscribeIconSolidWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawHideIconWithColor: (UIColor*)color;
+ (void)drawShowIconWithColor: (UIColor*)color;
+ (void)drawAddCircleIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawOptionsIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawTwitterIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawFacebookIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawNowPlayingIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawAddIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawExitIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawProfileIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawFeedIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawPauseIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawProfileSearchIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawClipIconRandomWithFrame: (CGRect)frame;
+ (void)drawSkipBack15IconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawSkipAhead15IconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawSettingsIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawTinyRecommendIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawFindFriendsIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawPlayCountIconWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawTungLogotypeWithFrame: (CGRect)frame color: (UIColor*)color;
+ (void)drawSubscribeButtonWithFrame: (CGRect)frame color: (UIColor*)color on: (BOOL)on down: (BOOL)down;
+ (void)drawClipButtonWithFrame: (CGRect)frame down: (BOOL)down;
+ (void)drawRecommendButtonWithFrame: (CGRect)frame on: (BOOL)on down: (BOOL)down;
+ (void)drawShareButtonWithFrame: (CGRect)frame down: (BOOL)down;
+ (void)drawWebsiteButtonWithFrame: (CGRect)frame down: (BOOL)down disabled: (BOOL)disabled;
+ (void)drawClipRecordButtonWithFrame: (CGRect)frame on: (BOOL)on down: (BOOL)down disabled: (BOOL)disabled;
+ (void)drawClipPlayButtonWithFrame: (CGRect)frame on: (BOOL)on down: (BOOL)down disabled: (BOOL)disabled;
+ (void)drawClipCancelButtonWithFrame: (CGRect)frame down: (BOOL)down disabled: (BOOL)disabled;
+ (void)drawClipOkButtonWithFrame: (CGRect)frame down: (BOOL)down disabled: (BOOL)disabled;
+ (void)drawHideControlsButtonWithFrame: (CGRect)frame;
+ (void)drawShowControlsButtonWithFrame: (CGRect)frame;
+ (void)drawCommentButtonWithFrame: (CGRect)frame on: (BOOL)on down: (BOOL)down disabled: (BOOL)disabled;
+ (void)drawTwitterButtonWithFrame: (CGRect)frame on: (BOOL)on down: (BOOL)down;
+ (void)drawFacebookButtonWithFrame: (CGRect)frame on: (BOOL)on down: (BOOL)down;
+ (void)drawPillTextbuttonWithFrame: (CGRect)frame down: (BOOL)down disabled: (BOOL)disabled buttonText: (NSString*)buttonText;
+ (void)drawSpeedButtonWithFrame: (CGRect)frame down: (BOOL)down buttonText: (NSString*)buttonText;
+ (void)drawSaveButtonWithFrame: (CGRect)frame on: (BOOL)on down: (BOOL)down;
+ (void)drawTungButtonOnWhiteWithFrame: (CGRect)frame down: (BOOL)down buttonText: (NSString*)buttonText;
+ (void)drawFollowButtonWithFrame: (CGRect)frame on: (BOOL)on down: (BOOL)down;
+ (void)drawPillButtonOnDarkWithFrame: (CGRect)frame down: (BOOL)down buttonText: (NSString*)buttonText;
+ (void)drawPlayButtonWithFrame: (CGRect)frame color: (UIColor*)color on: (BOOL)on down: (BOOL)down;
+ (void)drawSignUpWithTwitterWithFrame: (CGRect)frame down: (BOOL)down;
+ (void)drawSignUpWithFacebookWithFrame: (CGRect)frame down: (BOOL)down;
+ (void)drawSupportButtonWithFrame: (CGRect)frame down: (BOOL)down;
+ (void)drawSaveWithProgressWithFrame: (CGRect)frame on: (BOOL)on arc: (CGFloat)arc queued: (BOOL)queued;
+ (void)drawMagicButtonWithFrame: (CGRect)frame down: (BOOL)down buttonText: (NSString*)buttonText subtitle: (NSString*)subtitle;
+ (void)drawClipProgressWithFrame: (CGRect)frame buttonText: (NSString*)buttonText arc: (CGFloat)arc;
+ (void)drawCommentBkgdWithOuterFrame: (CGRect)outerFrame;
+ (void)drawCommentBkgdUserWithOuterFrame: (CGRect)outerFrame;
+ (void)drawEpisodeProgressWithOuterFrame: (CGRect)outerFrame color: (UIColor*)color progress: (CGFloat)progress;
+ (void)drawPopupWithArrowLeftWithFrame: (CGRect)frame;
+ (void)drawPopupWithArrowRightWithFrame: (CGRect)frame;
+ (void)drawSolidCircleWithFrame: (CGRect)frame;
+ (void)drawLargeBadgeWithFrame: (CGRect)frame buttonText: (NSString*)buttonText;
+ (void)drawSmallBadgeWithFrame: (CGRect)frame buttonText: (NSString*)buttonText;

@end
