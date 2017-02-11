//
//  tungCommonObjects.h
//  Tung
//
//  Created by Jamie Perkins on 5/22/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//
/*
 - holds logged in user entity
 - holds server session
 - manage global properties
 - manage 1 global player instance
 - manage player controls
 - manage podcast episode entities
 - manage twitter/facebook integration
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

// constants
#define MAX_RECORD_TIME 29
#define MIN_RECORD_TIME 2
#define MAX_COMMENT_CHARS 220

@interface TungCommonObjects : NSObject <NSURLConnectionDataDelegate, AVAssetResourceLoaderDelegate, FBSDKSharingDelegate>

// for presenting views, etc.
@property (strong, nonatomic) UIViewController *viewController;
// cred/session
@property (strong, nonatomic) UserEntity *loggedInUser;
@property (strong, nonatomic) NSString *sessionId;
@property NSNumber *connectionAvailable;

// player
@property EpisodeEntity *npEpisodeEntity;
@property (strong, nonatomic) UIButton *btn_player;
@property (nonatomic, retain) NSNumberFormatter *clipDurationFormatter;
@property CGFloat totalSeconds;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) NSMutableData *trackData; // data being downloaded
@property (nonatomic, strong) NSMutableData *saveTrackData;
@property NSInteger currentFeedIndex;
@property NSMutableDictionary *trackInfo;
@property NSInteger playbackRateIndex;
@property NSArray *playbackRates;
@property NSString *playFromTimestamp;
@property (strong, nonatomic) NSMutableArray *playQueue;
@property (strong, nonatomic) UIActivityIndicatorView *btnActivityIndicator;
@property BOOL npViewSetupForCurrentEpisode;
@property BOOL fileIsLocal;
@property BOOL fileIsStreaming;
@property BOOL fileWillBeCached; // file will only be cached if custom url scheme is used
@property BOOL shouldStayPaused;
@property BOOL saveOnDownloadComplete;


+ (id) establishTungObjects;
+ (CGSize) screenSize;
+ (NSString *) apiRootUrl;
+ (NSString *) tungSiteRootUrl;
+ (NSString *) apiKey;
+ (UIViewController *) activeViewController;
+ (CGFloat) iOSVersionFloat;

- (void) checkForNowPlaying;
- (void) controlButtonTapped;
- (void) seekToTime:(CMTime)time;
- (void) skipAhead15;
- (void) skipBack15;
- (void) queueAndPlaySelectedEpisode:(NSString *)urlString fromTimestamp:(NSString *)timestamp;
- (void) playUrl:(NSString *)urlString fromTimestamp:(NSString *)timestamp;
- (void) playNextEpisode;
- (void) savePositionForNowPlayingAndSync:(BOOL)sync;
- (BOOL) isPlaying;
- (void) playerPlay;
- (void) playerPause;
- (void) setControlButtonStateToPlay;
- (void) setControlButtonStateToPause;
- (void) setControlButtonStateToFauxDisabled;
- (void) setControlButtonStateToBuffering;
- (void) removeNowPlayingStatusFromAllEpisodes;
- (NSURL *) getStreamUrlForEpisodeEntity:(EpisodeEntity *)epEntity;
- (void) reestablishPlayerItemAndReplace;
- (NSArray *) getFeedOfNowPlayingEpisodeAndSetCurrentFeedIndex;
- (void) playRandomEpisode;

// caching/saving episodes
@property EpisodeEntity *episodeToSaveEntity;
+ (NSString *) getSavedEpisodesDirectoryPath;
+ (NSString *) getCachedEpisodesDirectoryPath;
+ (NSString *) getEpisodeFilenameForEntity:(EpisodeEntity *)epEntity;
- (void) cacheNowPlayingEpisodeAndMoveToSaved:(BOOL)moveToSaved;
- (void) queueEpisodeForDownload:(EpisodeEntity *)episodeEntity;
- (void) cancelDownloadForEpisode:(EpisodeEntity *)episodeEntity;
- (void) downloadEpisode:(EpisodeEntity *)episodeEntity;
- (void) deleteSavedEpisode:(EpisodeEntity *)epEntity confirm:(BOOL)confirm;
- (void) deleteAllSavedEpisodes;
+ (void) deleteAllCachedEpisodes;
+ (void) deleteCachedData;
- (void) showSavedInfoAlertForEpisode:(EpisodeEntity *)episodeEntity;
- (BOOL) moveToSavedOrQueueDownloadForEpisode:(EpisodeEntity *)episodeEntity;

// badges
@property (strong, nonatomic) TungMiscView *subscriptionsBadge;
@property (strong, nonatomic) TungMiscView *profileBadge;
- (void) setBadgeNumber:(NSNumber *)number forBadge:(TungMiscView *)badge;

// clip player
@property (nonatomic, strong) AVAudioPlayer *clipPlayer;
- (void) stopClipPlayback;

// feed related
- (void) checkFeedsLastFetchedTime;

// flags
@property (strong, nonatomic) NSNumber *feedNeedsRefresh;
@property (strong, nonatomic) NSNumber *feedNeedsRefetch;
@property (strong, nonatomic) NSNumber *profileFeedNeedsRefresh;
@property (strong, nonatomic) NSNumber *profileFeedNeedsRefetch;
@property (strong, nonatomic) NSNumber *profileNeedsRefresh;
@property (strong, nonatomic) NSNumber *notificationsNeedRefresh;
@property (strong, nonatomic) NSNumber *trendingFeedNeedsRefresh;
@property (strong, nonatomic) NSNumber *trendingFeedNeedsRefetch;

// core data
+ (BOOL) saveContextWithReason:(NSString*)reason;
+ (PodcastEntity *) getEntityForPodcast:(NSDictionary *)podcastDict save:(BOOL)save;
+ (EpisodeEntity *) getEntityForEpisode:(NSDictionary *)episodeDict withPodcastEntity:(PodcastEntity *)podcastEntity save:(BOOL)save;
+ (NSDictionary *) getEnclosureDictForEpisode:(NSDictionary *)episodeDict;
+ (NSString *) getUrlStringFromEpisodeDict:(NSDictionary *)episodeDict;
+ (NSString *) findEpisodeDescriptionWithDict:(NSDictionary *)episodeDict;
+ (NSDictionary *) entityToDict:(NSManagedObject *)entity;
+ (NSDate *) ISODateToNSDate: (NSString *)pubDate;
+ (EpisodeEntity *) getEpisodeEntityFromEpisodeId:(NSString *)episodeId;
+ (EpisodeEntity *) getEpisodeEntityFromUrlString:(NSString *)urlString;
+ (NSArray *) getAllSubscribedPodcasts;
+ (UserEntity *) saveUserWithDict:(NSDictionary *)userDict isLoggedInUser:(BOOL)isLoggedInUser;
+ (UserEntity *) retrieveUserEntityForUserWithId:(NSString *)userId;
+ (UserEntity *) getLoggedInUser;
+ (BOOL) checkForUserData;
+ (BOOL) checkForPodcastData;
+ (SettingsEntity *) settings;

// colors
+ (NSArray *) extractColorsFromImage:(UIImage *)image;
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
- (void) checkReachabilityWithCallback:(void (^)(BOOL reachable))callback;
- (void) getSessionWithCallback:(void (^)(void))callback;
- (void) handleUnauthorizedWithCallback:(void (^)(void))callback;
// stories post requests
+ (void) addOrUpdatePodcast:(PodcastEntity *)podcastEntity orEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(void))callback;
- (void) restorePodcastDataSinceTime:(NSNumber *)time;
- (void) addEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(void))callback;
- (void) subscribeToPodcast:(PodcastEntity *)podcastEntity withButton:(CircleButton *)button;
- (void) unsubscribeFromPodcast:(PodcastEntity *)podcastEntity withButton:(CircleButton *)button;
- (void) recommendEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success))callback;
- (void) unRecommendEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success))callback;;
- (void) syncProgressForEpisode:(EpisodeEntity *)episodeEntity;
- (void) incrementPlayCountForEpisode:(EpisodeEntity *)episodeEntity;
- (void) postComment:(NSString*)comment atTime:(NSString*)timestamp onEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) postClipWithComment:(NSString*)comment atTime:(NSString*)timestamp withDuration:(NSString *)duration onEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) deleteStoryEventWithId:(NSString *)eventId withCallback:(void (^)(BOOL success))callback;
- (void) flagCommentWithId:(NSString *)eventId;
+ (void) requestEpisodeInfoWithDict:(NSDictionary *)dict andCallback:(void (^)(BOOL success, NSDictionary *response))callback;
+ (void) requestPodcastInfoForCollectionId:(NSString *)collectionId withCallback:(void (^)(BOOL success, NSDictionary *response))callback;

// user requests
- (void) getProfileDataForUserWithId:(NSString *)target_id orUsername:(NSString *)username withCallback:(void (^)(NSDictionary *jsonData))callback;
- (void) updateUserWithDictionary:(NSDictionary *)userInfo withCallback:(void (^)(NSDictionary *jsonData))callback;
- (void) followUserWithId:(NSString *)target_id withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) unfollowUserWithId:(NSString *)target_id withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) getSuggestedUsersWithCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) preloadAlbumArtForSuggestedUsers:(NSArray *)suggestedUsers;
- (void) inviteFriends:(NSString *)friends;
- (void) removeSignedInUserData;
- (void) resetPlayerAndQueue;
- (void) signOut;

// media library/auto-import
- (void) promptAndRequestMediaLibraryAccess;
- (void) queryExistingPodcastSubscriptions;
- (void) bulkSubscribeToPodcastsWithTitles:(NSArray *)titles ;

// twitter
- (void) postTweetWithText:(NSString *)text andUrl:(NSString *)url;
- (void) verifyCredWithTwitterOauthHeaders:(NSDictionary *)headers withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) findTwitterFriendsWithPage:(NSNumber *)page andCallback:(void (^)(BOOL success, NSDictionary *response))callback;

// facebook
- (void) postToFacebookWithText:(NSString *)text Link:(NSString *)link andEpisode:(EpisodeEntity *)episodeEntity;
- (void) verifyCredWithFacebookAccessToken:(NSString *)token withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) findFacebookFriendsWithFacebookAccessToken:(NSString *)token withCallback:(void (^)(BOOL success, NSDictionary *response))callback;
- (void) getFacebookFriendsListPermissionsWithSuccessCallback:(void (^)(void))successCallback;

// alerts
- (void) promptForNotificationsForEpisodes;
- (void) promptForNotificationsForMentions;
+ (void) showConnectionErrorAlertForError:(NSError *)error;
+ (void) showNoConnectionAlert;
+ (void) showBannerAlertForText:(NSString *)text;
+ (void) simpleErrorAlertWithMessage:(NSString *)message;

// caching
+ (NSData*) retrieveLargeAvatarDataWithUrlString:(NSString *)urlString;
+ (void) replaceCachedLargeAvatarWithDataAtUrlString:(NSString *)urlString;
+ (NSData*) retrieveSmallAvatarDataWithUrlString:(NSString *)urlString;
+ (void) replaceCachedSmallAvatarWithDataAtUrlString:(NSString *)urlString;
+ (NSData*) retrieveAudioClipDataWithUrlString:(NSString *)urlString;
+ (NSString *) getCachedPodcastArtDirectoryPathForDefaultSize:(BOOL)small;
+ (NSString *) getSavedPodcastArtDirectoryPathForDefaultSize:(BOOL)small;
+ (BOOL) savePodcastArtForEntity:(PodcastEntity *)podcastEntity;
+ (BOOL) unsavePodcastArtForEntity:(PodcastEntity *)podcastEntity;
+ (NSData *) retrievePodcastArtDataForEntity:(PodcastEntity *)entity defaultSize:(BOOL)small;
+ (NSData *) retrieveDefaultSizePodcastArtDataWithUrlString:(NSString *)urlString;
+ (NSData*) retrievePodcastArtDataWithUrlString:(NSString *)urlString andCollectionId:(NSNumber *)collectionId defaultSize:(BOOL)small;
+ (NSData *) downloadAndCachePodcastArtForUrlString:(NSString *)urlString andCollectionId:(NSNumber *)collectionId defaultSize:(BOOL)small;
+ (NSData *) processPodcastArtForEntity:(PodcastEntity *)entity;
+ (void) replaceCachedPodcastArtForEntity:(PodcastEntity *)entity withNewArt:(NSString *)newArtUrlString;
+ (NSString *) getPodcastArtPathForEntity:(PodcastEntity *)podcastEntity defaultSize:(BOOL)small;
+ (NSURL *) getClipFileURL;

// keychain
- (void) establishCred;
- (void) saveKeychainCred: (NSString *)cred;
+ (NSString *) getKeychainCred;
+ (void) deleteCredentials;

// misc class methods
+ (void) clearTempDirectory;
+ (NSString *) generateHash;
+ (NSData *) generateBodyFromDictionary:(NSDictionary *)dict withBoundary:(NSString *)boundary;
+ (NSData *) serializeParamsForPostRequest:(NSDictionary *)params;
+ (NSString *) serializeParamsForGetRequest:(NSDictionary *)params;
+ (NSString *) cleanURLStringFromString:(NSString*)string;
+ (NSString *) formatNumberForCount:(NSNumber*)count;
+ (NSNumber *) stringToNumber:(NSString *)string;
+ (NSString *) audioFileStatusToString:(OSStatus)status;
+ (NSString *) keychainStatusToString:(OSStatus)status;
+ (void)fadeInView:(UIView *)view;
+ (void)fadeOutView:(UIView *)view;
+ (NSString *)timeElapsed: (NSString *)secondsString;
+ (NSString*) convertSecondsToTimeString:(CGFloat)totalSeconds;
+ (double) convertTimestampToSeconds:(NSString *)timestamp;
+ (NSString *) formatDurationFromString:(NSString *)duration;
+ (NSInteger) getIndexOfEpisodeWithGUID:(NSString *)guid inFeed:(NSArray *)feed;
+ (NSNumber *) getAllocatedSizeOfDirectoryAtURL:(NSURL *)directoryURL error:(NSError * __autoreleasing *)error;
+ (NSString *) formatBytes:(NSNumber *)bytes;
+ (UIImage *) image:(UIImage *)img croppedAndScaledToSquareSizeWithDimension:(CGFloat)dimension;
+ (NSURL *) addReferrerToUrlString:(NSString *)urlString;
+ (NSURL *) urlFromString:(id)urlString;
+ (NSString *) stringFromUrl:(id)url;
+ (NSString *) truncateStringWithEllipsis:(NSString *)string toLength:(NSInteger)length;

@end
