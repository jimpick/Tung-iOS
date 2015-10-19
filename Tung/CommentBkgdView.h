//
//  CommentBkgdView.h
//  Tung
//
//  Created by Jamie Perkins on 10/16/15.
//  Copyright © 2015 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    kCommentBkgdTypeMine,
    kCommentBkgdTypeTheirs
} CommentBkgdType;

@interface CommentBkgdView : UIView

@property (nonatomic) CommentBkgdType type;

@end
