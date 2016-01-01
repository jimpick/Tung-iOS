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
#import "TungMiscView.h"

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
// player
@property EpisodeEntity *npEpisodeEntity;
@property (strong, nonatomic) UIButton *btn_player;
@property (nonatomic, retain) NSNumberFormatter *clipDurationFormatter;
@property CGFloat totalSeconds;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) NSMutableData *trackData; // data being downloaded
@property NSInteger currentFeedIndex;
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

- (void) checkForNowPlaying;
- (void) controlButtonTapped;
- (void) seekToTime:(CMTime)time;
- (void) skipAhead15;
- (void) skipBack15;
- (void) queueAndPlaySelectedEpisode:(NSString *)urlString fromTimestamp:(NSString *)timestamp;
- (void) playUrl:(NSString *)urlString fromTimestamp:(NSString *)timestamp;
- (void) playNextEpisode;
- (void) dismissSearch;
- (void) savePositionForNowPlayingAndSync:(BOOL)sync;
- (BOOL) isPlaying;
- (void) playerPlay;
- (void) playerPause;
- (void) setControlButtonStateToPlay;
- (void) setControlButtonStateToPause;
- (void) setControlButtonStateToFauxDisabled;
- (void) setControlButtonStateToBuffering;
- (NSURL *) getEpisodeUrl:(NSURL *)url;
- (void) replacePlayerItemWithLocalCopy;

// badges
@property (strong, nonatomic) TungMiscView *subscriptionsBadge;
@property (strong, nonatomic) TungMiscView *profileBadge;
- (void) setBadgeNumber:(NSNumber *)number forBadge:(TungMiscView *)badge;

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
@property (strong, nonatomic) NSNumber *profileFeedNeedsRefresh;
@property (strong, nonatomic) NSNumber *profileNeedsRefresh;

// core data
+ (BOOL) saveContextWithReason:(NSString*)reason;
+ (PodcastEntity *) getEntityForPodcast:(NSDictionary *)podcastDict save:(BOOL)save;
+ (EpisodeEntity *) getEntityForEpisode:(NSDictionary *)episodeDict withPodcastEntity:(PodcastEntity *)podcastEntity save:(BOOL)save;
+ (NSString *) findEpisodeDescriptionWithDict:(NSDictionary *)episodeDict;
+ (NSString *) findPodcastDescriptionWithDict:(NSDictionary *)dict;
+ (NSDictionary *) entityToDict:(NSManagedObject *)entity;
+ (NSDate *) ISODateToNSDate: (NSString *)pubDate;
+ (EpisodeEntity *) getEpisodeEntityFromEpisodeId:(NSString *)episodeId;
+ (UserEntity *) saveUserWithDict:(NSDictionary *)userDict;
+ (UserEntity *) retrieveUserEntityForUserWithId:(NSString *)userId;
- (NSDictionary *) getLoggedInUserData;
- (void) deleteLoggedInUserData;
+ (BOOL) checkForUserData;
+ (BOOL) checkForPodcastData;
+ (SettingsEntity *) settings;

// colors
+ (NSArray *) determineKeyColorsFromImage:(UIImage *)image;
+ (UIColor *) lightenKeyColor:(UIColor *)keyColor;
+ (UIColor *) darkenKeyColor:(UIColor *)keyColor;
+ (NSString *) UIColorToHexString:(UIColor *)color;
+ (UIColor *) colorFromHexString:(NSString *)hexString;
+ (UIColor *) tungColor;
+ (UIColor *) lightTungColor;
+ (UIColor *) mediumTungColor;
+ (UIColor *) darkTungColor;
+ (UIColor *) bkgdGrayColor;
+ (UIColor *) facebookColor;
+ (UIColor *) twitterColor;

// requests
- (void) establishCred;
- (void) getSessionWithCallback:(void (^)(void))callback;
- (void) killSessionForTesting;
// stories post requests
- (void) addPodcast:(PodcastEntity *)podcastEntity orEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(void))callback;
- (void) restorePodcastDataSinceTime:(NSNumber *)time;
- (void) addEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(void))callback;
- (void) subscribeToPodcast:(PodcastEntity *)podcastEntity withButton:(CircleButton *)button;
- (void) unsubscribeFromPodcast:(PodcastEntity *)podcastEntity withButton:(CircleButton *)button;
- (void) recommendEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) unRecommendEpisode:(EpisodeEntity *)episodeEntity;
- (void) syncProgressForEpisode:(EpisodeEntity *)episodeEntity;
- (void) postComment:(NSString*)comment atTime:(NSString*)timestamp onEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) postClipWithComment:(NSString*)comment atTime:(NSString*)timestamp withDuration:(NSString *)duration onEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) deleteStoryEventWithId:(NSString *)eventId withCallback:(void (^)(BOOL success))callback;
- (void) flagCommentWithId:(NSString *)eventId;
- (void) requestEpisodeInfoForId:(NSString *)episodeId andCollectionId:(NSString *)collectionId withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
// user requests
- (void) getProfileDataForUser:(NSString *)target_id withCallback:(void (^)(NSDictionary *jsonData))callback;
- (void) updateUserWithDictionary:(NSDictionary *)userInfo withCallback:(void (^)(NSDictionary *jsonData))callback;
- (void) followUserWithId:(NSString *)target_id withCallback:(void (^)(BOOL success))callback;
- (void) unfollowUserWithId:(NSString *)target_id withCallback:(void (^)(BOOL success))callback;
- (void) followAllUsersFromId:(NSString *)target_id withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) signOut;

// caching
+ (NSData*) retrieveLargeAvatarDataWithUrlString:(NSString *)urlString;
+ (NSData*) retrieveSmallAvatarDataWithUrlString:(NSString *)urlString;
+ (NSData*) retrieveAudioClipDataWithUrlString:(NSString *)urlString;
+ (NSData*) retrieveSSLPodcastArtDataWithUrlString:(NSString *)urlString;
+ (NSData*) retrievePodcastArtDataWithUrlString:(NSString *)urlString andCollectionId:(NSNumber *)collectionId;
+ (NSURL *) getClipFileURL;
+ (NSString *) getAlbumArtFilenameFromUrlString:(NSString *)artURLString;

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
+ (NSString *)timeElapsed: (NSString *)secondsString;
+ (NSString*) convertSecondsToTimeString:(CGFloat)totalSeconds;
+ (double) convertTimestampToSeconds:(NSString *)timestamp;
+ (NSInteger) getIndexOfEpisodeWithUrl:(NSString *)urlString inFeed:(NSArray *)feed;
+ (BOOL) hasGrantedNotificationPermissions;

@end
