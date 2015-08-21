//
//  JPXMLtoDictionary.h
//  Version 0.2.0
//
//  Created by Jamie Perkins on 4/3/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface JPXMLtoDictionary : NSObject <NSXMLParserDelegate>

@property (nonatomic, assign) BOOL isParsing;

-(NSDictionary *) xmlDataToDictionary:(NSData *)data;

@end
