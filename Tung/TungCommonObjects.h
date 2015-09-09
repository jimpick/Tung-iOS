//
//  tungCommonObjects.h
//  Tung
//
//  Created by Jamie Perkins on 5/22/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//
/*
 - manage user credentials
 - manage server session
 - manage global properties
 - manage 1 global streamer instance
 - manage player controls
 - manage podcast episode entities
 - manage twitter integration
 */

#import <Foundation/Foundation.h>
#import <FacebookSDK/FacebookSDK.h>
#import <Security/Security.h>
#import "Reachability.h"
#import "FSAudioStream.h"
#import <AudioToolbox/AudioToolbox.h>
#import "CircleButton.h"
#import "AppDelegate.h"

@protocol ControlButtonDelegate <NSObject>

@required

-(void) initiateSearch;
-(void) dismissPodcastSearch;

@optional

-(void) nowPlayingDidChange;

@end

@interface TungCommonObjects : NSObject <UIAlertViewDelegate, UIActionSheetDelegate, FSPCMAudioStreamDelegate>

@property (nonatomic, assign) id <ControlButtonDelegate> ctrlBtnDelegate;
// for presenting views, etc.
@property (strong, nonatomic) UIViewController *viewController;
// cred/session
@property (strong, nonatomic) NSString *tungId;
@property (strong, nonatomic) NSString *tungToken;
@property (strong, nonatomic) NSString *sessionId;
@property NSNumber *connectionAvailable;
// root info
@property (strong, nonatomic) NSString *tung_version;
@property (nonatomic, retain) NSString *tungSiteRootUrl;
@property (nonatomic, retain) NSString *apiRootUrl;
@property (nonatomic, retain) NSString *twitterApiRootUrl;
// colors
@property (nonatomic, retain) UIColor *tungColor;
@property (nonatomic, retain) UIColor *darkTungColor;
@property (nonatomic, retain) UIColor *bkgdGrayColor;
@property (nonatomic, retain) UIColor *facebookColor;
@property (nonatomic, retain) UIColor *twitterColor;
// player
@property EpisodeEntity *npEpisodeEntity;
@property NSMutableDictionary *npPodcastDict;
@property (strong, nonatomic) UIButton *btn_player;
@property (nonatomic, retain) NSNumberFormatter *clipDurationFormatter;
@property (nonatomic, readonly) FSAudioStream *streamer;
@property (nonatomic) FSAudioStreamState streamerState;
@property (strong, nonatomic) NSMutableArray *playQueue;
@property (strong, nonatomic) UIActivityIndicatorView *btnActivityIndicator;
@property BOOL lockPosbar;
@property BOOL npViewSetupForCurrentEpisode;
@property BOOL canRecord;
// twitter
@property (nonatomic, strong) NSArray *arrayOfTwitterAccounts;
@property (nonatomic, strong) ACAccount *twitterAccountToUse;
@property (nonatomic, strong) NSString *twitterAccountStatus;
// table
@property (strong, nonatomic) NSNumber *needsReload;

// player
- (void) controlButtonTapped;
- (void) queueAndPlaySelectedEpisode:(NSString *)urlString;
- (void) playNextPodcast;
- (void) dismissSearch;
- (void) cacheFeed:(NSDictionary *)feed forEntity:(PodcastEntity *)entity;
- (NSDictionary*) retrieveCachedFeedForEntity:(PodcastEntity *)entity;
- (void) assignCurrentFeed:(NSArray *)currentFeed;
- (void) savePositionForNowPlaying;

+ (NSString*) convertSecondsToTimeString:(CGFloat)totalSeconds;
+ (double) convertDurationStringToSeconds:(NSString *)duration;
+ (NSURL *) getClipFileURL;

// core data
+ (BOOL) saveContext;
+ (PodcastEntity *) savePodcast:(NSDictionary *)podcastDict;
+ (EpisodeEntity *) savePodcast:(NSDictionary *)podcastDict andEpisode:(NSDictionary *)episodeDict;
+ (NSString *) findEpisodeDescriptionWithDict:(NSDictionary *)episodeDict;
+ (NSString *) findPodcastDescriptionWithDict:(NSDictionary *)dict;
+ (NSDictionary *) podcastEntityToDict:(PodcastEntity *)podcastEntity;
+ (UserEntity *) saveUserWithDict:(NSDictionary *)userDict;
+ (UserEntity *) retrieveUserEntityForUserWithId:(NSString *)userId;
+ (NSDictionary *) userEntityToDict:(UserEntity *)userEntity;
- (NSDictionary *) getLoggedInUserData;
- (void) deleteLoggedInUserData;

// color cube
- (NSArray *) determineKeyColorsFromImage:(UIImage *)image;
- (UIColor *) lightenKeyColor:(UIColor *)keyColor;
- (UIColor *) darkenKeyColor:(UIColor *)keyColor;

// requests
- (void) establishCred;
- (void) getSessionWithCallback:(void (^)(void))callback;
- (void) killSessionForTesting;
// stories requests
- (void) addPodcast:(PodcastEntity *)podcastEntity withCallback:(void (^)(void))callback;
- (void) addEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(void))callback;
- (void) subscribeToPodcast:(PodcastEntity *)podcastEntity andButton:(CircleButton *)button;
- (void) unsubscribeFromPodcast:(PodcastEntity *)podcastEntity andButton:(CircleButton *)button;
- (void) recommendEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) unRecommendEpisode:(EpisodeEntity *)episodeEntity;
- (void) incrementListenCount:(EpisodeEntity *)episodeEntity;
- (void) postComment:(NSString*)comment atTime:(NSString*)timestamp onEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) postClipWithComment:(NSString*)comment atTime:(NSString*)timestamp withDuration:(NSString *)duration onEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
// user requests
- (void) getUserIdFromUsername:(NSString *)username withCallback:(void (^)(NSDictionary *jsonData))callback;
- (void) getProfileDataForUser:(NSString *)target_id withCallback:(void (^)(NSDictionary *jsonData))callback;
- (void) restoreUserDataWithCallback:(void (^)(void))callback;
- (void) updateUserWithDictionary:(NSDictionary *)userInfo withCallback:(void (^)(NSDictionary *jsonData))callback;
- (void) followUserWithId:(NSString *)target_id withCallback:(void (^)(BOOL success))callback;
- (void) unfollowUserWithId:(NSString *)target_id withCallback:(void (^)(BOOL success))callback;
- (void) signOut;
// twittter
- (void) establishTwitterAccount;
- (void) postTweetWithText:(NSString *)text andUrl:(NSString *)url;
// facebook
- (void) postToFacebookWithText:(NSString *)text andShortLink:(NSString *)shortLink tag:(BOOL)tag;
// class methods
+ (id) establishTungObjects;
+ (void) clearTempDirectory;
+ (void) checkReachabilityWithCallback:(void (^)(BOOL reachable))callback;
+ (NSString *) generateHash;
+ (NSString *) getKeychainCred;
+ (void) saveKeychainCred: (NSString *)cred;
+ (NSData *) generateBodyFromDictionary:(NSDictionary *)dict withBoundary:(NSString *)boundary;
+ (NSData *) serializeParamsForPostRequest:(NSDictionary *)params;
+ (NSString *) serializeParamsForGetRequest:(NSDictionary *)params;
+ (void) deleteCredentials;
+ (NSString *) cleanURLStringFromString:(NSString*)string;
+ (NSString *) formatNumberForCount:(NSNumber*)count;
+ (NSString *) UIColorToHexString:(UIColor *)color;
+ (NSString *) OSStatusToStr:(OSStatus)status;
+ (void)fadeInView:(UIView *)view;
+ (void)fadeOutView:(UIView *)view;
+ (NSData*) retrievePodcastArtDataWithUrlString:(NSString *)urlString;

@end
