//
//  JPXMLtoDictionary.m
//  Version 0.2.0
//
//  Created by Jamie Perkins on 4/3/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "JPXMLtoDictionary.h"

@interface JPXMLtoDictionary()

@property (strong, nonatomic) NSDate *parserStartTime;
@property (strong, nonatomic) NSMutableArray *openElements;
@property (strong, nonatomic) NSMutableArray *openDictionaries;
@property (strong, nonatomic) NSMutableArray *openArrays;
@property (strong, nonatomic) NSMutableArray *openArrayKeys;
@property (strong, nonatomic) NSMutableString *currentString;
@property (strong, nonatomic) NSMutableArray *attributeDictionaries;
@property (strong, nonatomic) NSMutableString *justClosed;
@property (strong, nonatomic) NSMutableArray *arrayCounts;
@property (strong, nonatomic) NSMutableArray *arrayKeys;
@property (strong, nonatomic) NSMutableArray *isArrayFlags;
@property (strong, nonatomic) NSData *data;
@property (nonatomic, assign) NSInteger arrayStartIndex;
@property (nonatomic, assign) NSInteger arrayEndIndex;
@property (nonatomic, assign) NSInteger arrayCount;
@property (strong, nonatomic) NSMutableArray *currentArrayCounts;
@property (nonatomic, assign) BOOL firstParse;

@end

@implementation JPXMLtoDictionary

#pragma mark - public methods

-(void) convertFromUrl:(NSURL *)url {
    //NSLog(@"converting xml from url: %@", url);
    _data = [NSData dataWithContentsOfURL:url];
    [self beginParsing];
}

-(void) convertFromUrl:(NSURL *)url withLimit:(NSInteger)limit andPage:(NSInteger)page {
    _data = [NSData dataWithContentsOfURL:url];
    _arrayStartIndex = (limit * page) + 1;
    _arrayEndIndex = limit * (page + 1);
    [self beginParsing];
}

-(void) convertFromData:(NSData *)data {
    //NSLog(@"converting xml from data: %@", data);
    _data = data;
    [self beginParsing];
}

-(void) convertFromData:(NSData *)data withLimit:(NSInteger)limit andPage:(NSInteger)page {
    _data = data;
    _arrayStartIndex = (limit * page) + 1;
    _arrayEndIndex = limit * (page + 1);
    [self beginParsing];
}

#pragma mark - NSXMLParser delegate methods

-(void) parserDidStartDocument:(NSXMLParser *)parser {
    if (_firstParse) {
        //NSLog(@"////// parsing started");
        _parserStartTime = [NSDate date];
        _isParsing = YES;
    }
}

-(void) parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    
    // create a key based on depth and element name
    [_openElements addObject:elementName]; // openElements solely for determining depth
    NSMutableString *depthDash = [@"" mutableCopy];
    for (int i = 0; i < _openElements.count; i++) {
        depthDash = [[depthDash stringByAppendingString:@"–"] mutableCopy];
    }
    NSString *key = [depthDash stringByAppendingString:elementName];
    
    if (_firstParse) {
        // detect array item
        if ([_justClosed isEqualToString:elementName]) {
            // first detected
            if (![_arrayKeys containsObject:key]) {
                [_arrayKeys addObject:key];
                [_arrayCounts addObject:[NSNumber numberWithInt:1]];
            }
            // repeat
            else {
                int count = [[_arrayCounts lastObject] intValue];
                count++;
                // replace old count
                [_arrayCounts removeLastObject];
                [_arrayCounts addObject:[NSNumber numberWithInt:count]];
            }
        }
    }
    else {
        NSLog(@"%@", key); // uncomment to see xml structure
        // if it's an array
        if ([_arrayKeys containsObject:key]) {
            [_isArrayFlags addObject:@"YES"];
            // if it's the first item in the array
            if (![_openArrayKeys containsObject:key]) {
                [_openArrayKeys addObject:key];
            	[_openArrays addObject:[@[] mutableCopy]];
            }
        }
        else {
            [_isArrayFlags addObject:@"NO"];
        }
        
        [_openDictionaries addObject:[@{} mutableCopy]];
        _currentString = [@"" mutableCopy]; // reset
        [_attributeDictionaries addObject:attributeDict];
    }
    
}
-(void) parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    
    if (!_firstParse && string.length > 0) {
        _currentString = [[_currentString stringByAppendingString:string] mutableCopy];
    }
}

-(void) parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    [_openElements removeLastObject];
    _justClosed = [elementName mutableCopy];
    
    if (!_firstParse) {
        // if present, add attribute dictionary under "el:attributes" key
        if ([[_attributeDictionaries lastObject] allKeys].count > 0) {
            [[_openDictionaries lastObject] setObject:[_attributeDictionaries lastObject] forKey:@"el:attributes"];
        }
        [_attributeDictionaries removeLastObject];

        if (_arrayCount > 101) {
            NSLog(@"break!");
        }
        
        // close the currently open dictionary
        NSDictionary *completedDict = [_openDictionaries lastObject];
        
        // if there is a parent element
        if (_openDictionaries.count > 1) {
            
            // since it's not the root dict we can remove it bc it's closed
            [_openDictionaries removeLastObject];
            // if it contains child element(s) we assign the completed dict to it
            if (completedDict.allValues.count > 0) {
                
                if ([[_isArrayFlags lastObject] isEqualToString:@"YES"]) {
                    
                    _arrayCount++;
                    
                    if (_arrayEndIndex && _arrayCount >= _arrayStartIndex && _arrayCount <= _arrayEndIndex) {
                        [[_openArrays lastObject] addObject:completedDict];
                        [[_openDictionaries lastObject] setObject:[_openArrays lastObject] forKey:elementName];
                    }
                    else if (!_arrayEndIndex) {
                        [[_openArrays lastObject] addObject:completedDict];
                        [[_openDictionaries lastObject] setObject:[_openArrays lastObject] forKey:elementName];
                    }
                    
                    [self decrementArrayCount];
                }
                else {
                	[[_openDictionaries lastObject] setObject:completedDict forKey:elementName];
                }
            }
            // if the current string has length, this tag contained text and not child elements
            else if (_currentString.length > 0) {
                
                // detect pubDate and convert to NSDate
                NSDate *pubDate = nil;
                if ([elementName isEqualToString:@"pubDate"]) {
                    pubDate = [self pubDateToNSDate:_currentString];
                }
                
                if ([[_isArrayFlags lastObject] isEqualToString:@"YES"]) {
                    
                    _arrayCount++;
                    
                    if (_arrayEndIndex && _arrayCount >= _arrayStartIndex && _arrayCount <= _arrayEndIndex) {
                        (pubDate) ? [_openArrays addObject:pubDate] : [_openArrays addObject:_currentString];
                        [[_openDictionaries lastObject] setObject:[_openArrays lastObject] forKey:elementName];
                    }
                    else if (!_arrayEndIndex) {
                        (pubDate) ? [_openArrays addObject:pubDate] : [_openArrays addObject:_currentString];
                        [[_openDictionaries lastObject] setObject:[_openArrays lastObject] forKey:elementName];
                    }
                    
                    [self decrementArrayCount];
                }
                else {
                    if (pubDate) [[_openDictionaries lastObject] setObject:pubDate forKey:elementName];
                	else [[_openDictionaries lastObject] setObject:_currentString forKey:elementName];
                }
                _currentString = [@"" mutableCopy]; // reset
            }
            // else, no contents
        }
        // else, the parent element is the root element. parserDidEndDocument will fire
        [_isArrayFlags removeLastObject];
    }
}

-(void) parserDidEndDocument:(NSXMLParser *)parser {
    if (_firstParse) {
        _firstParse = NO;
        // parse again, this time, storing values
        parser = NULL;
        // because "NSXMLParser does not suport reentrant parsing"
        dispatch_queue_t reentrantAvoidanceQueue = dispatch_queue_create("reentrantAvoidanceQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_async(reentrantAvoidanceQueue, ^{
        	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:_data];
        	parser.delegate = self;
        	[parser parse];
        });
        dispatch_sync(reentrantAvoidanceQueue, ^{ });
    }
    else {
        _isParsing = NO;
        // uncomment the 2 lines below to see parsing time
//        NSTimeInterval parseTime = [[NSDate date] timeIntervalSinceDate:_parserStartTime];
//        NSLog(@"////// parsing finished. Took %f s", parseTime);
        dispatch_async(dispatch_get_main_queue(), ^{
        	[_delegate xmlDictionaryComplete:[_openDictionaries lastObject]];
        });
    }
}

-(void) parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    NSLog(@"Parser error: %@", [parseError localizedDescription]);
    
    _isParsing = NO;
}

#pragma mark - Private methods

-(void) beginParsing {
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:_data];
    parser.delegate = self;
    
    // initialize caches
    _openElements = [@[] mutableCopy];
    _openDictionaries = [@[] mutableCopy];
    _openArrays = [@[] mutableCopy];
    _openArrayKeys = [@[] mutableCopy];
    _currentString = [@"" mutableCopy];
    _attributeDictionaries = [@[] mutableCopy];
    _arrayCounts = [@[] mutableCopy];
    _arrayKeys = [@[] mutableCopy];
    _isArrayFlags = [@[] mutableCopy];
    _arrayCount = 0;
    
    _firstParse = YES;
    // parser's gonna parse
    [parser parse];
}

static NSDateFormatter *pubDateInterpreter = nil;

-(NSDate *) pubDateToNSDate: (NSString *)pubDate {
    
    if (pubDateInterpreter == nil) {
        pubDateInterpreter = [[NSDateFormatter alloc] init];
        [pubDateInterpreter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss ZZ"];
    }
    return [pubDateInterpreter dateFromString:pubDate];
    
}

-(void) decrementArrayCount {
    int count = [[_arrayCounts lastObject] intValue];
    
    [_arrayCounts removeLastObject];
    if (count == 0) {
        // last object in array
        [_openArrays removeLastObject];
        [_openArrayKeys removeLastObject];
        _arrayCount = 0; // reset array count;
    }
    else {
        count--;
        [_arrayCounts addObject:[NSNumber numberWithInt:count]];
    }
}

@end
