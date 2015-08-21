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
#import <AVFoundation/AVFoundation.h>
#import "ALDisk.h"
#import "CCColorCube.h"

@interface TungCommonObjects()

// Private properties and methods

@property NSArray *currentFeed;
@property NSNumber *currentFeedIndex;
@property NSString *nowPlayingFileType;

- (void) playQueuedPodcast;

- (NSString *) getCurrentFeedPath;
- (void) readCurrentFeedFromDisk;

- (NSString *) getPlayQueuePath;
- (void) savePlayQueue;
- (void) readPlayQueueFromDisk;
- (NSURL *) getEpisodeUrl:(NSURL *)url;
- (void) saveNowPlayingEpisodeInTempDirectory;

- (void) setControlButtonStateToPlay;
- (void) setControlButtonStateToPause;
- (void) setControlButtonStateToAdd;
- (void) setControlButtonStateToBuffering;

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
        
        _tung_version = @"0.1.0";
        //_apiRootUrl = @"https://api.tung.fm/";
        _apiRootUrl = @"https://staging-api.tung.fm/";
        _tungSiteRootUrl = @"https://tung.fm/";
        _twitterApiRootUrl = @"https://api.twitter.com/1.1/";
        // refresh feed flag
        _needsReload = [NSNumber numberWithBool:NO];
        // colors
        _tungColor = [UIColor colorWithRed:87.0/255 green:90.0/255 blue:215.0/255 alpha:1];
        _darkTungColor = [UIColor colorWithRed:58.0/255 green:65.0/255 blue:175.0/255 alpha:1];
        _bkgdGrayColor = [UIColor colorWithRed:230.0/255.0 green:230.0/255.0 blue:230.0/255.0 alpha:1];
        _facebookColor = [UIColor colorWithRed:61.0/255 green:90.0/255 blue:152.0/255 alpha:1];
        _twitterColor = [UIColor colorWithRed:42.0/255 green:169.0/255 blue:224.0/255 alpha:1];
        
        /* remove after tungStereo removed */
        _clipDurationFormatter = [[NSNumberFormatter alloc] init];
        [_clipDurationFormatter setMinimumIntegerDigits:2];
        [_clipDurationFormatter setMinimumFractionDigits:0];
        
        [self initStreamer];
        
        [self readPlayQueueFromDisk];
        NSLog(@"play queue read from disk: %@", _playQueue);
        if (_playQueue.count > 0) {
            [self setControlButtonStateToPlay];
        }
        
        _connectionAvailable = [NSNumber numberWithInt:-1];

        
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

#pragma mark - Player instance methods

- (void) initStreamer {
    
    // set audio session
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: nil];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    // setup with config...
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioStreamStateDidChange:)
                                                 name:FSAudioStreamStateChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioStreamErrorOccurred:)
                                                 name:FSAudioStreamErrorNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioStreamMetaDataAvailable:)
                                                 name:FSAudioStreamMetaDataNotification
                                               object:nil];
}

- (void) setupStreamerWithPrebufferSize:(CGFloat)bytes {
    
    NSLog(@"setup streamer with prebuffer size: %f", bytes);
    
    _streamer = nil;

    // streamer config
    FSStreamConfiguration *config = [[FSStreamConfiguration alloc] init];
    config.requiredInitialPrebufferedByteCountForNonContinuousStream = 0;
    
    float availableBytes = [ALDisk freeDiskSpaceInBytes];
    
    if (bytes > availableBytes) {
        _canRecord = NO;
        NSLog(@"WARNING: cannot record, not enough disk space to download podcast");
        config.maxPrebufferedByteCount = 1024 * 1024; // 1MB
        
    } else {
        _canRecord = YES;
        config.maxPrebufferedByteCount = bytes;
    }
    
    // make streamer cache dir in temp dir
    NSString *streamerDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"streamer"];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:streamerDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        config.cacheDirectory = streamerDir;
    }
    
    _streamer = [[FSAudioStream alloc] initWithConfiguration:config];
    _streamer.delegate = self;
}

- (void)audioStreamStateDidChange:(NSNotification *)notification {
    
    if (!(notification.object == _streamer)) {
        return;
    }
    
    NSDictionary *dict = [notification userInfo];
    int state = [[dict valueForKey:FSAudioStreamNotificationKey_State] intValue];

    // react to state changes
    __unsafe_unretained typeof(self) weakSelf = self;
    //NSLog(@"streamer state did change: %u", state);
    
    /*
     kFsAudioStreamRetrievingURL, 0
     kFsAudioStreamStopped, 1
     kFsAudioStreamBuffering, 2
     kFsAudioStreamPlaying, 3
     kFsAudioStreamPaused, 4
     kFsAudioStreamSeeking, 5
     kFSAudioStreamEndOfFile, 6
     kFsAudioStreamFailed, 7
     kFsAudioStreamRetryingStarted, 8
     kFsAudioStreamRetryingSucceeded, 9
     kFsAudioStreamRetryingFailed, 10
     kFsAudioStreamPlaybackCompleted, 11
     kFsAudioStreamUnknownState 12
     */
    
    _streamerState = state;
    
    switch (state) {
        case kFsAudioStreamRetrievingURL:
        case kFsAudioStreamBuffering:
        case kFsAudioStreamSeeking:
            //NSLog(@"streamer state - retrieving URL, buffering, or seeking");
            [weakSelf setControlButtonStateToBuffering];
            _lockPosbar = YES;
            break;
            
        case kFsAudioStreamPlaying:
            //NSLog(@"streamer state - playing");
            [weakSelf setControlButtonStateToPause];
            _lockPosbar = NO;
            break;
            
        case kFsAudioStreamPaused:
            //NSLog(@"streamer state - paused");
            [weakSelf setControlButtonStateToPlay];
            [weakSelf savePositionForNowPlaying];
            break;
            
        case kFSAudioStreamEndOfFile:
            NSLog(@"streamer state - end of file");
            [self saveNowPlayingEpisodeInTempDirectory];
            break;
            
        case kFsAudioStreamPlaybackCompleted: {
            NSLog(@"streamer state - playback completed");
            [weakSelf completedPlayback];
            [weakSelf ejectCurrentEpisode];
            [weakSelf playNextPodcast];
            break;
        }
        case kFsAudioStreamStopped:
            //NSLog(@"streamer state - stopped");
            break;
            
        case kFsAudioStreamFailed:
            NSLog(@"streamer state - failed");
            break;
        case kFsAudioStreamRetryingStarted:
            NSLog(@"streamer state - retrying started");
            break;
        case kFsAudioStreamRetryingFailed: {
            NSLog(@"streamer state - retrying failed");
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *failedAlert = [[UIAlertView alloc] initWithTitle:@"Unable to stream" message:@"Would you like to download this podcast to play it?" delegate:weakSelf cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                failedAlert.tag = 89;
                [failedAlert show];
            });
            [weakSelf setControlButtonStateToAdd];
            break;
        }
            
        default:
            NSLog(@"streamer state - default: %u", state);
            break;
    }

};

- (void)audioStreamErrorOccurred:(NSNotification *)notification
{
    if (!(notification.object == _streamer)) {
        return;
    }
    
    NSDictionary *dict = [notification userInfo];
    int errorCode = [[dict valueForKey:FSAudioStreamNotificationKey_Error] intValue];
    
    switch (errorCode) {
        case kFsAudioStreamErrorOpen:
            NSLog(@"Error: Cannot open the audio stream");
            break;
        case kFsAudioStreamErrorStreamParse:
            NSLog(@"Error: Cannot read the audio stream");
            break;
        case kFsAudioStreamErrorNetwork:
            NSLog(@"Error: Network failed: cannot play the audio stream");
            break;
        case kFsAudioStreamErrorUnsupportedFormat:
            NSLog(@"Error: Unsupported format");
            break;
        case kFsAudioStreamErrorStreamBouncing:
            NSLog(@"Error: Network failed: cannot get enough data to play");
            break;
        default:
            NSLog(@"Error: Unknown error occurred");
            break;
    }
}

- (void)audioStreamMetaDataAvailable:(NSNotification *)notification
{
    if (!(notification.object == _streamer)) {
        return;
    }
    
    NSDictionary *dict = [notification userInfo];
    NSDictionary *metaData = [dict valueForKey:FSAudioStreamNotificationKey_MetaData];
    
    NSMutableString *streamInfo = [[NSMutableString alloc] init];
    
    if (metaData[@"MPMediaItemPropertyArtist"] &&
        metaData[@"MPMediaItemPropertyTitle"]) {
        [streamInfo appendString:metaData[@"MPMediaItemPropertyArtist"]];
        [streamInfo appendString:@" - "];
        [streamInfo appendString:metaData[@"MPMediaItemPropertyTitle"]];
    } else if (metaData[@"StreamTitle"]) {
        [streamInfo appendString:metaData[@"StreamTitle"]];
    }
    
    NSLog(@"%@", streamInfo);
}

// IN PROGRESS
- (void) remoteControlReceivedWithEvent:(UIEvent *)receivedEvent {
    NSLog(@"received remove control event: %@", receivedEvent);
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        
        switch (receivedEvent.subtype) {
            case UIEventSubtypeRemoteControlPlay:
            case UIEventSubtypeRemoteControlPause:
            case UIEventSubtypeRemoteControlStop:
            case UIEventSubtypeRemoteControlTogglePlayPause: {
                NSLog(@"- toggle play/pause");
                [_streamer pause];
                break;
            }
            case UIEventSubtypeRemoteControlPreviousTrack: {
                NSLog(@"- seek back");
                FSStreamPosition pos = {0};
                pos.position = 0;
                [_streamer seekToPosition:pos];
                break;
            }
            case UIEventSubtypeRemoteControlNextTrack: {
                NSLog(@"- seek forward");
                FSStreamPosition pos = {0};
                pos.position = 1;
                [_streamer seekToPosition:pos];
                break;
            }
            default:
                break;
        }
    }
}

- (void) controlButtonTapped {
    
    switch (_streamerState) {
            
        case kFsAudioStreamPlaying:
        case kFsAudioStreamPaused:
            //NSLog(@"ctrl button: play/pause");
            [_streamer pause];
            break;
            
        default:
            if (_playQueue.count > 0) {
                //NSLog(@"ctrl button: play queued url");
                [self playQueuedPodcast];
            }
            else {
                //NSLog(@"ctrl button: initiate search");
                [_ctrlBtnDelegate initiateSearch];
            }
            break;
    }
}

// for dismissing search from main tab bar by tapping icon
- (void) dismissSearch {
    [_ctrlBtnDelegate dismissPodcastSearch];
}

- (void) queueAndPlaySelectedEpisode:(NSString *)urlString {
    
    // url and file
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *fileName = [url lastPathComponent];
    NSString *fileType = [fileName pathExtension];
    NSLog(@"play file of type: %@", fileType);
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
                if (!!_streamer.url) {
                    [_streamer pause]; // toggle play/pause
                }
            }
        } else {
            [_playQueue insertObject:url atIndex:0];
            [self savePlayQueue];
            [self playQueuedPodcast];
        }
    }
}


static NSString *episodeDirName = @"episodes";
static NSString *outputFileName = @"output";

- (void) playQueuedPodcast {
    
    if (_playQueue.count > 0) {
        NSLog(@"play url");
        
        _npViewSetupForCurrentEpisode = NO;
        
        NSString *urlString = [NSString stringWithFormat:@"%@", [_playQueue objectAtIndex:0]];
        
        // find index of episode in current feed
        if (!_currentFeed) [self readCurrentFeedFromDisk];
        
        for (int i = 0; i < _currentFeed.count; i++) {
            NSString *url = [[[[_currentFeed objectAtIndex:i] objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"url"];
            if ([url isEqualToString:urlString]) {
                _currentFeedIndex = [NSNumber numberWithInt:i];
                break;
            }
        }
        
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
            /* create entity - case is next episode in feed is played. Episode entity wouldn't have been
             created yet, but podcast entity would. */
            // look up podcast entity
            NSLog(@"creating new entity for now playing entity");
            NSDictionary *episodeDict = [_currentFeed objectAtIndex:_currentFeedIndex.intValue];
            _npEpisodeEntity = [TungCommonObjects savePodcast:_npPodcastDict andEpisode:episodeDict];
        }
        
        // set max prebuffered byte count to data length of file about to be played
        // allows streamer to download the episode and play it at the same time; allows recording
        [self setupStreamerWithPrebufferSize:_npEpisodeEntity.dataLength.doubleValue];
        
        // set output file for recording (match extension)
        NSString *fileName = [[_playQueue objectAtIndex:0] lastPathComponent];
        _nowPlayingFileType = [fileName pathExtension];
        NSString *outputName = [NSString stringWithFormat:@"%@.%@", outputFileName, _nowPlayingFileType];
        NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:outputName];
        _streamer.outputFile = [NSURL fileURLWithPath:outputFilePath];
        //NSLog(@"- set streamer output file: %@", _streamer.outputFile);
        
        NSURL *urlToPlay = [self getEpisodeUrl:[_playQueue objectAtIndex:0]];
        
        // check for track progress, play
        if (_npEpisodeEntity.trackPosition > 0) {
            if (_npEpisodeEntity.trackPosition.floatValue == 1) {
                NSLog(@"-- track progress was 1 (entire episode played)");
                [_streamer playFromURL:urlToPlay];
            }
            else {
                NSLog(@"-- track progress exists. play from offset: %f", _npEpisodeEntity.trackPosition.floatValue);
                _streamer.url = urlToPlay;
                if (![_nowPlayingFileType isEqualToString:@"m4a"]) {
                    FSSeekByteOffset offset;
                    offset.start = _npEpisodeEntity.startByteOffset.unsignedLongLongValue;
                    offset.end = _npEpisodeEntity.endByteOffset.unsignedLongLongValue;
                    offset.position = _npEpisodeEntity.trackPosition.floatValue;
                    //offset.start = floorf(_npEpisodeEntity.dataLength.doubleValue * offset.position);
                    
                    [_streamer playFromOffset:offset];
                }
                else {
                    // freestreamer bug - can't playFromOffset with m4a
                    // https://github.com/muhku/FreeStreamer/issues/196
                    // ugly workaround
                    [_streamer play];
                    NSNumber *pos = [NSNumber numberWithFloat:_npEpisodeEntity.trackPosition.floatValue];
                    // have to delay or it won't work :/
                    [NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(seekToPosition:) userInfo:pos repeats:NO];
                }
            }
        } else {
            NSLog(@"-- no track progress, play from beginning");
            [_streamer playFromURL:urlToPlay];
        }
        // now playing did change
        if ([_ctrlBtnDelegate respondsToSelector:@selector(nowPlayingDidChange)])
        	[_ctrlBtnDelegate nowPlayingDidChange];
    }
    //NSLog(@"play queue: %@", _playQueue);
}


// looks for local file, else returns url
- (NSURL *) getEpisodeUrl:(NSURL *)url {
    
    NSString *episodeDir = [NSTemporaryDirectory() stringByAppendingPathComponent:episodeDirName];
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:episodeDir withIntermediateDirectories:YES attributes:nil error:&error];
        
    NSString *episodeFilename = [url.absoluteString lastPathComponent];
    NSString *episodeFilepath = [episodeDir stringByAppendingPathComponent:episodeFilename];

    if ([[NSFileManager defaultManager] fileExistsAtPath:episodeFilepath]) {
        NSLog(@"^^ will play local file");
        return [NSURL fileURLWithPath:episodeFilepath];
    } else {
        NSLog(@"^^ will stream from url");
        return url;
    }
}

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
    /*
     NSError *ftError = nil;
     NSArray *episodeFolderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:episodeDir error:&ftError];
     NSLog(@"episode folder contents ---------------");
     if ([episodeFolderContents count] > 0 && ftError == nil) {
         for (NSString *item in episodeFolderContents) {
         	NSLog(@"- %@", item);
         }
     }
    */
}


- (void) seekToPosition:(NSTimer *)position {
    FSStreamPosition pos = {0};
    NSNumber *num = position.userInfo;
    pos.position = num.floatValue;
    NSLog(@"seek to position: %f", pos.position);
    [_streamer seekToPosition:pos];
}

- (void) savePositionForNowPlaying {
    FSSeekByteOffset offset = _streamer.currentSeekByteOffset;
    NSLog(@"-- save track offset");
    NSLog(@"offset with start: %llu", offset.start);
    NSLog(@"offset with end: %llu", offset.end);
    NSLog(@"offset with position: %f", offset.position);
    _npEpisodeEntity.startByteOffset = [NSNumber numberWithUnsignedLongLong:offset.start];
    _npEpisodeEntity.endByteOffset = [NSNumber numberWithUnsignedLongLong:offset.end];
    _npEpisodeEntity.trackPosition = [NSNumber numberWithFloat:offset.position];
    [TungCommonObjects saveContext];
}

- (void) completedPlayback {
    NSNumber *progress = [NSNumber numberWithInt:1];
    _npEpisodeEntity.trackPosition = progress;
    [TungCommonObjects saveContext];
    // increment play count request
    [self incrementListenCount:_npEpisodeEntity];
}
- (void) ejectCurrentEpisode {
    if (_playQueue.count > 0) {
        [self savePositionForNowPlaying];
        [_streamer stop];
        NSLog(@"ejected current episode");
        [_playQueue removeObjectAtIndex:0];
    }
}


- (void) playNextPodcast {
    if (_playQueue.count > 0) {
        //AudioServicesPlaySystemSound(1103); // play beep
        [self playQueuedPodcast];
    }
    else {
        // play the next podcast in the feed if there is one
        if ([_currentFeed objectAtIndex:_currentFeedIndex.intValue + 1]) {
            NSLog(@"play next podcast in feed");
            NSDictionary *episodeDict = [_currentFeed objectAtIndex:_currentFeedIndex.intValue + 1];
            NSURL *url = [NSURL URLWithString:[[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"url"]];
            [_playQueue insertObject:url atIndex:0];
            [self savePlayQueue];
            [self playQueuedPodcast];
        } else {
        	[self setControlButtonStateToAdd];
        }
    }
}

/*
 Current feed is saved on disk in app directory to ensure it's always available
 */

- (NSString *) getCurrentFeedPath {
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSArray *folders = [fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
    //NSArray *folders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *appPath = [NSString stringWithFormat:@"%@/Application Support", [folders objectAtIndex:0]];
    NSError *writeError;
    [[NSFileManager defaultManager] createDirectoryAtPath:appPath withIntermediateDirectories:NO attributes:nil error:&writeError];
    return [appPath stringByAppendingPathComponent:@"currentFeed.txt"];
}

- (void) assignCurrentFeed:(NSArray *)currentFeed {
    _currentFeed = currentFeed;
    NSString *currentFeedPath = [self getCurrentFeedPath];
    // delete file if exists.
    if ([[NSFileManager defaultManager] fileExistsAtPath:currentFeedPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:currentFeedPath error:nil];
    }
    //[fileURL setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:&error];
    [_currentFeed writeToFile:currentFeedPath atomically:YES];
}
- (void) readCurrentFeedFromDisk {
    NSString *currentFeedPath = [self getCurrentFeedPath];
    _currentFeed = [NSArray arrayWithContentsOfFile:currentFeedPath];
}

/*
 Play Queue saving and retrieving
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
    NSLog(@"set control button state to pause");
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

/*
 Caching feed dictionaries - 
 Caches and returns data that's less than 1 day old only
 */

static NSString *feedDictsDirName = @"feedDicts";

- (void) cacheFeed:(NSDictionary *)feed forEntity:(PodcastEntity *)entity {
    
    NSLog(@"cache feed for entity");
    NSString *feedDir = [NSTemporaryDirectory() stringByAppendingPathComponent:feedDictsDirName];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:feedDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        
        // cache feed
        NSString *feedFileName = [NSString stringWithFormat:@"%@.txt", entity.collectionId];
        NSString *feedFilePath = [feedDir stringByAppendingPathComponent:feedFileName];
        // delete file if exists.
        if ([[NSFileManager defaultManager] fileExistsAtPath:feedFilePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:feedFilePath error:nil];
        }
        if ([feed writeToFile:feedFilePath atomically:YES]) {
        
            entity.feedLastCached = [NSDate date];
            
            [TungCommonObjects saveContext];
        }
    }
    
}
- (NSDictionary*) retrieveCachedFeedForEntity:(PodcastEntity *)entity {
    
    NSLog(@"retrieve cached feed for entity");
    if (entity.feedLastCached) {
    	long timeSinceLastCached = fabs([entity.feedLastCached timeIntervalSinceNow]);
        if (timeSinceLastCached > 60 * 60 * 24) {
            // cached feed is more than a day old, return nil.
            NSLog(@"cached feed dict was stale");
            return nil;
        } else {
            NSString *feedDir = [NSTemporaryDirectory() stringByAppendingPathComponent:feedDictsDirName];
            NSError *error;
            if ([[NSFileManager defaultManager] createDirectoryAtPath:feedDir withIntermediateDirectories:YES attributes:nil error:&error]) {
                NSString *feedFileName = [NSString stringWithFormat:@"%@.txt", entity.collectionId];
                NSString *feedFilePath = [feedDir stringByAppendingPathComponent:feedFileName];
                // return cached feed
                NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:feedFilePath];
                if (dict) {
                    NSLog(@"found fresh cached feed dictionary");
                	return dict;
                } else {
                    NSLog(@"tmp dir must have been cleared, cached feed not found");
                    return nil;
                }
            } else {
                return nil;
            }
        }
    } else {
        // feed has not been cached yet
        NSLog(@"feed dict not yet cached");
        return nil;
    }
    
}

+ (NSString*) convertSecondsToTimeString:(CGFloat)totalSeconds {
    
    int intSeconds = (int)roundf(totalSeconds);
    int seconds = intSeconds % 60;
    int minutes = (intSeconds / 60) % 60;
    int hours = intSeconds / 3600;
    return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds];
    
}

+ (double) convertDurationStringToSeconds:(NSString *)duration {
    
    NSArray *components = [duration componentsSeparatedByString:@":"];
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

/*
 NOT USED
 Methods for recording by intercepting PCM samples. Had to abandon because recorded
 audio was latent - a few seconds off from when you actually started/stopped recording.

- (void) initializeClipRecording {
    
    // ExtAudioFileRef method
    
    // output file
    NSString *pathToRecordingFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"newClip.lpcm"];
    // delete recording file if exists.
    if ([[NSFileManager defaultManager] fileExistsAtPath:pathToRecordingFile]) {
        [[NSFileManager defaultManager] removeItemAtPath:pathToRecordingFile error:nil];
    }
    NSURL *audioRecordingURLRaw = [NSURL fileURLWithPath:pathToRecordingFile];
    
    AudioStreamBasicDescription dstFormat;
    dstFormat.mSampleRate = (UInt32)[AVAudioSession sharedInstance].sampleRate;
    //NSLog(@"- sample rate: %f", dstFormat.mSampleRate);
//    size = sizeof(dstFormat.mChannelsPerFrame);
//    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels,
//                            &size,
//                            &dstFormat.mChannelsPerFrame);
    dstFormat.mFormatID = kAudioFormatLinearPCM;
    dstFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    dstFormat.mBytesPerPacket = 4;
    dstFormat.mFramesPerPacket = 1;
    dstFormat.mBytesPerFrame = 4;
    dstFormat.mChannelsPerFrame = 2;
    dstFormat.mBitsPerChannel = 16;

    _destinationFile = 0;
    
    OSStatus result = ExtAudioFileCreateWithURL((__bridge CFURLRef)audioRecordingURLRaw, kAudioFileCAFType, &dstFormat, NULL, kAudioFileFlags_EraseFile, &_destinationFile);
    
    NSLog(@"create new audio recording file: %@", [self OSStatusToStr:result]);
    
    //_clipData = [NSMutableData dataWithContentsOfURL:_audioRecordingURL];
//    NSLog(@"new audio file data length: %lu", (unsigned long)_clipData.length);
 
}

// intercept PCM audio samples
- (void)audioStream:(FSAudioStream *)audioStream audioBufferList:(AudioBufferList)bufferList count:(NSUInteger)count {

    if (_isRecording) {
        NSLog(@"receiving audio: %lu", (unsigned long)count);
        UInt32 nFrames = (UInt32)count/ 2;
        
        ExtAudioFileWriteAsync(_destinationFile, nFrames, &bufferList);
    }
}
 */

#pragma mark - core data related

+ (BOOL) saveContext {
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    // save
    NSError *savingError;
    BOOL saved = [appDelegate.managedObjectContext save:&savingError];
    if (!saved) NSLog(@"ERROR failed to save: %@", savingError);
    NSLog(@"* saved context *");
    return saved;
}

/*
 make sure there is a record for the podcast and the episode.
 Will not overwrite existing entities or create dupes.
 */

+ (PodcastEntity *) savePodcast:(NSDictionary *)podcastDict {
    PodcastEntity *podcastEntity;
    
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"PodcastEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"collectionId == %@", [podcastDict objectForKey:@"collectionId"]];
    [request setPredicate:predicate];
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    if (result.count > 0) {
        NSLog(@"found and assigned now playing entity");
        podcastEntity = [result lastObject];
    } else {
        podcastEntity = [NSEntityDescription insertNewObjectForEntityForName:@"PodcastEntity" inManagedObjectContext:appDelegate.managedObjectContext];
        podcastEntity.collectionId = [podcastDict objectForKey:@"collectionId"];
        podcastEntity.collectionName = [podcastDict objectForKey:@"collectionName"];
        podcastEntity.artworkUrl600 = [podcastDict objectForKey:@"artworkUrl600"];
        podcastEntity.artistName = [podcastDict objectForKey:@"artistName"];
        podcastEntity.feedUrl = [podcastDict objectForKey:@"feedUrl"];
        podcastEntity.isSubscribed = [NSNumber numberWithBool:NO];
        podcastEntity.keyColor1 = [podcastDict objectForKey:@"keyColor1"];
        podcastEntity.keyColor1Hex = [TungCommonObjects UIColorToHexString:[podcastDict objectForKey:@"keyColor1"]];
        podcastEntity.keyColor2 = [podcastDict objectForKey:@"keyColor2"];
        podcastEntity.keyColor2Hex = [TungCommonObjects UIColorToHexString:[podcastDict objectForKey:@"keyColor2"]];
        if ([podcastDict objectForKey:@"website"]) podcastEntity.website = [podcastDict objectForKey:@"website"];
        if ([podcastDict objectForKey:@"email"]) podcastEntity.email = [podcastDict objectForKey:@"email"];
        if ([podcastDict objectForKey:@"desc"]) podcastEntity.desc = [podcastDict objectForKey:@"desc"];
    }
    [TungCommonObjects saveContext];
    
    return podcastEntity;
}

+ (EpisodeEntity *) savePodcast:(NSDictionary *)podcastDict andEpisode:(NSDictionary *)episodeDict {
    
    NSLog(@"save podcast and episode entity");
    
    PodcastEntity *podcastEntity = [TungCommonObjects savePodcast:podcastDict];
    
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];

    // get episode entity
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"EpisodeEntity"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"guid == %@", [episodeDict objectForKey:@"guid"]];
    [request setPredicate:predicate];
    NSError *error = nil;
    NSArray *episodeResult = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    
    EpisodeEntity *episodeEntity;
    
    if (episodeResult.count == 0) {
        episodeEntity = [NSEntityDescription insertNewObjectForEntityForName:@"EpisodeEntity" inManagedObjectContext:appDelegate.managedObjectContext];
        episodeEntity.collectionId = [podcastDict objectForKey:@"collectionId"];
        if ([episodeDict objectForKey:@"itunes:image"])
            episodeEntity.episodeImageUrl = [[[episodeDict objectForKey:@"itunes:image"] objectForKey:@"el:attributes"] objectForKey:@"href"];
        episodeEntity.guid = [episodeDict objectForKey:@"guid"];
        episodeEntity.isRecommended = [NSNumber numberWithBool:NO];
        episodeEntity.pubDate = [episodeDict objectForKey:@"pubDate"];
        episodeEntity.trackPosition = [NSNumber numberWithFloat:0];
        episodeEntity.podcast = podcastEntity; // move out of if/else? podcast entity seems static
        if ([episodeDict objectForKey:@"itunes:duration"])
            episodeEntity.duration = [episodeDict objectForKey:@"itunes:duration"];
        episodeEntity.dataLength = [NSNumber numberWithDouble:[[[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"length"] doubleValue]];
    }
    else {
        episodeEntity = [episodeResult lastObject];
    }
    // update things that publisher may have changed
    episodeEntity.url = [[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"url"];
    episodeEntity.title = [episodeDict objectForKey:@"title"];
    episodeEntity.desc = [TungCommonObjects findEpisodeDescriptionWithDict:episodeDict];

    
    [TungCommonObjects saveContext];
    return episodeEntity;
}

// get episode description
+ (NSString *) findEpisodeDescriptionWithDict:(NSDictionary *)episodeDict {
    id desc = [episodeDict objectForKey:@"itunes:summary"];
    if ([desc isKindOfClass:[NSString class]]) {
        NSLog(@"- summary description");
        return (NSString *)desc;
    }
    else {
        id descr = [episodeDict objectForKey:@"description"];
        if ([descr isKindOfClass:[NSString class]]) {
            NSLog(@"- regular description");
            return (NSString *)descr;
        }
        else {
            NSLog(@"- no desc");
            return @"This episode has no description.";
        }
    }
}

+ (NSString *) findPodcastDescriptionWithDict:(NSDictionary *)dict {
    id desc = [[dict objectForKey:@"channel"] objectForKey:@"itunes:summary"];
    if ([desc isKindOfClass:[NSString class]]) {
        return (NSString *)desc;
    } else {
        id descr = [[dict objectForKey:@"channel"] objectForKey:@"description"];
        if ([descr isKindOfClass:[NSString class]]) {
            return (NSString *)descr;
        }
        else {
            return @"This podcast has no description.";
        }
    }
}

+ (NSDictionary *) podcastEntityToDict:(PodcastEntity *)podcastEntity {
    
    NSArray *keys = [[[podcastEntity entity] attributesByName] allKeys];
    NSDictionary *podcastDict = [[podcastEntity dictionaryWithValuesForKeys:keys] mutableCopy];
    return podcastDict;
}

+ (UserEntity *) saveUserWithDict:(NSDictionary *)userDict {
    NSString *tungId = [[userDict objectForKey:@"_id"] objectForKey:@"$id"];
    NSLog(@"save user with id: %@", tungId);
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
        NSLog(@"%@ not null", [userDict objectForKey:@"facebook_id"]);
        NSString *facebook_id = [userDict objectForKey:@"facebook_id"]; //ensure string
        userEntity.facebook_id = facebook_id;
    }

    [TungCommonObjects saveContext];
    
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

+ (NSDictionary *) userEntityToDict:(UserEntity *)userEntity {
   
    NSArray *keys = [[[userEntity entity] attributesByName] allKeys];
    NSDictionary *userDict = [[userEntity dictionaryWithValuesForKeys:keys] mutableCopy];
    return userDict;
}

- (NSDictionary *) getLoggedInUserData {
    
    if (_tungId) {
        UserEntity *userEntity = [TungCommonObjects retrieveUserEntityForUserWithId:_tungId];
        return [TungCommonObjects userEntityToDict:userEntity];
    } else {
        return nil;
    }
    
}

- (void) deleteLoggedInUserData {
    
    UserEntity *userEntity = [TungCommonObjects retrieveUserEntityForUserWithId:_tungId];
    if (userEntity) {
        AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
        [appDelegate.managedObjectContext deleteObject:userEntity];
        [TungCommonObjects saveContext];
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

#pragma mark - Session instance methods

- (void) establishCred {
    NSString *tungCred = [TungCommonObjects getKeychainCred];
    NSArray *components = [tungCred componentsSeparatedByString:@":"];
    _tungId = [components objectAtIndex:0];
    _tungToken = [components objectAtIndex:1];
    NSLog(@"id: %@", _tungId);
    NSLog(@"token: %@", _tungToken);
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
                        // new version notification
                        if (![[responseDict objectForKey:@"version"] isEqualToString:_tung_version]) {
                            NSLog(@"session response: %@", responseDict);
                            UIAlertView *newVersionAlert = [[UIAlertView alloc] initWithTitle:[responseDict objectForKey:@"alertTitle"] message:[responseDict objectForKey:@"alertBody"] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                            [newVersionAlert show];
                        }
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

- (void) addPodcast:(PodcastEntity *)podcastEntity withCallback:(void (^)(void))callback  {
    NSLog(@"add podcast request");
    NSURL *addPodcastRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/add-podcast.php", _apiRootUrl]];
    NSMutableURLRequest *addPodcastRequest = [NSMutableURLRequest requestWithURL:addPodcastRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [addPodcastRequest setHTTPMethod:@"POST"];
    NSString *email = (podcastEntity.email) ? podcastEntity.email : @"";
    NSString *website = (podcastEntity.website) ? podcastEntity.website : @"";
    NSString *desc = (podcastEntity.desc) ? podcastEntity.desc : @"";
    //    NSLog(@"podcast entity: %@", podcastEntity);
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": podcastEntity.collectionId,
                             @"collectionName": podcastEntity.collectionName,
                             @"artistName": podcastEntity.artistName,
                             @"artworkUrl600": podcastEntity.artworkUrl600,
                             @"feedUrl": podcastEntity.feedUrl,
                             @"keyColor1": podcastEntity.keyColor1Hex,
                             @"keyColor2": podcastEntity.keyColor2Hex,
                             @"email": email,
                             @"website": website,
                             @"desc": desc
                             };
    //NSLog(@"params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [addPodcastRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:addPodcastRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
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
                            [self addPodcast:podcastEntity withCallback:^ {
                                callback();
                            }];
                        }];
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
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


- (void) addEpisode:(EpisodeEntity *)episodeEntity withCallback:(void (^)(void))callback  {
    NSLog(@"add episode request");
    NSURL *addEpisodeRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/add-podcast.php", _apiRootUrl]];
    NSMutableURLRequest *addEpisodeRequest = [NSMutableURLRequest requestWithURL:addEpisodeRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [addEpisodeRequest setHTTPMethod:@"POST"];
    NSString *email = (episodeEntity.podcast.email) ? episodeEntity.podcast.email : @"";
    NSString *website = (episodeEntity.podcast.website) ? episodeEntity.podcast.website : @"";
    NSString *desc = (episodeEntity.podcast.desc) ? episodeEntity.podcast.desc : @"";
    
//    NSLog(@"episode entity: %@", episodeEntity);
//    NSLog(@"podcast entity: %@", episodeEntity.podcast);
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": episodeEntity.podcast.collectionId,
                             @"collectionName": episodeEntity.podcast.collectionName,
                             @"artistName": episodeEntity.podcast.artistName,
                             @"artworkUrl600": episodeEntity.podcast.artworkUrl600,
                             @"feedUrl": episodeEntity.podcast.feedUrl,
                             @"keyColor1": episodeEntity.podcast.keyColor1Hex,
                             @"keyColor2": episodeEntity.podcast.keyColor2Hex,
                             @"email": email,
                             @"website": website,
                             @"desc": desc,
                             @"GUID": episodeEntity.guid,
                             @"episodeUrl": episodeEntity.url,
                             @"episodePubDate": [NSString stringWithFormat:@"%@", episodeEntity.pubDate],
                             @"episodeDuration": episodeEntity.duration,
                             @"episodeTitle": episodeEntity.title,
                            };
    //NSLog(@"params: %@", params);
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [addEpisodeRequest setHTTPBody:serializedParams];
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
                            [self addEpisode:episodeEntity withCallback:^ {
                                callback();
                            }];
                        }];
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
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
- (void) subscribeToPodcast:(PodcastEntity *)podcastEntity andButton:(CircleButton *)button {
    NSLog(@"subscribe request for podcast with id %@", podcastEntity.collectionId);
    [button setEnabled:NO];
    NSURL *subscribeRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/subscribe.php", _apiRootUrl]];
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
                            [self subscribeToPodcast:podcastEntity andButton:button];
                        }];
                    }
                    // no podcast record
                    else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                        __unsafe_unretained typeof(self) weakSelf = self;
                        [self addPodcast:podcastEntity withCallback:^{
                            [weakSelf subscribeToPodcast:podcastEntity andButton:button];
                        }];
                    }
                    else {
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    [button setEnabled:YES];
                    NSLog(@"successfully subscribed to podcast");
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

- (void) unsubscribeFromPodcast:(PodcastEntity *)podcastEntity andButton:(CircleButton *)button {
    NSLog(@"unsubscribe request for podcast with id %@", podcastEntity.collectionId);
    [button setEnabled:NO];
    NSURL *unsubscribeFromPodcastRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/unsubscribe.php", _apiRootUrl]];
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
                            [self unsubscribeFromPodcast:podcastEntity andButton:button];
                        }];
                    }
                    // no podcast record
                    else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                        __unsafe_unretained typeof(self) weakSelf = self;
                        [self addPodcast:podcastEntity withCallback:^ {
                            [weakSelf unsubscribeFromPodcast:podcastEntity andButton:button];
                        }];
                    }
                    else {
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    [button setEnabled:YES];
                    NSLog(@"successfully unsubbed from podcast");
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
    NSLog(@"recommend episode");
    NSURL *recommendPodcastRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/recommend.php", _apiRootUrl]];
    NSMutableURLRequest *recommendPodcastRequest = [NSMutableURLRequest requestWithURL:recommendPodcastRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [recommendPodcastRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": episodeEntity.collectionId,
                             @"GUID": episodeEntity.guid,
                             @"episodeUrl": episodeEntity.url,
                             @"episodeTitle":episodeEntity.title
                             };
    NSData *serializedParams = [TungCommonObjects serializeParamsForPostRequest:params];
    [recommendPodcastRequest setHTTPBody:serializedParams];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:recommendPodcastRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
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
                            [self recommendEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                    // no podcast record
                    else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                        __unsafe_unretained typeof(self) weakSelf = self;
                        [self addEpisode:episodeEntity withCallback:^ {
                            [weakSelf recommendEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                    else {
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                        callback(NO, responseDict);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    NSString *shortlink = [[responseDict objectForKey:@"success"] objectForKey:@"shortlink"];
                    NSLog(@"successfully recommended podcast and got shortlink: %@", shortlink);
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
    NSLog(@"un-recommend episode");
    NSURL *unRecommendPodcastRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/un-recommend.php", _apiRootUrl]];
    NSMutableURLRequest *unRecommendPodcastRequest = [NSMutableURLRequest requestWithURL:unRecommendPodcastRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [unRecommendPodcastRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": episodeEntity.collectionId,
                             @"GUID": episodeEntity.guid
                             };
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
                    // no podcast record
                    else if ([[responseDict objectForKey:@"error"] isEqualToString:@"Need podcast info"]) {
                        __unsafe_unretained typeof(self) weakSelf = self;
                        [self addEpisode:episodeEntity withCallback:^ {
                            [weakSelf unRecommendEpisode:episodeEntity];
                        }];
                    }
                    else {
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    NSLog(@"successfully UN-recommended podcast");
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
    NSLog(@"increment listen count");
    NSURL *incrementListenCountRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@podcasts/increment-listen-count.php", _apiRootUrl]];
    NSMutableURLRequest *incrementListenCountRequest = [NSMutableURLRequest requestWithURL:incrementListenCountRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [incrementListenCountRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"collectionId": episodeEntity.collectionId,
                             @"GUID": episodeEntity.guid
                             };
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
                        [self addEpisode:episodeEntity withCallback:^ {
                            [weakSelf incrementListenCount:episodeEntity];
                        }];
                    }
                    else {
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    NSLog(@"successfully incremented listen count");
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
    NSLog(@"post comment request");
    NSURL *postCommentRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@stories/new-comment.php", _apiRootUrl]];
    NSMutableURLRequest *postCommentRequest = [NSMutableURLRequest requestWithURL:postCommentRequestURL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.0f];
    [postCommentRequest setHTTPMethod:@"POST"];
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": episodeEntity.collectionId,
                             @"GUID": episodeEntity.guid,
                             @"episodeUrl": episodeEntity.url,
                             @"episodeTitle":episodeEntity.title,
                             @"comment": comment,
                             @"timestamp": timestamp
                             };
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
                        [self addEpisode:episodeEntity withCallback:^ {
                            [weakSelf postComment:comment atTime:timestamp onEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                    else {
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                        callback(NO, responseDict);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    NSString *shortlink = [[responseDict objectForKey:@"success"] objectForKey:@"shortlink"];
                    NSLog(@"successfully posted comment and got shortlink: %@", shortlink);
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
    NSDictionary *params = @{@"sessionId":_sessionId,
                             @"collectionId": episodeEntity.collectionId,
                             @"GUID": episodeEntity.guid,
                             @"episodeUrl": episodeEntity.url,
                             @"episodeTitle":episodeEntity.title,
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
                        [self addEpisode:episodeEntity withCallback:^ {
                            [weakSelf postClipWithComment:comment atTime:timestamp withDuration:duration onEpisode:episodeEntity withCallback:callback];
                        }];
                    }
                    else {
                        NSLog(@"Error: %@", [responseDict objectForKey:@"error"]);
                        callback(NO, responseDict);
                    }
                }
                else if ([responseDict objectForKey:@"success"]) {
                    NSString *shortlink = [[responseDict objectForKey:@"success"] objectForKey:@"shortlink"];
                    NSLog(@"successfully posted clip and got shortlink: %@", shortlink);
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
                    NSLog(@"user updated successfully");
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

-(void) signOut {
    NSLog(@"signing out");
    
    [self deleteLoggedInUserData];
    
    _tungId = @"";
    _tungToken = @"";
    _sessionId = @"";
    _twitterAccountToUse = nil;
    _twitterAccountStatus = @"";
    
    // delete cred
    [TungCommonObjects deleteCredentials];
    
    // close FB session if open
    if (FBSession.activeSession.state == FBSessionStateOpen
        || FBSession.activeSession.state == FBSessionStateOpenTokenExtended) {
        
        // Close the session and remove the access token from the cache
        // The session state handler (in the app delegate) will be called automatically
        [FBSession.activeSession closeAndClearTokenInformation];
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
        NSString *value = val;
        [data appendData:[[NSString stringWithFormat:@"%@\r\n", value] dataUsingEncoding:NSUTF8StringEncoding]];
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

+ (NSString *) UIColorToHexString:(UIColor *)color {
    CGFloat red, green, blue, alpha;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    NSString *hexString = [NSString stringWithFormat:@"#%02x%02x%02x", (int)(red * 255),(int)(green * 255),(int)(blue * 255)];
    //NSLog(@"UIColor (red: %f, green: %f, blue: %f) to hex string: %@", red, green, blue, hexString);
    return hexString;
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

@end
