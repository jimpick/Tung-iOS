//
//  JPXMLtoDictionary.h
//  Version 0.2.0
//
//  Created by Jamie Perkins on 4/3/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol XMLtoDictionaryDelegate <NSObject>

@required
-(void) xmlDictionaryComplete:(NSDictionary *)dict;

@end

@interface JPXMLtoDictionary : NSObject <NSXMLParserDelegate>

@property (nonatomic, assign) id <XMLtoDictionaryDelegate> delegate;
@property (nonatomic, assign) BOOL isParsing;

-(void) convertFromUrl:(NSURL *)url;
-(void) convertFromUrl:(NSURL *)url withLimit:(NSInteger)limit andPage:(NSInteger)page;
-(void) convertFromData:(NSData *)data;
-(void) convertFromData:(NSData *)data withLimit:(NSInteger)limit andPage:(NSInteger)page;

@end
