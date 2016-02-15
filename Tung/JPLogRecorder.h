//
//  JPLogRecorder.h
//
//  Created by Jamie Perkins on 2/14/16.
//  Copyright © 2016 Inorganik Produce, Inc. All rights reserved.
//
//  Just like NSLogv, but instead of logging to system log, stores
//  logs in a mutable array saved on disk, limited to X number of logs
//  which can be retrieved at runtime.

#import <Foundation/Foundation.h>

#define JPLog( f, ... ) [JPLogRecorder logFromFile:[[NSString stringWithUTF8String:__FILE__] lastPathComponent] \
	lineNumber:[NSNumber numberWithInt:__LINE__] \
	formatAndArgs:f, ##__VA_ARGS__]

@interface JPLogRecorder : NSObject

// JPLog is mapped to this method - use JPLog not this
+ (void) logFromFile:(NSString *)file lineNumber:(NSNumber *)line formatAndArgs:(NSString *)format, ...;
// singleton reference to the log array
+ (NSMutableArray *) logArray;
// call this method in -applicationWillTerminate: for continous logging through crashes and force quits
+ (BOOL) saveLogArray;
// access the log at runtime in string form
+ (NSString *) logArrayAsString;
// set the max number of log statements retained in log array (default 50)
+ (void) setMaxLogsRetained:(NSInteger)maxLogs;
// turn on production logging
+ (void) setShouldLogInProduction:(BOOL)prodLogOn;
// query if production logging is on
+ (BOOL) shouldLogInProduction;

@end
