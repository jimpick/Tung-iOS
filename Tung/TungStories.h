//
//  TungActivity.h
//  Tung
//
//  Created by Jamie Perkins on 6/22/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TungCommonObjects;

@interface TungStories : NSObject

@property (nonatomic, retain) TungCommonObjects *tung;


@property (strong, nonatomic) NSMutableArray *storiesArray;

// request flags
@property (nonatomic, assign) BOOL requestingMore;
@property (nonatomic, assign) BOOL noMoreItemsToGet;
@property (nonatomic, assign) BOOL noResults;
@property (nonatomic, assign) BOOL queryExecuted;


@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;

@end
