//
//  JPXMLtoDictionary.m
//  Version 0.2.0
//
//  Created by Jamie Perkins on 4/3/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "JPXMLtoDictionary.h"
#import "JPLogRecorder.h"

@interface JPXMLtoDictionary()

@property (strong, nonatomic) NSMutableArray *dictionaryStack;
@property (strong, nonatomic) NSMutableString *currentString;

@end

@implementation JPXMLtoDictionary

#pragma mark - public methods

-(NSDictionary *) xmlDataToDictionary:(NSData *)data {
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = self;
    
    // initialize caches
    _dictionaryStack = [NSMutableArray array];
    _currentString = [@"" mutableCopy];
    
    // parser's gonna parse
    BOOL success = [parser parse];
    // Return the stack’s root dictionary on success
    if (success) {
        NSDictionary *resultDict = [_dictionaryStack objectAtIndex:0];
        return resultDict;
    }
    return nil;
}

#pragma mark - NSXMLParser delegate methods

-(void) parserDidStartDocument:(NSXMLParser *)parser {
    
    //JPLog(@"////// parsing started");
    _isParsing = YES;
}

-(void) parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    
    // Get the dictionary for the current level in the stack
    NSMutableDictionary *parentDict = [_dictionaryStack lastObject];
    
    // Create the child dictionary for the new element, and initialize it with the attributes
    NSMutableDictionary *childDict = [NSMutableDictionary dictionary];
    if (attributeDict.allKeys.count > 0)
    	[childDict setObject:attributeDict forKey:@"el:attributes"];
    
    // If there’s already an item for this key, it means we need to create an array
    id existingValue = [parentDict objectForKey:elementName];
    if (existingValue) {
        
        NSMutableArray *array = nil;
        if ([existingValue isKindOfClass:[NSMutableArray class]])
        {
            // The array exists, so use it
            array = (NSMutableArray *) existingValue;
        }
        else {
            // Create an array if it doesn’t exist
            array = [NSMutableArray array];
            [array addObject:existingValue];
            
            // Replace the child dictionary with an array of children dictionaries
            [parentDict setObject:array forKey:elementName];
        }
        
        // Add the new child dictionary to the array
        [array addObject:childDict];
    }
    else {
        // No existing value, so update the dictionary
        [parentDict setObject:childDict forKey:elementName];
    }
    
    // Update the stack
    [_dictionaryStack addObject:childDict];
    _currentString = [@"" mutableCopy]; // reset
    
    //[_attributeDictionaries addObject:attributeDict];
    
}
-(void) parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    
	[_currentString appendString:string];

}

-(void) parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    //if ([[_attributeDictionaries lastObject] allKeys].count > 0)
    //	[[_dictionaryStack lastObject] setObject:[_attributeDictionaries lastObject] forKey:@"el:attributes"];
    
    NSString *text = [_currentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // Set the text property
    if ([text length] > 0) {
        
        [_dictionaryStack removeLastObject];
        
        NSMutableDictionary *parentDict = [_dictionaryStack lastObject];
        
        if ([elementName isEqualToString:@"pubDate"] || [elementName isEqualToString:@"lastBuildDate"]) {
            [parentDict setObject:[self pubDateToNSDate:text] forKey:elementName];
        } else {
            [parentDict setObject:text forKey:elementName];
        }
        
        // Reset the text
        _currentString = [@"" mutableCopy]; // reset
    }
    else {
        // Pop the current dict
        if (_dictionaryStack.count > 1) [_dictionaryStack removeLastObject];
    }

}

-(void) parserDidEndDocument:(NSXMLParser *)parser {
    _isParsing = NO;

}

-(void) parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    JPLog(@"Parser error: %@", [parseError localizedDescription]);
    
    _isParsing = NO;
}

#pragma mark - Private methods

static NSDateFormatter *pubDateInterpreter_A = nil;
static NSDateFormatter *pubDateInterpreter_B = nil;
static NSDateFormatter *pubDateInterpreter_C = nil;
static NSDateFormatter *pubDateInterpreter_D = nil;

-(NSDate *) pubDateToNSDate: (NSString *)pubDate {
    
    NSDate *date = nil;
    if (pubDateInterpreter_A == nil) {
        pubDateInterpreter_A = [[NSDateFormatter alloc] init];
        [pubDateInterpreter_A setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss ZZ"];
    }
    
    if (pubDateInterpreter_B == nil) {
        pubDateInterpreter_B = [[NSDateFormatter alloc] init];
        [pubDateInterpreter_B setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss zzz"];
    }
    
    if (pubDateInterpreter_C == nil) {
        pubDateInterpreter_C = [[NSDateFormatter alloc] init];
        [pubDateInterpreter_C setDateFormat:@"e MMM yyyy HH:mm:ss z"];
    }
    // 11 Aug 2014 16:00:00 GMT
    if (pubDateInterpreter_D == nil) {
        pubDateInterpreter_D = [[NSDateFormatter alloc] init];
        [pubDateInterpreter_D setDateFormat:@"d MMM yyyy HH:mm:ss z"];
    }
    
    if ([pubDateInterpreter_A dateFromString:pubDate]) {
        date = [pubDateInterpreter_A dateFromString:pubDate];
    }
    else if ([pubDateInterpreter_B dateFromString:pubDate]) {
        date = [pubDateInterpreter_B dateFromString:pubDate];
    }
    else if ([pubDateInterpreter_C dateFromString:pubDate]) {
        date = [pubDateInterpreter_C dateFromString:pubDate];
    }
    else if ([pubDateInterpreter_D dateFromString:pubDate]) {
        date = [pubDateInterpreter_D dateFromString:pubDate];
    }
    else {
        JPLog(@"could not convert date: %@", pubDate);
        date = [NSDate date];
    }
    return date;
    
}

@end
