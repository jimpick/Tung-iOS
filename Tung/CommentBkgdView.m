//
//  CommentBkgdView.m
//  Tung
//
//  Created by Jamie Perkins on 10/16/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import "CommentBkgdView.h"
#import "TungPodcastStyleKit.h"

@implementation CommentBkgdView


- (void)drawRect:(CGRect)rect {
    switch (_type) {
        case kCommentBkgdTypeMine:
    		[TungPodcastStyleKit drawCommentBkgdUserWithOuterFrame:rect];
            break;
        default:
            [TungPodcastStyleKit drawCommentBkgdWithOuterFrame:rect];
            break;
    }
}


@end
