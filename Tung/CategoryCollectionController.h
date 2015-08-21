//
//  CategoryCollectionController.h
//  Tung
//
//  Created by Jamie Perkins on 3/31/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TPAACAudioConverter.h"

@interface CategoryCollectionController : UIViewController <UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, UICollectionViewDelegate, UIAlertViewDelegate, TPAACAudioConverterDelegate>

@property (strong, nonatomic) UICollectionView *categoryCollectionView;
@property (strong, nonatomic) NSMutableDictionary *recordingInfoDictionary;

- (IBAction)next:(id)sender;
- (void)updateSelectedCategory:(NSNumber *)selected;

@end
