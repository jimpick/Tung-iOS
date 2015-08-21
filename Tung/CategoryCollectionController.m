//
//  CategoryCollectionController.m
//  Tung
//
//  Created by Jamie Perkins on 3/31/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "CategoryCollectionController.h"
#import "TPAACAudioConverter.h"
#import "tungCommonObjects.h"
#import <AudioToolbox/AudioToolbox.h>

@interface CategoryCollectionController ()

@property (nonatomic) CGSize cellSize;
@property (nonatomic, strong) NSString *selectedCategoryImageName;
@property (nonatomic, strong) NSNumber *selectedCategory;
@property (nonatomic, strong) NSArray *colors;
@property (nonatomic, strong) NSArray *categories;
@property (nonatomic, strong) NSString *pathToConvertedFile;
@property (nonatomic, retain) tungCommonObjects *tungObjects;
@property (nonatomic, assign) CGFloat fontSize;

@end

@implementation CategoryCollectionController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _tungObjects = [tungCommonObjects establishTungObjects];
    
    // set up collection view size based on screen size
    CGFloat screenWidth = [[UIScreen mainScreen]bounds].size.width;
    CGFloat screenHeight = [[UIScreen mainScreen]bounds].size.height;
    NSLog(@"setting up collection view for screen size of %f x %f", screenWidth, screenHeight);
    
    CGSize collectionSize = CGSizeMake(screenWidth +1, screenHeight +1);
    CGFloat cellWidth = screenWidth / 2;
    CGFloat cellHeight = (screenHeight - 44 - 3) / 4; // deduct title bar and 3 spacers
    _cellSize = CGSizeMake(cellWidth, cellHeight);
    
    if (screenHeight < 568) {
        // 3.5 inch screen
        _selectedCategoryImageName = @"selectedCategory3point5inch.png";
        _fontSize = 19;
    } else {
        // 4 inch and larger screens
        _selectedCategoryImageName = @"selectedCategory.png";
        if (screenWidth >= 414) {
            _fontSize = 23;
        }
        else if (screenWidth  >= 375) {
            _fontSize = 20;
        }
        else {
            _fontSize = 19;
        }
    }
    CGPoint collectionPoint = CGPointMake(0, 0);
    CGRect collectionFrame = {collectionPoint, collectionSize};
    
    // set up collection view flow layout
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.minimumLineSpacing = 1.0f;
    flowLayout.minimumInteritemSpacing = 1.0f;
    flowLayout.itemSize = _cellSize;
    flowLayout.sectionInset = UIEdgeInsetsMake(0, 0, 0, 0);
    
    // instantiate
    self.categoryCollectionView = [[UICollectionView alloc] initWithFrame:collectionFrame collectionViewLayout:flowLayout];
    
    // set properties
    [self.categoryCollectionView setDataSource:self];
    [self.categoryCollectionView setDelegate:self];
    [self.categoryCollectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"categoryCell"];
    [self.categoryCollectionView setBackgroundColor:[UIColor whiteColor]];
    self.categoryCollectionView.scrollEnabled = YES;
    
    // add to view
    [self.view addSubview: self.categoryCollectionView];
    
    // convert lpcm -> aac
    NSString *originalFilePath = [self.recordingInfoDictionary objectForKey:@"pathToRecordingFile"];
    _pathToConvertedFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"newTung.m4a"];
    
    // delete converted file if exists.
    if ([[NSFileManager defaultManager] fileExistsAtPath:_pathToConvertedFile]) {
        NSError *deleteFileError;
        [[NSFileManager defaultManager] removeItemAtPath:_pathToConvertedFile error:&deleteFileError];
    }
    
    TPAACAudioConverter *audioConverter = [[TPAACAudioConverter alloc] initWithDelegate:self source:originalFilePath destination:_pathToConvertedFile];
    
    [audioConverter start];
    
    // orginal file size
    NSError *attributesError;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:originalFilePath error:&attributesError];
    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
    NSLog(@"started audio conversion. Original file size: %@ b", fileSizeNumber);
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    
    return [_tungObjects.categories count];
}

- (void)updateSelectedCategory:(NSNumber *)selected {
    NSInteger selCat = [selected integerValue];
    [self makeCategorySelected:selCat];
}

#pragma mark - collection view methods

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    UICollectionViewCell *categoryCell = [collectionView dequeueReusableCellWithReuseIdentifier:@"categoryCell" forIndexPath:indexPath];
    
    UIButton *cellButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect buttonFrame = {CGPointMake(0,0), _cellSize};
    [cellButton setFrame:buttonFrame];
    [cellButton addTarget:self action:@selector(pickCategory:) forControlEvents:UIControlEventTouchDown];
    [cellButton setTitleColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:.4] forState:UIControlStateNormal];
    cellButton.titleLabel.font = [UIFont systemFontOfSize:_fontSize];
    cellButton.adjustsImageWhenHighlighted = NO;
    // depending on item
    [cellButton setTitle:[_tungObjects.categories objectAtIndex:[indexPath item]] forState:UIControlStateNormal];
    [cellButton setBackgroundColor:[_tungObjects.categoryColors objectAtIndex:[indexPath item]]];
    [cellButton setTag:[indexPath item]];
    
    [categoryCell addSubview:cellButton];
    
    return categoryCell;
}

// NOT USED
/*
- (void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    NSLog(@"%@", indexPath);
}
 */

- (void)pickCategory:(id)sender {
    
    NSInteger tag = [sender tag];
    [self makeCategorySelected:tag];
}

- (void)makeCategorySelected:(NSInteger)selected {
    
    self.selectedCategory = [NSNumber numberWithInteger:selected];
    
    for (int i = 0; i < [_tungObjects.categories count]; i++) {
        
        NSIndexPath *cellIndex = [NSIndexPath indexPathForItem:i inSection:0];
        UICollectionViewCell *cell = [self.categoryCollectionView cellForItemAtIndexPath:cellIndex];
        
        NSArray *subviews = [cell subviews];
        UIButton *cellButton = [subviews objectAtIndex:1];
        
        if (i == selected) {
            
            [cellButton setBackgroundImage:[UIImage imageNamed:_selectedCategoryImageName] forState:UIControlStateNormal];
            [cellButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            cellButton.titleLabel.font = [UIFont boldSystemFontOfSize:_fontSize];
            
        } else {
            
            [cellButton setBackgroundImage:nil forState:UIControlStateNormal];
            [cellButton setTitleColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:.4] forState:UIControlStateNormal];
            cellButton.titleLabel.font = [UIFont systemFontOfSize:_fontSize];
        }
    }
}

#pragma mark - audio format conversion methods

- (void) AACAudioConverterDidFinishConversion:(TPAACAudioConverter *)converter {
    
    // Log conversion success with converted file size
    NSError *attributesError;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_pathToConvertedFile error:&attributesError];
    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
    NSLog(@"Finished conversion. Converted file size: %@ b", fileSizeNumber);
    
}

- (void) AACAudioConverter:(TPAACAudioConverter *)converter didFailWithError:(NSError *)error {
    
    NSLog(@"error converting audio file: %@", error);
}

- (void) AACAudioConverter:(TPAACAudioConverter *)converter didMakeProgress:(CGFloat)progress {
    
    NSLog(@"conversion progress: %f", progress);
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UIViewController *destination = segue.destinationViewController;
    UIViewController *categoryCollectionController = [segue sourceViewController];
    [destination setValue:categoryCollectionController forKey:@"categoryCollectionController"];
    // info to pass to next view controller
    if ([[segue identifier] isEqualToString:@"toPostView"]) {
        [self.recordingInfoDictionary setObject:_pathToConvertedFile forKey:@"convertedFile"];
    	[self.recordingInfoDictionary setObject:self.selectedCategory forKey:@"selectedCategory"];
    	[self.recordingInfoDictionary setObject:@"" forKey:@"captionText"];
    	[destination setValue:self.recordingInfoDictionary forKey:@"recordingInfoDictionary"];
    }
    
}

- (IBAction)next:(id)sender {
    if (self.selectedCategory != nil) {
        [self performSegueWithIdentifier:@"toPostView" sender:self];
    } else {
        UIAlertView *chooseCategoryAlert = [[UIAlertView alloc] initWithTitle:@"Please pick a category" message:nil delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [chooseCategoryAlert show];
    }
}
@end
