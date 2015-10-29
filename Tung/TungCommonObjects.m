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
#import "ALDisk.h"
#import "CCColorCube.h"
#import "TungPodcast.h"

#import <MobileCoreServices/MobileCoreServices.h> // for AVURLAsset resource loading

@interface TungCommonObjects()

// Private properties and methods

@property NSArray *currentFeed;

- (void) playQueuedPodcast;

// not used
- (NSString *) getPlayQueuePath;
- (void) savePlayQueue;
- (void) readPlayQueueFromDisk;

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSMutableArray *pendingRequests;

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
        
        NSLog(@"init tung objects");
        _sessionId = @"";
        _tung_version = @"0.1.0";
        //_apiRootUrl = @"https://api.tung.fm/";
        _apiRootUrl = @"https://staging-api.tung.fm/";
        _tungSiteRootUrl = @"https://tung.fm/";
        _twitterApiRootUrl = @"https://api.twitter.com/1.1/";
        // refresh feed flag
        _feedNeedsRefresh = [NSNumber numberWithBool:NO];
        // colors
        _tungColor = [UIColor colorWithRed:87.0/255 green:90.0/255 blue:215.0/255 alpha:1];
        _lightTungColor = [UIColor colorWithRed:238.0/255 green:239.0/255 blue:251.0/255 alpha:1];
        _mediumTungColor = [UIColor colorWithRed:115.0/255 green:126.0/255 blue:231.0/255 alpha:1];
        _darkTungColor = [UIColor colorWithRed:58.0/255 green:65.0/255 blue:175.0/255 alpha:1];
        _bkgdGrayColor = [UIColor colorWithRed:230.0/255.0 green:230.0/255.0 blue:230.0/255.0 alpha:1];
        _facebookColor = [UIColor colorWithRed:61.0/255 green:90.0/255 blue:152.0/255 alpha:1];
        _twitterColor = [UIColor colorWithRed:42.0/255 green:169.0/255 blue:224.0/255 alpha:1];
        
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
        [commandCenter.seekForwardCommand addTarget:self action:@selector(playNextEpisode)];
        [commandCenter.seekBackwardCommand addTarget:self action:@selector(seekBack)];
        [commandCenter.previousTrackCommand addTarget:self action:@selector(playPreviousEpisode)];
        [commandCenter.nextTrackCommand addTarget:self action:@selector(playNextEpisode)];
        
        

        // show what's in documents dir
        /*
        NSError *fError = nil;
        NSArray *folders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSArray *appFolderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[folders objectAtIndex:0] error:&fError];
        NSLog(@"documents folder contents ---------------");
        if ([appFolderContents count] > 0 && fError == nil) {
            for (NSString *item in appFolderContents) {
                NSLog(@"- %@", item);
            }
        }
         */
        
        // show what's in temp dir
        /*
         NSError *ftError = nil;
         NSArray *tmpFolderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:&ftError];
         NSLog(@"temp folder contents ---------------");
         if ([tmpFolderContents count] > 0 && ftError == nil) {
             for (NSString *item in tmpFolderContents) {
             	NSLog(@"- %@", item);
             }
         }
         */
        
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
        NSLog(@"Found now playing episode");
        _npEpisodeEntity = [npResult lastObject];
        NSURL *url = [NSURL URLWithString:_npEpisodeEntity.url];
        _playQueue = [@[url] mutableCopy];
        [self setControlButtonStateToPlay];
    } else {
        NSLog(@"no episode playing yet");
        _playQueue = [NSMutableArray array];
        [self setControlButtonStateToAdd];
    }
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
    if (_player) {
        [_player removeObserver:self forKeyPath:@"status"];
        [_player removeObserver:self forKeyPath:@"currentItem.playbackLikelyToKeepUp"];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:_player.currentItem];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:_player.currentItem];
        [_player cancelPendingPrerolls];
        _player = nil;
    }
    [self checkForNowPlaying];
}

#pragma mark - Player instance methods

- (BOOL) isPlaying {
    //NSLog(@"is playing at rate: %f", _player.rate);
    return (_player && _player.rate > 0.0f);
}
- (void) playerPlay {
    if (_player && _playQueue.count > 0) {
        [_player play];
        _shouldStayPaused = NO;
        [self setControlButtonStateToPause];
    }
}
- (void) playerPause {
    if ([self isPlaying]) {
        [_player pause];
        _shouldStayPaused = YES;
        [self setControlButtonStateToPlay];
        [self savePositionForNowPlaying];
        // see if file is cached yet, so player can switch to local file
        if (_fileIsStreaming && _fileIsLocal) {
            CMTime currentTime = _player.currentTime;
            [self replacePlayerItemWithLocalCopy];
            _shouldStayPaused = YES;
            [_player seekToTime:currentTime completionHandler:^(BOOL finished) {
                [_player pause];
            }];
        }
    }
}
- (void) seekBack {
    float currentTimeSecs = CMTimeGetSeconds(_player.currentTime);
    if (currentTimeSecs < 3) {
        [self playPreviousEpisode];
    } else {
        CMTime time = CMTimeMake(0, 1);
        [self seekToTime:time];
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
    // need to wait until player is playing to get duration or app freezes
    NSLog(@"determineTotalSeconds");
    if ([self isPlaying]) {
        NSLog(@"determined total seconds.");
        _totalSeconds = CMTimeGetSeconds(_player.currentItem.asset.duration);
        [_trackInfo setObject:[NSNumber numberWithFloat:_totalSeconds] forKey:MPMediaItemPropertyPlaybackDuration];
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:_trackInfo];
    }
    else if (_totalSeconds == 0) {
        [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(determineTotalSeconds) userInfo:nil repeats:NO];
    }
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    //NSLog(@"observe value for key path: %@", keyPath);
    if (object == _player && [keyPath isEqualToString:@"status"]) {
        
        switch (_player.status) {
            case AVPlayerStatusFailed:
                NSLog(@"-- AVPlayer status: Failed");
                [self ejectCurrentEpisode];
                [self setControlButtonStateToAdd];
                break;
            case AVPlayerStatusReadyToPlay:
                NSLog(@"-- AVPlayer status: ready to play");
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
                    
                    NSLog(@"seeking to time: %f", secs);
                    [_trackInfo setObject:[NSNumber numberWithFloat:secs] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
                    [_player seekToTime:time completionHandler:^(BOOL finished) {
                        [self playerPlay];
                        
                    }];
                } else {
                    NSLog(@"play from beginning");
                    [_trackInfo setObject:[NSNumber numberWithFloat:0] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
                    //[self playerPlay];
                    
                    [_player prerollAtRate:1.0 completionHandler:^(BOOL finished) {
                        NSLog(@"-- finished preroll: %d", finished);
                        if ([self isPlaying]) {
                            NSLog(@"started playing");
                            [self setControlButtonStateToPause];
                        } else {
                            NSLog(@"not yet playing, play");
                            [self playerPlay];
                        }
                    }];
                    
                }
                break;
            case AVPlayerItemStatusUnknown:
                NSLog(@"-- AVPlayer status: Unknown");
                break;
            default:
                break;
        }
    }
    if (object == _player && [keyPath isEqualToString:@"currentItem.playbackLikelyToKeepUp"]) {
        
        if (_player.currentItem.playbackLikelyToKeepUp) {
            NSLog(@"-- player likely to keep up");
            
            if (_totalSeconds == 0) [self determineTotalSeconds];

            float currentSecs = CMTimeGetSeconds(_player.currentTime);
            //NSLog(@"current secs: %f, total secs: %f", currentSecs, _totalSeconds);
            if (_totalSeconds > 0 && currentSecs >= _totalSeconds) {
                [self completedPlayback];
                return;
            }
            
            if ([self isPlaying]) {
                [self setControlButtonStateToPause];
            }
            else if (!_shouldStayPaused && ![self isPlaying]) {
                [self playerPlay];
            }
            
        } else {
            NSLog(@"-- player NOT likely to keep up");
            if ([self isPlaying]) [self setControlButtonStateToBuffering];
        }
    }
    /*
    if (object == _player && [keyPath isEqualToString:@"currentItem.loadedTimeRanges"]) {
        NSArray *timeRanges = (NSArray *)[change objectForKey:NSKeyValueChangeNewKey];
        if (timeRanges && [timeRanges count]) {
            CMTimeRange timerange = [[timeRanges objectAtIndex:0] CMTimeRangeValue];
            NSLog(@" . . . %.5f -> %.5f", CMTimeGetSeconds(timerange.start), CMTimeGetSeconds(CMTimeAdd(timerange.start, timerange.duration)));
        }
    }
    if (object == _player && [keyPath isEqualToString:@"currentItem.playbackBufferEmpty"]) {
        
        if (_player.currentItem.playbackBufferEmpty) {
            NSLog(@"-- playback buffer empty");
            [self setControlButtonStateToBuffering];
        }
    }*/
}

- (void) controlButtonTapped {
    
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
        if ([_ctrlBtnDelegate respondsToSelector:@selector(initiateSearch)]) {
        	[_ctrlBtnDelegate initiateSearch];
        }
    }
    
}

- (void) seekToTime:(CMTime)time {
    // disable posbar and show spinner while player seeks
    if (_fileIsStreaming) {
        // see if file is cached yet
        if (_fileIsLocal) {
            [self replacePlayerItemWithLocalCopy];
        } else {
            [self playerPause];
        }
    }
    [_player seekToTime:time];
}


// for dismissing search from main tab bar by tapping icon
- (void) dismissSearch {
    if (_ctrlBtnDelegate && [_ctrlBtnDelegate respondsToSelector:@selector(dismissPodcastSearch)]) {
        [_ctrlBtnDelegate dismissPodcastSearch];
    }
}

- (void) queueAndPlaySelectedEpisode:(NSString *)urlString {
    
    // url and file
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *fileName = [url lastPathComponent];
    NSString *fileType = [fileName pathExtension];
    //NSLog(@"play file of type: %@", fileType);
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
                [_playQueue insertObject:url atIndex:0];
                [self savePlayQueue];
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
            [self savePlayQueue];
            [self playQueuedPodcast];
        }
    }
}

- (void) playQueuedPodcast {
    
    if (_playQueue.count > 0) {
        NSLog(@"play url");
        
        [self stopClipPlayback];
        
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
        
        NSString *urlString = [NSString stringWithFormat:@"%@", [_playQueue objectAtIndex:0]];
        
        // assign now playing entity
        AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
        NSError *error = nil;
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
        NSPredicate *predicate = [NSPredicate predicateWithFormat: @"url == %@", urlString];
        [request setPredicate:predicate];
        NSArray *episodeResult = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
        if (episodeResult.count > 0) {
            NSLog(@"found and assigned now playing entity");
            _npEpisodeEntity = [episodeResult lastObject];
        } else {
            /* create entity - case is next episode in feed is played. Episode entity may not have been
             created yet, but podcast entity would, so we get it from np episode entity. */
            // look up podcast entity
            NSLog(@"creating new entity for now playing entity");
            NSDictionary *episodeDict = [_currentFeed objectAtIndex:_currentFeedIndex];
            NSDictionary *podcastDict = [TungCommonObjects entityToDict:_npEpisodeEntity.podcast];
            _npEpisodeEntity = [TungCommonObjects getEntityForPodcast:podcastDict andEpisode:episodeDict save:YES];
        }
        
        _npEpisodeEntity.isNowPlaying = [NSNumber numberWithBool:YES];
        // find index of episode in current feed for prev/next track fns
        _currentFeed = [TungPodcast extractFeedArrayFromFeedDict:[TungPodcast retrieveAndCacheFeedForPodcastEntity:_npEpisodeEntity.podcast forceNewest:NO]];
        _currentFeedIndex = [TungCommonObjects getIndexOfEpisodeWithUrl:urlString inFeed:_currentFeed];
        
        // set now playing info center info
        NSData *artImageData = [TungCommonObjects retrievePodcastArtDataWithUrlString:_npEpisodeEntity.podcast.artworkUrl600];
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
        
        // clear leftover connection data
        if (self.connection) {
            //NSLog(@"clear connection data");
            [self.connection cancel];
            self.connection = nil;
            _trackData = nil;
            self.response = nil;
        }
        self.pendingRequests = [NSMutableArray array];
        
        // set up new player item and player, observers
        NSURL *urlToPlay = [self getEpisodeUrl:[_playQueue objectAtIndex:0]];
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:urlToPlay options:nil];
        [asset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
        
        _player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
        // add observers
        [_player addObserver:self forKeyPath:@"status" options:0 context:nil];
        //[_player addObserver:self forKeyPath:@"currentItem.playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
        [_player addObserver:self forKeyPath:@"currentItem.playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
        //[_player addObserver:self forKeyPath:@"currentItem.loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
        // Subscribe to AVPlayerItem's notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(completedPlayback) name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerError:) name:AVPlayerItemPlaybackStalledNotification object:playerItem];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerError:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:playerItem];
        
        [self setControlButtonStateToBuffering];
        
        // now playing did change
        if ([_ctrlBtnDelegate respondsToSelector:@selector(nowPlayingDidChange)])
        	[_ctrlBtnDelegate nowPlayingDidChange];
    }
    //NSLog(@"play queue: %@", _playQueue);
}

- (void) savePositionForNowPlaying {
    
    float secs = CMTimeGetSeconds(_player.currentTime);
    
    _npEpisodeEntity.trackProgress = [NSNumber numberWithFloat:secs];
    if (_totalSeconds > 0) {
        float pos = secs / _totalSeconds;
        _npEpisodeEntity.trackPosition = [NSNumber numberWithFloat:pos];
    }
    [TungCommonObjects saveContextWithReason:[NSString stringWithFormat:@"saving track progress: %f", secs]];
}

- (void) completedPlayback {
    // increment play count request
    NSLog(@"completed playback");
    [self incrementListenCount:_npEpisodeEntity];
    // custom eject
    if (_playQueue.count > 0) {
        _npEpisodeEntity.trackPosition = [NSNumber numberWithFloat:1];
        [_playQueue removeObjectAtIndex:0];
    }
    [self playNextEpisode]; // ejects current episode
}
- (void) ejectCurrentEpisode {
    if (_playQueue.count > 0) {
        if ([self isPlaying]) [_player pause];
        _npEpisodeEntity.isNowPlaying = [NSNumber numberWithBool:NO];
        [self savePositionForNowPlaying];
        NSLog(@"ejected current episode");
        [_playQueue removeObjectAtIndex:0];
        _playFromTimestamp = nil;
    }
}

- (void) removeNowPlayingStatusFromAllEpisodes {
    NSLog(@"Remove now playing status from all episodes");
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    NSFetchRequest *eRequest = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSError *eError = nil;
    NSArray *eResult = [appDelegate.managedObjectContext executeFetchRequest:eRequest error:&eError];
    if (eResult.count > 0) {
        for (int i = 0; i < eResult.count; i++) {
            EpisodeEntity *episodeEntity = [eResult objectAtIndex:i];
            episodeEntity.isNowPlaying = [NSNumber numberWithBool:NO];
        }
    }
    [TungCommonObjects saveContextWithReason:@"remove now playing status from all episodes"];
}

// TODO: handle this error before shipping
- (void) playerError:(NSNotification *)notification {
    NSLog(@"player error: %@", notification);
}

- (void) playNextEpisode {
    if (_playQueue.count > 1) {
        [self ejectCurrentEpisode];
        AudioServicesPlaySystemSound(1103); // play beep
        NSLog(@"play next episode in queue");
        [self playQueuedPodcast];
    }
    else {
        if (!_currentFeed) {
            _currentFeed = [TungPodcast extractFeedArrayFromFeedDict:[TungPodcast retrieveAndCacheFeedForPodcastEntity:_npEpisodeEntity.podcast forceNewest:NO]];
        }
        // play the next podcast in the feed if there is one
        if (_currentFeedIndex + 1 < _currentFeed.count) {
            NSLog(@"play next episode in feed");
            [self ejectCurrentEpisode];
            NSDictionary *episodeDict = [_currentFeed objectAtIndex:_currentFeedIndex + 1];
            NSURL *url = [NSURL URLWithString:[[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"url"]];
            [_playQueue insertObject:url atIndex:0];
            [self savePlayQueue];
            [self playQueuedPodcast];
        } else {
            [self setControlButtonStateToAdd];
        }
    }
}

- (void) playPreviousEpisode {
    
    if (!_currentFeed) {
    	_currentFeed = [TungPodcast extractFeedArrayFromFeedDict:[TungPodcast retrieveAndCacheFeedForPodcastEntity:_npEpisodeEntity.podcast forceNewest:NO]];
    }

    // play the previous podcast in the feed if there is one
    if (_currentFeedIndex - 1 >= 0) {
        NSLog(@"play previous episode in feed");
        NSDictionary *episodeDict = [_currentFeed objectAtIndex:_currentFeedIndex - 1];
        NSURL *url = [NSURL URLWithString:[[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"url"]];
        [_playQueue insertObject:url atIndex:0];
        [self savePlayQueue];
        [self playQueuedPodcast];
    } else {
        [self setControlButtonStateToAdd];
    }
}

// looks for local file, else returns url with custom scheme
- (NSURL *) getEpisodeUrl:(NSURL *)url {
    
    //NSLog(@"get episode url: %@", url);
    
    NSString *episodeDir = [NSTemporaryDirectory() stringByAppendingPathComponent:episodeDirName];
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:episodeDir withIntermediateDirectories:YES attributes:nil error:&error];
	/*
    NSError *ftError = nil;
    NSArray *episodeDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:episodeDir error:&ftError];
    NSLog(@"episode directory contents ---------------");
    if ([episodeDirContents count] > 0 && ftError == nil) {
        for (NSString *item in episodeDirContents) {
            NSLog(@"- %@", item);
        }
    }
    */
    NSString *episodeFilename = [url.absoluteString lastPathComponent];
    episodeFilename = [episodeFilename stringByRemovingPercentEncoding];
    NSString *episodeFilepath = [episodeDir stringByAppendingPathComponent:episodeFilename];

    if ([[NSFileManager defaultManager] fileExistsAtPath:episodeFilepath]) {
        NSLog(@"^^^ will use local file");
        _fileIsLocal = YES;
        _fileIsStreaming = NO;
        return [NSURL fileURLWithPath:episodeFilepath];
    } else {
        NSLog(@"^^^ will stream from url");
        _fileIsLocal = NO;
        _fileIsStreaming = YES;
        // return url with custom scheme
        NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
        components.scheme = @"tungstream";
        return [components URL];
    }
}

- (void) replacePlayerItemWithLocalCopy {
    if (_fileIsLocal) {
        NSLog(@"replace player item with local copy");
        //CMTime currentTime = _player.currentTime;
        NSURL *urlToPlay = [self getEpisodeUrl:[_playQueue objectAtIndex:0]];
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:urlToPlay options:nil];
        AVPlayerItem *localPlayerItem = [[AVPlayerItem alloc] initWithAsset:asset];
        [_player replaceCurrentItemWithPlayerItem:localPlayerItem];
        //[_player seekToTime:currentTime];
        _fileIsStreaming = NO;
    }
}

// not currently used, since switch to AVPlayer means NSURLConnectionDataDelegate does it for us.
// may repurpose this later to save in documents directory
/*
- (void) saveNowPlayingEpisodeInTempDirectory {
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSString *episodeDir = [NSTemporaryDirectory() stringByAppendingPathComponent:episodeDirName];
    NSError *error;
    [fileManager createDirectoryAtPath:episodeDir withIntermediateDirectories:YES attributes:nil error:&error];
    
    NSString *outputName = [NSString stringWithFormat:@"%@.%@", outputFileName, _nowPlayingFileType];
    NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:outputName];
    
    NSURL *url = _streamer.url;
    
//    NSLog(@"file name absolute string: %@", [url.absoluteString lastPathComponent]);
//    NSLog(@"file name path: %@", [url.path lastPathComponent]);
    
    NSString *episodeFilename = [url.path lastPathComponent];
    NSString *episodeFilepath = [episodeDir stringByAppendingPathComponent:episodeFilename];
    error = nil;
    
    //NSLog(@"file to save: %@", episodeFilename);
    
    // save it isn't already saved
    if (![fileManager fileExistsAtPath:episodeFilepath]) {
        if ([fileManager copyItemAtPath:outputFilePath toPath:episodeFilepath error:&error]) {
            NSLog(@"^^^ successfully saved episode in temp dir");
        } else {
            NSLog(@"^^^ failed to save episode in temp dir: %@", error);
        }
    }
    
    // show what's in temp episode dir
 
     NSError *ftError = nil;
     NSArray *episodeFolderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:episodeDir error:&ftError];
     NSLog(@"episode folder contents ---------------");
     if ([episodeFolderContents count] > 0 && ftError == nil) {
         for (NSString *item in episodeFolderContents) {
         	NSLog(@"- %@", item);
         }
     }
 
}
*/

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
    NSLog(@"saved play queue %@ to path: %@", _playQueue, playQueuePath);
}

- (void) readPlayQueueFromDisk {
    NSString *playQueuePath = [self getPlayQueuePath];
    NSLog(@"read play queue from path: %@", playQueuePath);
    NSArray *queue = [NSArray arrayWithContentsOfFile:playQueuePath];
    if (queue) {
        NSLog(@"found saved play queue: %@", _playQueue);
        _playQueue = [queue mutableCopy];
    } else {
        NSLog(@"no saved play queue. create new");
        _playQueue = [NSMutableArray array];
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
- (void) setControlButtonStateToAdd {
    [_btnActivityIndicator stopAnimating];
    [_btn_player setImage:[UIImage imageNamed:@"btn-player-add.png"] forState:UIControlStateNormal];
    [_btn_player setImage:[UIImage imageNamed:@"btn-player-add-down.png"] forState:UIControlStateHighlighted];
}
- (void) setControlButtonStateToBuffering {
    [_btnActivityIndicator startAnimating];
    [_btn_player setImage:nil forState:UIControlStateNormal];
    [_btn_player setImage:nil forState:UIControlStateHighlighted];
}

#pragma mark - NSURLConnection delegate

static NSString *episodeDirName = @"episodes";
static NSString *outputFileName = @"output";

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    //NSLog(@"[NSURLConnectionDataDelegate] connection did receive response");
    _trackData = [NSMutableData data];
    _response = (NSHTTPURLResponse *)response;
    
    [self processPendingRequests];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    //NSLog(@"[NSURLConnectionDataDelegate] connection did receive data");
    [_trackData appendData:data];
    
    [self processPendingRequests];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    //NSLog(@"[NSURLConnectionDataDelegate] connection did finish loading");
    [self processPendingRequests];
    
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSString *episodeDir = [NSTemporaryDirectory() stringByAppendingPathComponent:episodeDirName];
    NSError *error;
    [fileManager createDirectoryAtPath:episodeDir withIntermediateDirectories:YES attributes:nil error:&error];
    error = nil;
    NSString *episodeFilename = [[_playQueue objectAtIndex:0] lastPathComponent];
    NSString *episodeFilepath = [episodeDir stringByAppendingPathComponent:episodeFilename];
    
    if ([_trackData writeToFile:episodeFilepath options:0 error:&error]) {
        //CMTime currentTime = _player.currentTime;
        NSLog(@"-- saved podcast track in temp episode dir");
        //AVPlayerItem *localPlayerItem = [[AVPlayerItem alloc] initWithURL:[NSURL fileURLWithPath:episodeFilepath]];
        //[_player replaceCurrentItemWithPlayerItem:localPlayerItem];
        //[_player seekToTime:currentTime];
        _fileIsLocal = YES;
    }
    else {
        NSLog(@"ERROR: track did not save: %@", error);
        _fileIsLocal = NO;
    }
}

#pragma mark - AVURLAsset resource loading

- (void)processPendingRequests
{
    //NSLog(@"[AVAssetResourceLoaderDelegate] process pending requests");
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
    //NSLog(@"[AVAssetResourceLoaderDelegate] fill in content information");
    NSString *mimeType = [self.response MIMEType];
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    
    contentInformationRequest.byteRangeAccessSupported = YES;
    contentInformationRequest.contentType = CFBridgingRelease(contentType);
    contentInformationRequest.contentLength = [self.response expectedContentLength];
}

- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest
{
    //NSLog(@"[AVAssetResourceLoaderDelegate] respond with data for request");
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
    if (self.connection == nil)
    {
        //NSLog(@"[AVAssetResourceLoaderDelegate] should wait for loading of requested resource");
        NSURL *interceptedURL = [loadingRequest.request URL];
        NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:interceptedURL resolvingAgainstBaseURL:NO];
        // TODO: scheme may be https...
        actualURLComponents.scheme = @"http";
        
        NSURLRequest *request = [NSURLRequest requestWithURL:[actualURLComponents URL]];
        self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        [self.connection setDelegateQueue:[NSOperationQueue mainQueue]];
        
        [self.connection start];
    }
    
    [self.pendingRequests addObject:loadingRequest];
    
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    //NSLog(@"[AVAssetResourceLoaderDelegate] did cancel loading request");
    [self.pendingRequests removeObject:loadingRequest];
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
            NSLog(@"** save context with reason: %@ :: Successfully saved", reason);
        } else {
            NSLog(@"** save context with reason: %@ :: ERROR: %@", reason, savingError);
        }
    } else {
        NSLog(@"** save context with reason: %@ :: Did not save, no changes", reason);
    }
    return saved;
}

/*
 make sure there is a record for the podcast and the episode.
 Will not overwrite existing entities or create dupes.
 */

+ (PodcastEntity *) getEntityForPodcast:(NSDictionary *)podcastDict save:(BOOL)save {
    PodcastEntity *podcastEntity;
    
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"PodcastEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"collectionId == %@", [podcastDict objectForKey:@"collectionId"]];
    [request setPredicate:predicate];
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    if (result.count > 0) {
        podcastEntity = [result lastObject];
    } else {
        podcastEntity = [NSEntityDescription insertNewObjectForEntityForName:@"PodcastEntity" inManagedObjectContext:appDelegate.managedObjectContext];
        id collectionIdId = [podcastDict objectForKey:@"collectionId"];
        NSNumber *collectionId;
        if ([collectionIdId isKindOfClass:[NSString class]]) {
            collectionId = [TungCommonObjects stringToNumber:collectionIdId];
        } else {
            collectionId = (NSNumber *)collectionIdId;
        }
        podcastEntity.collectionId = collectionId;
        podcastEntity.collectionName = [podcastDict objectForKey:@"collectionName"];
        podcastEntity.artworkUrl600 = [podcastDict objectForKey:@"artworkUrl600"];
        podcastEntity.artistName = [podcastDict objectForKey:@"artistName"];
        podcastEntity.feedUrl = [podcastDict objectForKey:@"feedUrl"];
        // subscribed?
        if ([podcastDict objectForKey:@"isSubscribed"]) {
            podcastEntity.isSubscribed = [NSNumber numberWithBool:YES];
            if ([podcastDict objectForKey:@"dateSubscribed"]) {
            	NSString *dateSubscribed = [podcastDict objectForKey:@"dateSubscribed"];
                podcastEntity.dateSubscribed = [TungCommonObjects ISODateToNSDate:dateSubscribed];
            }
        } else {
            podcastEntity.isSubscribed = [NSNumber numberWithBool:NO];
        }
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
        if ([podcastDict objectForKey:@"artworkUrlSSL"]) podcastEntity.artworkUrlSSL = [podcastDict objectForKey:@"artworkUrlSSL"];
        if ([podcastDict objectForKey:@"website"]) podcastEntity.website = [podcastDict objectForKey:@"website"];
        if ([podcastDict objectForKey:@"email"]) podcastEntity.email = [podcastDict objectForKey:@"email"];
        if ([podcastDict objectForKey:@"desc"]) podcastEntity.desc = [podcastDict objectForKey:@"desc"];
        
        if (save) [TungCommonObjects saveContextWithReason:@"save new podcast entity"];
    }
    
    return podcastEntity;
}

+ (EpisodeEntity *) getEntityForPodcast:(NSDictionary *)podcastDict andEpisode:(NSDictionary *)episodeDict save:(BOOL)save {
    
    PodcastEntity *podcastEntity = [TungCommonObjects getEntityForPodcast:podcastDict save:NO];
    
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];

    // get episode entity
    NSLog(@"get episode entity for episode dict: %@", episodeDict);
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"guid == %@", [episodeDict objectForKey:@"guid"]];
    [request setPredicate:predicate];
    NSError *error = nil;
    NSArray *episodeResult = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    
    EpisodeEntity *episodeEntity;
    
    if (episodeResult.count == 0) {
        episodeEntity = [NSEntityDescription insertNewObjectForEntityForName:@"EpisodeEntity" inManagedObjectContext:appDelegate.managedObjectContext];
        
        id collectionIdId = [podcastDict objectForKey:@"collectionId"];
        NSNumber *collectionId;
        if ([collectionIdId isKindOfClass:[NSString class]]) {
            collectionId = [TungCommonObjects stringToNumber:collectionIdId];
        } else {
            collectionId = (NSNumber *)collectionIdId;
        }
        episodeEntity.collectionId = collectionId;
        if ([episodeDict objectForKey:@"itunes:image"]) {
            episodeEntity.episodeImageUrl = [[[episodeDict objectForKey:@"itunes:image"] objectForKey:@"el:attributes"] objectForKey:@"href"];
        }
        episodeEntity.guid = [episodeDict objectForKey:@"guid"];
        if ([episodeDict objectForKey:@"isRecommended"]) {
        	episodeEntity.isRecommended = [NSNumber numberWithBool:YES];
        } else {
            episodeEntity.isRecommended = [NSNumber numberWithBool:NO];
        }
        if ([episodeDict objectForKey:@"id"]) {
            episodeEntity.id = [[episodeDict objectForKey:@"id"] objectForKey:@"$id"];
        }
        if ([episodeDict objectForKey:@"shortlink"]) {
            episodeEntity.shortlink = [episodeDict objectForKey:@"shortlink"];
        }
        id pubDateId = [episodeDict objectForKey:@"pubDate"];
        NSDate *pubDate;
        if ([pubDateId isKindOfClass:[NSDate class]]) {
            pubDate = pubDateId;
        } else {
            pubDate = [TungCommonObjects ISODateToNSDate:[episodeDict objectForKey:@"pubDate"]];
        }
        episodeEntity.pubDate = pubDate;
        episodeEntity.trackProgress = [NSNumber numberWithFloat:0];
        episodeEntity.trackPosition = [NSNumber numberWithFloat:0];
        episodeEntity.podcast = podcastEntity; // move out of if/else? podcast entity seems static
        if ([episodeDict objectForKey:@"itunes:duration"]) {
            episodeEntity.duration = [episodeDict objectForKey:@"itunes:duration"];
        }
        else if ([episodeDict objectForKey:@"duration"]) {
            episodeEntity.duration = [episodeDict objectForKey:@"duration"];
        }
        if ([episodeDict objectForKey:@"enclosure"]) {
        	episodeEntity.dataLength = [NSNumber numberWithDouble:[[[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"length"] doubleValue]];
        }
        episodeEntity.isNowPlaying = [NSNumber numberWithBool:NO];
    }
    else {
        episodeEntity = [episodeResult lastObject];
    }
    // update things that publisher may have changed
    NSString *url;
    if ([episodeDict objectForKey:@"enclosure"]) {
    	url = [[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"url"];
    } else if ([episodeDict objectForKey:@"url"]) {
        url = [episodeDict objectForKey:@"url"];
    }
    episodeEntity.url = url;
    episodeEntity.title = [episodeDict objectForKey:@"title"];
    episodeEntity.desc = [TungCommonObjects findEpisodeDescriptionWithDict:episodeDict];

    if (save) [TungCommonObjects saveContextWithReason:@"save new podcast and/or episode entity"];
    
    return episodeEntity;
}

// get episode description
+ (NSString *) findEpisodeDescriptionWithDict:(NSDictionary *)episodeDict {
    
    id desc = [episodeDict objectForKey:@"itunes:summary"];
    if ([desc isKindOfClass:[NSString class]]) {
        //NSLog(@"- summary description");
        return (NSString *)desc;
    }
    else {
        id descr = [episodeDict objectForKey:@"description"];
        if ([descr isKindOfClass:[NSString class]]) {
            //NSLog(@"- regular description");
            return (NSString *)descr;
        }
        else {
            //NSLog(@"- no desc");
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
        ISODateInterpreter = [[NSDateFormatter alloc] init]; // "2014-09-05 14:27:40 +0000",
        [ISODateInterpreter setDateFormat:@"yyyy-MM-dd HH:mm:ss Z"];
    }
    
    if ([ISODateInterpreter dateFromString:pubDate]) {
        date = [ISODateInterpreter dateFromString:pubDate];
    }
    else {
        NSLog(@"could not convert date: %@", pubDate);
        date = [NSDate date];
    }
    return date;
    
}

+ (UserEntity *) saveUserWithDict:(NSDictionary *)userDict {
    
    
    NSString *tungId = [userDict objectForKey:@"tung_id"];
    NSLog(@"save user with dict: %@", userDict);
    UserEntity *userEntity = [TungCommonObjects retrieveUserEntityForUserWithId:tungId];
    
    if (!userEntity) {
        NSLog(@"no existing user entity, create new");
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
    NSLog(@"retrieve user entity for user with id: %@", userId);
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

// not used
+ (BOOL) checkForUserData {
    // Show user entities
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSFetchRequest *findUsers = [[NSFetchRequest alloc] initWithEntityName:@"UserEntity"];
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:findUsers error:&error];
    if (result.count > 0) {
        /*
        for (int i = 0; i < result.count; i++) {
            UserEntity *userEntity = [result objectAtIndex:i];
            NSDictionary *userDict = [TungCommonObjects entityToDict:userEntity];
            NSLog(@"user at index: %d", i);
            NSLog(@"%@", userDict);
        }*/
        
        return YES;
    } else {
        NSLog(@"no user entities found");
        return NO;
    }
}

+ (BOOL) checkForPodcastData {
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    
    // show episode entity data
    /*
    NSLog(@"episode entity data");
    NSFetchRequest *eRequest = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSError *eError = nil;
    NSArray *eResult = [appDelegate.managedObjectContext executeFetchRequest:eRequest error:&eError];
    if (eResult.count > 0) {
        for (int i = 0; i < eResult.count; i++) {
            EpisodeEntity *episodeEntity = [eResult objectAtIndex:i];
            NSLog(@"episode at index: %d", i);
            // entity -> dict
            NSArray *ekeys = [[[episodeEntity entity] attributesByName] allKeys];
            NSDictionary *eDict = [episodeEntity dictionaryWithValuesForKeys:ekeys];
            NSLog(@"%@", eDict);
        }
    }
     */
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"PodcastEntity"];
    NSError *error;
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    if (result.count > 0) {
        /*
        for (int i = 0; i < result.count; i++) {
            PodcastEntity *podcastEntity = [result objectAtIndex:i];
            NSLog(@"podcast at index: %d", i);
            // entity -> dict
            NSArray *keys = [[[podcastEntity entity] attributesByName] allKeys];
            NSDictionary *podcastDict = [podcastEntity dictionaryWithValuesForKeys:keys];
            NSLog(@"%@", podcastDict);
        }
        */
        return YES;
    } else {
        return NO;
    }
}

+ (void) removePodcastAndEpisodeData {
    
    NSLog(@"remove podcast and episode data");
    
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    // delete episode entity data
    NSFetchRequest *eRequest = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSError *eError = nil;
    NSArray *eResult = [appDelegate.managedObjectContext executeFetchRequest:eRequest error:&eError];
    if (eResult.count > 0) {
        for (int i = 0; i < eResult.count; i++) {
            [appDelegate.managedObjectContext deleteObject:[eResult objectAtIndex:i]];
            NSLog(@"deleted episode record at index: %d", i);
        }
    }
    
    NSFetchRequest *pRequest = [[NSFetchRequest alloc] initWithEntityName:@"PodcastEntity"];
    NSError *pError = nil;
    NSArray *pResult = [appDelegate.managedObjectContext executeFetchRequest:pRequest error:&pError];
    if (pResult.count > 0) {
        for (int i = 0; i < pResult.count; i++) {
            [appDelegate.managedObjectContext deleteObject:[pResult objectAtIndex:i]];
            NSLog(@"deleted podcast record at index: %d", i);
        }
    }
    
    [self saveContextWithReason:@"removed podcast and episode data"];
}

+ (void) removeAllUserData {
    NSLog(@"remove all user data");
    
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"UserEntity"];
    NSError *error = nil;
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    if (result.count > 0) {
        for (int i = 0; i < result.count; i++) {
            [appDelegate.managedObjectContext deleteObject:[result objectAtIndex:i]];
            NSLog(@"deleted user record at index: %d", i);
        }
    }
}

#pragma mark - Key Colors

static CCColorCube *colorCube = nil;
static NSArray *colors;

- (NSString *) determineDominantColorFromRGB:(NSArray *)rbg {
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

- (NSArray *) determineKeyColorsFromImage:(UIImage *)image {
    
    if (!colorCube) colorCube = [[CCColorCube alloc] init];
    NSArray *colors = [colorCube extractColorsFromImage:image flags:CCAvoidWhite+CCAvoidBlack count:6];
    UIColor *keyColor1 = [UIColor colorWithRed:0.45 green:0.45 blue:0.45 alpha:1];// default
    UIColor *keyColor2 = _tungColor;// default
    if (colors.count > 0) {
        //NSLog(@"determine key colors ---------");
        //int x = 120;
        int keyColor1Index = -1;
        int keyColor2Index = -1;
        NSString *keyColor1DominantColor;
        for (int i = 0; i < colors.count; i++) {
            
            // find luminance and saturation
            UIColor *uicolor = colors[i];
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
            
            //NSLog(@"- color %d - dominant: %@, saturation: %f, RGB: %f - %f - %f", i, dominantColor, saturation, R, G, B);
            
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
                //NSLog(@"* set key color 1");
                keyColor1Index = i;
                keyColor1DominantColor = dominantColor;
            }
            else if (keyColor2Index < 0) {
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
        if (keyColor1Index > -1) keyColor1 = [colors objectAtIndex:keyColor1Index];
        if (keyColor2Index > -1) keyColor2 = [colors objectAtIndex:keyColor2Index];
        if (keyColor1Index > -1 && keyColor2Index == -1) keyColor2 = [colors objectAtIndex:keyColor1Index];
    }
    return @[keyColor1, keyColor2];
    
}

- (UIColor *) lightenKeyColor:(UIColor *)keyColor {
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
- (UIColor *) darkenKeyColor:(UIColor *)keyColor {
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
    //NSLog(@"UIColor (red: %f, green: %f, blue: %f) to hex string: %@", red, green, blue, hexString);
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

#pragma mark - Session instance methods

- (void) establishCred {
    NSString *tungCred = [TungCommonObjects getKeychainCred];
    NSArray *components = [tungCred componentsSeparatedByString:@":"];
    _tungId = [components objectAtIndex:0];
    _tungToken = [components objectAtIndex:1];
//    NSLog(@"id: %@", _tungId);
//    NSLog(@"token: %@", _tungToken);
}

// all requests require a session ID instead of credentials
// start here and get session with credentials
- (void) getSessionWithCallback:(void (^)(void))callback {
    NSLog(@"getting new session");
    
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
        //NSLog(@"response status code: %ld", (long)[httpResponse statusCode]);
        if (error == nil) {
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                if ([responseDict objectForKey:@"sessionId"]) {
                    
                    _sessionId = [responseDict objectForKey:@"sessionId"];
                    NSLog(@"	got new session: %@", _sessionId);
                    _connectionAvailable = [NSNumber numberWithInt:1];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // callback
                        callback();
                    });
                }
                else if ([responseDict objectForKey:@"error"]) {
                    NSLog(@"error getting session: response: %@", responseDict);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([[responseDict objectForKey:@"error"] isEqualToString:@"Unauthorized"]) {
                            
                            UIAlertView *unauthorizedAlert = [[UIAlertView alloc] initWithTitle:@"Unauthorized" message:@"Please try Signing in again." delegate:self cancelButtonTitle:nil otherButtonTitles:@"Sign out", nil];
                            unauthorizedAlert.tag = 99;
                            [unauthorizedAlert show];
                            
                        }
                    });
                }
            }
            else if ([data length] == 0 && error == nil) {
                NSLog(@"no response");
            }
            else if (error != nil) {
                //NSLog(@"Error: %@", error);
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"HTML: %@", html);
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

-(void) killSessionForTesting {
    NSLog(@"killing session...");
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
            NSLog(@"	killed session");
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
    NSLog(@"add podcast/episode request");
    NSURL *addEpisodeRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/add-podcast.php", _apiRootUrl]];
    NSMutableURLRequest *addEpisodeRequest = [NSMutableURLRequest requestWithURL:addEpisodeRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [addEpisodeRequest setHTTPMethod:@"POST"];
    // optional params
    NSString *email = (podcastEntity.email) ? podcastEntity.email : @"";
    NSString *website = (podcastEntity.website) ? podcastEntity.website : @"";
    
//    NSLog(@"episode entity: %@", episodeEntity);
//    NSLog(@"podcast entity: %@", episodeEntity.podcast);
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
                                        @"episodePubDate": [NSString stringWithFormat:@"%@", episodeEntity.pubDate],
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
    NSData *podcastArtData = [TungCommonObjects retrievePodcastArtDataWithUrlString:podcastEntity.artworkUrl600];
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
                NSLog(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        NSLog(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self addPodcast:podcastEntity orEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    NSString *artworkUrlSSL = [[responseDict objectForKey:@"success"] objectForKey:@"artworkUrlSSL"];
                    podcastEntity.artworkUrlSSL = artworkUrlSSL;
                    if (episodeEntity) {
                        // save episode id and shortlink
                        NSString *episodeId = [[responseDict objectForKey:@"success"] objectForKey:@"episodeId"];
                        NSString *shortlink = [[responseDict objectForKey:@"success"] objectForKey:@"shortlink"];
                        episodeEntity.id = episodeId;
                        episodeEntity.shortlink = shortlink;
                    }
                    [TungCommonObjects saveContextWithReason:@"got podcast artwork SSL url and/or episode shortlink and id"];
                    callback();
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"Error. HTML: %@", html);
            }
        });
    }];
}

// if a user deletes the app, they lose all their subscribe/recommend data. This call restores it.
- (void) restorePodcastDataWithCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    NSLog(@"restore podcast data");
    NSURL *restoreRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@app/restore-podcast-data.php", _apiRootUrl]];
    NSMutableURLRequest *restoreRequest = [NSMutableURLRequest requestWithURL:restoreRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [restoreRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId};
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [restoreRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:restoreRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                //NSLog(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        NSLog(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self restorePodcastDataWithCallback:callback];
                        }];
                    }
                    else {
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                        callback(NO, responseDict);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    callback(YES, responseDict);
                    
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"Error. HTML: %@", html);
            }
        });
    }];
}

// get shortlink and id for episode
- (void) getEpisodeInfoForEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(void))callback {
    NSLog(@"get episode info for episode");
    NSURL *getEpisodeInfoRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/get-episode-info.php", _apiRootUrl]];
    NSMutableURLRequest *getEpisodeInfoRequest = [NSMutableURLRequest requestWithURL:getEpisodeInfoRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [getEpisodeInfoRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": episodeEntity.collectionId,
                             @"GUID": episodeEntity.guid,
                             @"episodeUrl": episodeEntity.url,
                             @"episodePubDate": [NSString stringWithFormat:@"%@", episodeEntity.pubDate],
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
                NSLog(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // no podcast record
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                        __unsafe_unretained typeof(self) weakSelf = self;
                        [self addPodcast:episodeEntity.podcast orEpisode:episodeEntity withCallback:^ {
                            [weakSelf getEpisodeInfoForEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                    else {
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    // save episode id and shortlink
                    NSString *episodeId = [[responseDict objectForKey:@"success"] objectForKey:@"episodeId"];
                    NSString *shortlink = [[responseDict objectForKey:@"success"] objectForKey:@"shortlink"];
                    episodeEntity.id = episodeId;
                    episodeEntity.shortlink = shortlink;
                    [TungCommonObjects saveContextWithReason:@"got episode shortlink and id"];
                    callback();
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"Error. HTML: %@", html);
            }
        });
    }];
}

// SUBSCRIBING
- (void) subscribeToPodcast:(PodcastEntity *)podcastEntity withButton:(CircleButton *)button {
    NSLog(@"subscribe request for podcast with id %@", podcastEntity.collectionId);
    [button setEnabled:NO];
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
                //NSLog(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        NSLog(@"SESSION EXPIRED");
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
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                        [button setEnabled:YES];
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    [button setEnabled:YES];
                    //_feedNeedsRefresh = [NSNumber numberWithBool:YES];
                    NSLog(@"%@", [responseDict objectForKey:@"success"]);
                    // important: do not assign shortlink from subscribe story to episode entity
                }
            }
            else {
                
                [button setEnabled:YES];
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"Error. HTML: %@", html);
            }
        });
    }];
}

- (void) unsubscribeFromPodcast:(PodcastEntity *)podcastEntity withButton:(CircleButton *)button {
    NSLog(@"unsubscribe request for podcast with id %@", podcastEntity.collectionId);
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
                //NSLog(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        NSLog(@"SESSION EXPIRED");
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
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                        [button setEnabled:YES];
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    [button setEnabled:YES];
                    //_feedNeedsRefresh = [NSNumber numberWithBool:YES];
                    NSLog(@"%@", responseDict);
                }
            }
            else {
                [button setEnabled:YES];
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"Error. HTML: %@", html);
            }
        });
    }];
}

// RECOMMENDING
- (void) recommendEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback {

    NSURL *recommendPodcastRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/recommend.php", _apiRootUrl]];
    NSMutableURLRequest *recommendPodcastRequest = [NSMutableURLRequest requestWithURL:recommendPodcastRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [recommendPodcastRequest setHTTPMethod:@"POST"];
    NSString *episodeId = (episodeEntity.id) ? episodeEntity.id : @"";
    NSString *shortlink = (episodeEntity.shortlink) ? episodeEntity.shortlink : @"";
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": episodeEntity.collectionId,
                             @"GUID": episodeEntity.guid,
                             @"episodeUrl": episodeEntity.url,
                             @"episodePubDate": [NSString stringWithFormat:@"%@", episodeEntity.pubDate],
                             @"episodeTitle": episodeEntity.title,
                             @"episodeId": episodeId,
                             @"shortlink": shortlink
                             };
    NSLog(@"recommend episode");
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
                        NSLog(@"SESSION EXPIRED");
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
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                        callback(NO, responseDict);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    NSLog(@"%@", responseDict);
                    _feedNeedsRefresh = [NSNumber numberWithBool:YES];
                    if (!episodeEntity.id) {
                        // save episode id and shortlink
                        NSString *episodeId = [[responseDict objectForKey:@"success"] objectForKey:@"episodeId"];
                        NSString *shortlink = [[responseDict objectForKey:@"success"] objectForKey:@"shortlink"];
                        episodeEntity.id = episodeId;
                        episodeEntity.shortlink = shortlink;
                        [TungCommonObjects saveContextWithReason:@"got episode shortlink and id"];
                    }
                    callback(YES, responseDict);
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"Error. HTML: %@", html);
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
    
    NSLog(@"un-recommend episode");
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [unRecommendPodcastRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:unRecommendPodcastRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                //NSLog(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        NSLog(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self unRecommendEpisode:episodeEntity];
                        }];
                    }
                    else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need episode info"]) {
                        [self getEpisodeInfoForEpisode:episodeEntity withCallback:^{
                            [self unRecommendEpisode:episodeEntity];
                        }];
                    }
                    else {
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    NSLog(@"%@", responseDict);
                    _feedNeedsRefresh = [NSNumber numberWithBool:YES];
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"Error. HTML: %@", html);
            }
        });
    }];
}

- (void) incrementListenCount:(EpisodeEntity *)episodeEntity {

    NSURL *incrementListenCountRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/increment-listen-count.php", _apiRootUrl]];
    NSMutableURLRequest *incrementListenCountRequest = [NSMutableURLRequest requestWithURL:incrementListenCountRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [incrementListenCountRequest setHTTPMethod:@"POST"];
    
    NSString *episodeId = (episodeEntity.id) ? episodeEntity.id : @"";
    NSString *shortlink = (episodeEntity.shortlink) ? episodeEntity.shortlink : @"";
    NSDictionary *params = @{@"collectionId": episodeEntity.collectionId,
                             @"GUID": episodeEntity.guid,
                             @"episodeUrl": episodeEntity.url,
                             @"episodePubDate": [NSString stringWithFormat:@"%@", episodeEntity.pubDate],
                             @"episodeTitle": episodeEntity.title,
                             @"episodeId": episodeId,
                             @"shortlink": shortlink
                             };
    NSLog(@"increment listen count with params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [incrementListenCountRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:incrementListenCountRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                //NSLog(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        NSLog(@"SESSION EXPIRED");
                        [self getSessionWithCallback:^{
                            [self incrementListenCount:episodeEntity];
                        }];
                    }
                    // no podcast record
                    else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                        __unsafe_unretained typeof(self) weakSelf = self;
                        NSLog(@"increment listen count error: need podcast info");
                        [self addPodcast:episodeEntity.podcast orEpisode:episodeEntity withCallback:^ {
                            [weakSelf incrementListenCount:episodeEntity];
                        }];
                    }
                    else {
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    NSLog(@"increment listen count result: %@", responseDict);
                    if (!episodeEntity.id) {
                        // save episode id and shortlink
                        NSString *episodeId = [[responseDict objectForKey:@"success"] objectForKey:@"episodeId"];
                        NSString *shortlink = [[responseDict objectForKey:@"success"] objectForKey:@"shortlink"];
                        episodeEntity.id = episodeId;
                        episodeEntity.shortlink = shortlink;
                        [TungCommonObjects saveContextWithReason:@"got episode shortlink and id"];
                    }
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"Error. HTML: %@", html);
            }
        });
    }];
}

- (void) postComment:(NSString*)comment atTime:(NSString*)timestamp onEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback  {
    NSURL *postCommentRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/new-comment.php", _apiRootUrl]];
    NSMutableURLRequest *postCommentRequest = [NSMutableURLRequest requestWithURL:postCommentRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [postCommentRequest setHTTPMethod:@"POST"];
    
    NSString *episodeId = (episodeEntity.id) ? episodeEntity.id : @"";
    NSString *shortlink = (episodeEntity.shortlink) ? episodeEntity.shortlink : @"";
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": episodeEntity.collectionId,
                             @"GUID": episodeEntity.guid,
                             @"episodeUrl": episodeEntity.url,
                             @"episodePubDate": [NSString stringWithFormat:@"%@", episodeEntity.pubDate],
                             @"episodeTitle": episodeEntity.title,
                             @"episodeId": episodeId,
                             @"shortlink": shortlink,
                             @"comment": comment,
                             @"timestamp": timestamp
                             };
    
    NSLog(@"post comment request w/ params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [postCommentRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:postCommentRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (jsonData != nil && error == nil) {
                NSDictionary *responseDict = jsonData;
                NSLog(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        NSLog(@"SESSION EXPIRED");
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
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                        callback(NO, responseDict);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    NSLog(@"successfully posted comment");
                    if (!episodeEntity.id) {
                        // save episode id and shortlink
                        NSString *episodeId = [[responseDict objectForKey:@"success"] objectForKey:@"episodeId"];
                        NSString *shortlink = [[responseDict objectForKey:@"success"] objectForKey:@"shortlink"];
                        episodeEntity.id = episodeId;
                        episodeEntity.shortlink = shortlink;
                        [TungCommonObjects saveContextWithReason:@"got episode shortlink and id"];
                    }
                    _feedNeedsRefresh = [NSNumber numberWithBool:YES];
                    callback(YES, responseDict);
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"Error. HTML: %@", html);
                callback(NO, @{@"error": @"Unspecified error"});
            }
        });
    }];
}

- (void) postClipWithComment:(NSString*)comment atTime:(NSString*)timestamp withDuration:(NSString *)duration onEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(BOOL success, NSDictionary *response))callback  {
    NSLog(@"post clip request");
    NSURL *postClipRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/new-clip.php", _apiRootUrl]];
    NSMutableURLRequest *postClipRequest = [NSMutableURLRequest requestWithURL:postClipRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [postClipRequest setHTTPMethod:@"POST"];
    
    NSString *episodeId = (episodeEntity.id) ? episodeEntity.id : @"";
    NSString *shortlink = (episodeEntity.shortlink) ? episodeEntity.shortlink : @"";
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": episodeEntity.collectionId,
                             @"GUID": episodeEntity.guid,
                             @"episodeUrl": episodeEntity.url,
                             @"episodePubDate": [NSString stringWithFormat:@"%@", episodeEntity.pubDate],
                             @"episodeTitle": episodeEntity.title,
                             @"episodeId": episodeId,
                             @"shortlink": shortlink,
                             @"comment": comment,
                             @"timestamp": timestamp,
                             @"duration": duration
                             };
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
                NSLog(@"%@", responseDict);
                if ([responseDict objectForKey:@"error"]) {
                    // session expired
                    if ([[responseDict objectForKey:@"error"] isEqualToString:@"Session expired"]) {
                        // get new session and re-request
                        NSLog(@"SESSION EXPIRED");
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
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                        callback(NO, responseDict);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    NSLog(@"successfully posted clip");
                    if (!episodeEntity.id) {
                        // save episode id and shortlink
                        NSString *episodeId = [[responseDict objectForKey:@"success"] objectForKey:@"episodeId"];
                        NSString *shortlink = [[responseDict objectForKey:@"success"] objectForKey:@"shortlink"];
                        episodeEntity.id = episodeId;
                        episodeEntity.shortlink = shortlink;
                        [TungCommonObjects saveContextWithReason:@"got episode shortlink and id"];
                    }
                    _feedNeedsRefresh = [NSNumber numberWithBool:YES];
                    callback(YES, responseDict);
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"Error. HTML: %@", html);
                callback(NO, @{@"error": @"Unspecified error"});
            }
        });
    }];
}

/*//////////////////////////////////
 Users
 /////////////////////////////////*/

- (void) getUserIdFromUsername:(NSString *)username withCallback:(void (^)(NSDictionary *jsonData))callback {
    NSLog(@"getting user id from username");
    NSURL *getUserIdRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@users/userId.php?username=%@", _apiRootUrl, username]];
    NSMutableURLRequest *getUserIdRequest = [NSMutableURLRequest requestWithURL:getUserIdRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [getUserIdRequest setHTTPMethod:@"GET"];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:getUserIdRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        error = nil;
        id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        if (jsonData != nil && error == nil) {
            callback(jsonData);
        }
        else {
            NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"HTML: %@", html);
        }
    }];
}

- (void) getProfileDataForUser:(NSString *)target_id withCallback:(void (^)(NSDictionary *jsonData))callback {
    NSLog(@"getting user profile data for id: %@", target_id);
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
            	callback(jsonData);
            });
        }
        else {
            NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"HTML: %@", html);
        }
    }];
}

- (void) restoreUserDataWithCallback:(void (^)(void))callback {
    // this would happen before session id is set
    if (_sessionId == NULL) _sessionId = @"";
    // re-fetch user data
    [self getProfileDataForUser:_tungId withCallback:^(NSDictionary *jsonData) {
        if (jsonData != nil) {
            NSDictionary *responseDict = jsonData;
            if ([responseDict objectForKey:@"user"]) {
                NSLog(@"restored user data");
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSDictionary *userDict = [responseDict objectForKey:@"user"];
                    NSLog(@"%@", userDict);
                    // store user data
                    if ([TungCommonObjects saveUserWithDict:userDict]) {
                        callback();
                    }
                });
            }
            else if ([responseDict objectForKey:@"error"]) {
                NSLog(@"unable to recover userData - %@", [responseDict objectForKey:@"error"]);
                // TODO: user not found, if user was deleted
            }
        }
    }];
}

- (void) updateUserWithDictionary:(NSDictionary *)userInfo withCallback:(void (^)(NSDictionary *jsonData))callback {
    NSLog(@"update user with dictionary: %@", userInfo);
    
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
                        NSLog(@"SESSION EXPIRED");
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
                    NSLog(@"user updated successfully: %@", responseDict);
                    callback(responseDict);
                }
            }
            else {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"HTML: %@", html);
            }
        });
    }];
}

- (void) followUserWithId:(NSString *)target_id withCallback:(void (^)(BOOL success))callback {
    NSLog(@"follow user with id: %@", target_id);
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
                        NSLog(@"SESSION EXPIRED");
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
                NSLog(@"HTML: %@", html);
                callback(NO);
            }
        });
    }];
    
}
- (void) unfollowUserWithId:(NSString *)target_id withCallback:(void (^)(BOOL success))callback {
    NSLog(@"UN-follow user with id: %@", target_id);
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
                        NSLog(@"SESSION EXPIRED");
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
                NSLog(@"HTML: %@", html);
                callback(NO);
            }
        });
    }];
}

// for beta period
- (void) followAllUsersFromId:(NSString *)user_id withCallback:(void (^)(BOOL success, NSDictionary *response))callback {
    NSLog(@"follow all users with id: %@", user_id);
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
                NSLog(@"HTML: %@", html);
                callback(NO, @{@"error": @"unspecified error"});
            }
        });
    }];
}



-(void) signOut {
    NSLog(@"signing out");
    
    [self playerPause];
    
    [self removeNowPlayingStatusFromAllEpisodes];
    
    //[self deleteLoggedInUserData];
    [TungCommonObjects removeAllUserData];
    [TungCommonObjects removePodcastAndEpisodeData];
    
    _tungId = @"";
    _tungToken = @"";
    _sessionId = @"";
    _twitterAccountToUse = nil;
    _twitterAccountStatus = @"";
    
    // delete cred
    [TungCommonObjects deleteCredentials];
    
    // close FB session if open
    if ([FBSDKAccessToken currentAccessToken]) {
    	[[FBSDKLoginManager new] logOut];
    }

    // since this method can get called by dismissing an unauthorized alert
    // make sure _viewController property is set for VCs that call signOut
    UIViewController *welcome = [_viewController.navigationController.storyboard instantiateViewControllerWithIdentifier:@"welcome"];
    [_viewController presentViewController:welcome animated:YES completion:^{}];
}

#pragma mark Twitter

- (void) establishTwitterAccount {
    NSLog(@"establish twitter account");
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
        if (!granted) {
            NSLog(@"twitter access denied");
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
                    NSString *twitter_username;
                    NSDictionary *userData = [self getLoggedInUserData];
                    if (userData) twitter_username = [userData objectForKey:@"twitter_username"];
                    if (twitter_username != NULL) {
                        NSLog(@"twitter username found in logged-in user data: %@", twitter_username);
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
    NSLog(@"determine twitter account to use");
    if ([_arrayOfTwitterAccounts count] > 1) {
        // show action sheet allowing user to choose which twitter account they want to use
        UIActionSheet *accountOptionsSheet = [[UIActionSheet alloc] initWithTitle:@"Which account would you like to use?" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
        accountOptionsSheet.tag = 89;
        for (ACAccount *acct in _arrayOfTwitterAccounts) {
            [accountOptionsSheet addButtonWithTitle:[NSString stringWithFormat:@"@%@", acct.username]];
        }
        [accountOptionsSheet showInView:_viewController.view];
        
    } else {
        NSLog(@"only 1 account. established twitter account.");
        _twitterAccountToUse = [_arrayOfTwitterAccounts lastObject];
        [self updateUserDataWithTwitterAccount];
    }
}

- (void) updateUserDataWithTwitterAccount {
    self.twitterAccountStatus = @"success"; // needs "self" for observer to work
    NSLog(@"update user data with twitter account");
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
    
    NSLog(@"Attempting to post tweet: %@", tweet);
    NSDictionary *tweetParams = @{@"status": tweet};
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@statuses/update.json", _twitterApiRootUrl]];
    SLRequest *postTweetRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:requestURL parameters:tweetParams];
    postTweetRequest.account = _twitterAccountToUse;
    NSLog(@"posting tweet with account: %@", _twitterAccountToUse.username);
    [postTweetRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        long responseCode =  (long)[urlResponse statusCode];
        if (responseCode == 200) NSLog(@"tweet posted");
        
        //NSLog(@"Twitter HTTP response: %li", responseCode);
        if (error != nil) {
            //NSLog(@"Error: %@", error);
            NSString *html = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            NSLog(@"HTML: %@", html);
        }
    }];
}

#pragma mark - Facebook sharing and share delegate methods

- (void) postToFacebookWithText:(NSString *)text Link:(NSString *)link andEpisode:(EpisodeEntity *)episodeEntity {
    
    /*
    FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
    content.contentURL = [NSURL URLWithString:link];
    content.imageURL = [NSURL URLWithString:episodeEntity.podcast.artworkUrl600];
    content.contentDescription = @"Tung.fm - a social podcast player";
    
    NSDictionary *userData = [self getLoggedInUserData];
    NSArray *firstAndLastName = [[userData objectForKey:@"name"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    content.contentTitle = [NSString stringWithFormat:@"%@ listened to a podcast on Tung", [firstAndLastName objectAtIndex:0]];
    
    // with dialog
    //[FBSDKShareDialog showFromViewController:_viewController withContent:content delegate:self];
    
    // direct api post link
    [FBSDKShareAPI shareWithContent:content delegate:self];
    */
    
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
        NSLog(@"facebook share result: %@", result);
    }];

}

- (void) sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary *)results {
    
    NSLog(@"successfully shared story to FB. results: %@", results);
}

- (void) sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error {
    
    NSLog(@"failed to share to FB. Error: %@", error);
}

- (void) sharerDidCancel:(id<FBSDKSharing>)sharer {
    
    NSLog(@"FB sharing cancelled");
    
}


#pragma mark - handle alerts

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSLog(@"dismissed alert with button index: %ld", (long)buttonIndex);
    // unauthorized alert
    if (alertView.tag == 99) {
        // sign out
        [self signOut];
    }
    // must download to play
    else if (alertView.tag == 89) {
        // sign out
        NSLog(@"must download to play alert");
    }
}

#pragma mark - handle actionsheet

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    NSLog(@"dismissed action sheet with button: %ld", (long)buttonIndex);
    if (actionSheet.tag == 99) {
        
        if (buttonIndex == 0)
            [self signOut];
    }
    if (actionSheet.tag == 89) {
        
        _twitterAccountToUse = [_arrayOfTwitterAccounts objectAtIndex:buttonIndex];
        NSLog(@"chose account with username: %@", _twitterAccountToUse.username);
        [self updateUserDataWithTwitterAccount];
        
    }
}

#pragma mark - class methods

+ (void)clearTempDirectory {
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
    for (NSString *file in tmpDirectory) {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), file] error:NULL];
    }
    NSLog(@"cleared temporary directory");
}

+ (void) checkReachabilityWithCallback:(void (^)(BOOL reachable))callback {
    
    Reachability *internetReachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus netStatus = [internetReachability currentReachabilityStatus];
    NSLog(@"Network:");
    switch (netStatus) {
        default: {
            callback(NO);
            break;
        }
        case NotReachable: {
            NSLog(@"\tnot reachable");
            callback(NO);
            break;
        }
        case ReachableViaWWAN:
            NSLog(@"\treachable via cellular data");
            callback(YES);
            break;
        case ReachableViaWiFi:
            NSLog(@"\treachable via wifi");
            callback(YES);
            break;
    }
}

/*
 // always reports no connection
- (void) checkTungReachability {
    // causes long pause
    NSLog(@"checking tung reachability against %@", _apiRootUrl);
    Reachability *tungReachability = [Reachability reachabilityWithHostName:_apiRootUrl];
    NetworkStatus tungStatus = [tungReachability currentReachabilityStatus];
    switch (tungStatus) {
        case NotReachable: {
            NSLog(@"TUNG not reachable");
            UIAlertView *unavailableAlert = [[UIAlertView alloc] initWithTitle:@"Unavailable" message:@"tung is currently unavailable, please try again later." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [unavailableAlert show];
            break;
        }
        case ReachableViaWWAN:
            NSLog(@"TUNG reachable via cellular data");
            break;
        case ReachableViaWiFi:
            NSLog(@"TUNG reachable via wifi");
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
        NSLog(@"credentials found");
        NSString *tungCred = [[NSString alloc] initWithData:(__bridge_transfer NSData *)cfValue encoding:NSUTF8StringEncoding];
        return tungCred;
    } else {
    	NSLog(@"No cred found. Code: %ld", (long)results);
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
        NSLog(@"successfully stored credentials");
    } else {
        NSLog(@"Failed to store cred with code: %ld", (long)status);
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
//    NSLog(@"serialize params for post request:");
//    NSLog(@"%@", paramArray);
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
            NSLog(@"- deleted keychain cred");
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

+ (NSData*) retrievePodcastArtDataWithUrlString:(NSString *)urlString {
    
    NSString *podcastArtDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"podcastArt"];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:podcastArtDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        
        NSArray *components = [urlString pathComponents];
        NSString *artFilename = [NSString stringWithFormat:@"%@%@", components[components.count-2], components[components.count-1]];
        NSString *artFilepath = [podcastArtDir stringByAppendingPathComponent:artFilename];
        NSData *artImageData;
        // make sure it is cached, even though we preloaded it
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

+ (NSURL *) getClipFileURL {
    
    NSString *clipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"recording.m4a"];
    return [NSURL fileURLWithPath:clipFilePath];
}

+ (NSString *) getAlbumArtFilenameFromUrlString:(NSString *)artURLString {
    NSArray *components = [artURLString pathComponents];
    return [NSString stringWithFormat:@"%@%@", components[components.count-2], components[components.count-1]];
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

@end
