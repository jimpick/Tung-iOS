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
 - manage 1 global player instance
 - manage player controls
 - manage podcast episode entities
 - manage twitter integration
 */

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import "AppDelegate.h"
#import "Reachability.h"
#import <Social/Social.h>

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

#import "CircleButton.h"

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import <FBSDKShareKit/FBSDKShareKit.h>

@protocol ControlButtonDelegate <NSObject>

//@required


@optional

-(void) initiateSearch;
-(void) dismissPodcastSearch;
-(void) nowPlayingDidChange;

@end

@interface TungCommonObjects : NSObject <UIAlertViewDelegate, UIActionSheetDelegate, NSURLConnectionDataDelegate, AVAssetResourceLoaderDelegate, FBSDKSharingDelegate>

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
@property (nonatomic, retain) UIColor *lightTungColor;
@property (nonatomic, retain) UIColor *mediumTungColor;
@property (nonatomic, retain) UIColor *darkTungColor;
@property (nonatomic, retain) UIColor *bkgdGrayColor;
@property (nonatomic, retain) UIColor *facebookColor;
@property (nonatomic, retain) UIColor *twitterColor;
// player
@property EpisodeEntity *npEpisodeEntity;
@property NSMutableDictionary *npPodcastDict;
@property (strong, nonatomic) UIButton *btn_player;
@property (nonatomic, retain) NSNumberFormatter *clipDurationFormatter;
@property CGFloat totalSeconds;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) NSMutableData *trackData; // data being downloaded
@property NSNumber *currentFeedIndex;
@property NSMutableDictionary *trackInfo;
@property NSInteger playbackRateIndex;
@property NSArray *playbackRates;
@property NSString *playFromTimestamp;
@property (strong, nonatomic) NSMutableArray *playQueue;
@property (strong, nonatomic) UIActivityIndicatorView *btnActivityIndicator;
@property BOOL npViewSetupForCurrentEpisode;
@property BOOL fileIsLocal;
@property BOOL fileIsStreaming; // file can be local and streaming at the same time
@property BOOL shouldStayPaused;

// clip player
@property (nonatomic, strong) AVAudioPlayer *clipPlayer;
- (void) stopClipPlayback;

// twitter
@property (nonatomic, strong) NSArray *arrayOfTwitterAccounts;
@property (nonatomic, strong) ACAccount *twitterAccountToUse;
@property (nonatomic, strong) NSString *twitterAccountStatus;
- (void) establishTwitterAccount;
- (void) postTweetWithText:(NSString *)text andUrl:(NSString *)url;

// facebook
- (void) postToFacebookWithText:(NSString *)text Link:(NSString *)link andEpisode:(EpisodeEntity *)episodeEntity;

// flags
@property (strong, nonatomic) NSNumber *feedNeedsRefresh;

// player
- (void) controlButtonTapped;
- (void) queueAndPlaySelectedEpisode:(NSString *)urlString;
- (void) playNextEpisode;
- (void) dismissSearch;
- (void) cacheFeed:(NSDictionary *)feed forEntity:(PodcastEntity *)entity;
- (NSDictionary*) retrieveCachedFeedForEntity:(PodcastEntity *)entity;
- (void) assignCurrentFeed:(NSArray *)currentFeed;
- (void) savePositionForNowPlaying;
- (BOOL) isPlaying;
- (void) playerPlay;
- (void) playerPause;
- (void) setControlButtonStateToPlay;
- (void) setControlButtonStateToPause;
- (void) setControlButtonStateToAdd;
- (void) setControlButtonStateToBuffering;
- (NSURL *) getEpisodeUrl:(NSURL *)url;
- (void) replacePlayerItemWithLocalCopy;

// core data
+ (BOOL) saveContextWithReason:(NSString*)reason;
+ (PodcastEntity *) getEntityForPodcast:(NSDictionary *)podcastDict save:(BOOL)save;
+ (EpisodeEntity *) getEntityForPodcast:(NSDictionary *)podcastDict andEpisode:(NSDictionary *)episodeDict save:(BOOL)save;
+ (NSString *) findEpisodeDescriptionWithDict:(NSDictionary *)episodeDict;
+ (NSString *) findPodcastDescriptionWithDict:(NSDictionary *)dict;
+ (NSDictionary *) podcastEntityToDict:(PodcastEntity *)podcastEntity;
+ (NSDate *) ISODateToNSDate: (NSString *)pubDate;
+ (UserEntity *) saveUserWithDict:(NSDictionary *)userDict;
+ (UserEntity *) retrieveUserEntityForUserWithId:(NSString *)userId;
+ (NSDictionary *) userEntityToDict:(UserEntity *)userEntity;
- (NSDictionary *) getLoggedInUserData;
- (void) deleteLoggedInUserData;
+ (BOOL) checkForUserData;
+ (BOOL) checkForPodcastData;

// key colors
- (NSArray *) determineKeyColorsFromImage:(UIImage *)image;
- (UIColor *) lightenKeyColor:(UIColor *)keyColor;
- (UIColor *) darkenKeyColor:(UIColor *)keyColor;
+ (NSString *) UIColorToHexString:(UIColor *)color;
+ (UIColor *) colorFromHexString:(NSString *)hexString;

// requests
- (void) establishCred;
- (void) getSessionWithCallback:(void (^)(void))callback;
- (void) killSessionForTesting;
// stories post requests
- (void) addPodcast:(PodcastEntity *)podcastEntity orEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(void))callback;
- (void) restorePodcastDataWithCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) getEpisodeInfoForEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(void))callback;
- (void) subscribeToPodcast:(PodcastEntity *)podcastEntity withButton:(CircleButton *)button;
- (void) unsubscribeFromPodcast:(PodcastEntity *)podcastEntity withButton:(CircleButton *)button;
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
- (void) followAllUsersFromId:(NSString *)target_id withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) signOut;

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
+ (NSNumber *) stringToNumber:(NSString *)string;
+ (NSString *) OSStatusToStr:(OSStatus)status;
+ (void)fadeInView:(UIView *)view;
+ (void)fadeOutView:(UIView *)view;
+ (NSData*) retrievePodcastArtDataWithUrlString:(NSString *)urlString;
+ (NSString *)timeElapsed: (NSString *)secondsString;
+ (NSString*) convertSecondsToTimeString:(CGFloat)totalSeconds;
+ (double) convertTimestampToSeconds:(NSString *)timestamp;
+ (NSURL *) getClipFileURL;
+ (NSString *) getAlbumArtFilenameFromUrlString:(NSString *)artURLString;

@end
