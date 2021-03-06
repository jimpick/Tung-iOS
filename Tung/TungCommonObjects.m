//
//  tungCommonObjects.m
//  Tung
//
//  Created by Jamie Perkins on 5/22/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//


#import "TungCommonObjects.h"
#import "ALDisk.h"
#import "CCColorCube.h"
#import "TungPodcast.h"
#import <CommonCrypto/CommonDigest.h>
#import "KLCPopup.h"
#import "BannerAlert.h"
#import <MobileCoreServices/MobileCoreServices.h> // for AVURLAsset resource loading

@interface TungCommonObjects()

// caching episodes
@property (nonatomic, strong) NSURLConnection *trackDataConnection;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSMutableArray *pendingRequests;
// saving episodes
@property (nonatomic, strong) NSURLConnection *saveTrackConnection;
@property (nonatomic, strong) NSMutableArray *episodeSaveQueue;
@property (strong, nonatomic) NSTimer *savedStatusNotifTimer;
@property CGFloat bytesToSave;

@property (strong, nonatomic) NSTimer *syncProgressTimer;
@property (strong, nonatomic) NSTimer *incPlayCountTimer;
@property (strong, nonatomic) NSTimer *spinnerCheckTimer;
@property (strong, nonatomic) NSNumber *gettingSession;
@property NSArray *currentFeed;

@end

@implementation TungCommonObjects

NSDateFormatter *ISODateFormatter;

+ (id)establishTungObjects {
    static TungCommonObjects *tungObjects = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tungObjects = [[self alloc] init];
    });
    return tungObjects;
}

+ (NSString *) apiRootUrl {
    if (IS_PROD_ENV)
    	return @"https://api.tung.fm/";
	else
    	return @"https://staging-api.tung.fm/";
}

+ (NSString *) tungSiteRootUrl {
    if (IS_PROD_ENV)
    	return @"https://tung.fm/";
    else
    	return @"https://staging.tung.fm/";
}

- (id)init {
    if (self = [super init]) {
        
        _sessionId = @"";
        
        _loggedInUser = [TungCommonObjects getLoggedInUser];
        
        //NSLog(@"logged in user: %@", [TungCommonObjects entityToDict:_loggedInUser]);
        
        // flags
        _feedNeedsRefresh = [NSNumber numberWithBool:NO];
        _feedNeedsRefetch = [NSNumber numberWithBool:NO];
        _profileFeedNeedsRefresh = [NSNumber numberWithBool:NO];
        _profileFeedNeedsRefetch = [NSNumber numberWithBool:NO];
        _profileNeedsRefresh = [NSNumber numberWithBool:NO];
        _notificationsNeedRefresh = [NSNumber numberWithBool:NO];
        _trendingFeedNeedsRefresh = [NSNumber numberWithBool:NO];
        _trendingFeedNeedsRefetch = [NSNumber numberWithBool:NO];
        
        _connectionAvailable = [NSNumber numberWithBool:NO];
        
        _trackInfo = [[NSMutableDictionary alloc] init];
        
        // playback speed
        _playbackRates = @[[NSNumber numberWithFloat:.75],
                           [NSNumber numberWithFloat:1.0],
                           [NSNumber numberWithFloat:1.5],
                           [NSNumber numberWithFloat:2.0]];
        _playbackRateIndex = 1;
        
        // audio session
        if ([[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil]) {
            [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMediaServicesReset) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRouteChange:) name:AVAudioSessionRouteChangeNotification object:nil];
        
        // command center events
        MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
        [commandCenter.playCommand addTarget:self action:@selector(playerPlay)];
        [commandCenter.pauseCommand addTarget:self action:@selector(playerPause)];
        [commandCenter.seekForwardCommand addTarget:self action:@selector(playNextNewerEpisodeInFeed)];
        [commandCenter.seekBackwardCommand addTarget:self action:@selector(seekBack)];
        [commandCenter.previousTrackCommand addTarget:self action:@selector(playNextOlderEpisodeInFeed)];
        [commandCenter.nextTrackCommand addTarget:self action:@selector(playNextNewerEpisodeInFeed)];
        [commandCenter.skipBackwardCommand addTarget:self action:@selector(skipBack15)];
        [commandCenter.skipForwardCommand addTarget:self action:@selector(skipAhead15)];
        
        ISODateFormatter = [[NSDateFormatter alloc] init];
        [ISODateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        
        _episodeSaveQueue = [NSMutableArray array];
        _bytesToSave = 0;


        /* show what's in saved episodes dir
        NSError *fError = nil;
        NSString *savedEpisodesDir = [self getSavedEpisodesDirectoryPath];
        NSArray *savedEpisodesDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:savedEpisodesDir error:&fError];
        JPLog(@"saved episodes folder contents ---------------");
        if ([savedEpisodesDirContents count] > 0 && fError == nil) {
            for (NSString *item in savedEpisodesDirContents) {
                JPLog(@"- %@", item);
            }
        }*/
        
        /* show what's in cached episodes dir
        fError = nil;
        NSString *cachedEpisodesDir = [self getCachedEpisodesDirectoryPath];
        NSArray *cachedEpisodesDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cachedEpisodesDir error:&fError];
        JPLog(@"cached episodes folder contents ---------------");
        if ([cachedEpisodesDirContents count] > 0 && fError == nil) {
            for (NSString *item in cachedEpisodesDirContents) {
                JPLog(@"- %@", item);
            }
        } */
        
        /* show what's in cached podcast art dir
        NSError *fError = nil;
        NSString *cachedPodcastArtDir = [TungCommonObjects getCachedPodcastArtDirectoryPath];
        NSArray *cachedArtDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cachedPodcastArtDir error:&fError];
        JPLog(@"cached podcast art folder contents ---------------");
        if ([cachedArtDirContents count] > 0 && fError == nil) {
            for (NSString *item in cachedArtDirContents) {
             	JPLog(@"- %@", item);
            }
        }
         */
        
        /* show what's in temp dir
         NSError *ftError = nil;
         NSArray *tmpFolderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:&ftError];
         JPLog(@"temp folder contents ---------------");
         if ([tmpFolderContents count] > 0 && ftError == nil) {
             for (NSString *item in tmpFolderContents) {
             	JPLog(@"- %@", item);
             }
         }
        */
        
        // all saved user data
        /*
        AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSError *error = nil;
        NSFetchRequest *users = [[NSFetchRequest alloc] initWithEntityName:@"UserEntity"];
        NSArray *uResult = [appDelegate.managedObjectContext executeFetchRequest:users error:&error];
        NSLog(@"ALL USERS:");
        if (uResult.count > 0) {
            UserEntity *user = [uResult objectAtIndex:0];
            NSLog(@"user: %@", [TungCommonObjects entityToDict:user]);
        }
         */
        
        // log all podcast and episode entities
        //[TungCommonObjects checkForPodcastData];
        
        //[TungCommonObjects clearTempDirectory];
        
        //NSLog(@"notification settings: %@", [[UIApplication sharedApplication] currentUserNotificationSettings]);
        
    }
    return self;
}

CGSize screenSize;
+ (CGSize) screenSize {
    if (screenSize.width) {
        return screenSize;
    } else {
        screenSize = [[UIScreen mainScreen] bounds].size;
        return screenSize;
    }
}

NSString *tungApiKey;
+ (NSString *) apiKey {
    if (tungApiKey != nil) {
        return tungApiKey;
    } else {
        AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSDictionary *keys = [appDelegate getAppKeysDictionary];
        if ([keys objectForKey:@"error"]) {
            JPLog(@"Keys error: %@", [keys objectForKey:@"error"]);
            tungApiKey = @"";
        }
        else {
            tungApiKey = [keys objectForKey:@"tungApiKey"];
        }
        return tungApiKey;
    }
}

+ (UIViewController *) activeViewController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}

CGFloat versionFloat = 0.0;
+ (CGFloat) iOSVersionFloat {
    if (versionFloat > 0.0) {
        return versionFloat;
    }
    else {
        NSInteger majorVersion = [[NSProcessInfo processInfo] operatingSystemVersion].majorVersion;
        NSInteger minorVersion = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion;
        NSString *version = [NSString stringWithFormat:@"%ld.%ld", (long)majorVersion, (long)minorVersion];
        versionFloat = [version floatValue];
        return versionFloat;
    }
}

-(void) checkForNowPlaying {
    // find playing episode
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSFetchRequest *npRequest = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"isNowPlaying == YES"];
    [npRequest setPredicate:predicate];
    NSError *error = nil;
    NSArray *npResult = [appDelegate.managedObjectContext executeFetchRequest:npRequest error:&error];
    if (npResult.count > 0) {
        EpisodeEntity *epEntity = [npResult lastObject];
        
        if ([epEntity.title isKindOfClass:[NSString class]] && [epEntity.url isKindOfClass:[NSString class]]) {
            _npEpisodeEntity = epEntity;
            _playQueue = [@[_npEpisodeEntity.url] mutableCopy];
            if ([self isPlaying]) {
                [self setControlButtonStateToPause];
            } else {
                [self setControlButtonStateToPlay];
            }
            return;
        }
        else {
            //NSLog(@"check for now playing - found 'half' entity: %@", [TungCommonObjects entityToDict:_npEpisodeEntity]);
            [self removeNowPlayingStatusFromAllEpisodes];
        }
    }
    
    // no episode playing yet
    _playQueue = [NSMutableArray array];
    [self setControlButtonStateToFauxDisabled];;
    
}

#pragma mark - Audio session delegate methods

- (void) handleAudioSessionInterruption:(NSNotification*)notification {
    
    NSNumber *interruptionType = [[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey];
    NSNumber *interruptionOption = [[notification userInfo] objectForKey:AVAudioSessionInterruptionOptionKey];
    
    switch (interruptionType.unsignedIntegerValue) {
        case AVAudioSessionInterruptionTypeBegan:{
            // • Audio has stopped, already inactive
            // • Change state of UI, etc., to reflect non-playing state
            
            // below: nearly the same as playerPause but without _shouldStayPaused
            [_player pause];
            [self setControlButtonStateToPlay];
            [self savePositionForNowPlayingAndSync:YES];

        } break;
        case AVAudioSessionInterruptionTypeEnded:{
            // • Make session active
            // • Update user interface
            // • AVAudioSessionInterruptionOptionShouldResume option
            if (interruptionOption.unsignedIntegerValue == AVAudioSessionInterruptionOptionShouldResume) {
                if (!_shouldStayPaused) [self playerPlay];
            }
        } break;
        default:
            break;
    }
}
- (void) handleMediaServicesReset {
    // • No userInfo dictionary for this notification
    // • Audio streaming objects are invalidated (zombies)
    // • Handle this notification by fully reconfiguring audio
    
    //[TungCommonObjects showBannerAlertForText:@"Media services reset"];
    //JPLog(@"////// handle media services reset");
    if ([[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: nil]) {
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    }
    [self resetPlayer];
    [self checkForNowPlaying];
}

- (void) handleRouteChange:(NSNotification *)notification {
    
    NSNumber *reason = [notification.userInfo valueForKey:AVAudioSessionRouteChangeReasonKey];
    if (reason.intValue == 2) {
        _shouldStayPaused = YES;
        [self setControlButtonStateToPlay];
        [self savePositionForNowPlayingAndSync:YES];
    }
    
}



#pragma mark - Control button

- (void) controlButtonTapped {
    if (_btnActivityIndicator.isAnimating) return;
    
    if (_playQueue.count > 0) {
        
        if (_player) {
            if ([self isPlaying]) {
                [self playerPause];
            } else {
                [self playerPlay]; // players gonna play
            }
        } else {
            [self playQueuedPodcast];
        }
    }
    else {
        UIAlertController *searchPromptAlert = [UIAlertController alertControllerWithTitle:@"Nothing is playing" message:@"Tap a podcast in the feed and then tap ▶️ at the top, or, search for a podcast by tapping 🔍" preferredStyle:UIAlertControllerStyleAlert];
        [searchPromptAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [_viewController presentViewController:searchPromptAlert animated:YES completion:nil];
    }
}

- (void) setControlButtonStateToPlay {
    [_btnActivityIndicator stopAnimating];
    [_btn_player setImage:[UIImage imageNamed:@"btn-player-play.png"] forState:UIControlStateNormal];
    [_btn_player setImage:[UIImage imageNamed:@"btn-player-play-down.png"] forState:UIControlStateHighlighted];
}
- (void) setControlButtonStateToPause {
    [_btnActivityIndicator stopAnimating];
    [_btn_player setImage:[UIImage imageNamed:@"btn-player-pause.png"] forState:UIControlStateNormal];
    [_btn_player setImage:[UIImage imageNamed:@"btn-player-pause-down.png"] forState:UIControlStateHighlighted];
}
- (void) setControlButtonStateToFauxDisabled {
    [_btnActivityIndicator stopAnimating];
    [_btn_player setImage:[UIImage imageNamed:@"btn-player-play-down.png"] forState:UIControlStateNormal];
    [_btn_player setImage:[UIImage imageNamed:@"btn-player-play-down.png"] forState:UIControlStateHighlighted];
}
- (void) setControlButtonStateToBuffering {
    [_btnActivityIndicator startAnimating];
    [_btn_player setImage:nil forState:UIControlStateNormal];
    [_btn_player setImage:nil forState:UIControlStateHighlighted];
    [_btn_player setImage:nil forState:UIControlStateDisabled];
}


#pragma mark - Player instance methods

- (BOOL) isPlaying {
    //JPLog(@"is playing at rate: %f", _player.rate);
    return (_player && _player.rate > 0.0f);
}
- (void) playerPlay {
    if (_player && _playQueue.count > 0) {
        _shouldStayPaused = NO;
        if (_npEpisodeEntity.trackPosition.floatValue == 1) {
            // start over
            [self seekToTime:CMTimeMake(0, 100)];
        } else {
            [_player play];
        }
        [self setControlButtonStateToPause];
    } else {
        [self playQueuedPodcast];
    }
}
- (void) playerPause {
    if ([self isPlaying]) {
        
        //float currentSecs = CMTimeGetSeconds(_player.currentTime);
        //NSLog(@"currentSecs: %f, total secs: %f", currentSecs, _totalSeconds);
        
        [_player pause];
        _shouldStayPaused = YES;
        [self setControlButtonStateToPlay];
        [self savePositionForNowPlayingAndSync:YES];
        // see if file is cached yet, so player can switch to local file
        /* may be causing issues, disabling for now
        if (_fileIsStreaming && _fileIsLocal) {
            [self reestablishPlayerItemAndReplace];
        } */
    }
}
- (void) seekBack {
    float currentTimeSecs = CMTimeGetSeconds(_player.currentTime);
    if (currentTimeSecs < 3) {
        [self playNextOlderEpisodeInFeed];
    } else {
        CMTime time = CMTimeMake(0, 1);
        [self seekToTime:time];
    }
}

- (void) skipAhead15 {
    if (_player && _totalSeconds) {
        float secs = CMTimeGetSeconds(_player.currentTime);
        secs += 15;
        secs = MIN(_totalSeconds - 1, secs - 1);
        [self seekToTime:(CMTimeMake((secs * 100), 100))];
    }
}
- (void) skipBack15 {
    if (_player && _totalSeconds) {
        float secs = CMTimeGetSeconds(_player.currentTime);
        secs -= 15;
        secs = MAX(0, secs);
        [self seekToTime:(CMTimeMake((secs * 100), 100))];
    }
}

- (void) determineTotalSeconds {
    
    _totalSeconds = CMTimeGetSeconds(_player.currentItem.asset.duration);
    [_trackInfo setObject:[NSNumber numberWithFloat:_totalSeconds] forKey:MPMediaItemPropertyPlaybackDuration];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:_trackInfo];
    //JPLog(@"determined total seconds: %f (%@)", _totalSeconds, [TungCommonObjects convertSecondsToTimeString:_totalSeconds]);
}

// PLAYER OBSERVING

- (void) addPlayerObserversForItem:(AVPlayerItem *)playerItem {
    // player notifications
    [_player addObserver:self forKeyPath:@"status" options:0 context:nil];
    [_player addObserver:self forKeyPath:@"currentItem.playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    [_player addObserver:self forKeyPath:@"currentItem.duration" options:0 context:nil];
    //[_player addObserver:self forKeyPath:@"currentItem.playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    //[_player addObserver:self forKeyPath:@"currentItem.loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    
    // Subscribe to AVPlayerItem's notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(completedPlayback) name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerError:) name:AVPlayerItemPlaybackStalledNotification object:playerItem];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerError:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:playerItem];
}

- (void) removePlayerObservers {
    [_player removeObserver:self forKeyPath:@"status"];
    [_player removeObserver:self forKeyPath:@"currentItem.playbackLikelyToKeepUp"];
    [_player removeObserver:self forKeyPath:@"currentItem.duration"];
    //[_player removeObserver:self forKeyPath:@"currentItem.playbackBufferEmpty"];
    //[_player removeObserver:self forKeyPath:@"currentItem.loadedTimeRanges"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:_player.currentItem];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:_player.currentItem];
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    //JPLog(@"observe value for key path: %@", keyPath);
    if (object == _player && [keyPath isEqualToString:@"status"]) {
        
        switch (_player.status) {
            case AVPlayerStatusFailed:
                JPLog(@"-- AVPlayer status: Failed");
                [self ejectCurrentEpisode];
                [self setControlButtonStateToFauxDisabled];
                break;
            case AVPlayerStatusReadyToPlay:
                JPLog(@"-- AVPlayer status: ready to play");
                // check for track progress
                float secs = 0;
                CMTime time;
                if (_playFromTimestamp) {
                    secs = [TungCommonObjects convertTimestampToSeconds:_playFromTimestamp];
                    time = CMTimeMake((secs * 100), 100);
                }
                else if (_npEpisodeEntity.trackProgress.floatValue > 0 && _npEpisodeEntity.trackPosition.floatValue < 1) {
                    secs = _npEpisodeEntity.trackProgress.floatValue;
                    time = CMTimeMake((secs * 100), 100);
                }
                // play
                if (secs > 0) {
                    //JPLog(@"seeking to time: %f (progress: %f)", secs, _npEpisodeEntity.trackProgress.floatValue);
                    [_trackInfo setObject:[NSNumber numberWithFloat:secs] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
                    [_player seekToTime:time completionHandler:^(BOOL finished) {}];
                } else {
                    [_trackInfo setObject:[NSNumber numberWithFloat:0] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
                    if (![self isPlaying]) {
                        //JPLog(@"play from beginning - with preroll");
                        [_player prerollAtRate:1.0 completionHandler:nil];
                    }
                }
                
                break;
            case AVPlayerItemStatusUnknown:
                JPLog(@"-- AVPlayer status: Unknown");
                break;
            default:
                break;
        }
    }
    if (object == _player && [keyPath isEqualToString:@"currentItem.playbackLikelyToKeepUp"]) {
        
        if (_player.currentItem.playbackLikelyToKeepUp) {
            //JPLog(@"-- player likely to keep up");
            [_spinnerCheckTimer invalidate];
            
            if (_totalSeconds > 0) {
                float currentSecs = CMTimeGetSeconds(_player.currentTime);
            	if (round(currentSecs) >= floor(_totalSeconds)) {
                    JPLog(@"detected completed playback");
                    [self completedPlayback];
                    return;
                }
            }
            
            if ([self isPlaying]) {
                [self setControlButtonStateToPause];
            }
            else if (!_shouldStayPaused && ![self isPlaying]) {
                [self playerPlay];
            }
            
        } else {
            //JPLog(@"-- player NOT likely to keep up");
            if (!_shouldStayPaused) [self setControlButtonStateToBuffering];
            [_spinnerCheckTimer invalidate];
            _spinnerCheckTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(checkSpinner) userInfo:nil repeats:NO];
        }
    }
    
    if (object == _player && [keyPath isEqualToString:@"currentItem.duration"]) {
        if (_totalSeconds == 0) [self determineTotalSeconds];
        //if (!_shouldStayPaused) [self setControlButtonStateToPause];
    }
    
    if (object == _player && [keyPath isEqualToString:@"currentItem.loadedTimeRanges"]) {
        NSArray *timeRanges = (NSArray *)[change objectForKey:NSKeyValueChangeNewKey];
        if (timeRanges && [timeRanges count]) {
            CMTimeRange timerange = [[timeRanges objectAtIndex:0] CMTimeRangeValue];
            JPLog(@" . . . %.3f, %@", CMTimeGetSeconds(CMTimeAdd(timerange.start, timerange.duration)), ([self isPlaying]) ? @"playing" : @"not playing");
            /*
             Even if you call play, player will NOT play until it's status is playbackLikelyToKeepUp
            if (CMTimeGetSeconds(timerange.duration) >= 10) {
                JPLog(@"got 10 secs, ready to play");
                [_player play];

            }
             */
        }
    }
    if (object == _player && [keyPath isEqualToString:@"currentItem.playbackBufferEmpty"]) {
        
        if (_player.currentItem.playbackBufferEmpty) {
            JPLog(@"-- playback buffer empty");
            [self setControlButtonStateToBuffering];
        }
    }
}
/*	spinner can get stuck because playback not likely to keep up
 	gets called even when the player is playing
 */
- (void) checkSpinner {
    if ([self isPlaying]) {
        if (_shouldStayPaused) {
            [self setControlButtonStateToPlay];
        } else {
            [self setControlButtonStateToPause];
        }
    }
}

- (void) seekToTime:(CMTime)time {
    /* may be causing issues, disabling for now
    if (_fileIsStreaming && _fileIsLocal) {
        [self reestablishPlayerItemAndReplace];
    }*/
    [_trackInfo setObject:[NSNumber numberWithFloat:CMTimeGetSeconds(time)] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:_trackInfo];
    //[_player seekToTime:time];
    [_player seekToTime:time completionHandler:^(BOOL finished) {
        if (!_shouldStayPaused) {
            // avoid endless loop, do not use [self playerPlay];
            [_player play];
        }
    }];
}

- (void) queueAndPlaySelectedEpisode:(NSString *)urlString fromTimestamp:(NSString *)timestamp {
    
    if (!urlString || urlString.length == 0) {
        [TungCommonObjects showNoAudioAlert];
        return;
    }
    
    // url and file
    NSURL *url = [TungCommonObjects urlFromString:urlString];
    NSString *fileName = [url lastPathComponent];
    NSString *fileType = [fileName pathExtension];
    //JPLog(@"play file of type: %@", fileType);
    // avoid videos
    if ([fileType isEqualToString:@"mp4"] || [fileType isEqualToString:@"m4v"]) {

        UIAlertController *videoAlert = [UIAlertController alertControllerWithTitle:@"Video podcast" message:@"Tung does not currently support video podcasts." preferredStyle:UIAlertControllerStyleAlert];
        [videoAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [_viewController presentViewController:videoAlert animated:YES completion:nil];
    }
    else {
        // make sure it isn't playing
        if (_playQueue.count > 0) {
            
            // it's new, but something else is loaded
            NSString *queuedItem = [TungCommonObjects stringFromUrl:[_playQueue objectAtIndex:0]];
            if (![queuedItem isEqualToString:urlString]) {
                [self ejectCurrentEpisode];
                if (timestamp) {
                    _playFromTimestamp = timestamp;
                }
                [_playQueue insertObject:urlString atIndex:0];
                [self playQueuedPodcast];
            }
            // trying to queue playing episode
            else {
                if (!!_player.currentItem) {
                    if ([self isPlaying]) [self playerPause];
                    else [self playerPlay];
                }
            }
        } else {
            [_playQueue insertObject:urlString atIndex:0];
            [self playQueuedPodcast];
        }
    }
}

- (void) playUrl:(NSString *)urlString fromTimestamp:(NSString *)timestamp {
    
    _playFromTimestamp = timestamp;
    
    NSString *queuedItem = [TungCommonObjects stringFromUrl:[_playQueue objectAtIndex:0]];
    if (_playQueue.count > 0 && [queuedItem isEqualToString:urlString]) {
        // already listening
        float secs = [TungCommonObjects convertTimestampToSeconds:timestamp];
        CMTime time = CMTimeMake((secs * 100), 100);
        if (_player) {
            [self playerPlay];
        	[_player seekToTime:time];
        } else {
            [self playQueuedPodcast];
        }
    }
    else {
        // different episode
        
        // play
        [self queueAndPlaySelectedEpisode:urlString fromTimestamp:timestamp];
    }
}

- (void) playQueuedPodcast {
    
    if (_playQueue.count > 0) {
        
        [self resetPlayer];
        
        NSString *urlString = [TungCommonObjects stringFromUrl:[_playQueue objectAtIndex:0]];
        
        if (urlString.length) {
        
            //JPLog(@"play queued podcast: %@", urlString);
            
            // assign now playing entity
            AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
            NSError *error = nil;
            NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
            NSPredicate *predicate = [NSPredicate predicateWithFormat: @"url == %@", urlString];
            [request setPredicate:predicate];
            NSArray *episodeResult = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
            if (episodeResult.count > 0) {
                //JPLog(@"found and assigned now playing entity");
                _npEpisodeEntity = [episodeResult lastObject];
            } else {
                /* create entity - case is next episode in feed is played. Episode entity may not have been
                 created yet, but podcast entity would, so we get it from np episode entity. */
                // look up podcast entity
                //JPLog(@"creating new entity for now playing entity");
                NSDictionary *episodeDict = [_currentFeed objectAtIndex:_currentFeedIndex];
                PodcastEntity *npPodcastEntity = _npEpisodeEntity.podcast;
                _npEpisodeEntity = [TungCommonObjects getEntityForEpisode:episodeDict withPodcastEntity:npPodcastEntity save:NO];
            }
            // increment listen count if it isn't already playing
            if (!_npEpisodeEntity.isNowPlaying.boolValue) {
                _incPlayCountTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(incrementPlayCountForNowPlaying) userInfo:nil repeats:NO];
            }
            
            //NSLog(@"sanitized guid: %@", [TungCommonObjects santizeGUID:_npEpisodeEntity.guid]);
            
            _npEpisodeEntity.isNowPlaying = [NSNumber numberWithBool:YES];
            [TungCommonObjects saveContextWithReason:@"now playing changed"];
            // find index of episode in current feed for prev/next track fns
            _currentFeed = [self getFeedOfNowPlayingEpisodeAndSetCurrentFeedIndex];
            
            //NSLog(@"now playing episode: %@", [TungCommonObjects entityToDict:_npEpisodeEntity]);
            
            // set now playing info center info
            NSData *artImageData = [TungCommonObjects retrievePodcastArtDataForEntity:_npEpisodeEntity.podcast defaultSize:NO];
            UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
            MPMediaItemArtwork *albumArt = [[MPMediaItemArtwork alloc] initWithImage:artImage];
            [_trackInfo setObject:albumArt forKey:MPMediaItemPropertyArtwork];
            [_trackInfo setObject:_npEpisodeEntity.title forKey:MPMediaItemPropertyTitle];
            [_trackInfo setObject:_npEpisodeEntity.podcast.collectionName forKey:MPMediaItemPropertyArtist];
            //[_trackInfo setObject:_npEpisodeEntity.podcast.collectionName forKey:MPMediaItemPropertyPodcastTitle];
            //[_trackInfo setObject:_npEpisodeEntity.podcast.artistName forKey:MPMediaItemPropertyAlbumTitle];
            [_trackInfo setObject:[NSNumber numberWithFloat:1.0] forKey:MPNowPlayingInfoPropertyPlaybackRate];
            [_trackInfo setObject:_npEpisodeEntity.pubDate forKey:MPMediaItemPropertyReleaseDate];
            // not used: MPMediaItemPropertyAssetURL
            
            // set up new player item and player, observers
            
            NSURL *urlToPlay = [self getStreamUrlForEpisodeEntity:_npEpisodeEntity];
            if (urlToPlay) {
                
                // set local notif. for deleting cached audio
                NSInteger days = DAYS_TO_KEEP_CACHED;
                [TungCommonObjects createLocalNotifToDeleteAudioForEntity:_npEpisodeEntity inDays:days forCached:YES];
                
                AVURLAsset *asset = [AVURLAsset URLAssetWithURL:urlToPlay options:nil];
                [asset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
                AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
                if ([TungCommonObjects iOSVersionFloat] >= 10.0) {
                    playerItem.preferredForwardBufferDuration = 10.0; // required X seconds to be loaded for playback to be ready
                }
                _player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
                if ([TungCommonObjects iOSVersionFloat] >= 10.0) {
                    _player.automaticallyWaitsToMinimizeStalling = NO;
                }
                
                [self addPlayerObserversForItem:playerItem];
                
                [self setControlButtonStateToBuffering];
                
                NSNotification *nowPlayingDidChangeNotif = [NSNotification notificationWithName:@"nowPlayingDidChange" object:nil userInfo:nil];
                [[NSNotificationCenter defaultCenter] postNotification:nowPlayingDidChangeNotif];
            }
            // else error handled in getStreamUrlForEpisodeEntity method
        }
        else {
            JPLog(@"Error: Empty url string passed to playQueuedPodcast");
            [TungCommonObjects simpleErrorAlertWithMessage:@"Could not play - empty url"];
        }
    }
    //JPLog(@"play queue: %@", _playQueue);
}

- (NSArray *) getFeedOfNowPlayingEpisodeAndSetCurrentFeedIndex {
    
    NSDictionary *feedDict = [TungPodcast retrieveAndCacheFeedForPodcastEntity:_npEpisodeEntity.podcast forceNewest:NO reachable:_connectionAvailable.boolValue];
    NSError *feedError;
    NSArray *feed = [TungPodcast extractFeedArrayFromFeedDict:feedDict error:&feedError];
    _currentFeedIndex = 0; // default
    if (!feedError) {
        _currentFeedIndex = [TungCommonObjects getIndexOfEpisodeWithGUID:_npEpisodeEntity.guid inFeed:feed];
        return feed;
    }
    else {
        NSString *errorString = [NSString stringWithFormat:@"Error with Now Playing episode's feed: %@", feedError.localizedDescription];
        [TungCommonObjects simpleErrorAlertWithMessage:errorString];
        JPLog(@"now playing feed error: %@", errorString);
        
        return @[];
    }
    
}

// gets new episodes from subscribed podcasts and plays a random one
- (void) playRandomEpisode {
    
    NSArray *result = [TungCommonObjects getAllSubscribedPodcasts];
    
    if (result.count > 0) {
        
        // build list of new episodes
        NSMutableArray *newEpisodes = [NSMutableArray array];
        
        for (int i = 0; i < result.count; i++) {
            PodcastEntity *podEntity = [result objectAtIndex:i];
            NSDictionary *feedDict = [TungPodcast retrieveCachedFeedForPodcastEntity:podEntity];
            NSError *feedError;
            NSArray *episodes = [TungPodcast extractFeedArrayFromFeedDict:feedDict error:&feedError];
            
            if (!feedError) {
                // only check the 10 most recent, or less
                NSInteger max = MIN(10, episodes.count);
                for (NSInteger j = 0; j < max; j++) {
                    NSDictionary *episodeDict = [episodes objectAtIndex:j];
                    EpisodeEntity *epEntity = [TungCommonObjects getEntityForEpisode:episodeDict withPodcastEntity:podEntity save:NO];
                    if (epEntity.trackProgress.floatValue > 0.0) {
                        continue;
                    }
                    else {
                        [newEpisodes addObject:@{
                                                 @"episode": episodeDict,
                                                 @"podcast": [TungCommonObjects entityToDict:podEntity]
                                                 }];
                    }
                }
            }
        }
        
        if (newEpisodes.count > 0) {
            
            JPLog(@"found %lu new episodes. drawing random number...", (unsigned long)newEpisodes.count);
            NSInteger i = arc4random_uniform((uint32_t) newEpisodes.count);
            JPLog(@"drew %d", i);
            
            NSDictionary *chosenDict = [newEpisodes objectAtIndex:i];
            PodcastEntity *podEntity = [TungCommonObjects getEntityForPodcast:[chosenDict objectForKey:@"podcast"] save:NO];
            EpisodeEntity *episodeEntity = [TungCommonObjects getEntityForEpisode:[chosenDict objectForKey:@"episode"] withPodcastEntity:podEntity save:YES];
            
            [self queueAndPlaySelectedEpisode:episodeEntity.url fromTimestamp:nil];
            
        }
        else {
            // inbox zero for subscribed podcasts
            UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Just wow." message:@"You've achieved inbox zero for subscribed podcasts. No new episodes to listen to!" preferredStyle:UIAlertControllerStyleAlert];
            [errorAlert addAction:[UIAlertAction actionWithTitle:@"Check out the feed" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
                [appDelegate switchTabBarSelectionToTabIndex:0];
            }]];
            [errorAlert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
            [[TungCommonObjects activeViewController] presentViewController:errorAlert animated:YES completion:nil];
        }
    }
    else {
        // no subscribed podcasts
        UIAlertController *noSubscribesAlert = [UIAlertController alertControllerWithTitle:@"No subscribed podcasts" message:@"Discover some great new episodes in the feed, or you could import your podcast subscriptions." preferredStyle:UIAlertControllerStyleAlert];
        [noSubscribesAlert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
        [noSubscribesAlert addAction:[UIAlertAction actionWithTitle:@"Check out the feed" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate switchTabBarSelectionToTabIndex:0];
        }]];
        [noSubscribesAlert addAction:[UIAlertAction actionWithTitle:@"Import podcast subsciptions" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
            [appDelegate switchTabBarSelectionToTabIndex:2];
            [self promptAndRequestMediaLibraryAccess];
        }]];
        [[TungCommonObjects activeViewController] presentViewController:noSubscribesAlert animated:YES completion:nil];
    }
}

// removes observers, releases player related properties
- (void) resetPlayer {
    //JPLog(@"reset player ///////////////");
    _npViewSetupForCurrentEpisode = NO;
    _shouldStayPaused = NO;
    _totalSeconds = 0;
    [_incPlayCountTimer invalidate];
    
    // remove old player and observers
    if (_player) {
        [_player cancelPendingPrerolls];
        [_player.currentItem cancelPendingSeeks];
        [self removePlayerObservers];
        _player = nil;
    }
    
    _trackData = [NSMutableData data];
    
    // clear leftover connection data
    if (_trackDataConnection) {
        //JPLog(@"clear connection data");
        [_trackDataConnection cancel];
        _trackDataConnection = nil;
        _trackData = [NSMutableData data];
        self.response = nil;
    }
    self.pendingRequests = [NSMutableArray array];
}

- (void) savePositionForNowPlayingAndSync:(BOOL)sync {

    if (_totalSeconds > 0) {
        float secs = CMTimeGetSeconds(_player.currentTime);
        _npEpisodeEntity.trackProgress = [NSNumber numberWithFloat:secs];
        
        float pos = secs / _totalSeconds;
        if (round(secs) >= floor(_totalSeconds)) {
            pos = 1.0;
        }
        _npEpisodeEntity.trackPosition = [NSNumber numberWithFloat:pos];
        [TungCommonObjects saveContextWithReason:[NSString stringWithFormat:@"saving track position: %f", pos]];
        // sync with server after delay
        if (sync && _connectionAvailable.boolValue) {
            [_syncProgressTimer invalidate];
            _syncProgressTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(syncProgressFromTimer:) userInfo:_npEpisodeEntity repeats:NO];
        }
    }
}

- (void) completedPlayback {
    float currentTimeSecs = CMTimeGetSeconds(_player.currentTime);
    JPLog(@"completed playback? current secs: %f, total secs: %f", currentTimeSecs, _totalSeconds);
    
    // called prematurely
    if (_totalSeconds == 0) {
        JPLog(@"completed playback called prematurely. totalSeconds not set");
        return;
    }
    if (round(currentTimeSecs) < floor(_totalSeconds)) {
        JPLog(@"completed playback called prematurely.");
        if (_fileIsStreaming && _fileIsLocal) {
            [self reestablishPlayerItemAndReplace];
        }
        else {
            JPLog(@"- attempt to reload episode");
            // do not need timestamp bc eject current episode saves position
            NSString *urlString = _npEpisodeEntity.url;
            [self ejectCurrentEpisode];
            [self queueAndPlaySelectedEpisode:urlString fromTimestamp:nil];
        }
        return;
    }
    //[TungCommonObjects showBannerAlertForText:[NSString stringWithFormat:@"completed playback. current secs: %f, total secs: %f", currentTimeSecs, _totalSeconds]];
    [self playNextEpisode]; // ejects current episode
}

- (void) ejectCurrentEpisode {
    //NSLog(@"ejecting current episode");
    if (_playQueue.count > 0) {
        if ([self isPlaying]) [_player pause];
        [self removeNowPlayingStatusFromAllEpisodes];
        //_npEpisodeEntity.isNowPlaying = [NSNumber numberWithBool:NO];
        [self savePositionForNowPlayingAndSync:YES];
        [_playQueue removeObjectAtIndex:0];
        _playFromTimestamp = nil;
    }
}

- (void) removeNowPlayingStatusFromAllEpisodes {
    // find playing episodes
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSFetchRequest *npRequest = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"isNowPlaying == YES"];
    [npRequest setPredicate:predicate];
    NSError *error = nil;
    NSArray *npResult = [appDelegate.managedObjectContext executeFetchRequest:npRequest error:&error];
    if (npResult.count > 0) {
        for (int i = 0; i < npResult.count; i++) {
            EpisodeEntity *episodeEntity = [npResult objectAtIndex:i];
            episodeEntity.isNowPlaying = [NSNumber numberWithBool:NO];
        }
    }
    //[TungCommonObjects saveContextWithReason:@"remove now playing status from all episodes"];
}

// uses some logic to play next unplayed episode
- (void) playNextEpisode {
    // play manually queued episode
    if (_playQueue.count > 1) {
        [self ejectCurrentEpisode];
        //AudioServicesPlaySystemSound(1103); // play beep
        JPLog(@"play next episode");
        [self playQueuedPodcast];
    }
    // play next episode in feed
    else {
        if (!_currentFeed) {
            _currentFeed = [self getFeedOfNowPlayingEpisodeAndSetCurrentFeedIndex];
        }
        // first see if there is a newer one and if it has been listened to yet
        if (_currentFeedIndex - 1 > -1) {
            
            NSDictionary *epDict = [_currentFeed objectAtIndex:_currentFeedIndex - 1];
            EpisodeEntity *epEntity = [TungCommonObjects getEntityForEpisode:epDict withPodcastEntity:_npEpisodeEntity.podcast save:NO];
            
            if (epEntity.trackPosition.floatValue == 0) {
                //JPLog(@"newer episode hasn't been listened to yet, queue and play");
                [self ejectCurrentEpisode];
                _currentFeedIndex--;
                [_playQueue insertObject:epEntity.url atIndex:0];
                [self playQueuedPodcast];
                return;
            }
        }
        // if method hasn't returned, try to play the next older episode in feed
        [self playNextOlderEpisodeInFeed];
    }
}

- (void) playNextOlderEpisodeInFeed {
    
    if (!_currentFeed) {
    	_currentFeed = [self getFeedOfNowPlayingEpisodeAndSetCurrentFeedIndex];
    }

    if (_currentFeedIndex + 1 < _currentFeed.count) {
        JPLog(@"play previous episode in feed");
        [self ejectCurrentEpisode];
        _currentFeedIndex++;
        NSDictionary *episodeDict = [_currentFeed objectAtIndex:_currentFeedIndex];
        NSString *urlString = [TungCommonObjects getUrlStringFromEpisodeDict:episodeDict];
        if (urlString) {
            [_playQueue insertObject:urlString atIndex:0];
            [self playQueuedPodcast];
        }
    } else {
        [self savePositionForNowPlayingAndSync:YES];
        [self setControlButtonStateToPlay];
    }
}

- (void) playNextNewerEpisodeInFeed {
    
    if (!_currentFeed) {
        _currentFeed = [self getFeedOfNowPlayingEpisodeAndSetCurrentFeedIndex];
    }
    
    if (_currentFeedIndex - 1 >= 0) {
        JPLog(@"play previous episode in feed");
        [self ejectCurrentEpisode];
        _currentFeedIndex--;
        NSDictionary *episodeDict = [_currentFeed objectAtIndex:_currentFeedIndex];
        NSString *urlString = [TungCommonObjects getUrlStringFromEpisodeDict:episodeDict];
        if (urlString) {
        	[_playQueue insertObject:urlString atIndex:0];
        	[self playQueuedPodcast];
        }
    } else {
        [self savePositionForNowPlayingAndSync:YES];
        [self setControlButtonStateToPlay];
    }
}


- (void) playerError:(NSNotification *)notification {
    JPLog(@"PLAYER ERROR: %@ ...attempting to recover playback", notification);
    
    // re-queue now playing
    [self savePositionForNowPlayingAndSync:NO];
    
    [self resetPlayer];
    
    [self queueAndPlaySelectedEpisode:_npEpisodeEntity.url fromTimestamp:nil];
    
    UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Player Error" message:@"Attempting to recover playback." preferredStyle:UIAlertControllerStyleAlert];
    [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [[TungCommonObjects activeViewController] presentViewController:errorAlert animated:YES completion:nil];
}

// looks for local file, else returns url with custom scheme
- (NSURL *) getStreamUrlForEpisodeEntity:(EpisodeEntity *)epEntity {
    // first look for file in episode temp dir
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cachedEpisodeFilepath = [TungCommonObjects getCachedFilepathForEpisodeEntity:epEntity];
	//NSLog(@"check for cached episode with filepath: %@", cachedEpisodeFilepath);
    if ([fileManager fileExistsAtPath:cachedEpisodeFilepath]) {
        //JPLog(@"^^^ will use local file in TEMP dir");
        _fileIsLocal = YES;
        _fileIsStreaming = NO;
        _fileWillBeCached = YES;
        return [NSURL fileURLWithPath:cachedEpisodeFilepath];
    }
    else {
        // look for file in saved episodes directory
        NSString *savedEpisodeFilepath = [TungCommonObjects getSavedFilepathForEpisodeEntity:epEntity];
        //NSLog(@"check for saved episode with filepath: %@", savedEpisodeFilepath);
        if ([fileManager fileExistsAtPath:savedEpisodeFilepath]) {
            //JPLog(@"^^^ will use local file in SAVED dir");
            _fileIsLocal = YES;
            _fileIsStreaming = NO;
            _fileWillBeCached = YES;
            return [NSURL fileURLWithPath:savedEpisodeFilepath];
        }
        else {
            // fuck it, we'll do it live!
            _fileIsLocal = NO;
            _fileIsStreaming = YES;
            
            NSURL *url = [NSURL URLWithString:epEntity.url];
            NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
            // if episode has track position > 0.1, we do not use custom scheme,
            // because this way AVPlayer will start streaming from the timestamp
            // instead of downloading from the start as with a custom scheme
            if (_npEpisodeEntity.trackPosition.floatValue > 0.1 && _npEpisodeEntity.trackPosition.floatValue < 1.0 && !_trackData.length) {
                // no caching
                _fileWillBeCached = NO;
                //JPLog(@"^^^ will STREAM from url with NO caching");
            }
            else {
                // return url with custom scheme
                components.scheme = @"tungstream";
                _fileWillBeCached = YES;
                //JPLog(@"^^^ will STREAM from url with custom scheme");
                
            }
            
            if (_connectionAvailable.boolValue) {
            	return [components URL];
            }
            else {
                JPLog(@"Error: Can't play because resource needs to be streamed and there is no connection");
                [TungCommonObjects showNoConnectionAlert];
                return nil;
            }
        }
    }
}

// make sure player item is fetching from the available location
- (void) reestablishPlayerItemAndReplace {
    JPLog(@"reestablish player item");

	[self savePositionForNowPlayingAndSync:NO];

    // clear leftover connection data
    _trackDataConnection = nil;
    _trackData = [NSMutableData data];
    self.response = nil;
    self.pendingRequests = [NSMutableArray array];
    
    if (_player) {
        [self removePlayerObservers];
        [_player cancelPendingPrerolls];
    }
    
    CMTime currentTime = _player.currentTime;
    NSURL *urlToPlay = [self getStreamUrlForEpisodeEntity:_npEpisodeEntity];
    if (urlToPlay) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:urlToPlay options:nil];
        [asset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
        AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithAsset:asset];
        [_player replaceCurrentItemWithPlayerItem:playerItem];
        
        [self addPlayerObserversForItem:playerItem];
        
        [_player seekToTime:currentTime completionHandler:^(BOOL finished) {
            if (!_shouldStayPaused) {
                [_player play];
            }
        }];
    }
}

/*
	Play Queue saving and retrieving
	Does not seem to be a reliable way to recall what was playing when app becomes active
	NOT USED
 	*/
- (NSString *) getPlayQueuePath {
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSArray *folders = [fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
    //NSArray *folders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *appPath = [NSString stringWithFormat:@"%@/Application Support", [folders objectAtIndex:0]];
    NSError *writeError;
    [[NSFileManager defaultManager] createDirectoryAtPath:appPath withIntermediateDirectories:NO attributes:nil error:&writeError];
    return [appPath stringByAppendingPathComponent:@"playQueue.txt"];
}

- (void) savePlayQueue {
    NSString *playQueuePath = [self getPlayQueuePath];
    
    // delete file if exists.
    if ([[NSFileManager defaultManager] fileExistsAtPath:playQueuePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:playQueuePath error:nil];
    }
    //[fileURL setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:&error];
    [_playQueue writeToFile:playQueuePath atomically:YES];
    JPLog(@"saved play queue %@ to path: %@", _playQueue, playQueuePath);
}

- (void) readPlayQueueFromDisk {
    NSString *playQueuePath = [self getPlayQueuePath];
    JPLog(@"read play queue from path: %@", playQueuePath);
    NSArray *queue = [NSArray arrayWithContentsOfFile:playQueuePath];
    if (queue) {
        JPLog(@"found saved play queue: %@", _playQueue);
        _playQueue = [queue mutableCopy];
    } else {
        JPLog(@"no saved play queue. create new");
        _playQueue = [NSMutableArray array];
    }
}

#pragma mark - caching/saving episodes

static NSString *episodeDirName = @"episodes";

+ (NSString *) getSavedEpisodesDirectoryPath {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *folders = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsDir = [folders objectAtIndex:0];
    NSError *error;
    BOOL success = [documentsDir setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:&error];
    if (success) {
        NSString *episodesDir = [documentsDir.path stringByAppendingPathComponent:episodeDirName];
        [fileManager createDirectoryAtPath:episodesDir withIntermediateDirectories:YES attributes:nil error:&error];
        return episodesDir;
    }
    else {
        JPLog(@"error making folder excluded from backup: %@", error.localizedDescription);
        return nil;
    }
}
+ (NSString *) getCachedEpisodesDirectoryPath {

    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSString *episodesDir = [NSTemporaryDirectory() stringByAppendingPathComponent:episodeDirName];
    NSError *error;
    [fileManager createDirectoryAtPath:episodesDir withIntermediateDirectories:YES attributes:nil error:&error];
    return episodesDir;
}

+ (NSString *) santizeGUID:(NSString *)guid {
    
    guid = [guid stringByRemovingPercentEncoding];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"([0-9A-Za-z\\-]+)" options:0 error:nil];
    NSMutableArray *components = [NSMutableArray array];
    [regex enumerateMatchesInString:guid options:0 range:NSMakeRange(0, guid.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        [components addObject:[guid substringWithRange:result.range]];
    }];
    NSString *result = [components componentsJoinedByString:@""];
    return result;
}

// removes query string, percent encoding
+ (NSString *) getEpisodeFilenameForEntity:(EpisodeEntity *)epEntity {
    
    NSURL *url = [TungCommonObjects urlFromString:epEntity.url];
    NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    urlComponents.query = nil;
    NSString *urlStr = [urlComponents.string stringByRemovingPercentEncoding];
    NSString *filename = [urlStr lastPathComponent];
    NSString *extension = [filename pathExtension];
    NSString *episodeFilename = [NSString stringWithFormat:@"%@-%@.%@", epEntity.collectionId, [TungCommonObjects santizeGUID:epEntity.guid], extension];
    //NSLog(@"filename result: %@", episodeFilename);
    return episodeFilename;
}

+ (NSString *) getSavedFilepathForEpisodeEntity:(EpisodeEntity *)epEntity {
    
    NSString *episodeFilename = [TungCommonObjects getEpisodeFilenameForEntity:epEntity];
    NSString *savedEpisodesDir = [TungCommonObjects getSavedEpisodesDirectoryPath];
    NSString *savedEpisodeFilepath = [savedEpisodesDir stringByAppendingPathComponent:episodeFilename];
    return savedEpisodeFilepath;
}

+ (NSString *) getCachedFilepathForEpisodeEntity:(EpisodeEntity *)epEntity {
    
    NSString *episodeFilename = [TungCommonObjects getEpisodeFilenameForEntity:epEntity];
    NSString *savedEpisodesDir = [TungCommonObjects getCachedEpisodesDirectoryPath];
    NSString *savedEpisodeFilepath = [savedEpisodesDir stringByAppendingPathComponent:episodeFilename];
    return savedEpisodeFilepath;
}

NSTimer *debounceSaveStatusTimer;
// meant to minimize notification duplication, bc of unavoidable cases where multiple notifs get fired
+ (void) queueSaveStatusDidChangeNotification {
    //JPLog(@"queue saveStatusDidChange notification");
    [debounceSaveStatusTimer invalidate];
    debounceSaveStatusTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(postSavedStatusDidChangeNotification) userInfo:nil repeats:NO];
}
+ (void) postSavedStatusDidChangeNotification {
    //JPLog(@"POST saveStatusDidChange notification");
    NSNotification *saveStatusChangedNotif = [NSNotification notificationWithName:@"saveStatusDidChange" object:nil userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotification:saveStatusChangedNotif];
}

- (void) cacheNowPlayingEpisodeAndMoveToSaved:(BOOL)moveToSaved {
    // we use the _trackDataConnection because this is specifically for now playing,
    // if it's to ultimately save the track, user will be able to see d/l progress
    _fileWillBeCached = YES;
    _saveOnDownloadComplete = moveToSaved;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:_npEpisodeEntity.url]];
    _trackDataConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [_trackDataConnection setDelegateQueue:[NSOperationQueue mainQueue]];
    [_trackDataConnection start];
}

- (void) queueEpisodeForDownload:(EpisodeEntity *)episodeEntity {
    
    //JPLog(@"queue episode for saving: %@", episodeEntity.title);
    
    // check if there is enough disk space
    CGFloat freeDiskSpace = [ALDisk freeDiskSpaceInBytes];
    _bytesToSave += episodeEntity.dataLength.doubleValue;
    NSString *freeSpace = [TungCommonObjects formatBytes:[NSNumber numberWithFloat:freeDiskSpace]];
    NSString *spaceNeeded = [TungCommonObjects formatBytes:[NSNumber numberWithFloat:_bytesToSave]];
    
    if (freeDiskSpace <= _bytesToSave) {
        JPLog(@"Error queueing episode for save: not enough storage. free space: %@, space needed: %@", freeSpace, spaceNeeded);
        
        UIAlertController *notEnoughDiskAlert = [UIAlertController alertControllerWithTitle:@"Not enough storage" message:[NSString stringWithFormat:@"The episode(s) you're trying to save require %@ but you only have %@ available. Try removing some other saved episodes or delete all saved episodes from settings.", spaceNeeded, freeSpace] preferredStyle:UIAlertControllerStyleAlert];
        [notEnoughDiskAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [_viewController presentViewController:notEnoughDiskAlert animated:YES completion:nil];
        return;
    }
    
    // if not yet notified, notify of episode expiration
    SettingsEntity *settings = [TungCommonObjects settings];
    if (!settings.hasSeenEpisodeExpirationAlert.boolValue) {
        NSInteger days = DAYS_TO_KEEP_SAVED;
        NSString *expirationTitle = [NSString stringWithFormat:@"Saved episodes will be kept for %ld days.", (long)days];
        UIAlertController *episodeExpirationAlert = [UIAlertController alertControllerWithTitle:expirationTitle message:@"After that, they will be automatically deleted." preferredStyle:UIAlertControllerStyleAlert];
        
        [episodeExpirationAlert addAction:[UIAlertAction actionWithTitle:@"Don't show again" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            settings.hasSeenEpisodeExpirationAlert = [NSNumber numberWithBool:YES];
            [TungCommonObjects saveContextWithReason:@"settings changed"];
        }]];
        [episodeExpirationAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        if ([TungCommonObjects iOSVersionFloat] >= 9.0) {
        	episodeExpirationAlert.preferredAction = [episodeExpirationAlert.actions objectAtIndex:1];
        }
        [_viewController presentViewController:episodeExpirationAlert animated:YES completion:nil];
        
    }
    
    [_episodeSaveQueue addObject:episodeEntity.url];
    episodeEntity.isQueuedForSave = [NSNumber numberWithBool:YES];
    
    // if nothing's downloading, start download
    if (!_saveTrackConnection) {
        [self downloadEpisode:episodeEntity];
    } else {
        [TungCommonObjects saveContextWithReason:@"queued episode for save"];
        [TungCommonObjects queueSaveStatusDidChangeNotification];
    }
}

- (void) cancelDownloadForEpisode:(EpisodeEntity *)episodeEntity {
    
    //JPLog(@"cancel save for episode: %@", episodeEntity.title);
    
    // deduct bytes to save
    _bytesToSave -= episodeEntity.dataLength.doubleValue;
    
    [_episodeSaveQueue removeObject:episodeEntity.url];
    episodeEntity.isQueuedForSave = [NSNumber numberWithBool:NO];
    episodeEntity.isDownloadingForSave = [NSNumber numberWithBool:NO];
    [TungCommonObjects saveContextWithReason:@"episode cancelled saving"];
    [TungCommonObjects queueSaveStatusDidChangeNotification];
    
    // cancel download
    
    if ([episodeEntity.url isEqualToString:_episodeToSaveEntity.url]) {
        [_saveTrackConnection cancel];
        _saveTrackConnection = nil;
        _saveTrackData = nil;
        [self downloadNextEpisodeInQueue];
    }
}

- (void) downloadNextEpisodeInQueue {
    if (_episodeSaveQueue.count > 0) {
        // lookup entity by guid
        NSString *urlString = [_episodeSaveQueue objectAtIndex:0];
        EpisodeEntity *epEntity = [TungCommonObjects getEpisodeEntityFromUrlString:urlString];
        if (epEntity) {
            [self downloadEpisode:epEntity];
        }
    }
}

- (void) downloadEpisode:(EpisodeEntity *)episodeEntity {
    
    //JPLog(@"start download of episode: %@", episodeEntity.title);
    _episodeToSaveEntity = episodeEntity;
    episodeEntity.isQueuedForSave = [NSNumber numberWithBool:YES];
    episodeEntity.isDownloadingForSave = [NSNumber numberWithBool:YES];
    [TungCommonObjects saveContextWithReason:@"new episode downloading"];
    [TungCommonObjects queueSaveStatusDidChangeNotification];
    
    NSURL *url = [NSURL URLWithString:episodeEntity.url];
    //NSLog(@"init download connection with url: %@", url);
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    _saveTrackConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [_saveTrackConnection setDelegateQueue:[NSOperationQueue mainQueue]];
    [_saveTrackConnection start];
}

+ (void) deleteSavedEpisode:(EpisodeEntity *)epEntity confirm:(BOOL)confirm {
        
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *episodeFilepath = [TungCommonObjects getSavedFilepathForEpisodeEntity:epEntity];
    NSError *error;
    BOOL success = NO;
    if ([fileManager fileExistsAtPath:episodeFilepath]) {
        success = [fileManager removeItemAtPath:episodeFilepath error:&error];
        if (success) {
            JPLog(@"successfully removed episode from saved");
        } else {
            JPLog(@"failed to remove episode: %@", error);
        }
    }
    
    if (success) {
        // update entity
        epEntity.isSaved = [NSNumber numberWithBool:NO];
        [TungCommonObjects saveContextWithReason:@"deleted saved episode file"];
        
        [TungCommonObjects queueSaveStatusDidChangeNotification];
        
        //JPLog(@"deleted episode with url: %@", urlString);
        if (confirm) {
            [TungCommonObjects showBannerAlertForText:@"Your saved copy of this episode has been deleted."];
        }
        
        // safe to remove feed from saved? (are other episodes saved?)
        BOOL safeToRemoveFeed = YES;
        for (EpisodeEntity *ep in epEntity.podcast.episodes) {
            if (ep.isSaved.boolValue) {
                safeToRemoveFeed = NO;
                break;
            }
        }
        if (safeToRemoveFeed) {
            [TungPodcast unsaveFeedForEntity:epEntity.podcast];
            if (!epEntity.podcast.isSubscribed.boolValue) {
                [TungCommonObjects unsavePodcastArtForEntity:epEntity.podcast];
            }
        }
    }
}

+ (void) deleteAllSavedEpisodes {
    //JPLog(@"delete all saved episodes");
    // remove "isSaved" status from all entities
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"isSaved == YES"];
    [request setPredicate:predicate];
    NSArray *episodeResult = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    // collect entities
    NSMutableArray *collectionIds = [NSMutableArray array];
    NSMutableArray *podcastEntities = [NSMutableArray array];
    if (episodeResult.count > 0) {
        for (int i = 0; i < episodeResult.count; i++) {
        	EpisodeEntity *epEntity = [episodeResult objectAtIndex:i];
            epEntity.isSaved = [NSNumber numberWithBool:NO];
            
            if (![collectionIds containsObject:epEntity.collectionId]) {
            	[collectionIds addObject:epEntity.collectionId];
                [podcastEntities addObject:epEntity.podcast];
            }
        }
        [TungCommonObjects saveContextWithReason:@"removed saved status from episodes"];
        [TungCommonObjects queueSaveStatusDidChangeNotification];
    }
    error = nil;
    
    // remove saved files
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *episodesDir = [TungCommonObjects getSavedEpisodesDirectoryPath];
    NSArray *episodesDirContents = [fileManager contentsOfDirectoryAtPath:episodesDir error:&error];
    
    if (episodesDirContents.count > 0 && error == nil) {
        for (NSString *item in episodesDirContents) {
            if ([fileManager removeItemAtPath:[episodesDir stringByAppendingPathComponent:item] error:NULL]) {
                JPLog(@"- removed item: %@", item);
            };
        }
    }
    
    // loop through podcast entities to un-save feeds, art
    for (int i = 0; i < podcastEntities.count; i++) {
        PodcastEntity *podEntity = [podcastEntities objectAtIndex:i];
        if (!podEntity.isSubscribed.boolValue) {
            [TungPodcast unsaveFeedForEntity:podEntity];
            [TungCommonObjects unsavePodcastArtForEntity:podEntity];
        }
    }

}

+ (BOOL) deleteCachedEpisode:(EpisodeEntity *)epEntity {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *episodeFilepath = [TungCommonObjects getCachedFilepathForEpisodeEntity:epEntity];
    NSError *error;
    
    if ([fileManager fileExistsAtPath:episodeFilepath]) {
        
        if (!epEntity.isNowPlaying.boolValue) {
            BOOL success = [fileManager removeItemAtPath:episodeFilepath error:&error];
            return success;
        }
        else {
            // episode is still cached and playing, don't delete but renew cache time
            // set local notif. for deleting cached audio
            NSInteger days = DAYS_TO_KEEP_CACHED;
            [self createLocalNotifToDeleteAudioForEntity:epEntity inDays:days forCached:YES];
            return NO;
        }
    }
    return NO;
    
}

+ (void) deleteAllCachedEpisodes {
    //JPLog(@"delete all cached episodes");
    // remove saved files
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *episodesDir = [TungCommonObjects getCachedEpisodesDirectoryPath];
    NSError *error;
    NSArray *episodesDirContents = [fileManager contentsOfDirectoryAtPath:episodesDir error:&error];
    
    if (episodesDirContents.count > 0 && error == nil) {
        for (NSString *item in episodesDirContents) {
            if ([fileManager removeItemAtPath:[episodesDir stringByAppendingPathComponent:item] error:NULL]) {
                //JPLog(@"- removed item: %@", item);
            };
        }
    }
}

// clears everyting in temp folder except cached episodes and MediaCache
+ (void) deleteCachedData {
    NSError *error = nil;
    NSArray *tmpFolderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:&error];
    if ([tmpFolderContents count] > 0 && error == nil) {
        for (NSString *item in tmpFolderContents) {
            if (![item isEqualToString:@"MediaCache"] && ![item isEqualToString:@"episodes"]) {
                NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:item];
                [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
                if (error) {
                    JPLog(@"error removing item at path: %@ - %@", path, error.localizedDescription);
                    error = nil;
                }
            }
        }
    }
}

- (void) showSavedInfoAlertForEpisode:(EpisodeEntity *)episodeEntity {
    // tell user when episode will be auto deleted
    NSString *formattedDate = [NSDateFormatter localizedStringFromDate:episodeEntity.savedUntilDate dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
    
    UIAlertController *episodeSavedInfoAlert = [UIAlertController alertControllerWithTitle:@"Saved" message:[NSString stringWithFormat:@"This episode will be saved until\n%@", formattedDate] preferredStyle:UIAlertControllerStyleAlert];
    [episodeSavedInfoAlert addAction:[UIAlertAction actionWithTitle:@"Remove" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [TungCommonObjects deleteSavedEpisode:episodeEntity confirm:YES];
    }]];
    UIAlertAction *keepAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [episodeSavedInfoAlert addAction:keepAction];
    if ([TungCommonObjects iOSVersionFloat] >= 9.0) {
    	episodeSavedInfoAlert.preferredAction = keepAction;
    }
    [_viewController presentViewController:episodeSavedInfoAlert animated:YES completion:nil];
}

/*	move episode from temp dir to saved dir
	if it's not in temp, queues episode for download */
- (BOOL) moveToSavedOrQueueDownloadForEpisode:(EpisodeEntity *)episodeEntity {
    
    // find in temp
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *cachedEpisodeFilepath = [TungCommonObjects getCachedFilepathForEpisodeEntity:episodeEntity];
    //NSLog(@"move episode - path: %@", cachedEpisodeFilepath);
    
    BOOL result = NO;
    if ([fileManager fileExistsAtPath:cachedEpisodeFilepath]) {
        // save in docs directory
        NSString *savedEpisodeFilepath = [TungCommonObjects getSavedFilepathForEpisodeEntity:episodeEntity];
        NSError *error;
        // if somehow it was already saved, remove it or it will error
        [fileManager removeItemAtPath:savedEpisodeFilepath error:&error];
        error = nil;
        result = [fileManager moveItemAtPath:cachedEpisodeFilepath toPath:savedEpisodeFilepath error:&error];
        //JPLog(@"moved episode to saved from temp: %@", (result) ? @"Success" : @"Failed");
        if (result) {
            episodeEntity.isSaved = [NSNumber numberWithBool:YES];
            NSDate *todayPlusThirtyDays = [[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitDay value:30 toDate:[NSDate date] options:0];
            episodeEntity.savedUntilDate = todayPlusThirtyDays;
            [TungCommonObjects saveContextWithReason:@"moved episode to saved"];
            [TungCommonObjects queueSaveStatusDidChangeNotification];
            
        } else {
            JPLog(@"Error moving episode: %@", error);
            episodeEntity.isSaved = [NSNumber numberWithBool:NO];
        }
    } else {
        // file does not exist in temp path
        episodeEntity.isSaved = [NSNumber numberWithBool:NO];
        [self queueEpisodeForDownload:episodeEntity];
    }
    return result;
}

+ (NSDate *) createLocalNotifToDeleteAudioForEntity:(EpisodeEntity *)epEntity inDays:(NSInteger)days forCached:(BOOL)cached {
    
    // delate saved or cached episode?
    NSString *saveType = (cached) ? @"deleteCachedEpisodeWithUrl" : @"deleteEpisodeWithUrl";
    
    NSDate *todayPlusXDays = [[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitDay value:days toDate:[NSDate date] options:0];
    UILocalNotification *expiredEpisodeNotif = [[UILocalNotification alloc] init];
    expiredEpisodeNotif.fireDate = todayPlusXDays;
    expiredEpisodeNotif.timeZone = [[NSCalendar currentCalendar] timeZone];
    expiredEpisodeNotif.hasAction = NO;
    expiredEpisodeNotif.userInfo = @{saveType: epEntity.url};
    [[UIApplication sharedApplication] scheduleLocalNotification:expiredEpisodeNotif];
    return todayPlusXDays;
}


#pragma mark - NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    //PLog(@"[NSURLConnectionDataDelegate] connection did receive response");
    if (connection == _trackDataConnection) {
        //NSLog(@"connection response: %@", response);
        
        // get data length from response header
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if ([[httpResponse allHeaderFields] objectForKey:@"Content-Length"]) {
            NSNumber *dataLength = [NSNumber numberWithDouble:[[[httpResponse allHeaderFields] objectForKey:@"Content-Length"] doubleValue]];
            _npEpisodeEntity.dataLength = dataLength;
            //NSLog(@"episode size: %@", [TungCommonObjects formatBytes:dataLength]);
        }
        _response = (NSHTTPURLResponse *)response;
        
        [self processPendingRequests];
    }
    else if (connection == _saveTrackConnection) {
        
        // get data length from response header
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if ([[httpResponse allHeaderFields] objectForKey:@"Content-Length"]) {
            NSNumber *dataLength = [NSNumber numberWithDouble:[[[httpResponse allHeaderFields] objectForKey:@"Content-Length"] doubleValue]];
            _episodeToSaveEntity.dataLength = dataLength;
        }
        
        _saveTrackData = [NSMutableData data];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    //JPLog(@"[NSURLConnectionDataDelegate] connection did receive data: %d", data.length);
    if (connection == _trackDataConnection) {
        [_trackData appendData:data];
        
        [self processPendingRequests];
    }
    else if (connection == _saveTrackConnection) {
        
        [_saveTrackData appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (connection == _trackDataConnection) {
        //JPLog(@"[NSURLConnectionDataDelegate] connection did finish loading");
        [self processPendingRequests];
        
        NSString *cachedEpisodeFilepath = [TungCommonObjects getCachedFilepathForEpisodeEntity:_npEpisodeEntity];
        NSError *error;
        if ([_trackData writeToFile:cachedEpisodeFilepath options:0 error:&error]) {
            
            _fileIsLocal = YES;
            //JPLog(@"-- saved podcast track in temp episode dir: %@", episodeFilepath);
            //_trackData = nil;
            // move to saved?
            if (_saveOnDownloadComplete) {
                [self moveToSavedOrQueueDownloadForEpisode:_npEpisodeEntity];
                _saveOnDownloadComplete = NO; // reset
            }
        }
        else {
            JPLog(@"ERROR: track did not get cached: %@", error);
            _fileIsLocal = NO;
        }
    }
    else if (connection == _saveTrackConnection) {
        
        // deduct bytes to save
        _bytesToSave -= _episodeToSaveEntity.dataLength.doubleValue;
        // save in docs directory
        NSString *savedEpisodeFilepath = [TungCommonObjects getSavedFilepathForEpisodeEntity:_episodeToSaveEntity];
        NSError *error;
        
        if ([_saveTrackData writeToFile:savedEpisodeFilepath options:0 error:&error]) {
            JPLog(@"-- saved podcast track");
            
            // save feed and art
            [TungCommonObjects savePodcastArtForEntity:_episodeToSaveEntity.podcast];
            [TungPodcast saveFeedForEntity:_episodeToSaveEntity.podcast];
            
            _saveTrackData = nil;
            _saveTrackConnection = nil;
            // update entity
            _episodeToSaveEntity.isQueuedForSave = [NSNumber numberWithBool:NO];
            _episodeToSaveEntity.isDownloadingForSave = [NSNumber numberWithBool:NO];
            _episodeToSaveEntity.isSaved = [NSNumber numberWithBool:YES];
            
            // set date and local notif. for deletion
            NSInteger days = DAYS_TO_KEEP_SAVED;
            NSDate *todayPlusThirtyDays = [TungCommonObjects createLocalNotifToDeleteAudioForEntity:_episodeToSaveEntity inDays:days forCached:NO];
            _episodeToSaveEntity.savedUntilDate = todayPlusThirtyDays;
            [TungCommonObjects saveContextWithReason:@"episode finished saving"];
            
            // next?
            [_episodeSaveQueue removeObjectAtIndex:0];
            if (_episodeSaveQueue.count > 0) {
            	[self downloadNextEpisodeInQueue];
            } else {
                [TungCommonObjects queueSaveStatusDidChangeNotification];
            }
            
        }
        else {
            JPLog(@"Error saving track: %@", error);
            _saveTrackData = nil;
            _saveTrackConnection = nil;
            
            UIAlertController *noSaveAlert = [UIAlertController alertControllerWithTitle:@"Error saving episode" message:[NSString stringWithFormat:@"%@", [error localizedDescription]] preferredStyle:UIAlertControllerStyleAlert];
            [noSaveAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [_viewController presentViewController:noSaveAlert animated:YES completion:nil];
            // update entity
            _episodeToSaveEntity.isQueuedForSave = [NSNumber numberWithBool:NO];
            _episodeToSaveEntity.isDownloadingForSave = [NSNumber numberWithBool:NO];
            _episodeToSaveEntity.isSaved = [NSNumber numberWithBool:NO];
            [TungCommonObjects saveContextWithReason:@"episode did not save"];
            [TungCommonObjects queueSaveStatusDidChangeNotification];
        }
    }
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {
    
    JPLog(@"connection lost");
    [self reestablishPlayerItemAndReplace];
}

#pragma mark - AVURLAsset resource loading

- (void)processPendingRequests
{
    //JPLog(@"[AVAssetResourceLoaderDelegate] process pending requests");
    NSMutableArray *requestsCompleted = [NSMutableArray array];
    
    for (AVAssetResourceLoadingRequest *loadingRequest in self.pendingRequests)
    {
        [self fillInContentInformation:loadingRequest.contentInformationRequest];
        
        BOOL didRespondCompletely = [self respondWithDataForRequest:loadingRequest.dataRequest];
        
        if (didRespondCompletely)
        {
            [requestsCompleted addObject:loadingRequest];
            
            [loadingRequest finishLoading];
        }
    }
    
    [self.pendingRequests removeObjectsInArray:requestsCompleted];
}

- (void)fillInContentInformation:(AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest
{
    if (contentInformationRequest == nil || self.response == nil)
    {
        return;
    }
    //JPLog(@"[AVAssetResourceLoaderDelegate] fill in content information");
    NSString *mimeType = [self.response MIMEType];
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    
    contentInformationRequest.byteRangeAccessSupported = YES;
    contentInformationRequest.contentType = CFBridgingRelease(contentType);
    contentInformationRequest.contentLength = [self.response expectedContentLength];
}

- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest
{
    //JPLog(@"[AVAssetResourceLoaderDelegate] respond with data for request");
    long long startOffset = dataRequest.requestedOffset;
    if (dataRequest.currentOffset != 0)
    {
        startOffset = dataRequest.currentOffset;
    }
    
    // Don't have any data at all for this request
    if (_trackData.length < startOffset)
    {
        return NO;
    }
    
    // This is the total data we have from startOffset to whatever has been downloaded so far
    NSUInteger unreadBytes = _trackData.length - (NSUInteger)startOffset;
    
    // Respond with whatever is available if we can't satisfy the request fully yet
    NSUInteger numberOfBytesToRespondWith = MIN((NSUInteger)dataRequest.requestedLength, unreadBytes);
    
    [dataRequest respondWithData:[_trackData subdataWithRange:NSMakeRange((NSUInteger)startOffset, numberOfBytesToRespondWith)]];
    
    long long endOffset = startOffset + dataRequest.requestedLength;
    BOOL didRespondFully = _trackData.length >= endOffset;
    
    return didRespondFully;
}


- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    //JPLog(@"[AVAssetResourceLoaderDelegate] should wait for loading of requested resource");
    // implemented fix for stalling playback: http://stackoverflow.com/a/29977243/591487
    if (_fileIsLocal) {
        [self.pendingRequests addObject:loadingRequest];
        [self processPendingRequests];
        return YES;
    }
    // initiate connection only if we haven't already downloaded the file
    else if (_trackDataConnection == nil)
    {
        [self initiateAVAssetDownload];
    }
    
    [self.pendingRequests addObject:loadingRequest];
    
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    //JPLog(@"[AVAssetResourceLoaderDelegate] did cancel loading request");
    [self.pendingRequests removeObject:loadingRequest];
}

- (void) initiateAVAssetDownload {
    NSURL *url = [NSURL URLWithString:_npEpisodeEntity.url];
    JPLog(@"init track data connection with url: %@", url);
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    _trackDataConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [_trackDataConnection setDelegateQueue:[NSOperationQueue mainQueue]];
    [_trackDataConnection start];
}


#pragma mark - custom tab bar badges

UILabel *prototypeBadge;

- (void) setBadgeNumber:(NSNumber *)number forBadge:(TungMiscView *)badge {
    
    CGRect badgeFrame = badge.frame;
    badgeFrame.size = CGSizeMake(22, 22); // set default
    if (number.integerValue > 0) {
        if (number.integerValue > 9) {
            NSString *text;
            if (number.integerValue > 99) {
                text = @"99+";
            }
            else {
                text = [NSString stringWithFormat:@"%@", number];
            }
            if (!prototypeBadge) {
                prototypeBadge = [[UILabel alloc] init];
                prototypeBadge.font = [UIFont systemFontOfSize:12];
                prototypeBadge.numberOfLines = 1;
            }
            prototypeBadge.text = text;
            CGSize badgeSize = [prototypeBadge sizeThatFits:CGSizeMake(44, 22)];
            CGFloat newWidth = badgeSize.width + 15;
            badgeFrame.size.width = newWidth;
            badge.text = text;
        } else {
            badge.text = [NSString stringWithFormat:@"%@", number];
        }
        badge.hidden = NO;
    } else {
        badge.text = @"0";
        badge.hidden = YES;
    }
    badge.bounds = badgeFrame;
    [badge setNeedsDisplay];
}

#pragma mark - feed related

- (void) checkFeedsLastFetchedTime {
    SettingsEntity *settings = [TungCommonObjects settings];
    NSTimeInterval now_secs = [[NSDate date] timeIntervalSince1970];
    // if feed hasn't been fetched in the last hour
    if ((settings.feedLastFetched.doubleValue + 3600) < now_secs) {
        _feedNeedsRefresh = [NSNumber numberWithBool:YES];
    }
    // if trending feed hasn't been fetched in the last hour
    if ((settings.trendingFeedLastFetched.doubleValue + 3600) < now_secs) {
        _trendingFeedNeedsRefresh = [NSNumber numberWithBool:YES];
    }
}

#pragma mark - core data related


+ (BOOL) saveContextWithReason:(NSString*)reason {
    
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    // save
    BOOL saved = NO;
    if ([appDelegate.managedObjectContext hasChanges]) {
        NSError *savingError;
        saved = [appDelegate.managedObjectContext save:&savingError];
        if (saved) {
            //JPLog(@"SAVE CONTEXT: %@ :: Successfully saved", reason);
        } else {
            JPLog(@"SAVE CONTEXT ERROR: %@ :: REASON: %@", savingError, reason);
        }
    } else {
        JPLog(@"SAVE CONTEXT: %@ :: Did not save, no changes", reason);
    }
    return saved;
}

/*	make sure there is a record for the podcast and the episode.
	Will not overwrite existing entities or create dupes. */
+ (PodcastEntity *) getEntityForPodcast:(NSDictionary *)podcastDict save:(BOOL)save {
    
    if (!podcastDict || ![podcastDict objectForKey:@"collectionId"]) {
        JPLog(@"get entity for podcast ERROR: podcast dict was null");
        return nil;
    }
    
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    PodcastEntity *podcastEntity;
    
    NSError *error = nil;
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"PodcastEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"collectionId == %@", [podcastDict objectForKey:@"collectionId"]];
    [request setPredicate:predicate];
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    if (result.count > 0) {
        // existing entity
        podcastEntity = [result lastObject];
    } else {
        // new entity
        //JPLog(@"creating new podcast entity for %@", [podcastDict objectForKey:@"collectionId"]);
        podcastEntity = [NSEntityDescription insertNewObjectForEntityForName:@"PodcastEntity" inManagedObjectContext:appDelegate.managedObjectContext];
        id collectionIdId = [podcastDict objectForKey:@"collectionId"];
        NSNumber *collectionId;
        if ([collectionIdId isKindOfClass:[NSString class]]) {
            collectionId = [TungCommonObjects stringToNumber:collectionIdId];
        } else {
            collectionId = (NSNumber *)collectionIdId;
        }
        podcastEntity.collectionId = collectionId;
        
    }
    // optional properties
    if ([podcastDict objectForKey:@"collectionName"]) {
        podcastEntity.collectionName = [podcastDict objectForKey:@"collectionName"];
    }
    if ([podcastDict objectForKey:@"artistName"]) {
        podcastEntity.artistName = [podcastDict objectForKey:@"artistName"];
    }
    if ([podcastDict objectForKey:@"feedUrl"]) {
        podcastEntity.feedUrl = [podcastDict objectForKey:@"feedUrl"];
    }
    if (podcastDict[@"keyColor1"] || podcastDict[@"keyColor1Hex"]) {
        UIColor *keyColor1, *keyColor2;
        NSString *keyColor1Hex, *keyColor2Hex;
        
        if ([podcastDict objectForKey:@"keyColor1"]) {
            keyColor1 = [podcastDict objectForKey:@"keyColor1"];
            keyColor2 = [podcastDict objectForKey:@"keyColor2"];
            keyColor1Hex = [TungCommonObjects UIColorToHexString:keyColor1];
            keyColor2Hex = [TungCommonObjects UIColorToHexString:keyColor2];
        }
        // datasource: social feed
        else {
            keyColor1Hex = [podcastDict objectForKey:@"keyColor1Hex"];
            keyColor2Hex = [podcastDict objectForKey:@"keyColor2Hex"];
            keyColor1 = [TungCommonObjects colorFromHexString:keyColor1Hex];
            keyColor2 = [TungCommonObjects colorFromHexString:keyColor2Hex];
        }
        podcastEntity.keyColor1 = keyColor1;
        podcastEntity.keyColor2 = keyColor2;
        podcastEntity.keyColor1Hex = keyColor1Hex;
        podcastEntity.keyColor2Hex = keyColor2Hex;
    }
    // art
    if (podcastDict[@"artworkUrl"] && [podcastDict[@"artworkUrl"] isKindOfClass:[NSString class]]) {
        podcastEntity.artworkUrl = podcastDict[@"artworkUrl"];
    }
    // artworkUrlSSL temporarily stores artworkUrl600 for display before feed is loaded,
    // if no artworkUrlSSL already exists. then it is overwritten by actual SSL art
    if (podcastDict[@"artworkUrlSSL"] && [podcastDict[@"artworkUrlSSL"] isKindOfClass:[NSString class]]) {
        podcastEntity.artworkUrlSSL = podcastDict[@"artworkUrlSSL"];
    }
    else if (!podcastEntity.artworkUrlSSL && podcastDict[@"artworkUrl600"] && [podcastDict[@"artworkUrl600"] isKindOfClass:[NSString class]]) {
        podcastEntity.artworkUrlSSL = podcastDict[@"artworkUrl600"];
    }
    // small SSL art
    if (podcastDict[@"artworkUrlSSL_sm"] && [podcastDict[@"artworkUrlSSL_sm"] isKindOfClass:[NSString class]]) {
        podcastEntity.artworkUrlSSL_sm = podcastDict[@"artworkUrlSSL_sm"];
    }
    // subscribed?
    if ([podcastDict objectForKey:@"isSubscribed"]) {
        NSNumber *subscribed = [podcastDict objectForKey:@"isSubscribed"];
        podcastEntity.isSubscribed = subscribed;
        if (subscribed.boolValue) {
            NSNumber *timeSubscribed = [podcastDict objectForKey:@"timeSubscribed"];
            podcastEntity.timeSubscribed = timeSubscribed;
        }
    }
    
    // magic button
    if (podcastDict[@"buttonText"] && [podcastDict[@"buttonText"] isKindOfClass:[NSString class]]) {
        podcastEntity.buttonText = podcastDict[@"buttonText"];
        podcastEntity.buttonSubtitle = podcastDict[@"buttonSubtitle"];
        podcastEntity.buttonLink = podcastDict[@"buttonLink"];
    }
	// NOTE: many properties set AFTER an entity is retrieved
    
    if (save) [TungCommonObjects saveContextWithReason:@"save podcast entity"];
    
    return podcastEntity;
}

+ (EpisodeEntity *) getEntityForEpisode:(NSDictionary *)episodeDict withPodcastEntity:(PodcastEntity *)podcastEntity save:(BOOL)save {
    
    if (!episodeDict || !podcastEntity) {
        JPLog(@"get entity for episode: ERROR: podcast entity or episode dict was null");
        return nil;
    }
    
    //JPLog(@"get episode entity for episode: %@", episodeDict);
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];

    // get episode entity
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"guid == %@", [episodeDict objectForKey:@"guid"]];
    [request setPredicate:predicate];
    NSError *error = nil;
    NSArray *episodeResult = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    
    EpisodeEntity *episodeEntity;
    
    if (episodeResult.count > 0) {
        // get existing entity
        episodeEntity = [episodeResult lastObject];
    } else {
        // make sure guid is present for new entity
        if ([episodeDict objectForKey:@"guid"] == [NSNull null]) {
            JPLog(@"did not get episode entity - cannot create episode entity without GUID. %@", episodeDict);
            return nil;
        }
        // new entity
        episodeEntity = [NSEntityDescription insertNewObjectForEntityForName:@"EpisodeEntity" inManagedObjectContext:appDelegate.managedObjectContext];
        
        episodeEntity.collectionId = podcastEntity.collectionId;
        episodeEntity.guid = [episodeDict objectForKey:@"guid"];
    }
    
    episodeEntity.podcast = podcastEntity;
    
    
    // optional/variable properties
    if ([episodeDict objectForKey:@"itunes:image"]) {
        episodeEntity.episodeImageUrl = [[[episodeDict objectForKey:@"itunes:image"] objectForKey:@"el:attributes"] objectForKey:@"href"];
    }
    if ([episodeDict objectForKey:@"itunes:duration"]) {
        episodeEntity.duration = [TungCommonObjects formatDurationFromString:[episodeDict objectForKey:@"itunes:duration"]];
    }
    if ([episodeDict objectForKey:@"_id"]) {
        episodeEntity.id = [[episodeDict objectForKey:@"_id"] objectForKey:@"$id"];
    }
    if ([episodeDict objectForKey:@"shortlink"]) {
        episodeEntity.shortlink = [episodeDict objectForKey:@"shortlink"];
    }
    if ([episodeDict objectForKey:@"pubDate"]) {
        id pubDateId = [episodeDict objectForKey:@"pubDate"];
        NSDate *pubDate;
        if ([pubDateId isKindOfClass:[NSDate class]]) {
            pubDate = pubDateId;
        } else {
            pubDate = [TungCommonObjects ISODateToNSDate:[episodeDict objectForKey:@"pubDate"]];
        }
        episodeEntity.pubDate = pubDate;
    }
    if ([episodeDict objectForKey:@"enclosure"]) {
        NSDictionary *enclosureDict = [TungCommonObjects getEnclosureDictForEpisode:episodeDict];
        episodeEntity.dataLength = [NSNumber numberWithDouble:[[[enclosureDict objectForKey:@"el:attributes"] objectForKey:@"length"] doubleValue]];
    }
    
    NSString *urlString = [TungCommonObjects getUrlStringFromEpisodeDict:episodeDict];
    if (urlString) {
    	episodeEntity.url = urlString;
    }
    if ([episodeDict objectForKey:@"trackProgress"]) {
        NSNumber *progress = [episodeDict objectForKey:@"trackProgress"];
        episodeEntity.trackProgress = progress;
    }
    if ([episodeDict objectForKey:@"trackPosition"]) {
        NSNumber *position = [episodeDict objectForKey:@"trackPosition"];
        episodeEntity.trackPosition = position;
    }
    if ([episodeDict objectForKey:@"isRecommended"]) {
        episodeEntity.isRecommended = [NSNumber numberWithBool:YES];
    }
    if ([episodeDict objectForKey:@"title"]) {
    	episodeEntity.title = [episodeDict objectForKey:@"title"];
    }
    if (!episodeEntity.desc) {
    	episodeEntity.desc = [TungCommonObjects findEpisodeDescriptionWithDict:episodeDict];
    }

    if (save) [TungCommonObjects saveContextWithReason:@"save episode entity"];
    
    return episodeEntity;
}

+ (NSDictionary *) getEnclosureDictForEpisode:(NSDictionary *)episodeDict {
    if ([episodeDict objectForKey:@"enclosure"]) {
        id enclosure = [episodeDict objectForKey:@"enclosure"];
        if ([enclosure isKindOfClass:[NSArray class]]) {
            return [enclosure lastObject];
        } else {
            return enclosure;
        }
    } else {
        return nil;
    }
}

+ (NSString *) getUrlStringFromEpisodeDict:(NSDictionary *)episodeDict {
    NSString *urlString;
    if ([episodeDict objectForKey:@"url"]) {
        urlString = [episodeDict objectForKey:@"url"];
        return urlString;
    }
    else if ([episodeDict objectForKey:@"enclosure"]) {
        NSDictionary *enclosureDict = [TungCommonObjects getEnclosureDictForEpisode:episodeDict];
        urlString = [[enclosureDict objectForKey:@"el:attributes"] objectForKey:@"url"];
        return urlString;
    }
    else {
        return nil;
    }
}

// get episode description
+ (NSString *) findEpisodeDescriptionWithDict:(NSDictionary *)episodeDict {
    
    id desc = [episodeDict objectForKey:@"itunes:summary"];
    if ([desc isKindOfClass:[NSString class]]) {
        //JPLog(@"- summary description");
        return (NSString *)desc;
    }
    else {
        id descr = [episodeDict objectForKey:@"description"];
        if ([descr isKindOfClass:[NSString class]]) {
            //JPLog(@"- regular description");
            return (NSString *)descr;
        }
        else {
            //JPLog(@"- no desc");
            return @"";
        }
    }
}

+ (NSDictionary *) entityToDict:(NSManagedObject *)entity {
    
    NSArray *keys = [[[entity entity] attributesByName] allKeys];
    NSDictionary *dict = [[entity dictionaryWithValuesForKeys:keys] mutableCopy];
    return dict;
}

// date converter for restoring podcast data
static NSDateFormatter *ISODateInterpreter = nil;
+ (NSDate *) ISODateToNSDate: (NSString *)pubDate {
    
    NSDate *date = nil;
    if (ISODateInterpreter == nil) {
        ISODateInterpreter = [[NSDateFormatter alloc] init]; // "2014-09-05 14:27:40",
        [ISODateInterpreter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    }
    
    if ([ISODateInterpreter dateFromString:pubDate]) {
        date = [ISODateInterpreter dateFromString:pubDate];
    }
    else {
        JPLog(@"could not convert date: %@", pubDate);
        date = [NSDate date];
    }
    return date;
    
}

+ (EpisodeEntity *) getEpisodeEntityFromEpisodeId:(NSString *)episodeId {
    
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"id == %@", episodeId];
    [request setPredicate:predicate];
    NSArray *episodeResult = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    if (episodeResult.count) {
        return [episodeResult lastObject];
    } else {
        return nil;
    }
}
+ (EpisodeEntity *) getEpisodeEntityFromUrlString:(NSString *)urlString {

    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"url == %@", urlString];
    [request setPredicate:predicate];
    NSArray *episodeResult = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    if (episodeResult.count > 0) {
        EpisodeEntity *epEntity = [episodeResult lastObject];
        return epEntity;
    }
    else {
        JPLog(@"ERROR: could not find episode entity for url: %@", urlString);
        return nil;
    }
}

+ (NSArray *) getAllSubscribedPodcasts {
    
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"PodcastEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isSubscribed == YES"];
    request.predicate = predicate;
    NSSortDescriptor *dateSort = [[NSSortDescriptor alloc] initWithKey:@"timeSubscribed" ascending:YES];
    NSSortDescriptor *orderSort = [[NSSortDescriptor alloc] initWithKey:@"sortOrder" ascending:YES];
    request.sortDescriptors = @[orderSort, dateSort];
    
    NSError *error;
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    
    if (!error) {
        return result;
    }
    else {
        JPLog(@"Error getting subscribed podcasts: %@", error.localizedDescription);
        return [NSArray array];
    }
}


+ (UserEntity *) saveUserWithDict:(NSDictionary *)userDict isLoggedInUser:(BOOL)isLoggedInUser {
    
    NSString *tungId;
    if ([userDict objectForKey:@"_id"]) {
    	tungId = [[userDict objectForKey:@"_id"] objectForKey:@"$id"];
    } else {
        tungId = [userDict objectForKey:@"tung_id"];
    }
    //JPLog(@"save user with dict: %@", userDict);
    UserEntity *userEntity = [TungCommonObjects retrieveUserEntityForUserWithId:tungId];
    
    if (!userEntity) {
        //JPLog(@"no existing user entity, create new");
        AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
        userEntity = [NSEntityDescription insertNewObjectForEntityForName:@"UserEntity" inManagedObjectContext:appDelegate.managedObjectContext];
    }
    userEntity.tung_id = tungId;
    userEntity.username = [userDict objectForKey:@"username"];
    userEntity.name = [userDict objectForKey:@"name"];
    userEntity.email = [userDict objectForKey:@"email"];
    userEntity.small_av_url = [userDict objectForKey:@"small_av_url"];
    userEntity.large_av_url = [userDict objectForKey:@"large_av_url"];
    // optional
    userEntity.location = [userDict objectForKey:@"location"];
    userEntity.bio = [userDict objectForKey:@"bio"];
    userEntity.url = [userDict objectForKey:@"url"];
    if ([userDict objectForKey:@"twitter_id"] != (id)[NSNull null]) {
        NSString *twitter_id = [userDict objectForKey:@"twitter_id"]; //ensure string
        userEntity.twitter_id = twitter_id;
    }
    if ([userDict objectForKey:@"twitter_username"] != (id)[NSNull null]) {
    	NSString *twitter_username = [userDict objectForKey:@"twitter_username"];
    	userEntity.twitter_username = twitter_username;
    }
    if ([userDict objectForKey:@"facebook_id"] != (id)[NSNull null]) {
        NSString *facebook_id = [userDict objectForKey:@"facebook_id"]; //ensure string
        userEntity.facebook_id = facebook_id;
    }
    
    if ([userDict objectForKey:@"token"] && [[userDict objectForKey:@"token"] isKindOfClass:[NSString class]]) {
        userEntity.token = [userDict objectForKey:@"token"];
    }
    
    userEntity.isLoggedInUser = [NSNumber numberWithBool:isLoggedInUser];

    [TungCommonObjects saveContextWithReason:@"save new user entity"];
    
    //NSLog(@"saved user: %@", [TungCommonObjects entityToDict:userEntity]);
    
    return userEntity;
}

+ (UserEntity *) retrieveUserEntityForUserWithId:(NSString *)userId {
    //JPLog(@"retrieve user entity for user with id: %@", userId);
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSFetchRequest *findUser = [[NSFetchRequest alloc] initWithEntityName:@"UserEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"tung_id == %@", userId];
    [findUser setPredicate:predicate];
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:findUser error:&error];
    
    if (result.count > 0) {
        UserEntity *user = [result objectAtIndex:0];
        return user;
    } else {
        return nil;
    }
}

+ (UserEntity *) getLoggedInUser {

    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSFetchRequest *findLoggedInUser = [[NSFetchRequest alloc] initWithEntityName:@"UserEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"isLoggedInUser == YES"];
    [findLoggedInUser setPredicate:predicate];
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:findLoggedInUser error:&error];
    
    if (result.count > 0) {
        UserEntity *user = [result objectAtIndex:0];
        return user;
    } else {
        return nil;
    }
}

+ (SettingsEntity *) settings {
    
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSFetchRequest *findSettings = [[NSFetchRequest alloc] initWithEntityName:@"SettingsEntity"];
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:findSettings error:&error];
    
    SettingsEntity *settings;
    if (result.count > 0) {
        settings = [result objectAtIndex:0];
    } else {
        settings = [NSEntityDescription insertNewObjectForEntityForName:@"SettingsEntity" inManagedObjectContext:appDelegate.managedObjectContext];
    }
    return settings;
}

// not used... only for debugging
+ (BOOL) checkForUserData {
    // Show user entities
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSFetchRequest *findUsers = [[NSFetchRequest alloc] initWithEntityName:@"UserEntity"];
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:findUsers error:&error];
    if (result.count > 0) {
        
        for (int i = 0; i < result.count; i++) {
            UserEntity *userEntity = [result objectAtIndex:i];
            NSDictionary *userDict = [TungCommonObjects entityToDict:userEntity];
            JPLog(@"user at index: %d", i);
            JPLog(@"%@", userDict);
        }
        
        return YES;
    } else {
        JPLog(@"no user entities found");
        return NO;
    }
}

// not used... only for debugging
+ (BOOL) checkForPodcastData {
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // show episode entity data
    JPLog(@"episode entity data");
    NSFetchRequest *eRequest = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSError *eError = nil;
    NSArray *eResult = [appDelegate.managedObjectContext executeFetchRequest:eRequest error:&eError];
    if (eResult.count > 0) {
        
        JPLog(@"found %d episode entities.\n\n", eResult.count);
        for (int i = 0; i < eResult.count; i++) {
            EpisodeEntity *episodeEntity = [eResult objectAtIndex:i];
            JPLog(@"episode at index: %d", i);
            // entity -> dict
            NSDictionary *eDict = [TungCommonObjects entityToDict:episodeEntity];
            JPLog(@"%@", eDict);
        }
    }

    // podcast entity data
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"PodcastEntity"];
    NSError *error;
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    if (result.count > 0) {
        
        JPLog(@"found %d podcast entities.\n\n", result.count);
        for (int i = 0; i < result.count; i++) {
            PodcastEntity *podcastEntity = [result objectAtIndex:i];
            JPLog(@"podcast at index: %d", i);
            // entity -> dict
            NSDictionary *podcastDict = [TungCommonObjects entityToDict:podcastEntity];
            JPLog(@"%@", podcastDict);
        }
        
        return YES;
    } else {
        return NO;
    }
}

// called on sign-out
+ (void) removePodcastAndEpisodeData {
    
    //JPLog(@"remove podcast and episode data");
    
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    // delete episode entity data
    NSFetchRequest *eRequest = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSError *eError = nil;
    NSArray *eResult = [appDelegate.managedObjectContext executeFetchRequest:eRequest error:&eError];
    if (eResult.count > 0) {
        for (int i = 0; i < eResult.count; i++) {
            [appDelegate.managedObjectContext deleteObject:[eResult objectAtIndex:i]];
            //JPLog(@"deleted episode record at index: %d", i);
        }
    }
    
    NSFetchRequest *pRequest = [[NSFetchRequest alloc] initWithEntityName:@"PodcastEntity"];
    NSError *pError = nil;
    NSArray *pResult = [appDelegate.managedObjectContext executeFetchRequest:pRequest error:&pError];
    if (pResult.count > 0) {
        for (int i = 0; i < pResult.count; i++) {
            [appDelegate.managedObjectContext deleteObject:[pResult objectAtIndex:i]];
            //JPLog(@"deleted podcast record at index: %d", i);
        }
    }
    
    [self saveContextWithReason:@"removed podcast and episode data"];
}

// called on sign-out
+ (void) removeAllUserData {
    //JPLog(@"remove all user data");
    
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"UserEntity"];
    NSError *error = nil;
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    if (result.count > 0) {
        for (int i = 0; i < result.count; i++) {
            [appDelegate.managedObjectContext deleteObject:[result objectAtIndex:i]];
            //JPLog(@"deleted user record at index: %d", i);
        }
    }
}

#pragma mark - Colors

static CCColorCube *colorCube = nil;
static NSArray *colors;

+ (NSString *) determineDominantColorFromRGB:(NSArray *)rbg {
    if (!colors) colors = [NSArray arrayWithObjects:@"R", @"G", @"B", nil];
    float highest = 0;
    int highestIndex;
    for (int i = 0; i < rbg.count; i++) {
        NSNumber *num = [rbg objectAtIndex:i];
        if (num.floatValue > highest) {
            highest = num.floatValue;
            highestIndex = i;
        }
    }
    return [colors objectAtIndex:highestIndex];
}

+ (NSArray *) extractColorsFromImage:(UIImage *)image {
    
    if (!colorCube) colorCube = [[CCColorCube alloc] init];
    return [colorCube extractColorsFromImage:image flags:CCAvoidWhite+CCAvoidBlack count:6];
}

+ (NSArray *) determineKeyColorsFromImage:(UIImage *)image {
    /*
     IMPORTANT: make sure this stays in sync with php equivalent on server: "filterKeyColors()"
     ALSO: run color test after each edit:
     
     - search hospital records, should get nice pink
     - search joe rogan, should get rusty orange
     - search dalrymple report, should get lighter orange
     - search tim ferriss, should get nice flesh color
     - search quad talk, should get medium green
     - search dork forest, should get medium green
     - search planet money, should get planet money green
     - search startup, should get royal blue
     - search less than or equal,
     - search flash forward, should get medium purple
     - search relay fm, check results (variety of colors)
     */
    
    NSArray *keyColors = [self extractColorsFromImage:image];
    UIColor *keyColor1 = [UIColor colorWithRed:0.45 green:0.45 blue:0.45 alpha:1];// default
    UIColor *keyColor2 = [self tungColor];// default
    if (keyColors.count > 0) {
        //JPLog(@"determine key colors ---------");
        
        int keyColor1Index = -1;
        int keyColor2Index = -1;
        NSString *keyColor1DominantColor;
        for (int i = 0; i < keyColors.count; i++) {
            
            // find luminance and saturation
            UIColor *uicolor = keyColors[i];
            const CGFloat *components = CGColorGetComponents(uicolor.CGColor);
            
            float min = components[0];
            float max = components[0];
            for (int j = 0; j < 3; j++) {
                if (components[j] < min) min = components[j];
                if (components[j] > max) max = components[j];
            }
            //float variance = max - min;
            float luminance = (max + min)/2;
            float saturation = 0;
            if (luminance < 0.5 && luminance != 0) {
                saturation = (max - min)/(max + min);
            }
            else if (luminance > 0.5 && luminance != 0) {
                saturation = (max - min)/(2.0 - max - min);
            }
            
            float R = components[0];
            float G = components[1];
            float B = components[2];
            //float sum = R + G + B;
            
            NSString *dominantColor = [self determineDominantColorFromRGB:@[[NSNumber numberWithFloat:R], [NSNumber numberWithFloat:G], [NSNumber numberWithFloat:B]]];
            
            //NSLog(@"- color %d - dominant: %@, saturation: %f, luminance: %f, sum: %f, RGB: %f - %f - %f", i, dominantColor, saturation, luminance, sum, R, G, B);
            
            // requirements only for 1st key color
            if (keyColor1Index < 0) {
                // test for not gray
                if (saturation < 0.09) continue;
                // test for too dark green
                if (R < 0.01 && G < 0.55 && B < 0.01) continue;
                // test for dark blue/purple
                if (R < 0.4 && G < 0.4 && B < 0.75) continue;
                // test for dark red/brown
                if (R < 0.7 && G < 0.3 && B < 0.3) continue;
            }
            // test for too light overall
            if (R > 0.6 && G > 0.6 && B > 0.6) continue;
            // test for too bright green
            if (R > 0.53 && G > 0.75 && B > 0.1) continue;
            // test too bright yellow
            if (R > 0.95 && G > 0.65) continue;
            // test for retina blasting G
            if (G > 0.9) continue;
            // test for too light blue
            if (R > 0.5 && G > 0.75 && B > 0.85) continue;


            if (keyColor1Index < 0) {
                //NSLog(@"* set key color 1");
                keyColor1Index = i;
                keyColor1DominantColor = dominantColor;
            }
            else if (keyColor2Index < 0) {
                // ensure different dominant color in 2nd key color
                NSString *keyColor2DominantColor = dominantColor;
                if ([keyColor1DominantColor isEqualToString:keyColor2DominantColor]) {
                    continue;
                } else {
                    //NSLog(@"* set key color 2");
                    keyColor2Index = i;
                    break;
                }
            }
            else {
                break;
            }
        }
        // set key colors
        if (keyColor1Index > -1) keyColor1 = [keyColors objectAtIndex:keyColor1Index];
        if (keyColor2Index > -1) keyColor2 = [keyColors objectAtIndex:keyColor2Index];
        if (keyColor1Index > -1 && keyColor2Index == -1) keyColor2 = [keyColors objectAtIndex:keyColor1Index];
    }
    
    return @[keyColor1, keyColor2];
    
}

+ (UIColor *) lightenKeyColor:(UIColor *)keyColor {
    CGFloat red, green, blue, alpha;
    [keyColor getRed:&red green:&green blue:&blue alpha:&alpha];
    red = red *1.05;
    green = green *1.05;
    blue = blue *1.05;
    red = MIN(1, red);
    green = MIN(1, green);
    blue = MIN(1, blue);
    return [UIColor colorWithRed:red green:green blue:blue alpha:1];
}
+ (UIColor *) darkenKeyColor:(UIColor *)keyColor {
    CGFloat red, green, blue, alpha;
    [keyColor getRed:&red green:&green blue:&blue alpha:&alpha];
    red = red *.95;
    green = green *.95;
    blue = blue *.95;
    red = MAX(0, red);
    green = MAX(0, green);
    blue = MAX(0, blue);
    return [UIColor colorWithRed:red green:green blue:blue alpha:1];
}

+ (NSString *) UIColorToHexString:(UIColor *)color {
    CGFloat red, green, blue, alpha;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    NSString *hexString = [NSString stringWithFormat:@"#%02x%02x%02x", (int)(red * 255),(int)(green * 255),(int)(blue * 255)];
    //JPLog(@"UIColor (red: %f, green: %f, blue: %f) to hex string: %@", red, green, blue, hexString);
    return hexString;
}

+ (UIColor *) colorFromHexString:(NSString *)hexString {
    NSString *cleanString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if([cleanString length] == 3) {
        cleanString = [NSString stringWithFormat:@"%@%@%@%@%@%@",
                       [cleanString substringWithRange:NSMakeRange(0, 1)],[cleanString substringWithRange:NSMakeRange(0, 1)],
                       [cleanString substringWithRange:NSMakeRange(1, 1)],[cleanString substringWithRange:NSMakeRange(1, 1)],
                       [cleanString substringWithRange:NSMakeRange(2, 1)],[cleanString substringWithRange:NSMakeRange(2, 1)]];
    }
    if([cleanString length] == 6) {
        cleanString = [cleanString stringByAppendingString:@"ff"];
    }
    
    unsigned int baseValue;
    [[NSScanner scannerWithString:cleanString] scanHexInt:&baseValue];
    
    float red = ((baseValue >> 24) & 0xFF)/255.0f;
    float green = ((baseValue >> 16) & 0xFF)/255.0f;
    float blue = ((baseValue >> 8) & 0xFF)/255.0f;
    float alpha = ((baseValue >> 0) & 0xFF)/255.0f;
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

+ (UIColor *) tungColor {
	return [UIColor colorWithRed:87.0/255 green:90.0/255 blue:215.0/255 alpha:1];
}
+ (UIColor *) lightTungColor {
    return [UIColor colorWithRed:238.0/255 green:239.0/255 blue:251.0/255 alpha:1];
}
+ (UIColor *) mediumTungColor { // not used
    return [UIColor colorWithRed:115.0/255 green:126.0/255 blue:231.0/255 alpha:1];
}
+ (UIColor *) darkTungColor { // not used
    return [UIColor colorWithRed:58.0/255 green:65.0/255 blue:175.0/255 alpha:1];
}
+ (UIColor *) bkgdGrayColor {
    return [UIColor colorWithRed:230.0/255.0 green:230.0/255.0 blue:230.0/255.0 alpha:1];
}
+ (UIColor *) facebookColor {
    return [UIColor colorWithRed:61.0/255 green:90.0/255 blue:152.0/255 alpha:1];
}
+ (UIColor *) twitterColor {
    return [UIColor colorWithRed:42.0/255 green:169.0/255 blue:224.0/255 alpha:1];
}

#pragma mark - Session instance methods

- (void) checkReachabilityWithCallback:(void (^)(BOOL reachable))callback {
    
    Reachability *internetReachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus netStatus = [internetReachability currentReachabilityStatus];
    
    switch (netStatus) {
        case NotReachable: {
            JPLog(@"Network not reachable");
            //NSLog(@"%@",[NSThread callStackSymbols]);
            _connectionAvailable = [NSNumber numberWithBool:NO];
             if (callback) callback(NO);
            break;
        }
        case ReachableViaWWAN: {
            //JPLog(@"Network reachable via cellular data");
            _connectionAvailable = [NSNumber numberWithBool:YES];
             if (callback) callback(YES);
            break;
        }
        case ReachableViaWiFi: {
            //JPLog(@"Network reachable via wifi");
            _connectionAvailable = [NSNumber numberWithBool:YES];
             if (callback) callback(YES);
            break;
        }
        default: {
             if (callback) callback(NO);
            break;
        }
    }
}


/*	all requests require a session ID instead of credentials
	start here and get session with credentials */
- (void) getSessionWithCallback:(void (^)(void))callback {
    JPLog(@"getting new session");

    if (!_loggedInUser.tung_id) {
        JPLog(@"Tung ID was null, re-establish cred");
        [self establishCred];
    }
    
    if (_gettingSession.boolValue) {
        JPLog(@"Debounced a getSession request");
        return;
    }
    _gettingSession = [NSNumber numberWithBool:YES];
    
    NSURL *getSessionRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@app/session.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *getSessionRequest = [NSMutableURLRequest requestWithURL:getSessionRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [getSessionRequest setHTTPMethod:@"POST"];
    NSDictionary *cred = @{@"tung_id": _loggedInUser.tung_id,
                           @"token": _loggedInUser.token,
                           @"iOS_version": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]
                           };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:cred];
    [getSessionRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    [NSURLConnection sendAsynchronousRequest:getSessionRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        //NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        //JPLog(@"response status code: %ld", (long)[httpResponse statusCode]);
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"sessionId"]) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        _gettingSession = [NSNumber numberWithBool:NO];
                        _sessionId = [responseDict objectForKey:@"sessionId"];
                        //JPLog(@"got new session: %@", _sessionId);
                        _connectionAvailable = [NSNumber numberWithInt:1];
                        // callback
                        callback();
                    });
                }
                else if ([responseDict objectForKey:@"error"]) {
                    JPLog(@"Error getting session: response: %@", [responseDict objectForKey:@"error"]);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        _gettingSession = [NSNumber numberWithBool:NO];
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Unauthorized"]) {
                            // attempt to automatically sign back in or sign out
                            [self handleUnauthorizedWithCallback:^{
                                callback();
                            }];
                        }
                    });
                }
            }
            else if ([data length] == 0 && error == nil) {
                JPLog(@"no response");
            }
            else if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    JPLog(@"Error getting session: %@", error);
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"HTML: %@", html);
                    _gettingSession = [NSNumber numberWithBool:NO];
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                // _tableView.backgroundView = nil;
                _gettingSession = [NSNumber numberWithBool:NO];
                [TungCommonObjects showConnectionErrorAlertForError:error];
            });
        }
    }];
}

/*	if user's token expires, attempt to log them back in without bugging them.
	this happens because a new token is issued on each sign-in (signin != session).
	so if user signed into Tung on a different device, their token here won't work. */
-(void) handleUnauthorizedWithCallback:(void (^)(void))callback {
    
    JPLog(@"handle unauthorized with callback");
    
    if (_loggedInUser && _loggedInUser.tung_id) {
        
        // signed up with twitter
        if (_loggedInUser.twitter_id && [Twitter sharedInstance].session) {
            
            TWTROAuthSigning *oauthSigning = [[TWTROAuthSigning alloc] initWithAuthConfig:[Twitter sharedInstance].authConfig authSession:[Twitter sharedInstance].session];
            
            NSDictionary *authHeaders = [oauthSigning OAuthEchoHeadersToVerifyCredentials];
            [self verifyCredWithTwitterOauthHeaders:authHeaders withCallback:^(BOOL success, NSDictionary *responseDict) {
                // user exists
                if (success && [responseDict objectForKey:@"sessionId"]) {
                    JPLog(@"recovered session with twitter - signed in");
                    _sessionId = [responseDict objectForKey:@"sessionId"];
                    _connectionAvailable = [NSNumber numberWithInt:1];
                    
                    NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                    //JPLog(@"lastDataChange (server): %@, lastDataChange (local): %@", lastDataChange, _loggedInUser.lastDataChange);
                    if (lastDataChange.doubleValue > _loggedInUser.lastDataChange.doubleValue) {
                        JPLog(@"needs restore. ");
                        [self restorePodcastDataSinceTime:_loggedInUser.lastDataChange];
                    }
                    
                    NSMutableDictionary *loggedUserDict = [[responseDict objectForKey:@"user"] mutableCopy];
                    [loggedUserDict setObject:[responseDict objectForKey:@"token"] forKey:@"token"];
                    _loggedInUser = [TungCommonObjects saveUserWithDict:loggedUserDict isLoggedInUser:YES];
                    
                    callback();
                }
            }];
            return;
        }
        // signed up with facebook
        else if (_loggedInUser.facebook_id && [FBSDKAccessToken currentAccessToken]) {
            
            NSString *tokenString = [[FBSDKAccessToken currentAccessToken] tokenString];
            [self verifyCredWithFacebookAccessToken:tokenString withCallback:^(BOOL success, NSDictionary *responseDict) {
                if (success && [responseDict objectForKey:@"sessionId"]) {
                    JPLog(@"recovered session with facebook - signed in");
                    _sessionId = [responseDict objectForKey:@"sessionId"];
                    _connectionAvailable = [NSNumber numberWithInt:1];
                    
                    NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                    JPLog(@"lastDataChange (server): %@, lastDataChange (local): %@", lastDataChange, _loggedInUser.lastDataChange);
                    if (lastDataChange.doubleValue > _loggedInUser.lastDataChange.doubleValue) {
                        JPLog(@"needs restore. ");
                        [self restorePodcastDataSinceTime:_loggedInUser.lastDataChange];
                    }
                    
                    NSMutableDictionary *loggedUserDict = [[responseDict objectForKey:@"user"] mutableCopy];
                    [loggedUserDict setObject:[responseDict objectForKey:@"token"] forKey:@"token"];
                    _loggedInUser = [TungCommonObjects saveUserWithDict:loggedUserDict isLoggedInUser:YES];
                    
                    callback();
                }
            }];
            return;
        }
    }
	// if method hasn't returned... force user to sign out and sign in again
    UIAlertController *unauthorizedAlert = [UIAlertController alertControllerWithTitle:@"Credentials expired" message:@"Please sign in again." preferredStyle:UIAlertControllerStyleAlert];
    [unauthorizedAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self signOut];
    }]];
    [_viewController presentViewController:unauthorizedAlert animated:YES completion:nil];
}


/*//////////////////////////////////
 Tung Stories
 /////////////////////////////////*/


+ (void) addOrUpdatePodcast:(PodcastEntity *)podcastEntity orEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(void))callback  {
    
    if (!podcastEntity.collectionId || !podcastEntity.artworkUrl) {
        JPLog(@"Error adding/updating podcast: entity missing required info. %@", [TungCommonObjects entityToDict:podcastEntity]);
        return;
    }
    
    NSURL *addPodOrEpisodeRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/add-or-update-podcast.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *addPodOrEpisodeRequest = [NSMutableURLRequest requestWithURL:addPodOrEpisodeRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [addPodOrEpisodeRequest setHTTPMethod:@"POST"];
    // optional params
    NSString *email = (podcastEntity.email) ? podcastEntity.email : @"";
    NSString *website = (podcastEntity.website) ? podcastEntity.website : @"";
    
    JPLog(@"Add or Update Podcast for entity: %@", podcastEntity.collectionName);
    //NSLog(@"episode entity: %@", episodeEntity);
    NSMutableDictionary *params = [@{@"apiKey": [TungCommonObjects apiKey],
                                    @"collectionId": podcastEntity.collectionId,
                                    @"collectionName": podcastEntity.collectionName,
                                    @"artistName": podcastEntity.artistName,
                                    @"artworkUrl": podcastEntity.artworkUrl,
                                    @"feedUrl": podcastEntity.feedUrl,
                                    @"keyColor1Hex": podcastEntity.keyColor1Hex,
                                    @"keyColor2Hex": podcastEntity.keyColor2Hex,
                                    @"email": email,
                                    @"website": website
                                    } mutableCopy];

    if (episodeEntity) {
        NSDictionary *episodeParams = @{@"GUID": episodeEntity.guid,
                                        @"episodeUrl": episodeEntity.url,
                                        @"episodePubDate": [ISODateFormatter stringFromDate:episodeEntity.pubDate],
                                        @"episodeTitle": episodeEntity.title
                                        };
        [params addEntriesFromDictionary:episodeParams];
    }
    
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [addPodOrEpisodeRequest setHTTPBody:serializedParams];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:addPodOrEpisodeRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    JPLog(@"add or update response: %@", responseDict);
                    
                    if ([responseDict objectForKey:@"error"]) {
                        JPLog(@"Error adding or updating podcast: %@", [responseDict objectForKey:@"error"]);
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //JPLog(@"successfully added or updated podcast/episode. %@", responseDict);
                        NSString *artworkUrlSSL = [responseDict objectForKey:@"artworkUrlSSL"];
                        NSString *artworkUrlSSL_sm = [responseDict objectForKey:@"artworkUrlSSL_sm"];
                        podcastEntity.artworkUrlSSL = artworkUrlSSL;
                        podcastEntity.artworkUrlSSL_sm = artworkUrlSSL_sm;
                        
                        if (episodeEntity) {
                            // save episode id and shortlink
                            NSString *episodeId = [responseDict objectForKey:@"episodeId"];
                            NSString *shortlink = [responseDict objectForKey:@"shortlink"];
                            episodeEntity.id = episodeId;
                            episodeEntity.shortlink = shortlink;
                        }
                        [TungCommonObjects saveContextWithReason:@"got podcast artwork SSL urls and/or episode shortlink and id"];
                        
                        if (callback) callback();
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
            });
        }
    }];
}

/*	if a user deletes the app or signs out, they lose all their subscribe/recommend/progress data.
	also syncs web data with app data */
- (void) restorePodcastDataSinceTime:(NSNumber *)time {
    
    if (time.integerValue == 0) {
        [TungCommonObjects showBannerAlertForText:@"Restoring podcast data…"];
    }
    NSURL *restoreRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@app/restore-podcast-data.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *restoreRequest = [NSMutableURLRequest requestWithURL:restoreRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [restoreRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"lastDataChange":[NSString stringWithFormat:@"%@", time]
                             };
    JPLog(@"restore podcast data since %@", time);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [restoreRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:restoreRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    //JPLog(@"restore podcast response: %@", responseDict);
                    if ([responseDict objectForKey:@"error"]) {
                        // session expired
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self getSessionWithCallback:^{
                                [self restorePodcastDataSinceTime:time];
                            }];
                        }
                        else {
                            JPLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        NSArray *podcasts = [responseDict objectForKey:@"podcasts"];
                        NSArray *episodes = [responseDict objectForKey:@"episodes"];
                        NSMutableArray *podEntities = [NSMutableArray array];
                        if (podcasts.count) {
                            // restore subscribes
                            for (NSDictionary *podcastDict in podcasts) {
                                PodcastEntity *podEntity = [TungCommonObjects getEntityForPodcast:podcastDict save:YES];
                                [podEntities addObject:podEntity];
                            }
                        }
                        if (episodes.count) {
                            // restore recommends/progress
                            PodcastEntity *pEntity;
                            NSMutableString *lastCollectionId = [@"" mutableCopy];
                            for (NSDictionary *episodeDict in episodes) {
                                NSDictionary *eDict = [episodeDict objectForKey:@"episode"];
                                NSDictionary *pDict = [episodeDict objectForKey:@"podcast"];
                                // results are sorted by collectionId so podcast entity can be reused
                                if (![lastCollectionId isEqualToString:[pDict objectForKey:@"collectionId"]]) {
                                    lastCollectionId = [pDict objectForKey:@"collectionId"];
                                    pEntity = [TungCommonObjects getEntityForPodcast:pDict save:NO];
                                }
                                //JPLog(@"save ep entity %@", [eDict objectForKey:@"guid"]);
                                [TungCommonObjects getEntityForEpisode:eDict withPodcastEntity:pEntity save:YES];
                            }
                        }
                        // prefetch feeds
                        if (podEntities.count) {
                            for (PodcastEntity *podEntity in podEntities) {
                                
                                NSOperationQueue *fetchingQueue = [[NSOperationQueue alloc] init];
                                fetchingQueue.maxConcurrentOperationCount = 3;
                                [fetchingQueue addOperationWithBlock:^{
                                    [TungPodcast retrieveAndCacheFeedForPodcastEntity:podEntity forceNewest:NO reachable:_connectionAvailable.boolValue];
                                }];
                            }
                        }
                        JPLog(@"got restore data for %lu podcasts and %lu episodes", (unsigned long)podcasts.count, (unsigned long)episodes.count);
    //                    JPLog(@"- script duration: %@", [responseDict objectForKey:@"scriptDuration"]);
    //                    JPLog(@"- memory usage: %@", [responseDict objectForKey:@"memoryUsage"]);
    //                    JPLog(@"- lastDataChange: %@", [responseDict objectForKey:@"lastDataChange"]);
                        
                        NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                        _loggedInUser.lastDataChange = lastDataChange;
                        [TungCommonObjects saveContextWithReason:@"updated lastDataChange for restore"];
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
            });
        }
    }];
}

// get shortlink and id for episode, make new record in none exists.
- (void) addEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(void))callback {
    //JPLog(@"add episoe request");
    NSURL *getEpisodeInfoRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/add-episode.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *getEpisodeInfoRequest = [NSMutableURLRequest requestWithURL:getEpisodeInfoRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [getEpisodeInfoRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": episodeEntity.collectionId,
                             @"GUID": episodeEntity.guid,
                             @"episodeUrl": episodeEntity.url,
                             @"episodePubDate": [ISODateFormatter stringFromDate:episodeEntity.pubDate],
                             @"episodeTitle": episodeEntity.title
                             };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [getEpisodeInfoRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:getEpisodeInfoRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        // no podcast record
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                            __unsafe_unretained typeof(self) weakSelf = self;
                            [TungCommonObjects addOrUpdatePodcast:episodeEntity.podcast orEpisode:episodeEntity withCallback:^ {
                                [weakSelf addEpisode:episodeEntity withCallback:callback];
                            }];
                        }
                        else {
                            JPLog(@"Error adding episode: %@", [responseDict objectForKey:@"error"]);
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        // save episode id and shortlink
                        NSString *episodeId = [responseDict objectForKey:@"episodeId"];
                        NSString *shortlink = [responseDict objectForKey:@"shortlink"];
                        episodeEntity.id = episodeId;
                        episodeEntity.shortlink = shortlink;
                        [TungCommonObjects saveContextWithReason:@"got episode shortlink and id"];
                        callback();
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
            });
        }
    }];
}

// SUBSCRIBING
- (void) subscribeToPodcast:(PodcastEntity *)podcastEntity withButton:(CircleButton *)button {
    //JPLog(@"subscribe request for podcast with id %@", podcastEntity.collectionId);
    [button setEnabled:NO];
    
    SettingsEntity *settings = [TungCommonObjects settings];
    if (!settings.hasSeenNewEpisodesPrompt.boolValue && ![[UIApplication sharedApplication] isRegisteredForRemoteNotifications]) {
        [self promptForNotificationsForEpisodes];
    }
    
    NSURL *subscribeRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/subscribe.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *subscribeRequest = [NSMutableURLRequest requestWithURL:subscribeRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [subscribeRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": podcastEntity.collectionId};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [subscribeRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:subscribeRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    //JPLog(@"%@", responseDict);
                    if ([responseDict objectForKey:@"error"]) {
                        // session expired
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self getSessionWithCallback:^{
                                [self subscribeToPodcast:podcastEntity withButton:button];
                            }];
                        }
                        // no podcast record
                        else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                            __unsafe_unretained typeof(self) weakSelf = self;
                            [TungCommonObjects addOrUpdatePodcast:podcastEntity orEpisode:nil withCallback:^ {
                                [weakSelf subscribeToPodcast:podcastEntity withButton:button];
                            }];
                        }
                        else {
                            JPLog(@"Error subscribing to podcast: %@", [responseDict objectForKey:@"error"]);
                            [button setEnabled:YES];
                        }
                    }
                    // success
                    else if ([responseDict objectForKey:@"success"]) {
                        [button setEnabled:YES];
                        [TungCommonObjects savePodcastArtForEntity:podcastEntity];
                        
                        [TungPodcast retrieveAndCacheFeedForPodcastEntity:podcastEntity forceNewest:NO reachable:_connectionAvailable.boolValue];
                        
                        NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                        _loggedInUser.lastDataChange = lastDataChange;
                        podcastEntity.timeSubscribed = lastDataChange;
                        podcastEntity.isSubscribed = [NSNumber numberWithBool:YES];
                        
                        [TungCommonObjects saveContextWithReason:@"lastDataChange changed for logged in user, subscribe status changed"];
                        // important: do not assign shortlink from subscribe story to episode entity
                        // notification
                        NSDictionary *userInfo = @{ @"collectionId": podcastEntity.collectionId };
                        NSNotification *subscribeChangeNotif = [NSNotification notificationWithName:@"refreshSubscribeStatus" object:nil userInfo:userInfo];
                        [[NSNotificationCenter defaultCenter] postNotification:subscribeChangeNotif];
                    }
                }
                else {
                    [button setEnabled:YES];
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [button setEnabled:YES];
                JPLog(@"Error unsubscribing from podcast: %@", error.localizedDescription);
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
            });
        }
    }];
}

- (void) unsubscribeFromPodcast:(PodcastEntity *)podcastEntity withButton:(CircleButton *)button {
    //JPLog(@"unsubscribe request for podcast with id %@", podcastEntity.collectionId);
    [button setEnabled:NO];
    NSURL *unsubscribeFromPodcastRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/unsubscribe.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *unsubscribeFromPodcastRequest = [NSMutableURLRequest requestWithURL:unsubscribeFromPodcastRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [unsubscribeFromPodcastRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": podcastEntity.collectionId};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [unsubscribeFromPodcastRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:unsubscribeFromPodcastRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    //JPLog(@"%@", responseDict);
                    if ([responseDict objectForKey:@"error"]) {
                        // session expired
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self getSessionWithCallback:^{
                                [self unsubscribeFromPodcast:podcastEntity withButton:button];
                            }];
                        }
                        // no podcast record
                        else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                            __unsafe_unretained typeof(self) weakSelf = self;
                            [TungCommonObjects addOrUpdatePodcast:podcastEntity orEpisode:nil withCallback:^ {
                                [weakSelf unsubscribeFromPodcast:podcastEntity withButton:button];
                            }];
                        }
                        else {
                            JPLog(@"Error unsubscribing from podcast: %@", [responseDict objectForKey:@"error"]);
                            [button setEnabled:YES];
                        }
                    }
                    // success
                    else if ([responseDict objectForKey:@"success"]) {
                        [button setEnabled:YES];
                        
                        [TungCommonObjects unsavePodcastArtForEntity:podcastEntity];
                        // feeds only get saved when episodes are saved, no need to unsave feed
                        
                        NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                        _loggedInUser.lastDataChange = lastDataChange;
                        podcastEntity.timeSubscribed = [NSNumber numberWithInt:0];
                        podcastEntity.isSubscribed = [NSNumber numberWithBool:NO];
                        [TungCommonObjects saveContextWithReason:@"lastDataChange changed for logged in user, subscribe status change"];
                        // notification
                        NSDictionary *userInfo = @{ @"collectionId": podcastEntity.collectionId };
                        NSNotification *subscribeChangeNotif = [NSNotification notificationWithName:@"refreshSubscribeStatus" object:nil userInfo:userInfo];
                        [[NSNotificationCenter defaultCenter] postNotification:subscribeChangeNotif];
                    }
                }
                else {
                    [button setEnabled:YES];
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [button setEnabled:YES];
                JPLog(@"Error unsubscribing from podcast: %@", error.localizedDescription);
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
            });
        }
    }];
}

/*	STORY REQUESTS
	story requests send all episode info (episode entity) if there is no episode ID,
	so that episode record can be created if one doesn't exist yet. ID and shortlink
	are assigned locally with return data.
	*/

// RECOMMENDING
- (void) recommendEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success))callback {

    NSURL *recommendPodcastRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/recommend.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *recommendPodcastRequest = [NSMutableURLRequest requestWithURL:recommendPodcastRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [recommendPodcastRequest setHTTPMethod:@"POST"];
    
    NSDictionary *params;
    if (episodeEntity.id) {
        params = @{@"sessionId":_sessionId,
                   @"collectionId": episodeEntity.collectionId,
                   @"episodeId": episodeEntity.id,
                   @"episodeTitle": episodeEntity.title,
                   @"GUID": episodeEntity.guid
                   };
    } else {
        params = @{@"sessionId":_sessionId,
                   @"collectionId": episodeEntity.collectionId,
                   @"GUID": episodeEntity.guid,
                   @"episodeUrl": episodeEntity.url,
                   @"episodePubDate": [ISODateFormatter stringFromDate:episodeEntity.pubDate],
                   @"episodeTitle": episodeEntity.title
                   };
    }
    //JPLog(@"recommend episode request with params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [recommendPodcastRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:recommendPodcastRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        // session expired
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self getSessionWithCallback:^{
                                [self recommendEpisode:episodeEntity withCallback:callback];
                            }];
                        }
                        // no podcast record
                        else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                            __unsafe_unretained typeof(self) weakSelf = self;
                            [TungCommonObjects addOrUpdatePodcast:episodeEntity.podcast orEpisode:episodeEntity withCallback:^ {
                                [weakSelf recommendEpisode:episodeEntity withCallback:callback];
                            }];
                        }
                        else {
                            JPLog(@"Error recommending episode: %@", [responseDict objectForKey:@"error"]);
                            [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                            callback(NO);
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //JPLog(@"successfully recommended episode: %@", responseDict);
                        if (!episodeEntity.id) {
                            // save episode id and shortlink
                            NSString *episodeId = [responseDict objectForKey:@"episodeId"];
                            NSString *shortlink = [responseDict objectForKey:@"shortlink"];
                            episodeEntity.id = episodeId;
                            episodeEntity.shortlink = shortlink;
                        }
                        episodeEntity.isRecommended = [NSNumber numberWithBool:YES];
                        NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                        _loggedInUser.lastDataChange = lastDataChange;
                        [TungCommonObjects saveContextWithReason:@"recommended episode"];
                        _feedNeedsRefresh = [NSNumber numberWithBool:YES];
                        _profileFeedNeedsRefresh = [NSNumber numberWithBool:YES];
                        callback(YES);
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                    [TungCommonObjects simpleErrorAlertWithMessage:@"Server error"];
                    callback(NO);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"Error recommending episode: %@", error.localizedDescription);
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
                callback(NO);
            });
        }
    }];
}

- (void) unRecommendEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success))callback; {
    //JPLog(@"un-recommend episode");
    NSURL *unRecommendPodcastRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/un-recommend.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *unRecommendPodcastRequest = [NSMutableURLRequest requestWithURL:unRecommendPodcastRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [unRecommendPodcastRequest setHTTPMethod:@"POST"];
    NSString *episodeId = (episodeEntity.id) ? episodeEntity.id : @"";
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": episodeEntity.collectionId,
                             @"episodeId": episodeId
                             };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [unRecommendPodcastRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:unRecommendPodcastRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    //JPLog(@"%@", responseDict);
                    if ([responseDict objectForKey:@"error"]) {
                        // session expired
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self getSessionWithCallback:^{
                                [self unRecommendEpisode:episodeEntity withCallback:callback];
                            }];
                        }
                        else {
                            JPLog(@"Error un-recommending episode: %@", [responseDict objectForKey:@"error"]);
                            [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                            callback(NO);
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //JPLog(@"unrecommend response: %@", responseDict);
                        episodeEntity.isRecommended = [NSNumber numberWithBool:NO];
                        NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                        _loggedInUser.lastDataChange = lastDataChange;
                        [TungCommonObjects saveContextWithReason:@"un-recommended episode"];
                        _feedNeedsRefetch = [NSNumber numberWithBool:YES];
                        _trendingFeedNeedsRefetch = [NSNumber numberWithBool:YES];
                        _profileFeedNeedsRefetch = [NSNumber numberWithBool:YES];
                        callback(YES);
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                    [TungCommonObjects simpleErrorAlertWithMessage:@"Server error"];
                    callback(NO);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"Error un-recommending episode: %@", error.localizedDescription);
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
                callback(NO);
            });
        }
    }];
}

// SYNC TRACK PROGRESS WITH SERVER
- (void) syncProgressFromTimer:(NSTimer *)timer {
    [self syncProgressForEpisode:[timer userInfo]];
}
- (void) syncProgressForEpisode:(EpisodeEntity *)episodeEntity {
    
    NSURL *syncProgressRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/save-progress.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *syncProgressRequest = [NSMutableURLRequest requestWithURL:syncProgressRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [syncProgressRequest setHTTPMethod:@"POST"];
    
    NSDictionary *params;
    if (episodeEntity.id) {
        params = @{@"sessionId":_sessionId,
                   @"collectionId": episodeEntity.collectionId,
                   @"episodeId": episodeEntity.id,
                   @"GUID": episodeEntity.guid,
                   @"episodeProgress": episodeEntity.trackProgress,
                   @"episodePosition": episodeEntity.trackPosition
                   };
    } else {
        params = @{@"sessionId":_sessionId,
                   @"collectionId": episodeEntity.collectionId,
                   @"GUID": episodeEntity.guid,
                   @"episodeUrl": episodeEntity.url,
                   @"episodePubDate": [ISODateFormatter stringFromDate:episodeEntity.pubDate],
                   @"episodeTitle": episodeEntity.title,
                   @"episodeProgress": episodeEntity.trackProgress,
                   @"episodePosition": episodeEntity.trackPosition
                   };
    }
    
    //JPLog(@"sync progress (%f) request", episodeEntity.trackPosition.doubleValue);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [syncProgressRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:syncProgressRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        // session expired
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self getSessionWithCallback:^{
                                [self syncProgressForEpisode:episodeEntity];
                            }];
                        }
                        // no podcast record
                        else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                            __unsafe_unretained typeof(self) weakSelf = self;
                            [TungCommonObjects addOrUpdatePodcast:episodeEntity.podcast orEpisode:episodeEntity withCallback:^ {
                                [weakSelf syncProgressForEpisode:episodeEntity];
                            }];
                        }
                        else {
                            JPLog(@"Error syncing progress: %@", [responseDict objectForKey:@"error"]);
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //JPLog(@"save progress response %@", responseDict);
                        if (!episodeEntity.id) {
                            // save episode id and shortlink
                            NSString *episodeId = [responseDict objectForKey:@"episodeId"];
                            NSString *shortlink = [responseDict objectForKey:@"shortlink"];
                            episodeEntity.id = episodeId;
                            episodeEntity.shortlink = shortlink;
                        }
                        NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                        _loggedInUser.lastDataChange = lastDataChange;
                        [TungCommonObjects saveContextWithReason:@"save lastDataChange"];
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"Error syncing progress: %@", error.localizedDescription);
            });
        }
    }];
}

- (void) incrementPlayCountForNowPlaying {
    [self incrementPlayCountForEpisode:_npEpisodeEntity];
}

- (void) incrementPlayCountForEpisode:(EpisodeEntity *)episodeEntity {
    
    if (!_connectionAvailable.boolValue) {
        return;
    }
    
    NSURL *incrementCountRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/increment-listen-count.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *incrementCountRequest = [NSMutableURLRequest requestWithURL:incrementCountRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [incrementCountRequest setHTTPMethod:@"POST"];
    
    NSDictionary *params;
    if (episodeEntity.id) {
        params = @{@"sessionId":_sessionId,
                   @"apiKey": [TungCommonObjects apiKey],
                   @"collectionId": episodeEntity.collectionId,
                   @"episodeId": episodeEntity.id,
                   };
    } else {
        params = @{@"sessionId":_sessionId,
                   @"apiKey": [TungCommonObjects apiKey],
                   @"collectionId": episodeEntity.collectionId,
                   @"GUID": episodeEntity.guid,
                   @"episodeUrl": episodeEntity.url,
                   @"episodePubDate": [ISODateFormatter stringFromDate:episodeEntity.pubDate],
                   @"episodeTitle": episodeEntity.title
                   };
    }
    //JPLog(@"increment play count request with params: %@", params);
    
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [incrementCountRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:incrementCountRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        // no podcast record
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                            __unsafe_unretained typeof(self) weakSelf = self;
                            [TungCommonObjects addOrUpdatePodcast:episodeEntity.podcast orEpisode:episodeEntity withCallback:^ {
                                [weakSelf incrementPlayCountForEpisode:episodeEntity];
                            }];
                        }
                        else {
                            JPLog(@"Error incrementing play count: %@", [responseDict objectForKey:@"error"]);
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //JPLog(@"increment play count: %@", responseDict);
                        if (!episodeEntity.id) {
                            // save episode id and shortlink
                            NSString *episodeId = [responseDict objectForKey:@"episodeId"];
                            NSString *shortlink = [responseDict objectForKey:@"shortlink"];
                            episodeEntity.id = episodeId;
                            episodeEntity.shortlink = shortlink;
                        }
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
            	JPLog(@"Error incrementing play count: %@", error.localizedDescription);
            });
        }
    }];
}

// COMMENTS AND CLIPS
- (void) postComment:(NSString*)comment atTime:(NSString*)timestamp onEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback  {
    //JPLog(@"post comment request with session %@", _sessionId);
    NSURL *postCommentRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/new-comment.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *postCommentRequest = [NSMutableURLRequest requestWithURL:postCommentRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [postCommentRequest setHTTPMethod:@"POST"];
    
    NSDictionary *params;
    if (episodeEntity.id) {
        params = @{@"sessionId":_sessionId,
                   @"collectionId": episodeEntity.collectionId,
                   @"episodeId": episodeEntity.id,
                   @"episodeTitle": episodeEntity.title,
                   @"GUID": episodeEntity.guid,
                   @"comment": comment,
                   @"timestamp": timestamp
                   };
    } else {
        params = @{@"sessionId":_sessionId,
                   @"collectionId": episodeEntity.collectionId,
                   @"GUID": episodeEntity.guid,
                   @"episodeUrl": episodeEntity.url,
                   @"episodePubDate": [ISODateFormatter stringFromDate:episodeEntity.pubDate],
                   @"episodeTitle": episodeEntity.title,
                   @"comment": comment,
                   @"timestamp": timestamp
                   };
    }
    
    //JPLog(@"post comment request w/ params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [postCommentRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:postCommentRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    //JPLog(@"post comment response: %@", responseDict);
                    if ([responseDict objectForKey:@"error"]) {
                        // session expired
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self getSessionWithCallback:^{
                                [self postComment:comment atTime:timestamp onEpisode:episodeEntity withCallback:callback];
                            }];
                        }
                        // no podcast record
                        else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                            __unsafe_unretained typeof(self) weakSelf = self;
                            [TungCommonObjects addOrUpdatePodcast:episodeEntity.podcast orEpisode:episodeEntity withCallback:^ {
                                [weakSelf postComment:comment atTime:timestamp onEpisode:episodeEntity withCallback:callback];
                            }];
                        }
                        else {
                            JPLog(@"Error posting comment: %@", [responseDict objectForKey:@"error"]);
                            callback(NO, responseDict);
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //JPLog(@"successfully posted comment: %@", responseDict);
                        if (!episodeEntity.id) {
                            // save episode id and shortlink
                            NSString *episodeId = [responseDict objectForKey:@"episodeId"];
                            NSString *shortlink = [responseDict objectForKey:@"shortlink"];
                            episodeEntity.id = episodeId;
                            episodeEntity.shortlink = shortlink;
                            [TungCommonObjects saveContextWithReason:@"got episode shortlink and id"];
                        }
                        _feedNeedsRefresh = [NSNumber numberWithBool:YES];
                        _profileFeedNeedsRefresh = [NSNumber numberWithBool:YES];
                        callback(YES, responseDict);
                    }
                }
                else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        JPLog(@"Error. HTML: %@", html);
                        callback(NO, @{@"error": @"Unspecified error"});
                    });
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"Error posting comment: %@", error.localizedDescription);
                callback(NO, @{@"error": error.localizedDescription});
            });
        }
    }];
}

- (void) postClipWithComment:(NSString*)comment atTime:(NSString*)timestamp withDuration:(NSString *)duration onEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback  {
    //JPLog(@"post clip request");
    NSURL *postClipRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/new-clip.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *postClipRequest = [NSMutableURLRequest requestWithURL:postClipRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [postClipRequest setHTTPMethod:@"POST"];
    
    NSDictionary *params;
    if (episodeEntity.id) {
        params = @{@"sessionId":_sessionId,
                   @"collectionId": episodeEntity.collectionId,
                   @"episodeId": episodeEntity.id,
                   @"episodeTitle": episodeEntity.title,
                   @"GUID": episodeEntity.guid,
                   @"comment": comment,
                   @"timestamp": timestamp,
                   @"duration": duration
                   };
    } else {
        params = @{@"sessionId":_sessionId,
                   @"collectionId": episodeEntity.collectionId,
                   @"GUID": episodeEntity.guid,
                   @"episodeUrl": episodeEntity.url,
                   @"episodePubDate": [ISODateFormatter stringFromDate:episodeEntity.pubDate],
                   @"episodeTitle": episodeEntity.title,
                   @"comment": comment,
                   @"timestamp": timestamp,
                   @"duration": duration
                   };
    }
    
    // add content type
    NSString *boundary = [TungCommonObjects generateHash];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [postClipRequest addValue:contentType forHTTPHeaderField:@"Content-Type"];
    // add post body
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    // params
    [body appendData:[TungCommonObjects generateBodyFromDictionary:params withBoundary:boundary]];
    
    // clip recording
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"clip\"; filename=\"recording.m4a\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: audio/m4a\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    NSURL *clipFileURL = [TungCommonObjects getClipFileURL];
    NSData *recordingData = [[NSData alloc] initWithContentsOfURL:clipFileURL];
    [body appendData:recordingData];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // end of body
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [postClipRequest setHTTPBody:body];
    // set the content-length
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
    [postClipRequest setValue:postLength forHTTPHeaderField:@"Content-Length"];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];

    [NSURLConnection sendAsynchronousRequest:postClipRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    //JPLog(@"%@", responseDict);
                    if ([responseDict objectForKey:@"error"]) {
                        // session expired
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self getSessionWithCallback:^{
                                [self postClipWithComment:comment atTime:timestamp withDuration:duration onEpisode:episodeEntity withCallback:callback];
                            }];
                        }
                        // no podcast record
                        else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                            __unsafe_unretained typeof(self) weakSelf = self;
                            [TungCommonObjects addOrUpdatePodcast:episodeEntity.podcast orEpisode:episodeEntity withCallback:^ {
                                [weakSelf postClipWithComment:comment atTime:timestamp withDuration:duration onEpisode:episodeEntity withCallback:callback];
                            }];
                        }
                        else {
                            JPLog(@"Error posting clip: %@", [responseDict objectForKey:@"error"]);
                            callback(NO, responseDict);
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //JPLog(@"successfully posted clip: %@", responseDict);
                        if (!episodeEntity.id) {
                            // save episode id and shortlink
                            NSString *episodeId = [responseDict objectForKey:@"episodeId"];
                            NSString *shortlink = [responseDict objectForKey:@"shortlink"];
                            episodeEntity.id = episodeId;
                            episodeEntity.shortlink = shortlink;
                            [TungCommonObjects saveContextWithReason:@"got episode shortlink and id"];
                        }
                        _feedNeedsRefresh = [NSNumber numberWithBool:YES];
                        _profileFeedNeedsRefresh = [NSNumber numberWithBool:YES];
                        callback(YES, responseDict);
                    }
                }
                else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        JPLog(@"Error. HTML: %@", html);
                        callback(NO, @{@"error": @"Unspecified error"});
                    });
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"Error posting clip: %@", error.localizedDescription);
                callback(NO, @{@"error": error.localizedDescription});
            });
        }
    }];
}

- (void) deleteStoryEventWithId:(NSString *)eventId withCallback:(void (^)(BOOL success))callback  {
    //JPLog(@"delete story event with id: %@", eventId);
    NSURL *deleteEventRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/delete-story-event.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *deleteEventRequest = [NSMutableURLRequest requestWithURL:deleteEventRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [deleteEventRequest setHTTPMethod:@"POST"];
    
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"eventId": eventId
                             };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [deleteEventRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:deleteEventRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        // session expired
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self getSessionWithCallback:^{
                                [self deleteStoryEventWithId:eventId withCallback:callback];
                            }];
                        }
                        else {
                            JPLog(@"Error deleting story event: %@", responseDict);
                            [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                            callback(NO);
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //JPLog(@"successfully deleted story event: %@", responseDict);
                        callback(YES);
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                    callback(NO);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"Error deleting story event: %@", error.localizedDescription);
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
                callback(NO);
            });
        }
    }];
}

- (void) flagCommentWithId:(NSString *)eventId {
    //JPLog(@"flag comment with id: %@", eventId);
    NSURL *flagCommentRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/flag.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *flagCommentRequest = [NSMutableURLRequest requestWithURL:flagCommentRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [flagCommentRequest setHTTPMethod:@"POST"];
    
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"eventId": eventId
                             };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [flagCommentRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:flagCommentRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        // session expired
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self getSessionWithCallback:^{
                                [self flagCommentWithId:eventId];
                            }];
                        }
                        else {
                            JPLog(@"Error flagging comment: %@", [responseDict objectForKey:@"error"]);
                            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error flagging" message:[responseDict objectForKey:@"error"] preferredStyle:UIAlertControllerStyleAlert];
                            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                            [_viewController presentViewController:alert animated:YES completion:nil];
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //JPLog(@"successfully flagged comment");
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Successfully flagged" message:@"This comment will be moderated. Thank you for your feedback." preferredStyle:UIAlertControllerStyleAlert];
                        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                        [_viewController presentViewController:alert animated:YES completion:nil];
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"Error flagging comment: %@", error.localizedDescription);
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
            });
        }
    }];
}

// for getting episode and podcast entities
+ (void) requestEpisodeInfoWithDict:(NSDictionary *)dict andCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    //JPLog(@"requesting episode info");
    //NSDate *requestStart = [NSDate date];
    NSURL *episodeInfoURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/episode-info.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *episodeInfoRequest = [NSMutableURLRequest requestWithURL:episodeInfoURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [episodeInfoRequest setHTTPMethod:@"POST"];
    
    //JPLog(@"request for episodeInfo with params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:dict];
    [episodeInfoRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:episodeInfoRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        JPLog(@"(json not nil, error nil) Error requesting episode info: %@", responseDict);
                        callback(NO, responseDict);
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //NSTimeInterval requestDuration = [requestStart timeIntervalSinceNow];
                        //JPLog(@"successfully retrieved episode info in %f seconds", fabs(requestDuration));
                        callback(YES, responseDict);
                    }
                }
                else if (error != nil) {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"(error with json) Error requesting episode info. HTML: %@", html);
                    callback(NO, @{@"error": @"Unspecified error"});
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"(error not nil)Error requesting episode info: %@", error.localizedDescription);
                callback(NO, @{@"error": error.localizedDescription});
            });
        }
    }];
}

// get info for a podcast
+ (void) requestPodcastInfoForCollectionId:(NSString *)collectionId withCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    NSURL *podcastInfoURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/podcast-info.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *podcastInfoRequest = [NSMutableURLRequest requestWithURL:podcastInfoURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [podcastInfoRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{
                              @"collectionId": collectionId
                              };
    JPLog(@"request for podcastInfo with params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [podcastInfoRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:podcastInfoRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        callback(NO, responseDict);
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //NSTimeInterval requestDuration = [requestStart timeIntervalSinceNow];
                        //JPLog(@"successfully retrieved episode info in %f seconds", fabs(requestDuration));
                        callback(YES, responseDict);
                    }
                }
                else if (error != nil) {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error requesting podcast info. HTML: %@", html);
                    callback(NO, @{@"error": @"Unspecified error"});
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"Error requesting podcast info: %@", error.localizedDescription);
                callback(NO, @{@"error": error.localizedDescription});
            });
        }
    }];
}

/*//////////////////////////////////
 Users
 /////////////////////////////////*/


- (void) getProfileDataForUserWithId:(NSString *)target_id orUsername:(NSString *)username withCallback:(void (^)(NSDictionary *jsonData))callback {
    NSURL *getProfileDataRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/profile.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *getProfileDataRequest = [NSMutableURLRequest requestWithURL:getProfileDataRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [getProfileDataRequest setHTTPMethod:@"POST"];
    NSDictionary *params;
    if (_sessionId.length) {
    	params = @{@"sessionId":_sessionId,
                   @"target_user_id": target_id,
                   @"username": username};
    } else {
        params = @{@"tung_id": _loggedInUser.tung_id,
                   @"token": _loggedInUser.token,
                   @"iOS_version": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                   @"target_user_id": target_id,
                   @"username": username};
    }
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [getProfileDataRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:getProfileDataRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            if (jsonData != nil && error == nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self getSessionWithCallback:^{
                                [self getProfileDataForUserWithId:target_id orUsername:username withCallback:callback];
                            }];
                        }
                        else {
                            callback(responseDict);
                        }
                    }
                    else {
                        if ([responseDict objectForKey:@"sessionId"]) {
                            _sessionId = [responseDict objectForKey:@"sessionId"];
                            NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                            if (lastDataChange.doubleValue > _loggedInUser.lastDataChange.doubleValue) {
                                [self restorePodcastDataSinceTime:_loggedInUser.lastDataChange];
                            }
                        }
                        callback(responseDict);
                    }
                });
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"HTML: %@", html);
                });
            }
            
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"Error getting profile: %@", error.localizedDescription);
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
            });
        }
    }];
}


- (void) updateUserWithDictionary:(NSDictionary *)userInfo withCallback:(void (^)(NSDictionary *jsonData))callback {
    //JPLog(@"update user with dictionary: %@", userInfo);
    
    NSURL *updateUserRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/update-user.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *updateUserRequest = [NSMutableURLRequest requestWithURL:updateUserRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [updateUserRequest setHTTPMethod:@"POST"];
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:userInfo];
    [params setObject:_sessionId forKey:@"sessionId"];
    
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [updateUserRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:updateUserRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self getSessionWithCallback:^{
                                [self updateUserWithDictionary:userInfo withCallback:^(NSDictionary *responseDict) {
                                    callback(responseDict);
                                }];
                            }];
                        } else {
                            callback(responseDict); 
                        }
                    }
                    else {
                        //JPLog(@"user updated successfully: %@", responseDict);
                        callback(responseDict);
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error updating user: HTML: %@", html);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"Error updating user: %@", error.localizedDescription);
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
            });
        }
    }];
}

- (void) followUserWithId:(NSString *)target_id withCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    //NSLog(@"follow user with id: %@", target_id);
    NSURL *followUserRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/follow.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *followUserRequest = [NSMutableURLRequest requestWithURL:followUserRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [followUserRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"target_user_id": target_id};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [followUserRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:followUserRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    //NSLog(@"follow user response: %@", responseDict);
                    if ([responseDict objectForKey:@"error"]) {
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            [self getSessionWithCallback:^{
                                [self followUserWithId:target_id withCallback:^(BOOL success, NSDictionary *response) {
                                    callback(success, response);
                                }];
                            }];
                        } else {
                            callback(NO, responseDict);
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //JPLog(@"follow result: %@", responseDict);
                        callback(YES, responseDict);
                    } else {
                        callback(NO, responseDict);
                    }
                }
                else {
                    callback(NO, @{@"error": error.localizedDescription });
                    JPLog(@"Error following user: %@", error.localizedDescription);
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"HTML: %@", html);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"Error following user: %@", error.localizedDescription);
                callback(NO, @{@"error": error.localizedDescription });
            });
        }
    }];
    
}
- (void) unfollowUserWithId:(NSString *)target_id withCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    //NSLog(@"UN-follow user with id: %@", target_id);
    NSURL *unfollowUserRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/unfollow.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *unfollowUserRequest = [NSMutableURLRequest requestWithURL:unfollowUserRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [unfollowUserRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"target_user_id": target_id};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [unfollowUserRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:unfollowUserRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    //NSLog(@"unfollow request response: %@", responseDict);
                    if ([responseDict objectForKey:@"error"]) {
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            [self getSessionWithCallback:^{
                                [self unfollowUserWithId:target_id withCallback:^(BOOL success, NSDictionary *response) {
                                    callback(success, response);
                                }];
                            }];
                        } else {
                            callback(NO, responseDict);
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //JPLog(@"UN-follow result: %@", responseDict);
                        callback(YES, responseDict);
                    } else {
                        callback(NO, responseDict);
                    }
                }
                else {
                    callback(NO, @{@"error": error.localizedDescription });
                    JPLog(@"Error following user: %@", error.localizedDescription);
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"HTML: %@", html);
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"Error un-following user: %@", error.localizedDescription);
                callback(NO, @{@"error": error.localizedDescription });
            });
        }
    }];
}

// get suggested users and optionally bust cached result
- (void) getSuggestedUsersWithCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    NSURL *suggestedUsersURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/suggested-users.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *suggestedUsersRequest = [NSMutableURLRequest requestWithURL:suggestedUsersURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0f];
    
    if (_sessionId && _sessionId.length) {
        [suggestedUsersRequest setHTTPMethod:@"POST"];
        NSDictionary *params = @{@"sessionId":_sessionId};
        NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
        [suggestedUsersRequest setHTTPBody:serializedParams];
    }
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:suggestedUsersRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            
            if (jsonData != nil && error == nil) {
                
                NSDictionary *responseDict = jsonData;
                //NSLog(@"suggested users response: %@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            [self getSessionWithCallback:^{
                                [self getSuggestedUsersWithCallback:callback];
                            }];
                        } else {
                            callback(NO, responseDict);
                        }
                    });
                }
                else if ([responseDict objectForKey:@"success"]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        callback(YES, responseDict);
                        
                    });
                }
            }
            // errors
            else if (error != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    JPLog(@"Error getting suggested users: %@", error);
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"HTML: %@", html);
                    callback(NO, @{@"error": error});
                });
            }
        }
        // connection error
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(NO, @{@"error": error.localizedDescription});
            });
        }
    }];
}

- (void) preloadAlbumArtForSuggestedUsers:(NSArray *)suggestedUsers {
    
    NSOperationQueue *preloadQueue = [[NSOperationQueue alloc] init];
    preloadQueue.maxConcurrentOperationCount = 3;
    
    for (int i = 0; i < suggestedUsers.count; i++) {
        
        NSArray *podcasts = [[suggestedUsers objectAtIndex:i] objectForKey:@"podcasts"];
        
        for (int j = 0; j < podcasts.count; j++) {
            
            // preload avatar and album art
            [preloadQueue addOperationWithBlock:^{
                
                NSString *podcastArtUrlString = [[podcasts objectAtIndex:j] objectForKey:@"artworkUrlSSL_sm"];
                [TungCommonObjects retrieveDefaultSizePodcastArtDataWithUrlString:podcastArtUrlString];
            }];
        }
    }
}

- (void) inviteFriends:(NSString *)friends {
    JPLog(@"send invite friends request");
    NSURL *inviteFriendsRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/invite-friends.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *inviteFriendsRequest = [NSMutableURLRequest requestWithURL:inviteFriendsRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [inviteFriendsRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId": _sessionId,
                             @"friends": friends
                             };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [inviteFriendsRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:inviteFriendsRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                            // get new session and re-request
                            JPLog(@"SESSION EXPIRED");
                            [self getSessionWithCallback:^{
                                [self inviteFriends:friends];
                            }];
                        } else {
                            JPLog(@"Error inviting friends: %@", [responseDict objectForKey:@"error"]);
                            [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                        }
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        JPLog(@"Successfully invited friends: %@", responseDict);
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error: %@", html);
                    [TungCommonObjects simpleErrorAlertWithMessage:@"Sorry, something went wrong with your request"];
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                JPLog(@"Error inviting friends: %@", error.localizedDescription);
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
            });
        }
    }];
}

- (void) removeSignedInUserData {
    [TungCommonObjects removePodcastAndEpisodeData];
    [TungCommonObjects deleteAllCachedEpisodes];
    [TungCommonObjects deleteCachedData];
    [TungCommonObjects deleteAllSavedEpisodes];
    
    // session
    _loggedInUser.tung_id = @"";
    _loggedInUser.token = @"";
    _sessionId = @"";
    
}

- (void) resetPlayerAndQueue {
    
    [self playerPause];
    [self resetPlayer];
    [_syncProgressTimer invalidate];
    _playQueue = [@[] mutableCopy];
    _npEpisodeEntity = nil;
    NSNotification *nowPlayingDidChangeNotif = [NSNotification notificationWithName:@"nowPlayingDidChange" object:nil userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotification:nowPlayingDidChangeNotif];
}

-(void) signOut {
    JPLog(@"--- signing out");
    
    [self resetPlayerAndQueue];
    
    _loggedInUser = nil;
    [TungCommonObjects removeAllUserData];
    
    [self removeSignedInUserData];
    
    // twitter
    [[Twitter sharedInstance] logOut];
    
    // close FB session if open
    if ([FBSDKAccessToken currentAccessToken]) {
    	[[FBSDKLoginManager new] logOut];
    }
    
    // settings
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    SettingsEntity *settings = [TungCommonObjects settings];
    settings.numPodcastNotifications = [NSNumber numberWithInt:0];
    settings.numProfileNotifications = [NSNumber numberWithInt:0];
    [TungCommonObjects saveContextWithReason:@"reset settings"];

    // since this method can get called by dismissing an unauthorized alert
    // make sure _viewController property is set for VCs that call signOut
    UIViewController *welcome = [_viewController.navigationController.storyboard instantiateViewControllerWithIdentifier:@"welcome"];
    [_viewController presentViewController:welcome animated:YES completion:^{}];
}

#pragma mark - Media Library / Auto-import

- (void) promptAndRequestMediaLibraryAccess {
    
    UIAlertController *promptForMediaLibPermission = [UIAlertController alertControllerWithTitle:@"Import podcast subcriptions" message:@"Tung can import your podcast subscriptions from the Apple Podcasts app. Would you like to continue?" preferredStyle:UIAlertControllerStyleAlert];
    [promptForMediaLibPermission addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:nil]];
    [promptForMediaLibPermission addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        CGFloat version = [TungCommonObjects iOSVersionFloat];
        if (version >= 9.3) {
            [MPMediaLibrary requestAuthorization:^(MPMediaLibraryAuthorizationStatus status) {
                switch (status) {
                    case MPMediaLibraryAuthorizationStatusAuthorized:
                        [self queryExistingPodcastSubscriptions];
                        break;
                    default:
                        NSLog(@"Access to media library denied");
                        break;
                }
            }];
        }
        else {
            NSLog(@"did not need permission for media lib");
            [self queryExistingPodcastSubscriptions];
        }

    }]];
    if ([TungCommonObjects iOSVersionFloat] >= 9.0) {
    	promptForMediaLibPermission.preferredAction = [promptForMediaLibPermission.actions objectAtIndex:1];
    }
    [[TungCommonObjects activeViewController] presentViewController:promptForMediaLibPermission animated:YES completion:nil];
    
}

- (void) queryExistingPodcastSubscriptions {
    
    MPMediaQuery *existingSubs = [[MPMediaQuery alloc] init];
    NSNumber *type = [NSNumber numberWithInteger:MPMediaTypePodcast];
    MPMediaPropertyPredicate *podcastPredicate = [MPMediaPropertyPredicate predicateWithValue:type forProperty:MPMediaItemPropertyMediaType];
    [existingSubs addFilterPredicate:podcastPredicate];
    NSArray *pods = [existingSubs items];
    //NSLog(@"queried existing podcasts, found %lu", (unsigned long)pods.count);
    
    NSMutableArray *uniqueTitles = [NSMutableArray array];
    for (MPMediaItem *pod in pods) {
        if ([MPMediaItem canFilterByProperty:MPMediaItemPropertyPodcastPersistentID]) {
            NSString *collectionName = [pod valueForProperty:MPMediaItemPropertyPodcastTitle];
            if (![uniqueTitles containsObject:collectionName]) {
                [uniqueTitles addObject:collectionName];
            }
            //NSLog (@"- %@", collectionName);
        }
    }
    if (uniqueTitles.count) {
        [self bulkSubscribeToPodcastsWithTitles:uniqueTitles];
    }
    else {
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"No subscriptions" message:@"It appears you haven't subscribed to any podcasts with the Apple Podcasts app. You can try again any time from Settings." preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [[TungCommonObjects activeViewController] presentViewController:errorAlert animated:YES completion:nil];
    }
}

- (void) bulkSubscribeToPodcastsWithTitles:(NSArray *)titles {
    
    if (_connectionAvailable.boolValue) {
        
        NSURL *bulkSubscribeURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/bulk-subscribe.php", [TungCommonObjects apiRootUrl]]];
        NSMutableURLRequest *bulkSubscribeRequest = [NSMutableURLRequest requestWithURL:bulkSubscribeURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
        [bulkSubscribeRequest setHTTPMethod:@"POST"];
        
        NSDictionary *params = @{@"sessionId":_sessionId,
                                 @"titles": [titles componentsJoinedByString:@"#,#"]
                                 };
        NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
        [bulkSubscribeRequest setHTTPBody:serializedParams];
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [NSURLConnection sendAsynchronousRequest:bulkSubscribeRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
            if (error == nil) {
                id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (jsonData != nil && error == nil) {
                        NSDictionary *responseDict = jsonData;
                        //JPLog(@"%@", responseDict);
                        if ([responseDict objectForKey:@"error"]) {
                            // session expired
                            if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                                // get new session and re-request
                                JPLog(@"SESSION EXPIRED");
                                [self getSessionWithCallback:^{
                                    [self bulkSubscribeToPodcastsWithTitles:titles];
                                }];
                            }
                            else {
                                [TungCommonObjects simpleErrorAlertWithMessage:[responseDict objectForKey:@"error"]];
                            }
                        }
                        // success
                        else if ([responseDict objectForKey:@"success"]) {
                            
                            NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                            _loggedInUser.lastDataChange = lastDataChange;
                            
                            NSArray *notFoundPodcasts = [responseDict objectForKey:@"not-found"];
                            NSArray *podcasts = [responseDict objectForKey:@"podcasts"];
                            NSMutableString *alertMessage = [NSMutableString string];
                            NSMutableArray *alreadySubscribed = [NSMutableArray array];
                            NSInteger importCount = 0;
                            NSInteger maxTitleLength = 33;
                            
                            NSOperationQueue *fetchingQueue = [[NSOperationQueue alloc] init];
                            fetchingQueue.maxConcurrentOperationCount = 3;
                            
                            // podcasts found
                            for (int i = 0; i < podcasts.count; i++) {
                                
                                NSDictionary *podDict = [podcasts objectAtIndex:i];
                                PodcastEntity *podEntity = [TungCommonObjects getEntityForPodcast:podDict save:NO];
                                
                                [fetchingQueue addOperationWithBlock:^{
                                    [TungPodcast retrieveAndCacheFeedForPodcastEntity:podEntity forceNewest:NO reachable:_connectionAvailable.boolValue];
                                }];
                                
                                NSString *titleForAlert = [TungCommonObjects truncateStringWithEllipsis:podEntity.collectionName toLength:maxTitleLength];
                                // already subscribed?
                                if (podEntity.isSubscribed.boolValue) {
                                    [alreadySubscribed addObject:titleForAlert];
                                }
                                else {
                                    podEntity.isSubscribed = [NSNumber numberWithBool:YES];
                                    podEntity.timeSubscribed = lastDataChange;
                                    [alertMessage appendFormat:@"- %@\n", titleForAlert];
                                    importCount++;
                                }
                            }
                            // title
                            NSString *alertTitle;
                            if (importCount > 0) {
                                NSString *podcastPlural = (importCount == 1) ? @"podcast" : @"podcasts";
                                alertTitle = [NSString stringWithFormat:@"Successfully imported %ld %@", (long)importCount, podcastPlural];
                            }
                            else {
                                alertTitle = @"No podcasts were imported";
                            }
                            // list already subscribed
                            if (alreadySubscribed.count) {
                                [alertMessage appendString:@"\nAlready subscribed:\n"];
                                for (int i = 0; i < alreadySubscribed.count; i++) {
                                    [alertMessage appendFormat:@"- %@\n", [alreadySubscribed objectAtIndex:i]];
                                }
                            }
                            // list not found
                            if (notFoundPodcasts.count) {
                                [alertMessage appendString:@"\nNot found:\n"];
                                for (int i = 0; i < notFoundPodcasts.count; i++) {
                                    NSString *titleForAlert = [TungCommonObjects truncateStringWithEllipsis:[notFoundPodcasts objectAtIndex:i] toLength:maxTitleLength];
                                    [alertMessage appendFormat:@"- %@\n", titleForAlert];
                                }
                                [alertMessage appendString:@"You can add these any time by searching them."];
                            }
                            // save
                            [TungCommonObjects saveContextWithReason:@"lastDataChange changed for logged in user, bulk subscribed"];
                            
                            // alert results
                            UIAlertController *resultsAlert = [UIAlertController alertControllerWithTitle:alertTitle message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
                            [resultsAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                            [[TungCommonObjects activeViewController] presentViewController:resultsAlert animated:YES completion:nil];
                            
                            NSNotification *subscribeChangeNotif = [NSNotification notificationWithName:@"refreshSubscribeStatus" object:nil userInfo:nil];
                            [[NSNotificationCenter defaultCenter] postNotification:subscribeChangeNotif];
                        }
                    }
                    else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                            JPLog(@"Error. HTML: %@", html);
                            [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
                        });
                    }
                });
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
                });
            }
        }];
        
    } else {
        [TungCommonObjects showNoConnectionAlert];
    }
}

#pragma mark - Twitter

- (void) verifyCredWithTwitterOauthHeaders:(NSDictionary *)headers withCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    
    NSURL *verifyCredRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@app/twitter-signin.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *verifyCredRequest = [NSMutableURLRequest requestWithURL:verifyCredRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [verifyCredRequest setHTTPMethod:@"POST"];
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:headers];
    [params setObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] forKey:@"iOS_version"];
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [verifyCredRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:verifyCredRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    //JPLog(@"Verify cred response %@", responseDict);
                    
                    if ([responseDict objectForKey:@"error"]) {
                        JPLog(@"Error verifying cred with Twitter: %@", [responseDict objectForKey:@"error"]);
                        callback(NO, responseDict);
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        callback(YES, responseDict);
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                    callback(NO, @{@"error": html});
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
            	[TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
            });
        }
    }];
}

- (void) findTwitterFriendsWithPage:(NSNumber *)page andCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    
    // get auth headers for friends/ids endpoint:
    TWTROAuthSigning *oauthSigning = [[TWTROAuthSigning alloc] initWithAuthConfig:[Twitter sharedInstance].authConfig authSession:[Twitter sharedInstance].session];
    NSString *username = [Twitter sharedInstance].session.userName;
    NSString *endpoint = @"https://api.twitter.com/1.1/friends/ids.json";
    NSDictionary *parameters = @{
                                 @"cursor": @"-1",
                                 @"screen_name": username,
                                 @"count": @"5000",
                                 @"stringify_ids": @"true"
                                 };
    NSError *error;
    NSDictionary *authHeaders = [oauthSigning OAuthEchoHeadersForRequestMethod:@"GET" URLString:endpoint parameters:parameters error:&error];
    NSURL *findFriendsRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/find-twitter-friends.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *findFriendsRequest = [NSMutableURLRequest requestWithURL:findFriendsRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [findFriendsRequest setHTTPMethod:@"POST"];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:authHeaders];
    [params setObject:page forKey:@"page"];
    [params setObject:username forKey:@"screen_name"];
    if (_sessionId && _sessionId.length) {
        [params setObject:_sessionId forKey:@"sessionId"];
    }
    
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [findFriendsRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:findFriendsRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    //NSLog(@"find twitter friends response %@", responseDict);
                    
                    if ([responseDict objectForKey:@"error"]) {
                        JPLog(@"Error finding twitter friends (%@): %@", [responseDict objectForKey:@"twitterStatusCode"], [responseDict objectForKey:@"error"]);
                        //NSLog(@"responseDict: %@", responseDict);
                        callback(NO, responseDict);
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        callback(YES, responseDict);
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                    callback(NO, @{@"error": html});
                }
            });
        }
        else {
            JPLog(@"Error finding twitter friends: %@", error.localizedDescription);
            callback(NO, @{@"error": error.localizedDescription});
        }
    }];
}

// post tweet
- (void) postTweetWithText:(NSString *)text andUrl:(NSString *)url {
    
    NSString *tweet = [NSString stringWithFormat:@"%@ %@", text, url];
    
    //TWTRSession *session = [TWTRSessionStore session];
    NSString *twitterID = [Twitter sharedInstance].sessionStore.session.userID;
    TWTRAPIClient *client = [[TWTRAPIClient alloc] initWithUserID:twitterID];
    
    NSString *updateStatusEndpoint = @"https://api.twitter.com/1.1/statuses/update.json";
    NSDictionary *tweetParams = @{@"status": tweet};
    NSError *clientError;
    
    NSURLRequest *request = [client URLRequestWithMethod:@"POST" URL:updateStatusEndpoint parameters:tweetParams error:&clientError];
    
    if (request) {
        [client sendTwitterRequest:request completion:^(NSURLResponse *urlResponse, NSData *data, NSError *connectionError) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)urlResponse;
            long responseCode =  (long)[httpResponse statusCode];
            
            //JPLog(@"Twitter HTTP response: %li", responseCode);
            if (responseCode != 200 || connectionError != nil) {
                JPLog(@"post tweet error (%li): %@", responseCode, connectionError);
            }
        }];
    }
    else {
        JPLog(@"post tweet error: %@", clientError);
    }
    
}

#pragma mark - Facebook

- (void) postToFacebookWithText:(NSString *)text Link:(NSString *)link andEpisode:(EpisodeEntity *)episodeEntity {
    
    // status message
    NSDictionary *params = @{@"message": text,
                             @"link": link
                             };
    /* make the API call */
    FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc]
                                  initWithGraphPath:@"/me/feed"
                                  parameters:params
                                  HTTPMethod:@"POST"];
    [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
        // Handle the result
        JPLog(@"facebook share result: %@", result);
    }];
    
}

- (void) verifyCredWithFacebookAccessToken:(NSString *)token withCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    
    NSURL *verifyCredRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@app/facebook-signin.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *verifyCredRequest = [NSMutableURLRequest requestWithURL:verifyCredRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [verifyCredRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{ @"accessToken": token,
                              @"iOS_version": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [verifyCredRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:verifyCredRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    //JPLog(@"Verify cred response %@", responseDict);
                    if ([responseDict objectForKey:@"error"]) {
                        JPLog(@"Error verifying cred with FB: %@", [responseDict objectForKey:@"error"]);
                        
                        callback(NO, responseDict);
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        callback(YES, responseDict);
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                    callback(NO, @{@"error": html});
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
            });
        }
    }];
}

- (void) findFacebookFriendsWithFacebookAccessToken:(NSString *)token withCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    
    NSURL *findFriendsRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/find-facebook-friends.php", [TungCommonObjects apiRootUrl]]];
    NSMutableURLRequest *findFriendsRequest = [NSMutableURLRequest requestWithURL:findFriendsRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [findFriendsRequest setHTTPMethod:@"POST"];
    NSMutableDictionary *params = [@{ @"accessToken": token } mutableCopy];
    if (_sessionId && _sessionId.length) {
        [params setObject:_sessionId forKey:@"sessionId"];
    }
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [findFriendsRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:findFriendsRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (jsonData != nil && error == nil) {
                    NSDictionary *responseDict = jsonData;
                    if ([responseDict objectForKey:@"error"]) {
                        JPLog(@"Error verifying cred with FB: %@", [responseDict objectForKey:@"error"]);
                        callback(NO, responseDict);
                    }
                    else if ([responseDict objectForKey:@"success"]) {
                        //NSLog(@"find facebook friends response: %@", responseDict);
                        callback(YES, responseDict);
                    }
                }
                else {
                    NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    JPLog(@"Error. HTML: %@", html);
                    callback(NO, @{@"error": html});
                }
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [TungCommonObjects simpleErrorAlertWithMessage:error.localizedDescription];
            });
        }
    }];
}

- (void) getFacebookFriendsListPermissionsWithSuccessCallback:(void (^)(void))successCallback {
    FBSDKLoginManager *loginManager = [[FBSDKLoginManager alloc] init];
    [loginManager logInWithReadPermissions:@[@"user_friends"] fromViewController:_viewController handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if (error) {
            NSString *alertText = [NSString stringWithFormat:@"\"%@\"", error];
            UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Facebook error" message:alertText preferredStyle:UIAlertControllerStyleAlert];
            [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [_viewController presentViewController:errorAlert animated:YES completion:nil];
        }
        else if (result.isCancelled) {
            NSString *alertTitle = @"You denied permission";
            NSString *alertText = @"Tung cannot find your Facebook friends because it was denied permission";
            UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:alertTitle message:alertText preferredStyle:UIAlertControllerStyleAlert];
            [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [_viewController presentViewController:errorAlert animated:YES completion:nil];
        }
        else {
            successCallback();
        }
    }];
}

- (void) sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary *)results {
    
    //NSLog(@"successfully shared story to FB. results: %@", results);
}

- (void) sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error {
    
    JPLog(@"failed to share to FB. Error: %@", error);
}

- (void) sharerDidCancel:(id<FBSDKSharing>)sharer {
    
    //NSLog(@"FB sharing cancelled");
    
}

#pragma mark - Alerts

- (void) promptForNotificationsForEpisodes {

    UIAlertController *notifPermissionAlert = [UIAlertController alertControllerWithTitle:@"New episodes" message:@"Tung can notify you when new episodes are released for podcasts you subscribe to, based on your preference for each podcast. Would you like to receive notifications?" preferredStyle:UIAlertControllerStyleAlert];
    [notifPermissionAlert addAction:[UIAlertAction actionWithTitle:@"Don’t ask again" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        SettingsEntity *settings = [TungCommonObjects settings];
        settings.hasSeenNewEpisodesPrompt = [NSNumber numberWithBool:YES];
        [TungCommonObjects saveContextWithReason:@"settings changed"];
    }]];
    [notifPermissionAlert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:nil]];
    [notifPermissionAlert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        SettingsEntity *settings = [TungCommonObjects settings];
        settings.hasSeenNewEpisodesPrompt = [NSNumber numberWithBool:YES];
        [TungCommonObjects saveContextWithReason:@"settings changed"];
        
        [[UIApplication sharedApplication] registerForRemoteNotifications];
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeBadge categories:nil]];
    }]];
    if ([TungCommonObjects iOSVersionFloat] >= 9.0) {
    	notifPermissionAlert.preferredAction = [notifPermissionAlert.actions objectAtIndex:2];
    }
    [_viewController presentViewController:notifPermissionAlert animated:YES completion:nil];
}

- (void) promptForNotificationsForMentions {
    
    UIAlertController *notifPermissionAlert = [UIAlertController alertControllerWithTitle:@"User mentions" message:@"Tung can notify you when someone mentions you in a comment, or when new episodes are released for podcasts you subscribe to. Would you like to receive notifications?" preferredStyle:UIAlertControllerStyleAlert];
    [notifPermissionAlert addAction:[UIAlertAction actionWithTitle:@"Don’t ask again" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        SettingsEntity *settings = [TungCommonObjects settings];
        settings.hasSeenMentionsPrompt = [NSNumber numberWithBool:YES];
        [TungCommonObjects saveContextWithReason:@"settings changed"];
    }]];
    [notifPermissionAlert addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:nil]];
    [notifPermissionAlert addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        SettingsEntity *settings = [TungCommonObjects settings];
        settings.hasSeenMentionsPrompt = [NSNumber numberWithBool:YES];
        [TungCommonObjects saveContextWithReason:@"settings changed"];
        
        [[UIApplication sharedApplication] registerForRemoteNotifications];
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeBadge categories:nil]];
    }]];
    if ([TungCommonObjects iOSVersionFloat] >= 9.0) {
    	notifPermissionAlert.preferredAction = [notifPermissionAlert.actions objectAtIndex:2];
    }
    [_viewController presentViewController:notifPermissionAlert animated:YES completion:nil];
}

+ (void) showConnectionErrorAlertForError:(NSError *)error {
    
    //JPLog(@"show connection error: \n%@",[NSThread callStackSymbols]);
    UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Connection error" message:[error localizedDescription] preferredStyle:UIAlertControllerStyleAlert];
    [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [[TungCommonObjects activeViewController] presentViewController:errorAlert animated:YES completion:nil];
    
}

+ (void) showNoConnectionAlert {
    UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"No connection" message:@"Please try again when you're connected to the internet." preferredStyle:UIAlertControllerStyleAlert];
    [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [[TungCommonObjects activeViewController] presentViewController:errorAlert animated:YES completion:nil];
}

+ (void) simpleErrorAlertWithMessage:(NSString *)message {
    NSArray *emojis = @[@"😵", @"😭", @"😯", @"😤", @"🤔", @"😐", @"😣", @"🙄", @"😬", @"😢", @"🤕", @"💩"];
    int count = (int) emojis.count;
    int i = (int)arc4random_uniform(count);
    NSString *alertTitle = [NSString stringWithFormat:@"Error %@", [emojis objectAtIndex:i]];
    UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:alertTitle message:message preferredStyle:UIAlertControllerStyleAlert];
    [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [[TungCommonObjects activeViewController] presentViewController:errorAlert animated:YES completion:nil];
}

+ (void) showBannerAlertForText:(NSString *)text {
    
    BannerAlert *bannerAlertView = [[BannerAlert alloc] init];
    [bannerAlertView sizeBannerAndSetText:text forWidth:[self screenSize].width];
    //KLCPopupLayout layout = KLCPopupLayoutMake(KLCPopupHorizontalLayoutCenter, KLCPopupVerticalLayoutBottom);
    KLCPopup *bannerAlert = [KLCPopup popupWithContentView:bannerAlertView
                                                  showType:KLCPopupShowTypeFadeIn
                                               dismissType:KLCPopupDismissTypeFadeOut
                                                  maskType:KLCPopupMaskTypeDimmed
                                  dismissOnBackgroundTouch:NO
                                     dismissOnContentTouch:NO];
    //[bannerAlert showWithLayout:layout duration:3];
    [bannerAlert showWithDuration:3];
}

+ (void) showNoAudioAlert {
    UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"No audio attached" message:@"This item does not contain audio." preferredStyle:UIAlertControllerStyleAlert];
    [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [[TungCommonObjects activeViewController] presentViewController:errorAlert animated:YES completion:nil];
}

#pragma mark - Caching

// AVATARS

+ (NSData*) retrieveLargeAvatarDataWithUrlString:(NSString *)urlString {
    
    NSString *largeAvatarsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"largeAvatars"];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:largeAvatarsDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        // large avatars use the user's Mongo ID as the filename in a pseudo "large" directory
        NSString *filename = [urlString lastPathComponent];
        NSString *filepath = [largeAvatarsDir stringByAppendingPathComponent:filename];
        NSData *imageData;
        if ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
            imageData = [NSData dataWithContentsOfFile:filepath];
        } else {
            imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString: urlString]];
            [imageData writeToFile:filepath atomically:YES];
        }
        return imageData;
    }
    return nil;
}

+ (void) replaceCachedLargeAvatarWithDataAtUrlString:(NSString *)urlString {
    
    NSString *largeAvatarsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"largeAvatars"];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:largeAvatarsDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        // large avatars use the user's Mongo ID as the filename in a pseudo "large" directory
        NSString *filename = [urlString lastPathComponent];
        NSString *filepath = [largeAvatarsDir stringByAppendingPathComponent:filename];
        // delete old
        if ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
            [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
        }
        // save new
        NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString: urlString]];
        [imageData writeToFile:filepath atomically:YES];
        
    }
}


+ (NSData*) retrieveSmallAvatarDataWithUrlString:(NSString *)urlString {
    
    NSString *smallAvatarsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"smallAvatars"];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:smallAvatarsDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        // small avatars use the user's Mongo ID as the filename in a pseudo "small" directory
        NSString *filename = [urlString lastPathComponent];
        NSString *filepath = [smallAvatarsDir stringByAppendingPathComponent:filename];
        NSData *imageData;
        if ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
            imageData = [NSData dataWithContentsOfFile:filepath];
        } else {
            imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString: urlString]];
            [imageData writeToFile:filepath atomically:YES];
        }
        return imageData;
    }
    return nil;
}

+ (void) replaceCachedSmallAvatarWithDataAtUrlString:(NSString *)urlString {
    
    NSString *smallAvatarsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"smallAvatars"];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:smallAvatarsDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        // small avatars use the user's Mongo ID as the filename in a pseudo "small" directory
        NSString *filename = [urlString lastPathComponent];
        NSString *filepath = [smallAvatarsDir stringByAppendingPathComponent:filename];
		// delete old
        if ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
            [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
        }
        // save new
        NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString: urlString]];
        [imageData writeToFile:filepath atomically:YES];

    }
}

// CLIPS

+ (NSData*) retrieveAudioClipDataWithUrlString:(NSString *)urlString {
    
    NSString *audioClipsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"audioClips"];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:audioClipsDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        // clips use the Mongo clip ID as the filename
        NSString *filename = [urlString lastPathComponent];
        NSString *filepath = [audioClipsDir stringByAppendingPathComponent:filename];
        NSData *audioData;
        if ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
            audioData = [NSData dataWithContentsOfFile:filepath];
        } else {
            audioData = [NSData dataWithContentsOfURL:[NSURL URLWithString: urlString]];
            [audioData writeToFile:filepath atomically:YES];
        }
        return audioData;
    }
    return nil;
}

// PODCAST ART

+ (NSString *) getCachedPodcastArtDirectoryPathForDefaultSize:(BOOL)small {
    
    NSString *folderName = (small) ? @"podcastArtSmall" : @"podcastArt";
    NSString *podcastArtDir = [NSTemporaryDirectory() stringByAppendingPathComponent:folderName];
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:podcastArtDir withIntermediateDirectories:YES attributes:nil error:&error];
    return podcastArtDir;
    
}

+ (NSString *) getSavedPodcastArtDirectoryPathForDefaultSize:(BOOL)small {
    
    NSString *folderName = (small) ? @"podcastArtSmall" : @"podcastArt";
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *folders = [fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
    NSURL *libraryDir = [folders objectAtIndex:0];
    NSError *error;
    BOOL success = [libraryDir setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:&error];
    if (success) {
        NSString *savedArtDir = [libraryDir.path stringByAppendingPathComponent:folderName];
        NSError *error;
        [fileManager createDirectoryAtPath:savedArtDir withIntermediateDirectories:YES attributes:nil error:&error];
        return savedArtDir;
    }
    else {
        JPLog(@"error making folder excluded from backup: %@", error.localizedDescription);
        return nil;
    }
}

// art is saved for downloaded and subscribed podcasts, to ensure offline availability
+ (BOOL) savePodcastArtForEntity:(PodcastEntity *)podcastEntity {
    NSString *urlString = (podcastEntity.artworkUrlSSL_sm && podcastEntity.artworkUrlSSL_sm.length) ? podcastEntity.artworkUrlSSL_sm : podcastEntity.artworkUrl;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *extension = [[urlString lastPathComponent] pathExtension];
    if (!extension) extension = @"jpg";
    NSString *artFilename = [NSString stringWithFormat:@"%@.%@", podcastEntity.collectionId, extension];
    
    NSString *artFilepath = [[self getCachedPodcastArtDirectoryPathForDefaultSize:YES] stringByAppendingPathComponent:artFilename];
    NSString *savedArtPath = [[self getSavedPodcastArtDirectoryPathForDefaultSize:YES] stringByAppendingPathComponent:artFilename];
    NSError *error;
    
    if ([fileManager fileExistsAtPath:artFilepath]) {
        if ([fileManager fileExistsAtPath:savedArtPath]) [fileManager removeItemAtPath:savedArtPath error:&error];
        error = nil;
        return [fileManager moveItemAtPath:artFilepath toPath:savedArtPath error:&error];
    }
    else {
        NSData *artImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlString]];
        return [artImageData writeToFile:savedArtPath atomically:YES];
    }
}

+ (BOOL) unsavePodcastArtForEntity:(PodcastEntity *)podcastEntity {
    NSString *urlString = (podcastEntity.artworkUrlSSL_sm && podcastEntity.artworkUrlSSL_sm.length) ? podcastEntity.artworkUrlSSL_sm : podcastEntity.artworkUrl;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *extension = [[urlString lastPathComponent] pathExtension];
    if (!extension) extension = @"jpg";
    NSString *artFilename = [NSString stringWithFormat:@"%@.%@", podcastEntity.collectionId, extension];
    
    NSString *artFilepath = [[self getCachedPodcastArtDirectoryPathForDefaultSize:YES] stringByAppendingPathComponent:artFilename];
    NSString *savedArtPath = [[self getSavedPodcastArtDirectoryPathForDefaultSize:YES] stringByAppendingPathComponent:artFilename];
    NSError *error;
    // remove from saved if it's there
    if ([fileManager fileExistsAtPath:savedArtPath]) {
        [fileManager moveItemAtPath:savedArtPath toPath:artFilepath error:&error];
        return YES;
    }
    else {
        return NO;
    
    }
}

// chooses url to pass to retrievePodcastArtDataWithUrlString: andCollectionId: method
+ (NSData *) retrievePodcastArtDataForEntity:(PodcastEntity *)entity defaultSize:(BOOL)small {
    if (entity.artworkUrlSSL || entity.artworkUrlSSL_sm) {
        if (entity.artworkUrlSSL_sm && small) {
            return [self retrievePodcastArtDataWithUrlString:entity.artworkUrlSSL_sm andCollectionId:entity.collectionId defaultSize:small];
        }
        else {
        	//JPLog(@"retrieve art with SSL url: %@", entity.artworkUrlSSL);
        	return [self retrievePodcastArtDataWithUrlString:entity.artworkUrlSSL andCollectionId:entity.collectionId defaultSize:small];
        }
    }
    else if (entity.artworkUrl) {
        //JPLog(@"retrieve art with art url: %@", entity.artworkUrl);
        return [self retrievePodcastArtDataWithUrlString:entity.artworkUrl andCollectionId:entity.collectionId defaultSize:small];
    }
    else {
        //JPLog(@"Error retrieving podcast art: no urls available for entity");
        return [self defaultPodcastArtImageData];
    }
}

/*	For the specific case of needing podcast art but not having a reference 
 	to the podcast entity, but cdn SSL link is guaranteed.
 	DO NOT USE for PodcastViewCtrl header where artworkUrl600 may be
	temporarily stored under entity's artworkUrlSSL property
	because this caches the art under whatever filename is in the url.
	Art should only be cached only under the collectionId
 */
+ (NSData *) retrieveDefaultSizePodcastArtDataWithUrlString:(NSString *)urlString {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *artFilename = [urlString lastPathComponent];
    NSString *artFilepath = [[self getCachedPodcastArtDirectoryPathForDefaultSize:YES] stringByAppendingPathComponent:artFilename];
    // check for cached art data
    NSData *artImageData;
    if ([fileManager fileExistsAtPath:artFilepath]) {
        artImageData = [NSData dataWithContentsOfFile:artFilepath];
    }
    else {
        // look for saved art data
        NSString *savedArtPath = [[self getSavedPodcastArtDirectoryPathForDefaultSize:YES] stringByAppendingPathComponent:artFilename];
        if ([fileManager fileExistsAtPath:savedArtPath]) {
            artImageData = [NSData dataWithContentsOfFile:savedArtPath];
        }
        else {
            // download and cache
            artImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlString]];
            [artImageData writeToFile:artFilepath atomically:YES];
        }
    }
    return artImageData;
}

// for podcast art url from feed, stores SSL (tung CDN) art and feed url art agnostically
+ (NSData*) retrievePodcastArtDataWithUrlString:(NSString *)urlString andCollectionId:(NSNumber *)collectionId defaultSize:(BOOL)small {
    
    if (!urlString || !collectionId) {
        JPLog(@"Cannot retrieve podcast art: Missing url string or collection ID");
        // return default podcast image
        return [self defaultPodcastArtImageData];
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *extension = [[urlString lastPathComponent] pathExtension];
    if (!extension) extension = @"jpg";
    NSString *artFilename = [NSString stringWithFormat:@"%@.%@", collectionId, extension];
    NSString *artFilepath = [[self getCachedPodcastArtDirectoryPathForDefaultSize:small] stringByAppendingPathComponent:artFilename];
    // check for cached art data
    NSData *artImageData;
    if ([fileManager fileExistsAtPath:artFilepath]) {
        //JPLog(@"retrieved podcast art from cache for id: %@", collectionId);
        artImageData = [NSData dataWithContentsOfFile:artFilepath];
    }
    else {
        // look for saved art data
        NSString *savedArtPath = [[self getSavedPodcastArtDirectoryPathForDefaultSize:small] stringByAppendingPathComponent:artFilename];
        if ([fileManager fileExistsAtPath:savedArtPath]) {
            //JPLog(@"retrieved podcast art from saved for id: %@", collectionId);
            artImageData = [NSData dataWithContentsOfFile:savedArtPath];
        }
        else {
            // download and cache
            //JPLog(@"downloaded podcast art for filename: %@ and url string: %@", artFilename, urlString);
            artImageData = [self downloadAndCachePodcastArtForUrlString:urlString andCollectionId:collectionId defaultSize:small];
        }
    }
    return artImageData;
}

// "missing" or default podcast art image
+ (NSData *) defaultPodcastArtImageData {
    NSString *defaultPodcastImagePath = [[NSBundle mainBundle] pathForResource:@"default-podcast-art" ofType:@"jpg"];
    NSData *defaultPodcastImageData = [NSData dataWithContentsOfFile:defaultPodcastImagePath];
    return defaultPodcastImageData;
}

+ (NSData *) downloadAndCachePodcastArtForUrlString:(NSString *)urlString andCollectionId:(NSNumber *)collectionId defaultSize:(BOOL)small {

    NSString *extension = [[urlString lastPathComponent] pathExtension];
    if (!extension) extension = @"jpg";
    NSString *artFilename = [NSString stringWithFormat:@"%@.%@", collectionId, extension];
    NSString *artFilepath = [[self getCachedPodcastArtDirectoryPathForDefaultSize:small] stringByAppendingPathComponent:artFilename];
    NSData *artImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlString]];
    NSError *error;
    if (![artImageData writeToFile:artFilepath options:NSDataWritingAtomic error:&error]) {
        JPLog(@"Error saving image data: %@", error.localizedDescription);
        // return default podcast image
        return [self defaultPodcastArtImageData];
    }
    return artImageData;
}

// scales, sizes, and saves podcast art in jpg format for when artworkUrl changes
+ (NSData *) processPodcastArtForEntity:(PodcastEntity *)entity {
    // size image
    NSData *dataToResize = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:entity.artworkUrl]];
    UIImage *imageToResize = [[UIImage alloc] initWithData:dataToResize];
    NSInteger dimension = DEFAULT_ART_DIMENSION;
    UIImage *resizedImage = [TungCommonObjects image:imageToResize croppedAndScaledToSquareSizeWithDimension:dimension];
    // always use jpg, bc key colors are different for different file types,
    // even if image is same
    NSData *processedImageData = UIImageJPEGRepresentation(resizedImage, 0.9);
    UIImage *artImage = [[UIImage alloc] initWithData:processedImageData];
    NSArray *keyColors = [self determineKeyColorsFromImage:artImage];
    UIColor *keyColor1 = [keyColors objectAtIndex:0];
    UIColor *keyColor2 = [keyColors objectAtIndex:1];
    entity.keyColor1 = keyColor1;
    entity.keyColor2 = keyColor2;
    entity.keyColor1Hex = [self UIColorToHexString:keyColor1];
    entity.keyColor2Hex = [self UIColorToHexString:keyColor2];
    
    [self saveContextWithReason:@"updated podcast art"];
    
    // replace locally
    NSString *artFilename = [NSString stringWithFormat:@"%@.jpg", entity.collectionId];
    NSString *artFilepath = [[self getCachedPodcastArtDirectoryPathForDefaultSize:YES] stringByAppendingPathComponent:artFilename];
    [processedImageData writeToFile:artFilepath atomically:YES];
    
    return processedImageData;
}

/*	replace cached podcast art and update entity's key color properties
	artwork from feed link is processed and uploaded in addOrUpdatePodcast: 
 	method called in this method */
+ (void) replaceCachedPodcastArtForEntity:(PodcastEntity *)entity withNewArt:(NSString *)newArtUrlString {
    
    NSLog(@"replace cached podcast art for entity with new url: %@, and old url: %@", newArtUrlString, entity.artworkUrl);
    // remove old
	BOOL artWasSaved = [self unsavePodcastArtForEntity:entity];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *oldExtension = [[entity.artworkUrl lastPathComponent] pathExtension];
    if (!oldExtension) oldExtension = @"jpg";
    NSString *oldArtFilename = [NSString stringWithFormat:@"%@.%@", entity.collectionId, oldExtension];
    NSString *oldArtFilepath = [[self getCachedPodcastArtDirectoryPathForDefaultSize:YES] stringByAppendingPathComponent:oldArtFilename];
    if ([fileManager fileExistsAtPath:oldArtFilepath]) {
        [fileManager removeItemAtPath:oldArtFilepath error:nil];
    }
    entity.artworkUrl = newArtUrlString;
    
    [self processPodcastArtForEntity:entity];
    
    if (artWasSaved) {
        [self savePodcastArtForEntity:entity];
    }
    
    // notification
    NSDictionary *userInfo = @{ @"collectionId": entity.collectionId };
    NSNotification *newPodcastArtNotif = [NSNotification notificationWithName:@"podcastArtUpdated" object:nil userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:newPodcastArtNotif];

    // replace on server
    [self addOrUpdatePodcast:entity orEpisode:nil withCallback:nil];
}

// used for html markup for podcast description page
+ (NSString *) getPodcastArtPathForEntity:(PodcastEntity *)podcastEntity defaultSize:(BOOL)small {
    
    NSString *urlString;
    if (small && podcastEntity.artworkUrlSSL_sm && podcastEntity.artworkUrlSSL_sm.length) {
        urlString = podcastEntity.artworkUrlSSL_sm;
    }
    else if (!small && podcastEntity.artworkUrlSSL && podcastEntity.artworkUrlSSL.length) {
        urlString = podcastEntity.artworkUrlSSL;
    }
    else {
     	urlString = podcastEntity.artworkUrl;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *extension = [[urlString lastPathComponent] pathExtension];
    if (!extension) extension = @"jpg";
    NSString *artFilename = [NSString stringWithFormat:@"%@.%@", podcastEntity.collectionId, extension];
    NSString *artFilepath = [[self getCachedPodcastArtDirectoryPathForDefaultSize:small] stringByAppendingPathComponent:artFilename];
    // check for cached art data
    if ([fileManager fileExistsAtPath:artFilepath]) {
        return artFilepath;
    }
    else {
        // look for saved art data
        NSString *savedArtPath = [[self getSavedPodcastArtDirectoryPathForDefaultSize:small] stringByAppendingPathComponent:artFilename];
        if ([fileManager fileExistsAtPath:savedArtPath]) {
            return savedArtPath;
        }
        else {
            // download and cache
            NSData *artImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString: urlString]];
            [artImageData writeToFile:artFilepath atomically:YES];
            return artFilepath;
        }
    }
}

+ (NSURL *) getClipFileURL {
    
    NSString *clipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"recording.m4a"];
    return [NSURL fileURLWithPath:clipFilePath];
}

#pragma mark - Keychain

/* keychain functions not used because of bugs that Apple won't/can't fix */

- (void) establishCred {
    NSString *tungCred = [TungCommonObjects getKeychainCred];
    NSArray *components = [tungCred componentsSeparatedByString:@":"];
    _loggedInUser.tung_id = [components objectAtIndex:0];
    _loggedInUser.token = [components objectAtIndex:1];
    //NSLog(@"id: %@", _loggedInUser.tung_id);
    //NSLog(@"token: %@", _loggedInUser.token);
}

// save cred to keychain, set _loggedInUser.tung_id and _loggedInUser.token
- (void) saveKeychainCred: (NSString *)cred {
    
    [TungCommonObjects deleteCredentials];
    
    NSString *account = @"tung credentials";
    NSString *service = [[NSBundle mainBundle] bundleIdentifier];
    
    NSArray *credArray = [cred componentsSeparatedByString:@":"];
    _loggedInUser.tung_id = [credArray objectAtIndex:0];
    _loggedInUser.token = [credArray objectAtIndex:1];
    [CrashlyticsKit setUserIdentifier:_loggedInUser.tung_id];
    
    NSData *valueData = [cred dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *id_security_item = @{
                                       (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
                                       (__bridge id)kSecAttrService : service,
                                       (__bridge id)kSecAttrAccount : account,
                                       (__bridge id)kSecValueData : valueData
                                       };
    CFTypeRef result = NULL;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)id_security_item, &result);
    
    if (status == errSecSuccess) {
        JPLog(@"save cred: successfully stored credentials");
    } else {
        JPLog(@"save cred: failed to store cred with error: %@", [TungCommonObjects keychainStatusToString:status]);
    }
}
// get keychain credentials
+ (NSString *) getKeychainCred {
    //NSLog(@"get keychain cred");
    NSString *key = @"tung credentials";
    NSString *service = [[NSBundle mainBundle] bundleIdentifier];
    NSDictionary *query = @{
                            (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService : service,
                            (__bridge id)kSecAttrAccount : key,
                            (__bridge id)kSecReturnData : (__bridge id)kCFBooleanTrue
                            };
    CFDataRef cfValue = NULL;
    OSStatus results = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&cfValue);
    
    if (results == errSecSuccess) {
        //NSLog(@"credentials found");
        NSString *tungCred = [[NSString alloc] initWithData:(__bridge_transfer NSData *)cfValue encoding:NSUTF8StringEncoding];
        return tungCred;
    } else {
        JPLog(@"No cred found. %@", [self keychainStatusToString:results]);
        CLS_LOG(@"No cred found. %@", [self keychainStatusToString:results]);
        return NULL;
    }
}

+ (void) deleteCredentials {
    
    // delete credentials from keychain
    NSString *account = @"tung credentials";
    NSString *service = [[NSBundle mainBundle] bundleIdentifier];
    
    NSDictionary *deleteQuery = @{
                                  (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
                                  (__bridge id)kSecAttrService : service,
                                  (__bridge id)kSecAttrAccount : account
                                  };
    OSStatus foundExisting = SecItemCopyMatching((__bridge CFDictionaryRef)deleteQuery, NULL);
    if (foundExisting == errSecSuccess) {
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
        if (status == errSecSuccess) {
            JPLog(@"deleted keychain cred");
        } else {
            JPLog(@"failed to delete keychain cred: %@", [self keychainStatusToString:status]);
        }
    } else {
        JPLog(@"failed to delete keychain cred - did not exist");
    }
}

#pragma mark - class methods

+ (void)clearTempDirectory { // used only for debugging
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
    for (NSString *file in tmpDirectory) {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), file] error:NULL];
    }
    NSLog(@"cleared temporary directory");
}

/*
 // always reports no connection
- (void) checkTungReachability {
    // causes long pause
    JPLog(@"checking tung reachability against %@", [TungCommonObjects apiRootUrl]);
    Reachability *tungReachability = [Reachability reachabilityWithHostName:[TungCommonObjects apiRootUrl]];
    NetworkStatus tungStatus = [tungReachability currentReachabilityStatus];
    switch (tungStatus) {
        case NotReachable: {
            JPLog(@"TUNG not reachable");
 			[self showNoConnectionAlert];
            break;
        }
        case ReachableViaWWAN:
            JPLog(@"TUNG reachable via cellular data");
            break;
        case ReachableViaWiFi:
            JPLog(@"TUNG reachable via wifi");
            break;
    }
}
 */
+ (NSString *) generateHash {
    
    NSString *characters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSString *hash = @"";
    
    for (int i = 0; i < 32; i++) {
        int randNum = arc4random() % [characters length];
        NSString *charToAdd = [characters substringWithRange:NSMakeRange(randNum, 1)];
        hash = [hash stringByAppendingString:charToAdd];
    }
    
    return hash;
}

+ (NSData *) generateBodyFromDictionary:(NSDictionary *)dict withBoundary:(NSString *)boundary {
    
    NSMutableData *data = [NSMutableData data];
    for (id key in [dict allKeys]) {
        [data appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
        id val = [dict objectForKey:key];
        if ([val isKindOfClass:[NSString class]]) {
        	NSString *value = val;
        	[self percentEncodeString:value];
        	[data appendData:[[NSString stringWithFormat:@"%@\r\n", value] dataUsingEncoding:NSUTF8StringEncoding]];
        } else {
            [data appendData:[[NSString stringWithFormat:@"%@\r\n", [dict objectForKey:key]] dataUsingEncoding:NSUTF8StringEncoding]];
        }
        [data appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    return data;
}


+ (NSArray *) createEncodedArrayOfParams:(NSDictionary *)params {
    NSMutableArray *paramArray = [[NSMutableArray alloc] init];
    for (id key in [params allKeys]) {
        id val = [params objectForKey:key];
        if ([val isKindOfClass:[NSString class]]) {
            [paramArray addObject:[NSString stringWithFormat:@"%@=%@", key, [self percentEncodeString:val]]];
        } else {
            [paramArray addObject:[NSString stringWithFormat:@"%@=%@", key, [params objectForKey:key]]];
        }
    }
    return paramArray;
}

+ (NSString *) percentEncodeString:(NSString *)string {
    
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL, CFSTR("?=&#"), kCFStringEncodingUTF8));

    /*(NSString *) CFURLCreateStringByAddingPercentEscapes(NULL,
                                            (CFStringRef) string,
                                            NULL,
                                            (CFStringRef) @"!*'();:@&=+$,/?%#[]",
                                            kCFStringEncodingUTF8); */
}

+ (NSData *) serializeParamsForPostRequest:(NSDictionary *)params {
    
    NSArray *paramArray = [self createEncodedArrayOfParams:params];
//    JPLog(@"serialize params for post request:");
//    JPLog(@"%@", paramArray);
    NSString *resultString = [paramArray componentsJoinedByString:@"&"];
    return [resultString dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSString *) serializeParamsForGetRequest:(NSDictionary *)params {
    
    NSArray *paramArray = [self createEncodedArrayOfParams:params];
    return [NSString stringWithFormat:@"?%@", [paramArray componentsJoinedByString:@"&"]];
}

static NSRegularExpression *protocolRgx = nil;
static NSRegularExpression *trailingSlashRgx = nil;

// remove http/https and trailing slash from url
+ (NSString *) cleanURLStringFromString:(NSString*)string {
    
    NSMutableString *mString = [string mutableCopy];
    if (protocolRgx == nil) protocolRgx = [NSRegularExpression regularExpressionWithPattern:@"^https?:\\/\\/" options:0 error:nil];
    [protocolRgx replaceMatchesInString:mString options:0 range:NSMakeRange(0, [mString length]) withTemplate:@""];
    if (trailingSlashRgx == nil) trailingSlashRgx = [NSRegularExpression regularExpressionWithPattern:@"\\/$" options:0 error:nil];
    [trailingSlashRgx replaceMatchesInString:mString options:0 range:NSMakeRange(0, [mString length]) withTemplate:@""];
    return [NSString stringWithString:mString];
}

static NSNumberFormatter *countFormatter = nil;

+ (NSString *) formatNumberForCount:(NSNumber*)count {
    
    if (countFormatter == nil) {
        countFormatter = [[NSNumberFormatter alloc] init];
        countFormatter.usesGroupingSeparator = YES;
        countFormatter.maximumFractionDigits = 1;
    }
    NSString *result;
    if (count.doubleValue > 999999) {
        double simple = count.doubleValue/1000000;
        result = [NSString stringWithFormat:@"%@M", [countFormatter stringFromNumber:[NSNumber numberWithDouble:simple]]];
    }
    else if (count.doubleValue > 9999) {
        double simple = count.doubleValue/1000;
        result = [NSString stringWithFormat:@"%@K", [countFormatter stringFromNumber:[NSNumber numberWithDouble:simple]]];
    }
    else {
        result = [NSString stringWithFormat:@"%@", count];
	}
    return result;

}

static NSNumberFormatter *stringToNum = nil;

+ (NSNumber *) stringToNumber:(NSString *)string {
    if (!stringToNum) stringToNum = [[NSNumberFormatter alloc] init];
    stringToNum.numberStyle = NSNumberFormatterNoStyle;
    return [stringToNum numberFromString:string];
}

+ (NSString *)audioFileStatusToString:(OSStatus)status {
    
    switch (status) {
        case 0:
            return @"Success";
            
        case kAudioFileUnspecifiedError:
            return @"kAudioFileUnspecifiedError";
            
        case kAudioFileUnsupportedFileTypeError:
            return @"kAudioFileUnsupportedFileTypeError";
            
        case kAudioFileUnsupportedDataFormatError:
            return @"kAudioFileUnsupportedDataFormatError";
            
        case kAudioFileUnsupportedPropertyError:
            return @"kAudioFileUnsupportedPropertyError";
            
        case kAudioFileBadPropertySizeError:
            return @"kAudioFileBadPropertySizeError";
            
        case kAudioFilePermissionsError:
            return @"kAudioFilePermissionsError";
            
        case kAudioFileNotOptimizedError:
            return @"kAudioFileNotOptimizedError";
            
        case kAudioFileInvalidChunkError:
            return @"kAudioFileInvalidChunkError";
            
        case kAudioFileDoesNotAllow64BitDataSizeError:
            return @"kAudioFileDoesNotAllow64BitDataSizeError";
            
        case kAudioFileInvalidPacketOffsetError:
            return @"kAudioFileInvalidPacketOffsetError";
            
        case kAudioFileInvalidFileError:
            return @"kAudioFileInvalidFileError";
            
        case kAudioFileOperationNotSupportedError:
            return @"kAudioFileOperationNotSupportedError";
            
        case kAudioFileNotOpenError:
            return @"kAudioFileNotOpenError";
            
        case kAudioFileEndOfFileError:
            return @"kAudioFileEndOfFileError";
            
        case kAudioFilePositionError:
            return @"kAudioFilePositionError";
            
        case kAudioFileFileNotFoundError:
            return @"kAudioFileFileNotFoundError";
            
        default:
            return [NSString stringWithFormat:@"Unknown error: %d", (int)status];
    }
}

+ (NSString *)keychainStatusToString:(OSStatus)status {
    
    switch (status) {
        case 0:
            return @"Success";
        case -4:
            return @"Function or operation not implemented.";
        case -50:
            return @"One or more parameters passed to the function were not valid.";
        case -108:
            return @"Failed to allocate memory.";
        case -2000:
            return @"Username or servicename nil";
        case -25291:
            return @"No trust results are available.";
        case -25293:
            return @"Authorization/Authentication failed.";
        case -25299:
            return @"The item already exists.";
        case -25300:
            return @"The item cannot be found.";
        case -25308:
            return @"Interaction with the Security Server is not allowed.";
        case -26275:
            return @"Unable to decode the provided data.";
        case -34018:
            return @"errSecMissingEntitlement";
        default:
            return [NSString stringWithFormat:@"Unknown error: %d", (int)status];
    }
}

+ (void)fadeInView:(UIView *)view {
    [UIView animateWithDuration:0.2 animations:^{
        view.alpha = 1;
    }];
}
+ (void)fadeOutView:(UIView *)view {
    [UIView animateWithDuration:0.2 animations:^{
        view.alpha = 0;
    }];
}

static NSDateFormatter *shortFormatDateFormatter = nil;
static NSDateFormatter *dayDateFormatter = nil;

+ (NSString *)timeElapsed: (NSString *)secondsString {
    
    double secs = [secondsString doubleValue];
    NSDate *activityDate = [NSDate dateWithTimeIntervalSince1970:secs];
    
    NSString *resultString;
    double ti = [activityDate timeIntervalSinceDate:[NSDate date]];
    ti = ti * -1;
    if (ti < 60) { // less than a minute
        resultString = @"Just now";
    } else if (ti < 3600) { // less than an hour ("32m")
        int diff = round(ti / 60);
        resultString =  [NSString stringWithFormat:@"%dm ago", diff];
    } else if (ti < 86400) { // less than a day ("4h")
        int diff = round(ti / 60 / 60);
        resultString = [NSString stringWithFormat:@"%dh ago", diff];
    } else if (ti < 86400) { // yesterday
        resultString = @"Yesterday";
    } else if (ti < 86400 * 7) { // less than a week ("Fri")
        if (dayDateFormatter == nil) {
            dayDateFormatter = [[NSDateFormatter alloc] init];
            [dayDateFormatter setDateFormat:@"EEE"];
        }
        resultString = [dayDateFormatter stringFromDate:activityDate];
    } else { // further back ("Jul 31")
        if (shortFormatDateFormatter == nil) {
            shortFormatDateFormatter = [[NSDateFormatter alloc] init];
            [shortFormatDateFormatter setDateFormat:@"MMM d"];
        }
        resultString = [shortFormatDateFormatter stringFromDate:activityDate];
    }
    return resultString;
}

+ (NSString*) convertSecondsToTimeString:(CGFloat)totalSeconds {
    
    int intSeconds = (int)roundf(totalSeconds);
    int seconds = intSeconds % 60;
    int minutes = (intSeconds / 60) % 60;
    int hours = intSeconds / 3600;
    return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds];
    
}

+ (double) convertTimestampToSeconds:(NSString *)timestamp {
    
    NSArray *components = [timestamp componentsSeparatedByString:@":"];
    double result = 0;
    if (components.count > 2) {
        NSInteger hours = [[components objectAtIndex:0] integerValue];
        NSInteger minutes = [[components objectAtIndex:1] integerValue];
        NSInteger seconds = [[components objectAtIndex:2] integerValue];
        result = seconds + (minutes * 60) + (hours * 60 * 60);
    }
    else if (components.count > 1) {
        NSInteger minutes = [[components objectAtIndex:0] integerValue];
        NSInteger seconds = [[components objectAtIndex:1] integerValue];
        result = seconds + (minutes * 60);
    }
    else {
        result = [[components objectAtIndex:0] integerValue];
    }
    return result;
}

+ (NSString *) formatDurationFromString:(NSString *)duration {
    
    NSArray *components = [duration componentsSeparatedByString:@":"];
    
    if (components.count == 3) {
        NSNumber *hours = [components objectAtIndex:0];
        NSNumber *minutes = [components objectAtIndex:1];
        NSNumber *seconds = [components objectAtIndex:2];
        
        if (hours.doubleValue == 0 && minutes.doubleValue == 0 && seconds.doubleValue == 0) {
            return @"";
        }
        
        if (hours.integerValue > 0) {
            return duration;
        }
        else if (minutes.integerValue > 0) {
            return [NSString stringWithFormat:@"%ld:%@", (long)minutes.integerValue, [components objectAtIndex:2]];
        }
        else {
            return [NSString stringWithFormat:@"%@ seconds", [components objectAtIndex:2]];
        }
    }
    else if (components.count == 2) {
        NSNumber *minutes = [components objectAtIndex:0];
        NSNumber *seconds = [components objectAtIndex:1];
        if (minutes.doubleValue == 0 && seconds.doubleValue == 0) {
            return @"";
        }
        return [NSString stringWithFormat:@"%ld:%@", (long)minutes.integerValue, [components objectAtIndex:1]];
    }
    else {
        NSNumber *seconds = [components objectAtIndex:0];
        if (seconds.doubleValue > 0) {
            NSString *timestamp = [TungCommonObjects convertSecondsToTimeString:seconds.floatValue];
            return [TungCommonObjects formatDurationFromString:timestamp];
        } else {
            return @"";
        }
    }
}


+ (NSInteger) getIndexOfEpisodeWithGUID:(NSString *)guid inFeed:(NSArray *)feed {
    NSInteger feedIndex = 0;
    for (int i = 0; i < feed.count; i++) {
        NSString *guidAtIndex = [[feed objectAtIndex:i] objectForKey:@"guid"];
        if ([guidAtIndex isEqualToString:guid]) {
            feedIndex = i;
            break;
        }
    }
    return feedIndex;
}

+ (NSNumber *) getAllocatedSizeOfDirectoryAtURL:(NSURL *)directoryURL error:(NSError * __autoreleasing *)error {
    
    NSParameterAssert(directoryURL != nil);
    
    unsigned long long accumulatedSize = 0;
    
    // prefetching some properties during traversal will speed up things a bit.
    NSArray *prefetchedProperties = @[
                                      NSURLIsRegularFileKey,
                                      NSURLFileAllocatedSizeKey,
                                      NSURLTotalFileAllocatedSizeKey,
                                      ];
    
    // The error handler simply signals errors to outside code.
    __block BOOL errorDidOccur = NO;
    BOOL (^errorHandler)(NSURL *, NSError *) = ^(NSURL *url, NSError *localError) {
        if (error != NULL)
            *error = localError;
        errorDidOccur = YES;
        return NO;
    };
    
    // We have to enumerate all directory contents, including subdirectories.
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:directoryURL
                                                             includingPropertiesForKeys:prefetchedProperties
                                                                                options:(NSDirectoryEnumerationOptions)0
                                                                           errorHandler:errorHandler];
    // Start the traversal:
    for (NSURL *contentItemURL in enumerator) {
        
        // Bail out on errors from the errorHandler.
        if (errorDidOccur) return [NSNumber numberWithInt:0];
        // Get the type of this item, making sure we only sum up sizes of regular files.
        NSNumber *isRegularFile;
        if (! [contentItemURL getResourceValue:&isRegularFile forKey:NSURLIsRegularFileKey error:error]) return [NSNumber numberWithInt:0];
        if (! [isRegularFile boolValue]) continue; // Ignore anything except regular files.
        
        // To get the file's size we first try the most comprehensive value in terms of what the file may use on disk.
        // This includes metadata, compression (on file system level) and block size.
        NSNumber *fileSize;
        if (! [contentItemURL getResourceValue:&fileSize forKey:NSURLTotalFileAllocatedSizeKey error:error]) return [NSNumber numberWithInt:0];
        
        // In case the value is unavailable we use the fallback value (excluding meta data and compression)
        // This value should always be available.
        if (fileSize == nil) {
            if (! [contentItemURL getResourceValue:&fileSize forKey:NSURLFileAllocatedSizeKey error:error]) return [NSNumber numberWithInt:0];
        }
        // We're good, add up the value.
        accumulatedSize += [fileSize unsignedLongLongValue];
    }
    
    // Bail out on errors from the errorHandler.
    if (errorDidOccur) return [NSNumber numberWithInt:0];
	
    return [NSNumber numberWithUnsignedLongLong:accumulatedSize];
}

+ (NSString *) formatBytes:(NSNumber *)bytes {
    
    if (bytes.doubleValue == 0) {
        return @"0 MB";
    }
    if (bytes.doubleValue >= 1073741824) {
        double gb = bytes.doubleValue/1073741824;
        return [NSString stringWithFormat:@"%.f GB", gb];
    }
    if (bytes.doubleValue >= 1048576) {
        double mb = bytes.doubleValue/1048576;
        return [NSString stringWithFormat:@"%.f MB", mb];
    }
    if (bytes.doubleValue >= 1024) {
        double kb = bytes.doubleValue/1024;
        return [NSString stringWithFormat:@"%.f KB", kb];
    }
    else {
        return [NSString stringWithFormat:@"%.f bytes", bytes.doubleValue];
    }
}

// image scaling

+ (UIImage *) image:(UIImage *)img scaledToSize:(CGSize)size {
    //create drawing context
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    //draw
    [img drawInRect:CGRectMake(0.0f, 0.0f, size.width, size.height)];
    
    //capture resultant image
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //return image
    return image;
}

+ (UIImage *) image:(UIImage *)img croppedAndScaledToSquareSizeWithDimension:(CGFloat)dimension {
    
    CGSize targetSize = CGSizeMake(dimension, dimension);
    CGFloat widthRatio = targetSize.width  / img.size.width;
    CGFloat heightRatio = targetSize.height / img.size.height;
    CGFloat scaleFactor = MAX(widthRatio, heightRatio);
    CGSize newSize = CGSizeMake(img.size.width  * scaleFactor, img.size.height * scaleFactor);
    UIGraphicsBeginImageContext(targetSize);
    CGPoint origin = CGPointMake((targetSize.width  - newSize.width)  / 2, (targetSize.height - newSize.height) / 2);
    CGRect newRect = {origin, newSize};
    [img drawInRect:newRect];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return scaledImage;
}

+ (NSURL *) addReferrerToUrlString:(NSString *)urlString {
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:urlString];
    if (!components.scheme) {
        components.scheme = @"http://";
    }
    // add referrer
    NSString *referrer = @"ref=tungfm-iOS";
    if (components.query) {
        components.query = [NSString stringWithFormat:@"%@&%@", components.query, referrer];
    } else {
        components.query = referrer;
    }
    //NSLog(@"added ref to url: %@", components.URL);
    return components.URL;
}

+ (NSURL *) urlFromString:(id)urlString {
    
    if ([urlString isKindOfClass:[NSURL class]]) {
        NSURL *url = (NSURL *)urlString;
        return url;
    }
    else {
        NSString *uStr = (NSString *)urlString;
        NSString *encodedUrlString = [uStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSURL *url = [NSURL URLWithString:encodedUrlString];
        return url;
    }
}

+ (NSString *) stringFromUrl:(id)url {
    if ([url isKindOfClass:[NSString class]]) {
        NSString *urlString = (NSString *)url;
        return urlString;
    }
    else {
        NSURL *urlCast = (NSURL *)url;
        return urlCast.absoluteString;
    }
}

+ (NSString *) truncateStringWithEllipsis:(NSString *)string toLength:(NSInteger)length {
    if (string.length > length) {
        return [NSString stringWithFormat:@"%@…", [string substringToIndex:length]];
    }
    else {
        return string;
    }
}

@end
