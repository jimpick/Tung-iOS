//
//  JPLogRecorder.m
//
//  Created by Jamie Perkins on 2/14/16.
//  Copyright © 2016 Inorganik Produce, Inc. All rights reserved.
//

#import "JPLogRecorder.h"

static BOOL JPLogRecorder_shouldLogInProduction = NO;
static NSInteger JPLogRecorder_maxLogsRetained = 50;

@implementation JPLogRecorder

#pragma mark - Logging

+ (void) logFromFile:(NSString *)file lineNumber:(NSNumber *)line formatAndArgs:(NSString *)format, ... {
    
    if ([JPLogRecorder isLoggingEnabled]) {
        va_list args;
        va_start(args, format);
        NSString *log = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        
        NSString *logStatement = [NSString stringWithFormat:@"<%@:%@> %@", file, line, log];
        
        // pass through to NSLog
        NSLog(@"%@", logStatement);
        
        // add to front of logArray (with date) so it is in reverse chronological order
        NSMutableArray *logArray = [self logArray];
        NSString *formattedDate = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterMediumStyle];
        NSString *retainedLogStatement = [NSString stringWithFormat:@"[%@] %@", formattedDate, logStatement];
        [logArray insertObject:retainedLogStatement atIndex:0];
        
        // pop excess logs
        if ([logArray count] > JPLogRecorder_maxLogsRetained) {
            logArray = [[logArray subarrayWithRange:NSMakeRange(0, JPLogRecorder_maxLogsRetained)] mutableCopy];
        }
    }
}

#pragma mark - Log array

+ (NSMutableArray *) logArray {
    static NSMutableArray *logArray = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *logArrayFilepath = [self logArrayFilepath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:logArrayFilepath]) {
            logArray = [[NSMutableArray alloc] initWithContentsOfFile:logArrayFilepath];
        }
        else {
            logArray = [NSMutableArray array];
        }
    });
    return logArray;
}

+ (BOOL) saveLogArray {
    NSMutableArray *logArray = [self logArray];
    NSString *logArrayFilepath = [self logArrayFilepath];
    return [logArray writeToFile:logArrayFilepath atomically:YES];
}

+ (NSString *) logArrayFilepath {
    NSArray *folders = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
    NSURL *libraryDir = [folders objectAtIndex:0];
    return [libraryDir.path stringByAppendingPathComponent:@"JPLogRecorder_log.txt"];
}

+ (NSString *) logArrayAsString {
    NSMutableArray *logArray = [self logArray];
    return [logArray componentsJoinedByString:@"\n\n"];
}

+ (void) setMaxLogsRetained:(NSInteger)maxLogs {
    JPLogRecorder_maxLogsRetained = maxLogs;
}

#pragma mark - Flags

+ (BOOL) shouldLogInProduction {
    return JPLogRecorder_shouldLogInProduction;
}

+ (void) setShouldLogInProduction:(BOOL)prodLogOn {
    JPLogRecorder_shouldLogInProduction = prodLogOn;
}

+ (BOOL) isLoggingEnabled {
    return ([self isProduction]) ? JPLogRecorder_shouldLogInProduction : YES;
}

+ (BOOL) isProduction {
#ifdef DEBUG
    return NO;
#else
    return YES;
#endif
}

@end
