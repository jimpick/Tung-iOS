//
//  tungCommonObjects.m
//  Tung
//
//  Created by Jamie Perkins on 5/22/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//
/*
 
 Security Keychain Error codes:
 
 0 - No error.
 -4 - Function or operation not implemented.
 -50 - One or more parameters passed to the function were not valid.
 -108 - Failed to allocate memory.
 -2000 - username or servicename nil
 –25291 - No trust results are available.
 –25293 - Authorization/Authentication failed.
 –25299 - The item already exists.
 –25300 - The item cannot be found.
 –25308 - Interaction with the Security Server is not allowed.
 -26275 - Unable to decode the provided data.
 */

#import "TungCommonObjects.h"
//#import "ALDisk.h"
#import "CCColorCube.h"
#import "TungPodcast.h"
#import <CommonCrypto/CommonDigest.h>

#import <MobileCoreServices/MobileCoreServices.h> // for AVURLAsset resource loading

@interface TungCommonObjects()

// Private properties and methods

@property NSArray *currentFeed;

- (void) playQueuedPodcast;
- (void) resetPlayer;

// not used
- (NSString *) getPlayQueuePath;
- (void) savePlayQueue;
- (void) readPlayQueueFromDisk;

@property (nonatomic, strong) NSURLConnection *trackDataConnection;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSMutableArray *pendingRequests;
@property (nonatomic, strong) NSDateFormatter *ISODateFormatter;
@property (strong, nonatomic) NSTimer *syncProgressTimer;

@end

@implementation TungCommonObjects

+ (id)establishTungObjects {
    static TungCommonObjects *tungObjects = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tungObjects = [[self alloc] init];
    });
    return tungObjects;
}

- (id)init {
    if (self = [super init]) {
        
        _sessionId = @"";
        _tung_version = @"0.3.0";
        //_apiRootUrl = @"https://api.tung.fm/";
        _apiRootUrl = @"https://staging-api.tung.fm/";
        _tungSiteRootUrl = @"https://tung.fm/";
        // refresh feed flag
        _feedNeedsRefresh = [NSNumber numberWithBool:NO];
        
        _connectionAvailable = [NSNumber numberWithInt:-1];
        
        _trackInfo = [[NSMutableDictionary alloc] init];
        
        // playback speed
        _playbackRates = @[[NSNumber numberWithFloat:.75],
                           [NSNumber numberWithFloat:1.0],
                           [NSNumber numberWithFloat:1.5],
                           [NSNumber numberWithFloat:2.0]];
        _playbackRateIndex = 1;
        
        // audio session
        if ([[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: nil]) {
            [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMediaServicesReset) name:AVAudioSessionMediaServicesWereResetNotification object:nil];        
        
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
        
        _ISODateFormatter = [[NSDateFormatter alloc] init];
        [_ISODateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];

        // show what's in documents dir
        /*
        NSError *fError = nil;
        NSArray *folders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSArray *appFolderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[folders objectAtIndex:0] error:&fError];
        CLS_LOG(@"documents folder contents ---------------");
        if ([appFolderContents count] > 0 && fError == nil) {
            for (NSString *item in appFolderContents) {
                CLS_LOG(@"- %@", item);
            }
        }
         */
        
        // show what's in temp dir
        /*
         NSError *ftError = nil;
         NSArray *tmpFolderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:&ftError];
         CLS_LOG(@"temp folder contents ---------------");
         if ([tmpFolderContents count] > 0 && ftError == nil) {
             for (NSString *item in tmpFolderContents) {
             	CLS_LOG(@"- %@", item);
             }
         }
         */
        
        // all saved user data
        /*
        AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
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

-(void) checkForNowPlaying {
    // find playing episode
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    NSFetchRequest *npRequest = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"isNowPlaying == YES"];
    [npRequest setPredicate:predicate];
    NSError *error = nil;
    NSArray *npResult = [appDelegate.managedObjectContext executeFetchRequest:npRequest error:&error];
    if (npResult.count > 0) {
        EpisodeEntity *epEntity = [npResult lastObject];
        
        if (epEntity.title) {
            _npEpisodeEntity = epEntity;
            NSURL *url = [NSURL URLWithString:_npEpisodeEntity.url];
            _playQueue = [@[url] mutableCopy];
            if ([self isPlaying]) {
                [self setControlButtonStateToPause];
            } else {
                [self setControlButtonStateToPlay];
            }
            return;
        }
        else {
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
            [self playerPause];
        } break;
        case AVAudioSessionInterruptionTypeEnded:{
            // • Make session active
            // • Update user interface
            // • AVAudioSessionInterruptionOptionShouldResume option
            if (interruptionOption.unsignedIntegerValue == AVAudioSessionInterruptionOptionShouldResume) {
                [self playerPlay];
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
    if ([[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: nil]) {
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    }
    if (_player) {
        [self playerPause];
        [_player removeObserver:self forKeyPath:@"status"];
        [_player removeObserver:self forKeyPath:@"currentItem.playbackLikelyToKeepUp"];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:_player.currentItem];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:_player.currentItem];
        [_player cancelPendingPrerolls];
        _player = nil;
        _trackData = nil;
        _trackDataConnection = nil;
    }
    [self checkForNowPlaying];
}

#pragma mark - Player instance methods

- (BOOL) isPlaying {
    //CLS_LOG(@"is playing at rate: %f", _player.rate);
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
            [self setControlButtonStateToPause];
        }
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
        if (_fileIsStreaming && _fileIsLocal) {
            [self replacePlayerItemWithLocalCopy];
        }
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

- (void) stopClipPlayback {
    if (_clipPlayer && [_clipPlayer isPlaying]) {
        
        [_clipPlayer stop];
        [_clipPlayer setCurrentTime:0];
    }
}

// this also sets track info for MPNowPlayingInfoCenter
- (void) determineTotalSeconds {
    
    if (_totalSeconds == 0) {
        CLS_LOG(@"determineTotalSeconds");
        // need to wait until player is playing to get duration or app freezes
        if ([self isPlaying] || (![self isPlaying] && _shouldStayPaused)) {
            if ([self isPlaying]) {
                [self setControlButtonStateToPause];
            }
            _totalSeconds = CMTimeGetSeconds(_player.currentItem.asset.duration);
            [_trackInfo setObject:[NSNumber numberWithFloat:_totalSeconds] forKey:MPMediaItemPropertyPlaybackDuration];
            [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:_trackInfo];
            CLS_LOG(@"determined total seconds: %f (%@)", _totalSeconds, [TungCommonObjects convertSecondsToTimeString:_totalSeconds]);
        }
        else {
            [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(determineTotalSeconds) userInfo:nil repeats:NO];
        }
    }
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    //CLS_LOG(@"observe value for key path: %@", keyPath);
    if (object == _player && [keyPath isEqualToString:@"status"]) {
        
        switch (_player.status) {
            case AVPlayerStatusFailed:
                CLS_LOG(@"-- AVPlayer status: Failed");
                [self ejectCurrentEpisode];
                [self setControlButtonStateToFauxDisabled];;
                break;
            case AVPlayerStatusReadyToPlay:
                CLS_LOG(@"-- AVPlayer status: ready to play");
                [self setControlButtonStateToBuffering];
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
                    
                    CLS_LOG(@"seeking to time: %f", secs);
                    [_trackInfo setObject:[NSNumber numberWithFloat:secs] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
                    [_player seekToTime:time completionHandler:^(BOOL finished) {
                        CLS_LOG(@"finished seeking");
                        [self playerPlay];
                        if (_fileIsLocal) [self determineTotalSeconds];
                    }];
                } else {
                    [_trackInfo setObject:[NSNumber numberWithFloat:0] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
                    
                    if ([self isPlaying] && _fileIsLocal) {
                        CLS_LOG(@"play from beginning - already playing");
                        [self setControlButtonStateToPause];
                        [self determineTotalSeconds];
                    } else {
                        CLS_LOG(@"play from beginning - with preroll");
                        [_player prerollAtRate:1.0 completionHandler:^(BOOL finished) {
                            CLS_LOG(@"-- finished preroll: %d", finished);
                            if ([self isPlaying]) {
                                CLS_LOG(@"started playing");
                                [self setControlButtonStateToPause];
                            } else {
                                CLS_LOG(@"not yet playing, play");
                                [self playerPlay];
                            }
                            [self determineTotalSeconds];
                        }];
                    }
                }
                break;
            case AVPlayerItemStatusUnknown:
                CLS_LOG(@"-- AVPlayer status: Unknown");
                break;
            default:
                break;
        }
    }
    if (object == _player && [keyPath isEqualToString:@"currentItem.playbackLikelyToKeepUp"]) {
        
        if (_player.currentItem.playbackLikelyToKeepUp) {
            CLS_LOG(@"-- player likely to keep up");
            
            if (_totalSeconds == 0) {
                [self determineTotalSeconds];
            }
            else if (_totalSeconds > 0) {
                float currentSecs = CMTimeGetSeconds(_player.currentTime);
            	if (round(currentSecs) >= floor(_totalSeconds)) {
                    CLS_LOG(@"detected completed playback");
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
            CLS_LOG(@"-- player NOT likely to keep up");
            // see if file is cached yet, so player can switch to local file
            if (_fileIsStreaming && _fileIsLocal) {
                [self replacePlayerItemWithLocalCopy];
            }
            if (!_shouldStayPaused) [self setControlButtonStateToBuffering];
        }
    }
    /*
    if (object == _player && [keyPath isEqualToString:@"currentItem.loadedTimeRanges"]) {
        NSArray *timeRanges = (NSArray *)[change objectForKey:NSKeyValueChangeNewKey];
        if (timeRanges && [timeRanges count]) {
            CMTimeRange timerange = [[timeRanges objectAtIndex:0] CMTimeRangeValue];
            CLS_LOG(@" . . . %.5f -> %.5f", CMTimeGetSeconds(timerange.start), CMTimeGetSeconds(CMTimeAdd(timerange.start, timerange.duration)));
        }
    }
    if (object == _player && [keyPath isEqualToString:@"currentItem.playbackBufferEmpty"]) {
        
        if (_player.currentItem.playbackBufferEmpty) {
            CLS_LOG(@"-- playback buffer empty");
            [self setControlButtonStateToBuffering];
        }
    }*/
}

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
        UIAlertView *searchPromptAlert = [[UIAlertView alloc] initWithTitle:@"Nothing is playing" message:@"Would you like to search for a podcast?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
        [searchPromptAlert setTag:10];
        [searchPromptAlert show];
    }
}

/*
 Setting control button states
 */
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

- (void) seekToTime:(CMTime)time {
    if (_fileIsStreaming && _fileIsLocal) {
        [self replacePlayerItemWithLocalCopy];
    }
    [_trackInfo setObject:[NSNumber numberWithFloat:CMTimeGetSeconds(time)] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:_trackInfo];
    //[_player seekToTime:time];
    [_player seekToTime:time completionHandler:^(BOOL finished) {
        if (!_shouldStayPaused) {
            // avoid endless loop, do not use [self playerPlay];
            [_player play];
            [self setControlButtonStateToPause];
        }
    }];
}


// for dismissing search from main tab bar by tapping icon
- (void) dismissSearch {
    if (_ctrlBtnDelegate && [_ctrlBtnDelegate respondsToSelector:@selector(dismissPodcastSearch)]) {
        [_ctrlBtnDelegate dismissPodcastSearch];
    }
}

- (void) queueAndPlaySelectedEpisode:(NSString *)urlString fromTimestamp:(NSString *)timestamp {
    
    // url and file
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *fileName = [url lastPathComponent];
    NSString *fileType = [fileName pathExtension];
    //CLS_LOG(@"play file of type: %@", fileType);
    // avoid videos
    if ([fileType isEqualToString:@"mp4"] || [fileType isEqualToString:@"m4v"]) {
        UIAlertView *videoAlert = [[UIAlertView alloc] initWithTitle:@"Video Podcast" message:@"Tung does not currently support video podcasts." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [videoAlert show];
    }
    else {
        // make sure it isn't playing
        if (_playQueue.count > 0) {
            
            // it's new, but something else is loaded
            if (![[_playQueue objectAtIndex:0] isEqual:url]) {
                [self ejectCurrentEpisode];
                if (timestamp) {
                    _playFromTimestamp = timestamp;
                }
                [_playQueue insertObject:url atIndex:0];
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
            [_playQueue insertObject:url atIndex:0];
            [self playQueuedPodcast];
        }
    }
}

- (void) playUrl:(NSString *)urlString fromTimestamp:(NSString *)timestamp {
    NSURL *url = [NSURL URLWithString:urlString];
    
    _playFromTimestamp = timestamp;
    
    if (_playQueue.count > 0 && [[_playQueue objectAtIndex:0] isEqual:url]) {
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
        
        [self stopClipPlayback];
        
        [self resetPlayer];
        
        NSString *urlString = [NSString stringWithFormat:@"%@", [_playQueue objectAtIndex:0]];
        
        CLS_LOG(@"play url: %@", urlString);
        
        // assign now playing entity
        AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
        NSError *error = nil;
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
        NSPredicate *predicate = [NSPredicate predicateWithFormat: @"url == %@", urlString];
        [request setPredicate:predicate];
        NSArray *episodeResult = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
        if (episodeResult.count > 0) {
            //CLS_LOG(@"found and assigned now playing entity");
            _npEpisodeEntity = [episodeResult lastObject];
        } else {
            /* create entity - case is next episode in feed is played. Episode entity may not have been
             created yet, but podcast entity would, so we get it from np episode entity. */
            // look up podcast entity
            //CLS_LOG(@"creating new entity for now playing entity");
            NSDictionary *episodeDict = [_currentFeed objectAtIndex:_currentFeedIndex];
            PodcastEntity *npPodcastEntity = _npEpisodeEntity.podcast;
            _npEpisodeEntity = [TungCommonObjects getEntityForEpisode:episodeDict withPodcastEntity:npPodcastEntity save:NO];
        }
        
        _npEpisodeEntity.isNowPlaying = [NSNumber numberWithBool:YES];
        [TungCommonObjects saveContextWithReason:@"now playing changed"];
        // find index of episode in current feed for prev/next track fns
        _currentFeed = [TungPodcast extractFeedArrayFromFeedDict:[TungPodcast retrieveAndCacheFeedForPodcastEntity:_npEpisodeEntity.podcast forceNewest:NO]];
        _currentFeedIndex = [TungCommonObjects getIndexOfEpisodeWithUrl:urlString inFeed:_currentFeed];
        
        // set now playing info center info
        NSData *artImageData = [TungCommonObjects retrievePodcastArtDataWithUrlString:_npEpisodeEntity.podcast.artworkUrl600 andCollectionId:_npEpisodeEntity.collectionId];
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
        NSURL *urlToPlay = [self getEpisodeUrl:[_playQueue objectAtIndex:0]];
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:urlToPlay options:nil];
        [asset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
        
        _player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
        // add observers
        [_player addObserver:self forKeyPath:@"status" options:0 context:nil];
        //[_player addObserver:self forKeyPath:@"currentItem.playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
        //[_player addObserver:self forKeyPath:@"currentItem.loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
        // Subscribe to AVPlayerItem's notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(completedPlayback) name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerError:) name:AVPlayerItemPlaybackStalledNotification object:playerItem];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerError:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:playerItem];
        [_player addObserver:self forKeyPath:@"currentItem.playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
        
        [self setControlButtonStateToBuffering];
        
        // now playing did change
        /*
        if ([_ctrlBtnDelegate respondsToSelector:@selector(nowPlayingDidChange)])
        	[_ctrlBtnDelegate nowPlayingDidChange];
        */
        NSNotification *nowPlayingDidChangeNotif = [NSNotification notificationWithName:@"nowPlayingDidChange" object:nil userInfo:nil];
        [[NSNotificationCenter defaultCenter] postNotification:nowPlayingDidChangeNotif];
    }
    //CLS_LOG(@"play queue: %@", _playQueue);
}

// removes observers, releases player related properties
- (void) resetPlayer {
    //CLS_LOG(@"reset player ///////////////");
    _npViewSetupForCurrentEpisode = NO;
    _shouldStayPaused = NO;
    _totalSeconds = 0;
    // remove old player and observers
    if (_player) {
        [_player removeObserver:self forKeyPath:@"status"];
        [_player removeObserver:self forKeyPath:@"currentItem.playbackLikelyToKeepUp"];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:_player.currentItem];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:_player.currentItem];
        [_player cancelPendingPrerolls];
        _player = nil;
    }
    // clear leftover connection data
    if (_trackDataConnection) {
        //CLS_LOG(@"clear connection data");
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
    CLS_LOG(@"completed playback? current secs: %f, total secs: %f", currentTimeSecs, _totalSeconds);
    // called prematurely
    if (_totalSeconds == 0) {
        CLS_LOG(@"completed playback called prematurely. totalSeconds not set");
        [self determineTotalSeconds];
        return;
    }
    if (round(currentTimeSecs) < floor(_totalSeconds)) {
        CLS_LOG(@"completed playback called prematurely.");
        if (_fileIsStreaming && _fileIsLocal) {
            [self replacePlayerItemWithLocalCopy];
        }
        /*
        else {
            CLS_LOG(@"- attempt to reload episode");
            // do not need timestamp bc eject current episode saves position
            NSString *urlString = _npEpisodeEntity.url;
            [self ejectCurrentEpisode];
            [self queueAndPlaySelectedEpisode:urlString fromTimestamp:nil];
        }*/
        return;
    }
	
    [self playNextEpisode]; // ejects current episode
}
- (void) ejectCurrentEpisode {
    CLS_LOG(@"ejecting current episode");
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
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
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
        AudioServicesPlaySystemSound(1103); // play beep
        CLS_LOG(@"play next episode");
        [self playQueuedPodcast];
    }
    // play next episode in feed
    else {
        if (!_currentFeed) {
            NSLog(@"current feed was not set");
            _currentFeed = [TungPodcast extractFeedArrayFromFeedDict:[TungPodcast retrieveAndCacheFeedForPodcastEntity:_npEpisodeEntity.podcast forceNewest:NO]];
        }
        // first see if there is a newer one and if it has been listened to yet
        if (_currentFeedIndex - 1 > -1) {
            
            NSDictionary *epDict = [_currentFeed objectAtIndex:_currentFeedIndex - 1];
            EpisodeEntity *epEntity = [TungCommonObjects getEntityForEpisode:epDict withPodcastEntity:_npEpisodeEntity.podcast save:NO];
            
            if (epEntity.trackPosition.floatValue == 0) {
                CLS_LOG(@"newer episode hasn't been listened to yet, queue and play");
                [self ejectCurrentEpisode];
                _currentFeedIndex--;
                [_playQueue insertObject:[NSURL URLWithString:epEntity.url] atIndex:0];
                [self playQueuedPodcast];
                return;
            }
        }
        // check if there is an older one
        if (_currentFeedIndex + 1 < _currentFeed.count) {
            NSDictionary *epDict = [_currentFeed objectAtIndex:_currentFeedIndex + 1];
            EpisodeEntity *epEntity = [TungCommonObjects getEntityForEpisode:epDict withPodcastEntity:_npEpisodeEntity.podcast save:NO];
            
            if (epEntity.trackPosition.floatValue == 0) {
                CLS_LOG(@"older episode hasn't been listened to yet, queue and play");
                [self ejectCurrentEpisode];
                _currentFeedIndex++;
                [_playQueue insertObject:[NSURL URLWithString:epEntity.url] atIndex:0];
                [self playQueuedPodcast];
                return;
            }
        }
        CLS_LOG(@"episodes in both directions have been played. allow player to stop");
        
        [self savePositionForNowPlayingAndSync:YES];
        [self setControlButtonStateToPlay];
    }
}

- (void) playNextOlderEpisodeInFeed {
    
    if (!_currentFeed) {
    	_currentFeed = [TungPodcast extractFeedArrayFromFeedDict:[TungPodcast retrieveAndCacheFeedForPodcastEntity:_npEpisodeEntity.podcast forceNewest:NO]];
    }

    if (_currentFeedIndex + 1 >= 0) {
        CLS_LOG(@"play previous episode in feed");
        [self ejectCurrentEpisode];
        _currentFeedIndex++;
        NSDictionary *episodeDict = [_currentFeed objectAtIndex:_currentFeedIndex];
        NSURL *url = [NSURL URLWithString:[[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"url"]];
        [_playQueue insertObject:url atIndex:0];
 
        [self playQueuedPodcast];
    } else {
        [self setControlButtonStateToFauxDisabled];
    }
}

- (void) playNextNewerEpisodeInFeed {
    
    if (!_currentFeed) {
        _currentFeed = [TungPodcast extractFeedArrayFromFeedDict:[TungPodcast retrieveAndCacheFeedForPodcastEntity:_npEpisodeEntity.podcast forceNewest:NO]];
    }
    
    if (_currentFeedIndex - 1 >= 0) {
        CLS_LOG(@"play previous episode in feed");
        [self ejectCurrentEpisode];
        _currentFeedIndex--;
        NSDictionary *episodeDict = [_currentFeed objectAtIndex:_currentFeedIndex];
        NSURL *url = [NSURL URLWithString:[[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"url"]];
        [_playQueue insertObject:url atIndex:0];
        
        [self playQueuedPodcast];
    } else {
        [self setControlButtonStateToFauxDisabled];
    }
}


- (void) playerError:(NSNotification *)notification {
    CLS_LOG(@"PLAYER ERROR: %@ ...attempting to recover playback", [notification userInfo]);
    // try to recover playback
    if (_fileIsStreaming && _fileIsLocal) {
        [self replacePlayerItemWithLocalCopy];
    }
    else {
        CLS_LOG(@"- attempt to reload episode");
        // do not need timestamp bc eject current episode saves position
        NSString *urlString = _npEpisodeEntity.url;
        [self ejectCurrentEpisode];
        [self queueAndPlaySelectedEpisode:urlString fromTimestamp:nil];
    }
}

// looks for local file, else returns url with custom scheme
- (NSURL *) getEpisodeUrl:(NSURL *)url {
    
    //CLS_LOG(@"get episode url: %@", url);
    
    NSString *episodeDir = [NSTemporaryDirectory() stringByAppendingPathComponent:episodeDirName];
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:episodeDir withIntermediateDirectories:YES attributes:nil error:&error];
	/*
    NSError *ftError = nil;
    NSArray *episodeDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:episodeDir error:&ftError];
    CLS_LOG(@"episode directory contents ---------------");
    if ([episodeDirContents count] > 0 && ftError == nil) {
        for (NSString *item in episodeDirContents) {
            CLS_LOG(@"- %@", item);
        }
    }
    */
    NSString *episodeFilename = [url.path lastPathComponent];
    episodeFilename = [episodeFilename stringByRemovingPercentEncoding];
    NSString *episodeFilepath = [episodeDir stringByAppendingPathComponent:episodeFilename];

    if ([[NSFileManager defaultManager] fileExistsAtPath:episodeFilepath]) {
        CLS_LOG(@"^^^ will use local file");
        _fileIsLocal = YES;
        _fileIsStreaming = NO;
        _fileWillBeCached = YES;
        return [NSURL fileURLWithPath:episodeFilepath];
    } else {
        _fileIsLocal = NO;
        _fileIsStreaming = YES;
        
        NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
        // if episode has track position > 0.1, we do not use custom scheme,
        // because this way AVPlayer will start streaming from the timestamp
        // instead of downloading from the start as with a custom scheme
        if (_npEpisodeEntity.trackPosition.floatValue > 0.1 && _npEpisodeEntity.trackPosition.floatValue < 1.0) {
            // no caching
            _fileWillBeCached = NO;
            CLS_LOG(@"^^^ will stream from url with NO caching");
        }
        else {
            // return url with custom scheme
            components.scheme = @"tungstream";
            _fileWillBeCached = YES;
            CLS_LOG(@"^^^ will stream from url with custom scheme");
            
        }
        return [components URL];
    }
}

// replace player file with local cached copy
- (void) replacePlayerItemWithLocalCopy {
    CLS_LOG(@"replace player item with local copy");
    CMTime currentTime = _player.currentTime;
    NSURL *urlToPlay = [self getEpisodeUrl:[_playQueue objectAtIndex:0]];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:urlToPlay options:nil];
    AVPlayerItem *localPlayerItem = [[AVPlayerItem alloc] initWithAsset:asset];
    [_player replaceCurrentItemWithPlayerItem:localPlayerItem];
    [_player seekToTime:currentTime completionHandler:^(BOOL finished) {
        if (_shouldStayPaused) {
            [_player pause];
        } else {
            [_player play];
        }
    }];
}

static NSString *episodeDirName = @"episodes";

- (void) saveNowPlayingEpisodeInTempDirectory {
    
    _fileWillBeCached = YES;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:_npEpisodeEntity.url]];
    _trackDataConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [_trackDataConnection setDelegateQueue:[NSOperationQueue mainQueue]];
    [_trackDataConnection start];
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
    CLS_LOG(@"saved play queue %@ to path: %@", _playQueue, playQueuePath);
}

- (void) readPlayQueueFromDisk {
    NSString *playQueuePath = [self getPlayQueuePath];
    CLS_LOG(@"read play queue from path: %@", playQueuePath);
    NSArray *queue = [NSArray arrayWithContentsOfFile:playQueuePath];
    if (queue) {
        CLS_LOG(@"found saved play queue: %@", _playQueue);
        _playQueue = [queue mutableCopy];
    } else {
        CLS_LOG(@"no saved play queue. create new");
        _playQueue = [NSMutableArray array];
    }
}


#pragma mark - NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (connection == _trackDataConnection) {
        //CLS_LOG(@"[NSURLConnectionDataDelegate] connection did receive response");
        _trackData = [NSMutableData data];
        _response = (NSHTTPURLResponse *)response;
        
        [self processPendingRequests];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (connection == _trackDataConnection) {
        //CLS_LOG(@"[NSURLConnectionDataDelegate] connection did receive data");
        [_trackData appendData:data];
        
        [self processPendingRequests];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (connection == _trackDataConnection) {
        //CLS_LOG(@"[NSURLConnectionDataDelegate] connection did finish loading");
        [self processPendingRequests];
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        NSString *episodeDir = [NSTemporaryDirectory() stringByAppendingPathComponent:episodeDirName];
        NSError *error;
        [fileManager createDirectoryAtPath:episodeDir withIntermediateDirectories:YES attributes:nil error:&error];
        error = nil;
        NSString *episodeFilename = [[_playQueue objectAtIndex:0] lastPathComponent];
        NSString *episodeFilepath = [episodeDir stringByAppendingPathComponent:episodeFilename];
        
        if ([_trackData writeToFile:episodeFilepath options:0 error:&error]) {
            CLS_LOG(@"-- saved podcast track in temp episode dir");
            _fileIsLocal = YES;
            // we can safely release these
            _trackData = nil;
            _trackDataConnection = nil;
        }
        else {
            CLS_LOG(@"ERROR: track did not save: %@", error);
            _fileIsLocal = NO;
        }
    }
}

#pragma mark - AVURLAsset resource loading

- (void)processPendingRequests
{
    //CLS_LOG(@"[AVAssetResourceLoaderDelegate] process pending requests");
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
    //CLS_LOG(@"[AVAssetResourceLoaderDelegate] fill in content information");
    NSString *mimeType = [self.response MIMEType];
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    
    contentInformationRequest.byteRangeAccessSupported = YES;
    contentInformationRequest.contentType = CFBridgingRelease(contentType);
    contentInformationRequest.contentLength = [self.response expectedContentLength];
}

- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest
{
    //CLS_LOG(@"[AVAssetResourceLoaderDelegate] respond with data for request");
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
    if (_trackDataConnection == nil)
    {
        //CLS_LOG(@"[AVAssetResourceLoaderDelegate] should wait for loading of requested resource");
        NSURL *interceptedURL = [loadingRequest.request URL];
        NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:interceptedURL resolvingAgainstBaseURL:NO];
        // TODO: scheme may be https...
        actualURLComponents.scheme = @"http";
        
        NSURLRequest *request = [NSURLRequest requestWithURL:[actualURLComponents URL]];
        _trackDataConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        [_trackDataConnection setDelegateQueue:[NSOperationQueue mainQueue]];
        
        [_trackDataConnection start];
    }
    
    [self.pendingRequests addObject:loadingRequest];
    
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    //CLS_LOG(@"[AVAssetResourceLoaderDelegate] did cancel loading request");
    [self.pendingRequests removeObject:loadingRequest];
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

#pragma mark - core data related

+ (BOOL) saveContextWithReason:(NSString*)reason {
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    // save
    
    BOOL saved = NO;
    if ([appDelegate.managedObjectContext hasChanges]) {
        NSError *savingError;
    	saved = [appDelegate.managedObjectContext save:&savingError];
        if (saved) {
            //CLS_LOG(@"** save context with reason: %@ :: Successfully saved", reason);
        } else {
            CLS_LOG(@"** save context with reason: %@ :: ERROR: %@", reason, savingError);
        }
    } else {
        CLS_LOG(@"** save context with reason: %@ :: Did not save, no changes", reason);
    }
    return saved;
}

/*
 make sure there is a record for the podcast and the episode.
 Will not overwrite existing entities or create dupes.
 */

+ (PodcastEntity *) getEntityForPodcast:(NSDictionary *)podcastDict save:(BOOL)save {
    
    if (!podcastDict || ![podcastDict objectForKey:@"collectionId"]) {
        CLS_LOG(@"get entity for podcast: ERROR: podcast dict was null");
        return nil;
    }
    
    //CLS_LOG(@"get entity for podcast: %@", [podcastDict objectForKey:@"collectionName"]);
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
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
        CLS_LOG(@"creating new podcast entity for %@", [podcastDict objectForKey:@"collectionId"]);
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
    // subscribed?
    if ([podcastDict objectForKey:@"isSubscribed"]) {
        NSNumber *subscribed = [podcastDict objectForKey:@"isSubscribed"];
        podcastEntity.isSubscribed = subscribed;
        if (subscribed.boolValue) {
            NSNumber *timeSubscribed = [podcastDict objectForKey:@"timeSubscribed"];
            podcastEntity.timeSubscribed = timeSubscribed;
        }
    }
    // optional/variable properties
    if ([podcastDict objectForKey:@"collectionName"]) {
        podcastEntity.collectionName = [podcastDict objectForKey:@"collectionName"];
        podcastEntity.artistName = [podcastDict objectForKey:@"artistName"];
        
        podcastEntity.artworkUrl600 = [podcastDict objectForKey:@"artworkUrl600"];
        podcastEntity.feedUrl = [podcastDict objectForKey:@"feedUrl"];
        
        UIColor *keyColor1, *keyColor2;
        NSString *keyColor1Hex, *keyColor2Hex;
        // datasource: podcast search
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
        podcastEntity.keyColor1Hex = keyColor1Hex;
        podcastEntity.keyColor2 = keyColor2;
        podcastEntity.keyColor2Hex = keyColor2Hex;
        if ([podcastDict objectForKey:@"artworkUrlSSL"] != (id)[NSNull null]) {
            podcastEntity.artworkUrlSSL = [podcastDict objectForKey:@"artworkUrlSSL"];
        }
        if ([podcastDict objectForKey:@"website"] != (id)[NSNull null]) {
            podcastEntity.website = [podcastDict objectForKey:@"website"];
        }
        if ([podcastDict objectForKey:@"email"] != (id)[NSNull null]) {
            podcastEntity.email = [podcastDict objectForKey:@"email"];
        }
        if ([podcastDict objectForKey:@"desc"] != (id)[NSNull null]) {
            podcastEntity.desc = [podcastDict objectForKey:@"desc"];
        }
    }
    
    if (save) [TungCommonObjects saveContextWithReason:@"save podcast entity"];
    
    return podcastEntity;
}

+ (EpisodeEntity *) getEntityForEpisode:(NSDictionary *)episodeDict withPodcastEntity:(PodcastEntity *)podcastEntity save:(BOOL)save {
    
    if (!episodeDict || !podcastEntity) {
        CLS_LOG(@"get entity for episode: ERROR: podcast entity or episode dict was null");
        return nil;
    }
    
    //CLS_LOG(@"get episode entity for episode: %@", episodeDict);
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];

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
            CLS_LOG(@"did not get episode entity - cannot create episode entity without GUID");
            return nil;
        }
        // new entity
        episodeEntity = [NSEntityDescription insertNewObjectForEntityForName:@"EpisodeEntity" inManagedObjectContext:appDelegate.managedObjectContext];
        
        episodeEntity.collectionId = podcastEntity.collectionId;
    }
    
    episodeEntity.podcast = podcastEntity;
    
    // optional/variable properties
    if ([episodeDict objectForKey:@"guid"]) {
        episodeEntity.guid = [episodeDict objectForKey:@"guid"];
    }
    if ([episodeDict objectForKey:@"itunes:image"]) {
        episodeEntity.episodeImageUrl = [[[episodeDict objectForKey:@"itunes:image"] objectForKey:@"el:attributes"] objectForKey:@"href"];
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
        episodeEntity.dataLength = [NSNumber numberWithDouble:[[[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"length"] doubleValue]];
    }
    
    NSString *url;
    if ([episodeDict objectForKey:@"url"]) {
        url = [episodeDict objectForKey:@"url"];
    }
    else if ([episodeDict objectForKey:@"enclosure"]) {
    	url = [[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"url"];
    }
    else {
        url = @"";
    }
    episodeEntity.url = url;
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
    episodeEntity.desc = [TungCommonObjects findEpisodeDescriptionWithDict:episodeDict];

    if (save) [TungCommonObjects saveContextWithReason:@"save episode entity"];
    
    return episodeEntity;
}

// get episode description
+ (NSString *) findEpisodeDescriptionWithDict:(NSDictionary *)episodeDict {
    
    id desc = [episodeDict objectForKey:@"itunes:summary"];
    if ([desc isKindOfClass:[NSString class]]) {
        //CLS_LOG(@"- summary description");
        return (NSString *)desc;
    }
    else {
        id descr = [episodeDict objectForKey:@"description"];
        if ([descr isKindOfClass:[NSString class]]) {
            //CLS_LOG(@"- regular description");
            return (NSString *)descr;
        }
        else {
            //CLS_LOG(@"- no desc");
            return @"";
        }
    }
}

+ (NSString *) findPodcastDescriptionWithDict:(NSDictionary *)dict {
    NSString *descrip;
    id desc = [[dict objectForKey:@"channel"] objectForKey:@"itunes:summary"];
    if ([desc isKindOfClass:[NSString class]]) {
        descrip = (NSString *)desc;
    } else {
        id descr = [[dict objectForKey:@"channel"] objectForKey:@"description"];
        if ([descr isKindOfClass:[NSString class]]) {
            descrip = (NSString *)descr;
        }
        else {
            return @"This podcast has no description.";
        }
    }
    return [descrip stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    
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
        CLS_LOG(@"could not convert date: %@", pubDate);
        date = [NSDate date];
    }
    return date;
    
}

+ (EpisodeEntity *) getEpisodeEntityFromEpisodeId:(NSString *)episodeId {
    
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
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


+ (UserEntity *) saveUserWithDict:(NSDictionary *)userDict {
    
    NSString *tungId;
    if ([userDict objectForKey:@"_id"]) {
    	tungId = [[userDict objectForKey:@"_id"] objectForKey:@"$id"];
    } else {
        tungId = [userDict objectForKey:@"tung_id"];
    }
    //CLS_LOG(@"save user with dict: %@", userDict);
    UserEntity *userEntity = [TungCommonObjects retrieveUserEntityForUserWithId:tungId];
    
    if (!userEntity) {
        //CLS_LOG(@"no existing user entity, create new");
        AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
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
    NSString *twitter_username = [userDict objectForKey:@"twitter_username"];
    if (twitter_username.length > 0) {
    	userEntity.twitter_username = twitter_username;
    }
    if ([userDict objectForKey:@"facebook_id"] != (id)[NSNull null]) {
        NSString *facebook_id = [userDict objectForKey:@"facebook_id"]; //ensure string
        userEntity.facebook_id = facebook_id;
    }

    [TungCommonObjects saveContextWithReason:@"save new user entity"];
    
    return userEntity;
}

+ (UserEntity *) retrieveUserEntityForUserWithId:(NSString *)userId {
    //CLS_LOG(@"retrieve user entity for user with id: %@", userId);
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
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

- (NSDictionary *) getLoggedInUserData {
    
    if (_tungId) {
        UserEntity *userEntity = [TungCommonObjects retrieveUserEntityForUserWithId:_tungId];
        return [TungCommonObjects entityToDict:userEntity];
    } else {
        return nil;
    }
    
}

// not used
- (void) deleteLoggedInUserData {
    
    UserEntity *userEntity = [TungCommonObjects retrieveUserEntityForUserWithId:_tungId];
    if (userEntity) {
        AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
        [appDelegate.managedObjectContext deleteObject:userEntity];
        [TungCommonObjects saveContextWithReason:@"delete logged in user entity"];
    }
}

+ (SettingsEntity *) settings {
    
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
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
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSFetchRequest *findUsers = [[NSFetchRequest alloc] initWithEntityName:@"UserEntity"];
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:findUsers error:&error];
    if (result.count > 0) {
        
        for (int i = 0; i < result.count; i++) {
            UserEntity *userEntity = [result objectAtIndex:i];
            NSDictionary *userDict = [TungCommonObjects entityToDict:userEntity];
            CLS_LOG(@"user at index: %d", i);
            CLS_LOG(@"%@", userDict);
        }
        
        return YES;
    } else {
        CLS_LOG(@"no user entities found");
        return NO;
    }
}

// not used... only for debugging
+ (BOOL) checkForPodcastData {
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    
    // show episode entity data
    CLS_LOG(@"episode entity data");
    NSFetchRequest *eRequest = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSError *eError = nil;
    NSArray *eResult = [appDelegate.managedObjectContext executeFetchRequest:eRequest error:&eError];
    if (eResult.count > 0) {
        for (int i = 0; i < eResult.count; i++) {
            EpisodeEntity *episodeEntity = [eResult objectAtIndex:i];
            CLS_LOG(@"episode at index: %d", i);
            // entity -> dict
            NSArray *ekeys = [[[episodeEntity entity] attributesByName] allKeys];
            NSDictionary *eDict = [episodeEntity dictionaryWithValuesForKeys:ekeys];
            CLS_LOG(@"%@", eDict);
        }
    }
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"PodcastEntity"];
    NSError *error;
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    if (result.count > 0) {
        
        for (int i = 0; i < result.count; i++) {
            PodcastEntity *podcastEntity = [result objectAtIndex:i];
            CLS_LOG(@"podcast at index: %d", i);
            // entity -> dict
            NSArray *keys = [[[podcastEntity entity] attributesByName] allKeys];
            NSDictionary *podcastDict = [podcastEntity dictionaryWithValuesForKeys:keys];
            CLS_LOG(@"%@", podcastDict);
        }
        
        return YES;
    } else {
        return NO;
    }
}

+ (void) removePodcastAndEpisodeData {
    
    CLS_LOG(@"remove podcast and episode data");
    
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    // delete episode entity data
    NSFetchRequest *eRequest = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSError *eError = nil;
    NSArray *eResult = [appDelegate.managedObjectContext executeFetchRequest:eRequest error:&eError];
    if (eResult.count > 0) {
        for (int i = 0; i < eResult.count; i++) {
            [appDelegate.managedObjectContext deleteObject:[eResult objectAtIndex:i]];
            //CLS_LOG(@"deleted episode record at index: %d", i);
        }
    }
    
    NSFetchRequest *pRequest = [[NSFetchRequest alloc] initWithEntityName:@"PodcastEntity"];
    NSError *pError = nil;
    NSArray *pResult = [appDelegate.managedObjectContext executeFetchRequest:pRequest error:&pError];
    if (pResult.count > 0) {
        for (int i = 0; i < pResult.count; i++) {
            [appDelegate.managedObjectContext deleteObject:[pResult objectAtIndex:i]];
            //CLS_LOG(@"deleted podcast record at index: %d", i);
        }
    }
    
    [self saveContextWithReason:@"removed podcast and episode data"];
}

+ (void) removeAllUserData {
    CLS_LOG(@"remove all user data");
    
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"UserEntity"];
    NSError *error = nil;
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    if (result.count > 0) {
        for (int i = 0; i < result.count; i++) {
            [appDelegate.managedObjectContext deleteObject:[result objectAtIndex:i]];
            CLS_LOG(@"deleted user record at index: %d", i);
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

+ (NSArray *) determineKeyColorsFromImage:(UIImage *)image {
    
    if (!colorCube) colorCube = [[CCColorCube alloc] init];
    NSArray *keyColors = [colorCube extractColorsFromImage:image flags:CCAvoidWhite+CCAvoidBlack count:6];
    UIColor *keyColor1 = [UIColor colorWithRed:0.45 green:0.45 blue:0.45 alpha:1];// default
    UIColor *keyColor2 = [self tungColor];// default
    if (keyColors.count > 0) {
        //CLS_LOG(@"determine key colors ---------");
        //int x = 120;
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
            
            NSString *dominantColor = [self determineDominantColorFromRGB:@[[NSNumber numberWithFloat:R], [NSNumber numberWithFloat:G], [NSNumber numberWithFloat:B]]];
            
            //CLS_LOG(@"- color %d - dominant: %@, saturation: %f, RGB: %f - %f - %f", i, dominantColor, saturation, R, G, B);
            
            // test for not gray (only for first keyColor)
            if (saturation < 0.09 && keyColor1Index < 0) {
                continue;
            }
            // test for bright yellow/green
            if (R > 0.65 && G > 0.65) {
                continue;
            }
            /*
             // test for dark blue/green
             if (R < 0.4 && G < 0.4 && sum < 1.4) {
             continue;
             }
             */
            // test for dark purple
            if (R < 0.4 && G < 0.4 && B < 0.6) {
                continue;
            }
            // test for dark red/brown
            if (R < 0.6 && G < 0.3 && B < 0.3) {
                continue;
            }
            // test for too dark
            if (R < 0.4 && G < 0.4 && B < 0.4) {
                continue;
            }
            // test for too light
            if (R > 0.6 && G > 0.6 && B > 0.6) {
                continue;
            }
            
            if (keyColor1Index < 0) {
                //CLS_LOG(@"* set key color 1");
                keyColor1Index = i;
                keyColor1DominantColor = dominantColor;
            }
            else if (keyColor2Index < 0) {
                NSString *keyColor2DominantColor = dominantColor;
                if ([keyColor1DominantColor isEqualToString:keyColor2DominantColor]) {
                    continue;
                } else {
                    //CLS_LOG(@"* set key color 2");
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
    //CLS_LOG(@"UIColor (red: %f, green: %f, blue: %f) to hex string: %@", red, green, blue, hexString);
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

- (void) establishCred {
    NSString *tungCred = [TungCommonObjects getKeychainCred];
    NSArray *components = [tungCred componentsSeparatedByString:@":"];
    _tungId = [components objectAtIndex:0];
    _tungToken = [components objectAtIndex:1];
    //CLS_LOG(@"id: %@", _tungId);
    //CLS_LOG(@"token: %@", _tungToken);
}

- (void) verifyCredWithTwitterOauthHeaders:(NSDictionary *)headers withCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    
    NSURL *verifyCredRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@app/twitter-signin.php", _apiRootUrl]];
    NSMutableURLRequest *verifyCredRequest = [NSMutableURLRequest requestWithURL:verifyCredRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [verifyCredRequest setHTTPMethod:@"POST"];
    
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:headers];
    [verifyCredRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:verifyCredRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                //CLS_LOG(@"Verify cred response %@", responseDict);
                
                if ([responseDict objectForKey:@"error"]) {
                    CLS_LOG(@"Error: %@", [responseDict objectForKey:@"error"]);
                    callback(NO, responseDict);
                }
                else if ([responseDict objectForKey:@"success"]) {
                    callback(YES, responseDict);
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error. HTML: %@", html);
                callback(NO, @{@"error": html});
            }
        });
    }];

}

- (void) verifyCredWithFacebookAccessToken:(NSString *)token withCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    
    NSURL *verifyCredRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@app/facebook-signin.php", _apiRootUrl]];
    NSMutableURLRequest *verifyCredRequest = [NSMutableURLRequest requestWithURL:verifyCredRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [verifyCredRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{ @"accessToken": token };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [verifyCredRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:verifyCredRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                //CLS_LOG(@"Verify cred response %@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    CLS_LOG(@"Error: %@", [responseDict objectForKey:@"error"]);
                    
                    callback(NO, responseDict);
                }
                else if ([responseDict objectForKey:@"success"]) {
                    callback(YES, responseDict);
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error. HTML: %@", html);
                callback(NO, @{@"error": html});
            }
        });
    }];
}

// all requests require a session ID instead of credentials
// start here and get session with credentials
- (void) getSessionWithCallback:(void (^)(void))callback {
    CLS_LOG(@"getting new session with id: %@", _tungId);
    if (!_tungId) {
        CLS_LOG(@"Tung ID was null, re-establish cred");
        [self establishCred];
    }
    
    NSURL *getSessionRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@app/session.php", _apiRootUrl]];
    NSMutableURLRequest *getSessionRequest = [NSMutableURLRequest requestWithURL:getSessionRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [getSessionRequest setHTTPMethod:@"POST"];
    NSDictionary *cred = @{@"tung_id": _tungId,
                           @"token": _tungToken
                           };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:cred];
    [getSessionRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    [NSURLConnection sendAsynchronousRequest:getSessionRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        //NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        //CLS_LOG(@"response status code: %ld", (long)[httpResponse statusCode]);
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"sessionId"]) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        _sessionId = [responseDict objectForKey:@"sessionId"];
                        //CLS_LOG(@"got new session: %@", _sessionId);
                        _connectionAvailable = [NSNumber numberWithInt:1];
                        // callback
                        callback();
                    });
                }
                else if ([responseDict objectForKey:@"error"]) {
                    CLS_LOG(@"error getting session: response: %@", responseDict);
                    dispatch_async(dispatch_get_main_queue(), ^{
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
                CLS_LOG(@"no response");
            }
            else if (error != nil) {
                //CLS_LOG(@"Error: %@", error);
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"HTML: %@", html);
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                // _tableView.backgroundView = nil;
                UIAlertView *connectionErrorAlert = [[UIAlertView alloc] initWithTitle:@"Connection error" message:[error localizedDescription] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [connectionErrorAlert show];
            });
        }
    }];
}

// if user's token expires, attempt to log them back in without bugging them.
// this happens because a new token is issued on each sign-in (signin != session).
// so if user signed into Tung on a different device, their token here won't work.
-(void) handleUnauthorizedWithCallback:(void (^)(void))callback {
    
    UserEntity *loggedUser = [TungCommonObjects retrieveUserEntityForUserWithId:_tungId];
    if (loggedUser && loggedUser.tung_id) {
        
        // signed up with twitter
        if (loggedUser.twitter_id && [Twitter sharedInstance].session) {
            
            TWTROAuthSigning *oauthSigning = [[TWTROAuthSigning alloc] initWithAuthConfig:[Twitter sharedInstance].authConfig authSession:[Twitter sharedInstance].session];
            
            NSDictionary *authHeaders = [oauthSigning OAuthEchoHeadersToVerifyCredentials];
            [self verifyCredWithTwitterOauthHeaders:authHeaders withCallback:^(BOOL success, NSDictionary *responseDict) {
                // user exists
                if (success && [responseDict objectForKey:@"sessionId"]) {
                    CLS_LOG(@"recovered session with twitter - signed in");
                    _sessionId = [responseDict objectForKey:@"sessionId"];
                    _connectionAvailable = [NSNumber numberWithInt:1];
                    
                    NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                    CLS_LOG(@"lastDataChange (server): %@, lastDataChange (local): %@", lastDataChange, loggedUser.lastDataChange);
                    if (lastDataChange.doubleValue > loggedUser.lastDataChange.doubleValue) {
                        CLS_LOG(@"needs restore. ");
                        [self restorePodcastDataSinceTime:loggedUser.lastDataChange];
                    }
                    
                    // construct token of id and token together and save to keychain
                    [TungCommonObjects deleteCredentials];
                    NSString *tungId = [[[responseDict objectForKey:@"user"] objectForKey:@"_id"] objectForKey:@"$id"];
                    NSString *tungCred = [NSString stringWithFormat:@"%@:%@", tungId, [responseDict objectForKey:@"token"]];
                    [TungCommonObjects saveKeychainCred:tungCred];
                    
                    callback();
                }
            }];
            return;
        }
        // signed up with facebook
        else if (loggedUser.facebook_id && [FBSDKAccessToken currentAccessToken]) {
            
            NSString *tokenString = [[FBSDKAccessToken currentAccessToken] tokenString];
            [self verifyCredWithFacebookAccessToken:tokenString withCallback:^(BOOL success, NSDictionary *responseDict) {
                if (success && [responseDict objectForKey:@"sessionId"]) {
                    CLS_LOG(@"recovered session with facebook - signed in");
                    _sessionId = [responseDict objectForKey:@"sessionId"];
                    _connectionAvailable = [NSNumber numberWithInt:1];
                    
                    NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                    CLS_LOG(@"lastDataChange (server): %@, lastDataChange (local): %@", lastDataChange, loggedUser.lastDataChange);
                    if (lastDataChange.doubleValue > loggedUser.lastDataChange.doubleValue) {
                        CLS_LOG(@"needs restore. ");
                        [self restorePodcastDataSinceTime:loggedUser.lastDataChange];
                    }
                    
                    // construct token of id and token together and save to keychain
                    [TungCommonObjects deleteCredentials];
                    NSString *tungId = [[[responseDict objectForKey:@"user"] objectForKey:@"_id"] objectForKey:@"$id"];
                    NSString *tungCred = [NSString stringWithFormat:@"%@:%@", tungId, [responseDict objectForKey:@"token"]];
                    [TungCommonObjects saveKeychainCred:tungCred];
                    
                    callback();
                }
            }];
            return;
        }
    }
	// if method hasn't returned... force user to sign out and sign in again
    UIAlertView *unauthorizedAlert = [[UIAlertView alloc] initWithTitle:@"Session expired" message:@"Please sign in again." delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    unauthorizedAlert.tag = 99;
    [unauthorizedAlert show];
}


-(void) killSessionForTesting {
    CLS_LOG(@"killing session...");
    NSURL *killSessionRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@app/kill-session.php",_apiRootUrl]];
    NSMutableURLRequest *killSessionRequest = [NSMutableURLRequest requestWithURL:killSessionRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [killSessionRequest setHTTPMethod:@"POST"];
    NSDictionary *cred = @{@"sessionId":_sessionId};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:cred];
    [killSessionRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:killSessionRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        if (jsonData != nil && error == nil) {
            NSDictionary *responseDict = jsonData;
            CLS_LOG(@"	killed session");
            dispatch_async(dispatch_get_main_queue(), ^{
                // notification
                UIAlertView *killedSessionAlert = [[UIAlertView alloc] initWithTitle:@"Killed Session" message:[NSString stringWithFormat:@"session with ID %@ has been killed", [responseDict objectForKey:@"sessionId"]] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [killedSessionAlert show];
            });
        }
    }];
}

/*//////////////////////////////////
 Tung Stories
 /////////////////////////////////*/


- (void) addPodcast:(PodcastEntity *)podcastEntity orEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(void))callback  {
    
    if (!podcastEntity.collectionId) {
        NSLog(@"add podcast entity null: %@", [TungCommonObjects entityToDict:podcastEntity]);
        return;
    }
    
    CLS_LOG(@"add podcast/episode request");
    NSURL *addEpisodeRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/add-podcast.php", _apiRootUrl]];
    NSMutableURLRequest *addEpisodeRequest = [NSMutableURLRequest requestWithURL:addEpisodeRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [addEpisodeRequest setHTTPMethod:@"POST"];
    // optional params
    NSString *email = (podcastEntity.email) ? podcastEntity.email : @"";
    NSString *website = (podcastEntity.website) ? podcastEntity.website : @"";
    
    //CLS_LOG(@"episode entity: %@", episodeEntity);
    //CLS_LOG(@"podcast entity: %@", episodeEntity.podcast);
    NSMutableDictionary *params = [@{@"sessionId":_sessionId,
                                    @"collectionId": podcastEntity.collectionId,
                                    @"collectionName": podcastEntity.collectionName,
                                    @"artistName": podcastEntity.artistName,
                                    @"artworkUrl600": podcastEntity.artworkUrl600,
                                    @"feedUrl": podcastEntity.feedUrl,
                                    @"keyColor1Hex": podcastEntity.keyColor1Hex,
                                    @"keyColor2Hex": podcastEntity.keyColor2Hex,
                                    @"email": email,
                                    @"website": website
                                    } mutableCopy];

    if (episodeEntity) {
        NSDictionary *episodeParams = @{@"GUID": episodeEntity.guid,
                                        @"episodeUrl": episodeEntity.url,
                                        @"episodePubDate": [_ISODateFormatter stringFromDate:episodeEntity.pubDate],
                                        @"episodeTitle": episodeEntity.title
                                        };
        [params addEntriesFromDictionary:episodeParams];
    }
    
    // add content type
    NSString *boundary = [TungCommonObjects generateHash];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [addEpisodeRequest addValue:contentType forHTTPHeaderField:@"Content-Type"];
    // add post body
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    // key value pairs
    [body appendData:[TungCommonObjects generateBodyFromDictionary:params withBoundary:boundary]];
    
    // podcast art
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"podcastArt\"; filename=\"%@\"\r\n", @"art.jpg"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    NSData *podcastArtData = [TungCommonObjects retrievePodcastArtDataWithUrlString:podcastEntity.artworkUrl600 andCollectionId:podcastEntity.collectionId];
    [body appendData:podcastArtData];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // end of body
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [addEpisodeRequest setHTTPBody:body];
    // set the content-length
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
    [addEpisodeRequest setValue:postLength forHTTPHeaderField:@"Content-Length"];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:addEpisodeRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                //CLS_LOG(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self addPodcast:podcastEntity orEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    NSString *artworkUrlSSL = [responseDict objectForKey:@"artworkUrlSSL"];
                    podcastEntity.artworkUrlSSL = artworkUrlSSL;
                    if (episodeEntity) {
                        // save episode id and shortlink
                        NSString *episodeId = [responseDict objectForKey:@"episodeId"];
                        NSString *shortlink = [responseDict objectForKey:@"shortlink"];
                        episodeEntity.id = episodeId;
                        episodeEntity.shortlink = shortlink;
                    }
                    [TungCommonObjects saveContextWithReason:@"got podcast artwork SSL url and/or episode shortlink and id"];
                    callback();
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error. HTML: %@", html);
            }
        });
    }];
}

// if a user deletes the app or signs out, they lose all their subscribe/recommend/progress data.
// also syncs web data with app data
- (void) restorePodcastDataSinceTime:(NSNumber *)time {
    NSURL *restoreRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@app/restore-podcast-data.php", _apiRootUrl]];
    NSMutableURLRequest *restoreRequest = [NSMutableURLRequest requestWithURL:restoreRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [restoreRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"lastDataChange":[NSString stringWithFormat:@"%@", time]
                             };
    CLS_LOG(@"restore podcast data since %@ request", time);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [restoreRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:restoreRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                //CLS_LOG(@"restore podcast response: %@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self restorePodcastDataSinceTime:time];
                        }];
                    }
                    else {
                        CLS_LOG(@"Error: %@", [responseDict objectForKey:@"error"]);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    NSArray *podcasts = [responseDict objectForKey:@"podcasts"];
                    NSArray *episodes = [responseDict objectForKey:@"episodes"];
                    if (podcasts.count) {
                        // restore subscribes
                        for (NSDictionary *podcastDict in podcasts) {
                            [TungCommonObjects getEntityForPodcast:podcastDict save:YES];
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
                            	pEntity = [TungCommonObjects getEntityForPodcast:pDict save:YES];
                            }
                            [TungCommonObjects getEntityForEpisode:eDict withPodcastEntity:pEntity save:NO];
                        }
                        [TungCommonObjects saveContextWithReason:@"episode entities restored"];
                    }
                    CLS_LOG(@"got restore data for %lu podcasts and %lu episodes", (unsigned long)podcasts.count, (unsigned long)episodes.count);
//                    CLS_LOG(@"- script duration: %@", [responseDict objectForKey:@"scriptDuration"]);
//                    CLS_LOG(@"- memory usage: %@", [responseDict objectForKey:@"memoryUsage"]);
//                    CLS_LOG(@"- lastDataChange: %@", [responseDict objectForKey:@"lastDataChange"]);
                    UserEntity *loggedUser = [TungCommonObjects retrieveUserEntityForUserWithId:_tungId];
                    if (loggedUser) {
                        NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                        loggedUser.lastDataChange = lastDataChange;
                        [TungCommonObjects saveContextWithReason:@"updated lastDataChange for restore"];
                    }
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error. HTML: %@", html);
            }
        });
    }];
}

// get shortlink and id for episode, make new record in none exists.
- (void) addEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(void))callback {
    CLS_LOG(@"add episoe request");
    NSURL *getEpisodeInfoRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/add-episode.php", _apiRootUrl]];
    NSMutableURLRequest *getEpisodeInfoRequest = [NSMutableURLRequest requestWithURL:getEpisodeInfoRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [getEpisodeInfoRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": episodeEntity.collectionId,
                             @"GUID": episodeEntity.guid,
                             @"episodeUrl": episodeEntity.url,
                             @"episodePubDate": [_ISODateFormatter stringFromDate:episodeEntity.pubDate],
                             @"episodeTitle": episodeEntity.title
                             };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [getEpisodeInfoRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:getEpisodeInfoRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"error"]) {
                    // no podcast record
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                        __unsafe_unretained typeof(self) weakSelf = self;
                        [self addPodcast:episodeEntity.podcast orEpisode:episodeEntity withCallback:^ {
                            [weakSelf addEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                    else {
                        CLS_LOG(@"Error: %@", [responseDict objectForKey:@"error"]);
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
                CLS_LOG(@"Error. HTML: %@", html);
            }
        });
    }];
}

// SUBSCRIBING
- (void) subscribeToPodcast:(PodcastEntity *)podcastEntity withButton:(CircleButton *)button {
    CLS_LOG(@"subscribe request for podcast with id %@", podcastEntity.collectionId);
    [button setEnabled:NO];
    
    SettingsEntity *settings = [TungCommonObjects settings];
    if (!settings.hasSeenNewEpisodesPrompt.boolValue && ![TungCommonObjects hasGrantedNotificationPermissions]) {
        [self promptForNotificationsForEpisodes];
    }
    
    NSURL *subscribeRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/subscribe.php", _apiRootUrl]];
    NSMutableURLRequest *subscribeRequest = [NSMutableURLRequest requestWithURL:subscribeRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [subscribeRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": podcastEntity.collectionId};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [subscribeRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:subscribeRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                //CLS_LOG(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self subscribeToPodcast:podcastEntity withButton:button];
                        }];
                    }
                    // no podcast record
                    else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                        __unsafe_unretained typeof(self) weakSelf = self;
                        [self addPodcast:podcastEntity orEpisode:nil withCallback:^ {
                            [weakSelf subscribeToPodcast:podcastEntity withButton:button];
                        }];
                    }
                    else {
                        CLS_LOG(@"Error: %@", [responseDict objectForKey:@"error"]);
                        [button setEnabled:YES];
                    }
                }
                // success
                else if ([responseDict objectForKey:@"success"]) {
                    [button setEnabled:YES];
                    NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                    UserEntity *loggedUser = [TungCommonObjects retrieveUserEntityForUserWithId:_tungId];
                    if (loggedUser) {
                        loggedUser.lastDataChange = lastDataChange;
                    }
                    podcastEntity.timeSubscribed = lastDataChange;
                    podcastEntity.isSubscribed = [NSNumber numberWithBool:YES];
                    [TungCommonObjects saveContextWithReason:@"lastDataChange changed for logged in user, subscribe status changed"];
                    // important: do not assign shortlink from subscribe story to episode entity
                }
            }
            else {
                
                [button setEnabled:YES];
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error. HTML: %@", html);
            }
        });
    }];
}

- (void) unsubscribeFromPodcast:(PodcastEntity *)podcastEntity withButton:(CircleButton *)button {
    CLS_LOG(@"unsubscribe request for podcast with id %@", podcastEntity.collectionId);
    [button setEnabled:NO];
    NSURL *unsubscribeFromPodcastRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/unsubscribe.php", _apiRootUrl]];
    NSMutableURLRequest *unsubscribeFromPodcastRequest = [NSMutableURLRequest requestWithURL:unsubscribeFromPodcastRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [unsubscribeFromPodcastRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": podcastEntity.collectionId};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [unsubscribeFromPodcastRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:unsubscribeFromPodcastRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                //CLS_LOG(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self unsubscribeFromPodcast:podcastEntity withButton:button];
                        }];
                    }
                    // no podcast record
                    else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                        __unsafe_unretained typeof(self) weakSelf = self;
                        [self addPodcast:podcastEntity orEpisode:nil withCallback:^ {
                            [weakSelf unsubscribeFromPodcast:podcastEntity withButton:button];
                        }];
                    }
                    else {
                        CLS_LOG(@"Error: %@", [responseDict objectForKey:@"error"]);
                        [button setEnabled:YES];
                    }
                }
                // success
                else if ([responseDict objectForKey:@"success"]) {
                    [button setEnabled:YES];
                    UserEntity *loggedUser = [TungCommonObjects retrieveUserEntityForUserWithId:_tungId];
                    if (loggedUser) {
                        NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                        loggedUser.lastDataChange = lastDataChange;
                    }
                    podcastEntity.timeSubscribed = [NSNumber numberWithInt:0];
                    podcastEntity.isSubscribed = [NSNumber numberWithBool:NO];
                    [TungCommonObjects saveContextWithReason:@"lastDataChange changed for logged in user, subscribe status change"];
                }
            }
            else {
                [button setEnabled:YES];
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error. HTML: %@", html);
            }
        });
    }];
}

/* STORY REQUESTS
 story requests send all episode info (episode entity) if there is no episode ID,
 so that episode record can be created if one doesn't exist yet. ID and shortlink 
 are assigned locally with return data.
 */

// RECOMMENDING
- (void) recommendEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback {

    NSURL *recommendPodcastRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/recommend.php", _apiRootUrl]];
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
                   @"episodePubDate": [_ISODateFormatter stringFromDate:episodeEntity.pubDate],
                   @"episodeTitle": episodeEntity.title
                   };
    }
    //CLS_LOG(@"recommend episode request with params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [recommendPodcastRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:recommendPodcastRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self recommendEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                    // no podcast record
                    else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                        __unsafe_unretained typeof(self) weakSelf = self;
                        [self addPodcast:episodeEntity.podcast orEpisode:episodeEntity withCallback:^ {
                            [weakSelf recommendEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                    else {
                        CLS_LOG(@"Error: %@", [responseDict objectForKey:@"error"]);
                        callback(NO, responseDict);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    CLS_LOG(@"successfully recommended episode");
                    if (!episodeEntity.id) {
                        // save episode id and shortlink
                        NSString *episodeId = [responseDict objectForKey:@"episodeId"];
                        NSString *shortlink = [responseDict objectForKey:@"shortlink"];
                        episodeEntity.id = episodeId;
                        episodeEntity.shortlink = shortlink;
                    }
                    UserEntity *loggedUser = [TungCommonObjects retrieveUserEntityForUserWithId:_tungId];
                    if (loggedUser) {
                        NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                        loggedUser.lastDataChange = lastDataChange;
                    }
                    [TungCommonObjects saveContextWithReason:@"got episode shortlink and id, and lastDataChange"];
                    _feedNeedsRefresh = [NSNumber numberWithBool:YES];
                    _profileFeedNeedsRefresh = [NSNumber numberWithBool:YES];
                    callback(YES, responseDict);
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error. HTML: %@", html);
                callback(NO, @{@"error": @"Unspecified error"});
            }
        });
    }];
}

- (void) unRecommendEpisode:(EpisodeEntity *)episodeEntity {
    NSURL *unRecommendPodcastRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/un-recommend.php", _apiRootUrl]];
    NSMutableURLRequest *unRecommendPodcastRequest = [NSMutableURLRequest requestWithURL:unRecommendPodcastRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [unRecommendPodcastRequest setHTTPMethod:@"POST"];
    NSString *episodeId = (episodeEntity.id) ? episodeEntity.id : @"";
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"episodeId": episodeId
                             };
    
    CLS_LOG(@"un-recommend episode");
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [unRecommendPodcastRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:unRecommendPodcastRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                //CLS_LOG(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self unRecommendEpisode:episodeEntity];
                        }];
                    }
                    else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need episode info"]) {
                        // shouldn't ever happen...
                        __unsafe_unretained typeof(self) weakSelf = self;
                        [self addEpisode:episodeEntity withCallback:^{
                            [weakSelf unRecommendEpisode:episodeEntity];
                        }];
                    }
                    else {
                        CLS_LOG(@"Error: %@", [responseDict objectForKey:@"error"]);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    UserEntity *loggedUser = [TungCommonObjects retrieveUserEntityForUserWithId:_tungId];
                    if (loggedUser) {
                        NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                        loggedUser.lastDataChange = lastDataChange;
                    }
                    [TungCommonObjects saveContextWithReason:@"lastDataChange changed for logged in user"];
                    _feedNeedsRefresh = [NSNumber numberWithBool:YES];
                    _profileFeedNeedsRefresh = [NSNumber numberWithBool:YES];
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error. HTML: %@", html);
            }
        });
    }];
}

// SYNC TRACK PROGRESS WITH SERVER
- (void) syncProgressFromTimer:(NSTimer *)timer {
    [self syncProgressForEpisode:[timer userInfo]];
}
- (void) syncProgressForEpisode:(EpisodeEntity *)episodeEntity {
    
    NSURL *syncProgressRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/save-progress.php", _apiRootUrl]];
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
                   @"episodePubDate": [_ISODateFormatter stringFromDate:episodeEntity.pubDate],
                   @"episodeTitle": episodeEntity.title,
                   @"episodeProgress": episodeEntity.trackProgress,
                   @"episodePosition": episodeEntity.trackPosition
                   };
    }
    
    CLS_LOG(@"sync progress (%f) request", episodeEntity.trackPosition.doubleValue);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [syncProgressRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:syncProgressRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self syncProgressForEpisode:episodeEntity];
                        }];
                    }
                    // no podcast record
                    else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                        __unsafe_unretained typeof(self) weakSelf = self;
                        [self addPodcast:episodeEntity.podcast orEpisode:episodeEntity withCallback:^ {
                            [weakSelf syncProgressForEpisode:episodeEntity];
                        }];
                    }
                    else {
                        CLS_LOG(@"Error: %@", [responseDict objectForKey:@"error"]);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    //CLS_LOG(@"%@", responseDict);
                    if (!episodeEntity.id) {
                        // save episode id and shortlink
                        NSString *episodeId = [responseDict objectForKey:@"episodeId"];
                        NSString *shortlink = [responseDict objectForKey:@"shortlink"];
                        episodeEntity.id = episodeId;
                        episodeEntity.shortlink = shortlink;
                    }
                    UserEntity *loggedUser = [TungCommonObjects retrieveUserEntityForUserWithId:_tungId];
                    if (loggedUser) {
                        NSNumber *lastDataChange = [responseDict objectForKey:@"lastDataChange"];
                        loggedUser.lastDataChange = lastDataChange;
                    }
                    [TungCommonObjects saveContextWithReason:@"save lastDataChange"];
                    _feedNeedsRefresh = [NSNumber numberWithBool:YES];
                    _profileFeedNeedsRefresh = [NSNumber numberWithBool:YES];
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error. HTML: %@", html);
            }
        });
    }];
}

// COMMENTS AND CLIPS
- (void) postComment:(NSString*)comment atTime:(NSString*)timestamp onEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback  {
    //CLS_LOG(@"post comment request");
    NSURL *postCommentRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/new-comment.php", _apiRootUrl]];
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
                   @"episodePubDate": [_ISODateFormatter stringFromDate:episodeEntity.pubDate],
                   @"episodeTitle": episodeEntity.title,
                   @"comment": comment,
                   @"timestamp": timestamp
                   };
    }
    
    //CLS_LOG(@"post comment request w/ params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [postCommentRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:postCommentRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                //CLS_LOG(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self postComment:comment atTime:timestamp onEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                    // no podcast record
                    else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                        __unsafe_unretained typeof(self) weakSelf = self;
                        [self addPodcast:episodeEntity.podcast orEpisode:episodeEntity withCallback:^ {
                            [weakSelf postComment:comment atTime:timestamp onEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                    else {
                        CLS_LOG(@"Error: %@", [responseDict objectForKey:@"error"]);
                        callback(NO, responseDict);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    CLS_LOG(@"successfully posted comment");
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
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error. HTML: %@", html);
                callback(NO, @{@"error": @"Unspecified error"});
            }
        });
    }];
}

- (void) postClipWithComment:(NSString*)comment atTime:(NSString*)timestamp withDuration:(NSString *)duration onEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback  {
    //CLS_LOG(@"post clip request");
    NSURL *postClipRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/new-clip.php", _apiRootUrl]];
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
                   @"episodePubDate": [_ISODateFormatter stringFromDate:episodeEntity.pubDate],
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
        
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                //CLS_LOG(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self postClipWithComment:comment atTime:timestamp withDuration:duration onEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                    // no podcast record
                    else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                        __unsafe_unretained typeof(self) weakSelf = self;
                        [self addPodcast:episodeEntity.podcast orEpisode:episodeEntity withCallback:^ {
                            [weakSelf postClipWithComment:comment atTime:timestamp withDuration:duration onEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                    else {
                        CLS_LOG(@"Error: %@", [responseDict objectForKey:@"error"]);
                        callback(NO, responseDict);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    CLS_LOG(@"successfully posted clip");
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
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error. HTML: %@", html);
                callback(NO, @{@"error": @"Unspecified error"});
            }
        });
    }];
}

- (void) deleteStoryEventWithId:(NSString *)eventId withCallback:(void (^)(BOOL success))callback  {
    CLS_LOG(@"delete story event with id: %@", eventId);
    NSURL *deleteEventRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/delete-story-event.php", _apiRootUrl]];
    NSMutableURLRequest *deleteEventRequest = [NSMutableURLRequest requestWithURL:deleteEventRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [deleteEventRequest setHTTPMethod:@"POST"];
    
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"eventId": eventId
                             };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [deleteEventRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:deleteEventRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self deleteStoryEventWithId:eventId withCallback:callback];
                        }];
                    }
                    else {
                        CLS_LOG(@"Error: %@", [responseDict objectForKey:@"error"]);
                        callback(NO);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    CLS_LOG(@"successfully deleted story event");
                    callback(YES);
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error. HTML: %@", html);
                callback(NO);
            }
        });
    }];
}

- (void) flagCommentWithId:(NSString *)eventId {
    CLS_LOG(@"flag comment with id: %@", eventId);
    NSURL *flagCommentRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/flag.php", _apiRootUrl]];
    NSMutableURLRequest *flagCommentRequest = [NSMutableURLRequest requestWithURL:flagCommentRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [flagCommentRequest setHTTPMethod:@"POST"];
    
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"eventId": eventId
                             };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [flagCommentRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:flagCommentRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self flagCommentWithId:eventId];
                        }];
                    }
                    else {
                        CLS_LOG(@"Error: %@", [responseDict objectForKey:@"error"]);
                        UIAlertView *errorFlaggingAlert = [[UIAlertView alloc] initWithTitle:@"Error flagging" message:[responseDict objectForKey:@"error"] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                        [errorFlaggingAlert show];
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    CLS_LOG(@"successfully flagged comment - %@", responseDict);
                    
                    UIAlertView *successfullyFlaggedAlert = [[UIAlertView alloc] initWithTitle:@"Successfully flagged" message:@"This comment will be moderated. Thank you for your feedback." delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                    [successfullyFlaggedAlert show];
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error. HTML: %@", html);
            }
        });
    }];
}

// for getting episode and podcast entities
-(void) requestEpisodeInfoForId:(NSString *)episodeId andCollectionId:(NSString *)collectionId withCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    //CLS_LOG(@"requesting episode info");
    //NSDate *requestStart = [NSDate date];
    NSURL *episodeInfoURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/episode-info.php", _apiRootUrl]];
    NSMutableURLRequest *feedRequest = [NSMutableURLRequest requestWithURL:episodeInfoURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [feedRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{
                             @"sessionId": _sessionId,
                             @"episodeId": episodeId,
                             @"collectionId": collectionId
                             };
    //CLS_LOG(@"request for episodeInfo with params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [feedRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:feedRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {

        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"error"]) {
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self requestEpisodeInfoForId:episodeId andCollectionId:collectionId withCallback:callback];
                        }];
                    }
                    else {
                        CLS_LOG(@"Error requesting episode info: %@", [responseDict objectForKey:@"error"]);
                        callback(NO, responseDict);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    //NSTimeInterval requestDuration = [requestStart timeIntervalSinceNow];
                    //CLS_LOG(@"successfully retrieved episode info in %f seconds", fabs(requestDuration));
                    callback(YES, responseDict);
                }
            }
            else if (error != nil) {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error requesting episode info. HTML: %@", html);
                callback(NO, @{@"error": @"Unspecified error"});
            }
        });
    }];
}

/*//////////////////////////////////
 Users
 /////////////////////////////////*/


- (void) getProfileDataForUser:(NSString *)target_id withCallback:(void (^)(NSDictionary *jsonData))callback {
    CLS_LOG(@"getting user profile data for id: %@", target_id);
    NSURL *getProfileDataRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/profile.php", _apiRootUrl]];
    NSMutableURLRequest *getProfileDataRequest = [NSMutableURLRequest requestWithURL:getProfileDataRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [getProfileDataRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"target_user_id": target_id};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [getProfileDataRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:getProfileDataRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        if (jsonData != nil && error == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                NSDictionary *responseDict = jsonData;
                if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                    // get new session and re-request
                    CLS_LOG(@"SESSION EXPIRED");
                    [self getSessionWithCallback:^{
                        [self getProfileDataForUser:target_id withCallback:callback];
                    }];
                }
                else {
            		callback(responseDict);
                }
            });
        }
        else {
            NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            CLS_LOG(@"HTML: %@", html);
        }
    }];
}


- (void) updateUserWithDictionary:(NSDictionary *)userInfo withCallback:(void (^)(NSDictionary *jsonData))callback {
    CLS_LOG(@"update user with dictionary: %@", userInfo);
    
    NSURL *updateUserRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/update-user.php", _apiRootUrl]];
    NSMutableURLRequest *updateUserRequest = [NSMutableURLRequest requestWithURL:updateUserRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [updateUserRequest setHTTPMethod:@"POST"];
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:userInfo];
    [params setObject:_sessionId forKey:@"sessionId"];
    
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [updateUserRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:updateUserRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"error"]) {
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
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
                    CLS_LOG(@"user updated successfully: %@", responseDict);
                    callback(responseDict);
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"HTML: %@", html);
            }
        });
    }];
}

- (void) followUserWithId:(NSString *)target_id withCallback:(void (^)(BOOL success))callback {
    CLS_LOG(@"follow user with id: %@", target_id);
    NSURL *followUserRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/follow.php", _apiRootUrl]];
    NSMutableURLRequest *followUserRequest = [NSMutableURLRequest requestWithURL:followUserRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [followUserRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"target_user_id": target_id};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [followUserRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:followUserRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"error"]) {
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self followUserWithId:target_id withCallback:^(BOOL success) {
                                callback(success);
                            }];
                        }];
                    } else {
                        callback(NO);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    callback(YES);
                } else {
                    callback(NO);
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"HTML: %@", html);
                callback(NO);
            }
        });
    }];
    
}
- (void) unfollowUserWithId:(NSString *)target_id withCallback:(void (^)(BOOL success))callback {
    CLS_LOG(@"UN-follow user with id: %@", target_id);
    NSURL *unfollowUserRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/unfollow.php", _apiRootUrl]];
    NSMutableURLRequest *unfollowUserRequest = [NSMutableURLRequest requestWithURL:unfollowUserRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [unfollowUserRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"target_user_id": target_id};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [unfollowUserRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:unfollowUserRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"error"]) {
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self unfollowUserWithId:target_id withCallback:^(BOOL success) {
                                callback(success);
                            }];
                        }];
                    } else {
                        callback(NO);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    callback(YES);
                } else {
                    callback(NO);
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"HTML: %@", html);
                callback(NO);
            }
        });
    }];
}

// for beta period
- (void) followAllUsersFromId:(NSString *)user_id withCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    CLS_LOG(@"follow all users with id: %@", user_id);
    NSURL *followAllUsersRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/follow-all.php", _apiRootUrl]];
    NSMutableURLRequest *followAllUsersRequest = [NSMutableURLRequest requestWithURL:followAllUsersRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [followAllUsersRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"new_user_id": user_id};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [followAllUsersRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:followAllUsersRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"error"]) {
                    callback(NO, [responseDict objectForKey:@"error"]);
                }
                else if ([responseDict objectForKey:@"success"]) {
                    callback(YES, [responseDict objectForKey:@"success"]);
                } else {
                    callback(NO, @{@"error": @"unspecified error"});
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"HTML: %@", html);
                callback(NO, @{@"error": @"unspecified error"});
            }
        });
    }];
}

- (void) inviteFriends:(NSString *)friends {
    CLS_LOG(@"send invite friends request");
    NSURL *inviteFriendsRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/invite-friends.php", _apiRootUrl]];
    NSMutableURLRequest *inviteFriendsRequest = [NSMutableURLRequest requestWithURL:inviteFriendsRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [inviteFriendsRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId": _sessionId,
                             @"friends": friends
                             };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [inviteFriendsRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:inviteFriendsRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"error"]) {
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        CLS_LOG(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self inviteFriends:friends];
                        }];
                    } else {
                    	CLS_LOG(@"Error inviting friends: %@", [responseDict objectForKey:@"error"]);
                        UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Oops..." message:[responseDict objectForKey:@"error"] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                        [errorAlert show];
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    CLS_LOG(@"Successfully invited friends: %@", responseDict);
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                CLS_LOG(@"Error: %@", html);
                UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"An error occurred" message:@"Sorry, something went wrong with your request" delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [errorAlert show];
            }
        });
    }];
}

-(void) signOut {
    CLS_LOG(@"--- signing out");
    
    [self playerPause];
    [_syncProgressTimer invalidate];
    _playQueue = [@[] mutableCopy];
    _npEpisodeEntity = nil;
    
    [self resetPlayer];
    
    //[self deleteLoggedInUserData];
    [TungCommonObjects removeAllUserData];
    [TungCommonObjects removePodcastAndEpisodeData];
    
    // session
    _tungId = @"";
    _tungToken = @"";
    _sessionId = @"";
    
    // twitter
    [[Twitter sharedInstance] logOut];
    
    // delete cred
    [TungCommonObjects deleteCredentials];
    
    // close FB session if open
    if ([FBSDKAccessToken currentAccessToken]) {
    	[[FBSDKLoginManager new] logOut];
    }
    
    // clear temp directory
    [TungCommonObjects clearTempDirectory];
    
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

#pragma mark Twitter

- (void) establishTwitterAccount {
    CLS_LOG(@"establish twitter account");
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
        if (!granted) {
            CLS_LOG(@"twitter access denied");
            dispatch_async(dispatch_get_main_queue(), ^{
                // alert user
                UIAlertView *deniedAccessToTwitterAlert = [[UIAlertView alloc] initWithTitle:@"No Twitter Access" message:@"To give Tung access to your Twitter accounts, go to Settings > Twitter and turn on access for Tung." delegate:_viewController cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [deniedAccessToTwitterAlert show];
                self.twitterAccountStatus = @"failed";
            });
        } else {
            // permission to use twitter granted, determine which account to use
            dispatch_async(dispatch_get_main_queue(), ^{
                //
                _arrayOfTwitterAccounts = [accountStore accountsWithAccountType:accountType];
                if ([_arrayOfTwitterAccounts count] > 0) {
                    // first check if userData has a twitter id
                    NSDictionary *userData = [self getLoggedInUserData];
                    if (userData && [userData objectForKey:@"twitter_username"] != (id)[NSNull null]) {
                        NSString *twitter_username = [userData objectForKey:@"twitter_username"];
                        CLS_LOG(@"twitter username found in logged-in user data: %@", twitter_username);
                        for (ACAccount *acct in _arrayOfTwitterAccounts) {
                            if ([acct.username isEqualToString:twitter_username]) {
                                _twitterAccountToUse = acct;
                                [self updateUserDataWithTwitterAccount];
                            }
                        }
                        if (_twitterAccountToUse == NULL) [self determineTwitterAccountToUse];
                        
                    }
                    // if not, determine account to use and store it.
                    else {
                        [self determineTwitterAccountToUse];
                    }
                }
                else {
                    UIAlertView *noTwitterAccountAlert = [[UIAlertView alloc] initWithTitle:@"No Twitter Accounts" message:@"It appears you haven't added any Twitter accounts to your phone yet. You can add one in Settings > Twitter. " delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [noTwitterAccountAlert show];
                    self.twitterAccountStatus = @"failed";
                }
            });
        }
    }];
}

- (void) determineTwitterAccountToUse {
    CLS_LOG(@"determine twitter account to use");
    if ([_arrayOfTwitterAccounts count] > 1) {
        // show action sheet allowing user to choose which twitter account they want to use
        UIActionSheet *accountOptionsSheet = [[UIActionSheet alloc] initWithTitle:@"Which account would you like to use?" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
        accountOptionsSheet.tag = 89;
        for (ACAccount *acct in _arrayOfTwitterAccounts) {
            [accountOptionsSheet addButtonWithTitle:[NSString stringWithFormat:@"@%@", acct.username]];
        }
        [accountOptionsSheet showInView:_viewController.view];
        
    } else {
        //CLS_LOG(@"only 1 account. established twitter account.");
        _twitterAccountToUse = [_arrayOfTwitterAccounts lastObject];
        [self updateUserDataWithTwitterAccount];
    }
}

- (void) updateUserDataWithTwitterAccount {
    self.twitterAccountStatus = @"success"; // needs "self" for observer to work
    CLS_LOG(@"update user data with twitter account");
    // update user record if we've established user ID
    if (_tungId) {
        NSMutableDictionary *userData = [[self getLoggedInUserData] mutableCopy];
        if (userData != NULL) {
            [userData setObject:_twitterAccountToUse.username forKey:@"twitter_username"];
            [TungCommonObjects saveUserWithDict:userData];
        }
    }
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
    
    NSURLRequest *request = [[[Twitter sharedInstance] APIClient] URLRequestWithMethod:@"POST" URL:updateStatusEndpoint parameters:tweetParams error:&clientError];
    
    if (request) {
        [client sendTwitterRequest:request completion:^(NSURLResponse *urlResponse, NSData *data, NSError *connectionError) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)urlResponse;
            long responseCode =  (long)[httpResponse statusCode];
            if (responseCode == 200) {
                CLS_LOG(@"tweet posted");
            }
            
            CLS_LOG(@"Twitter HTTP response: %li", responseCode);
            if (connectionError != nil) {
                CLS_LOG(@"Error: %@", connectionError);
            }
        }];
    }
    else {
        CLS_LOG(@"Error: %@", clientError);
    }
    
}

#pragma mark - Facebook sharing and share delegate methods

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
        CLS_LOG(@"facebook share result: %@", result);
    }];

}

- (void) sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary *)results {
    
    CLS_LOG(@"successfully shared story to FB. results: %@", results);
}

- (void) sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error {
    
    CLS_LOG(@"failed to share to FB. Error: %@", error);
}

- (void) sharerDidCancel:(id<FBSDKSharing>)sharer {
    
    CLS_LOG(@"FB sharing cancelled");
    
}


#pragma mark - handle alerts

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    CLS_LOG(@"dismissed alert with button index: %ld", (long)buttonIndex);
    // search prompt
    if (alertView.tag == 10 && buttonIndex) {
        if ([_ctrlBtnDelegate respondsToSelector:@selector(initiateSearch)]) {
            [_ctrlBtnDelegate initiateSearch];
        }
    }
    // notification permissions - new episodes
    if (alertView.tag == 20) {
        
        SettingsEntity *settings = [TungCommonObjects settings];
        settings.hasSeenNewEpisodesPrompt = [NSNumber numberWithBool:YES];
        [TungCommonObjects saveContextWithReason:@"settings changed"];
        
        if (buttonIndex == 1) {
            [[UIApplication sharedApplication] registerForRemoteNotifications];
            [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeBadge categories:nil]];
        }
    }
    // notification permissions - mentions
    if (alertView.tag == 21) {
        
        SettingsEntity *settings = [TungCommonObjects settings];
        settings.hasSeenMentionsPrompt = [NSNumber numberWithBool:YES];
        [TungCommonObjects saveContextWithReason:@"settings changed"];
        
        if (buttonIndex == 1) {
            [[UIApplication sharedApplication] registerForRemoteNotifications];
            [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeBadge categories:nil]];
        }
    }
    // unauthorized alert
    if (alertView.tag == 99) {
        [self signOut];
    }
}

- (void) promptForNotificationsForEpisodes {
    
    UIAlertView *notifPermissionAlert = [[UIAlertView alloc] initWithTitle:@"New Episodes" message:@"Tung can notify you when new episodes are released for podcasts you subscribe to, based on your preference for each podcast. Would you like to receive notifications?" delegate:self cancelButtonTitle:nil otherButtonTitles:@"No", @"Yes", nil];
    [notifPermissionAlert setTag:20];
    [notifPermissionAlert show];
}
- (void) promptForNotificationsForMentions {
    
    UIAlertView *notifPermissionAlert = [[UIAlertView alloc] initWithTitle:@"User Mentions" message:@"Tung can notify you when someone mentions you in a comment, or when new episodes are released for podcasts you subscribe to. Would you like to receive notifications?" delegate:self cancelButtonTitle:nil otherButtonTitles:@"No", @"Yes", nil];
    [notifPermissionAlert setTag:21];
    [notifPermissionAlert show];
}

#pragma mark - handle actionsheet

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    //CLS_LOG(@"dismissed action sheet with button: %ld", (long)buttonIndex);
    
    // sign out
    if (actionSheet.tag == 99) {
        
        if (buttonIndex == 0)
            [self signOut];
    }
    // chose twitter account
    if (actionSheet.tag == 89) {
        
        _twitterAccountToUse = [_arrayOfTwitterAccounts objectAtIndex:buttonIndex];
        //CLS_LOG(@"chose account with username: %@", _twitterAccountToUse.username);
        [self updateUserDataWithTwitterAccount];
        
    }
}

#pragma mark - Caching

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

// for podcast art that is saved in tung CDN
+ (NSData*) retrieveSSLPodcastArtDataWithUrlString:(NSString *)urlString {
    
    NSString *podcastArtDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SSLPodcastArt"];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:podcastArtDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        // SSL podcast art uses the collection ID as the filename
        NSString *artFilename = [urlString lastPathComponent];
        NSString *artFilepath = [podcastArtDir stringByAppendingPathComponent:artFilename];
        NSData *artImageData;
        if ([[NSFileManager defaultManager] fileExistsAtPath:artFilepath]) {
            artImageData = [NSData dataWithContentsOfFile:artFilepath];
        } else {
            artImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString: urlString]];
            [artImageData writeToFile:artFilepath atomically:YES];
        }
        return artImageData;
    }
    return nil;
}

// for podcast art url from feed
+ (NSData*) retrievePodcastArtDataWithUrlString:(NSString *)urlString andCollectionId:(NSNumber *)collectionId {
    
    NSString *podcastArtDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"podcastArt"];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:podcastArtDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        
        NSString *extension = [[urlString lastPathComponent] pathExtension];
        if (!extension) extension = @"jpg";
        NSString *artFilename = [NSString stringWithFormat:@"%@.%@", collectionId, extension];
        NSString *artFilepath = [podcastArtDir stringByAppendingPathComponent:artFilename];
        NSData *artImageData;
        if ([[NSFileManager defaultManager] fileExistsAtPath:artFilepath]) {
            artImageData = [NSData dataWithContentsOfFile:artFilepath];
        } else {
            artImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString: urlString]];
            [artImageData writeToFile:artFilepath atomically:YES];
        }
        return artImageData;
    }
    return nil;
}

+ (NSURL *) getClipFileURL {
    
    NSString *clipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"recording.m4a"];
    return [NSURL fileURLWithPath:clipFilePath];
}

+ (NSString *) getAlbumArtFilenameFromUrlString:(NSString *)artURLString {
    NSArray *components = [artURLString pathComponents];
    return [NSString stringWithFormat:@"%@%@", components[components.count-2], components[components.count-1]];
}

#pragma mark - class methods

+ (void)clearTempDirectory {
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
    for (NSString *file in tmpDirectory) {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), file] error:NULL];
    }
    CLS_LOG(@"cleared temporary directory");
}

+ (void) checkReachabilityWithCallback:(void (^)(BOOL reachable))callback {
    
    Reachability *internetReachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus netStatus = [internetReachability currentReachabilityStatus];

    switch (netStatus) {
        default: {
            callback(NO);
            break;
        }
        case NotReachable: {
            CLS_LOG(@"Network not reachable");
            callback(NO);
            break;
        }
        case ReachableViaWWAN:
            //CLS_LOG(@"Network reachable via cellular data");
            callback(YES);
            break;
        case ReachableViaWiFi:
            //CLS_LOG(@"Network reachable via wifi");
            callback(YES);
            break;
    }
}

/*
 // always reports no connection
- (void) checkTungReachability {
    // causes long pause
    CLS_LOG(@"checking tung reachability against %@", _apiRootUrl);
    Reachability *tungReachability = [Reachability reachabilityWithHostName:_apiRootUrl];
    NetworkStatus tungStatus = [tungReachability currentReachabilityStatus];
    switch (tungStatus) {
        case NotReachable: {
            CLS_LOG(@"TUNG not reachable");
            UIAlertView *unavailableAlert = [[UIAlertView alloc] initWithTitle:@"Unavailable" message:@"tung is currently unavailable, please try again later." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [unavailableAlert show];
            break;
        }
        case ReachableViaWWAN:
            CLS_LOG(@"TUNG reachable via cellular data");
            break;
        case ReachableViaWiFi:
            CLS_LOG(@"TUNG reachable via wifi");
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

// get keychain credentials
+ (NSString *) getKeychainCred {
    
    NSString *key = @"tung credentials";
    NSString *service = [[NSBundle mainBundle] bundleIdentifier];
    NSDictionary *query = @{
                            (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService : service,
                            (__bridge id)kSecAttrAccount : key,
                            (__bridge id)kSecReturnData : (__bridge id)kCFBooleanTrue,
                            (__bridge id)kSecAttrSynchronizable : (__bridge id)kCFBooleanTrue
                            };
    CFDataRef cfValue = NULL;
    OSStatus results = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&cfValue);
    
    if (results == errSecSuccess) {
        //CLS_LOG(@"credentials found");
        NSString *tungCred = [[NSString alloc] initWithData:(__bridge_transfer NSData *)cfValue encoding:NSUTF8StringEncoding];
        return tungCred;
    } else {
    	//CLS_LOG(@"No cred found. Code: %ld", (long)results);
        return NULL;
    }
}

// save cred to keychain
+ (void) saveKeychainCred: (NSString *)cred {
    
    NSString *key = @"tung credentials";
    NSData *valueData = [cred dataUsingEncoding:NSUTF8StringEncoding];
    NSString *service = [[NSBundle mainBundle] bundleIdentifier];
    
    NSDictionary *id_security_item = @{
                                       (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
                                       (__bridge id)kSecAttrService : service,
                                       (__bridge id)kSecAttrAccount : key,
                                       (__bridge id)kSecValueData : valueData,
                                       (__bridge id)kSecAttrSynchronizable : (__bridge id)kCFBooleanTrue // iCloud sync
                                       };
    CFTypeRef result = NULL;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)id_security_item, &result);
    
    if (status == errSecSuccess) {
        //CLS_LOG(@"successfully stored credentials");
    } else {
        CLS_LOG(@"Failed to store cred with code: %ld", (long)status);
    }
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
//    CLS_LOG(@"serialize params for post request:");
//    CLS_LOG(@"%@", paramArray);
    NSString *resultString = [paramArray componentsJoinedByString:@"&"];
    return [resultString dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSString *) serializeParamsForGetRequest:(NSDictionary *)params {
    
    NSArray *paramArray = [self createEncodedArrayOfParams:params];
    return [NSString stringWithFormat:@"?%@", [paramArray componentsJoinedByString:@"&"]];
}

+ (void) deleteCredentials {
    
    // delete credentials from keychain
    NSString *key = @"tung credentials";
    NSString *service = [[NSBundle mainBundle] bundleIdentifier];
    
    NSDictionary *deleteQuery = @{
                                  (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
                                  (__bridge id)kSecAttrService : service,
                                  (__bridge id)kSecAttrAccount : key,
                                  (__bridge id)kSecAttrSynchronizable : (__bridge id)kCFBooleanTrue // iCloud sync
                                  };
    OSStatus foundExisting = SecItemCopyMatching((__bridge CFDictionaryRef)deleteQuery, NULL);
    if (foundExisting == errSecSuccess) {
        OSStatus deleted = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
        if (deleted == errSecSuccess) {
            CLS_LOG(@"deleted keychain cred");
        }
    }
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

+ (NSString *)OSStatusToStr:(OSStatus)status {
    
    switch (status) {
        case 0:
            return @"success";
            
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
            return [NSString stringWithFormat:@"unknown error: %d", (int)status];
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


+ (NSInteger) getIndexOfEpisodeWithUrl:(NSString *)urlString inFeed:(NSArray *)feed {
    NSInteger feedIndex = -1;
    for (int i = 0; i < feed.count; i++) {
        NSString *url = [[[[feed objectAtIndex:i] objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"url"];
        if ([url isEqualToString:urlString]) {
            feedIndex = i;
            break;
        }
    }
    return feedIndex;
}

+ (BOOL) hasGrantedNotificationPermissions {
    return [[UIApplication sharedApplication] currentUserNotificationSettings].types;
}

@end
