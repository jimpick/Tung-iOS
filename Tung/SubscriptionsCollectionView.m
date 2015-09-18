//
//  SubscriptionsCollectionView.m
//  Tung
//
//  Created by Jamie Perkins on 5/1/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "SubscriptionsCollectionView.h"
#import "AppDelegate.h"
#import "SubscriptionViewCell.h"
#import "PodcastViewController.h"

@interface SubscriptionsCollectionView () <NSFetchedResultsControllerDelegate>

@property NSFetchedResultsController *resultsController;
@property TungPodcast *podcast;
@property TungCommonObjects *tung;
@property NSMutableArray *sectionChanges;
@property NSMutableArray *itemChanges;
@property UISearchController *searchController;
@property UIImageView *findPodcastsHere;

@end

@implementation SubscriptionsCollectionView

static NSString * const reuseIdentifier = @"artCell";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Subscriptions";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiateSearch)];
    
    _tung = [TungCommonObjects establishTungObjects];
    _tung.ctrlBtnDelegate = self;
    _podcast = [TungPodcast new];
    
    // for search controller
    self.definesPresentationContext = YES;
    _podcast.navController = [self navigationController];
    _podcast.delegate = self;
    
    // get subscribed podcasts
    AppDelegate *appDelegate =  [[UIApplication sharedApplication] delegate];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"PodcastEntity"];
    //NSPredicate *predicate = [NSPredicate predicateWithFormat: @"isSubscribed == %@", [NSNumber numberWithBool:YES]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isSubscribed == YES"];
    request.predicate = predicate;
    NSSortDescriptor *dateSort = [[NSSortDescriptor alloc] initWithKey:@"dateSubscribed" ascending:YES];

    request.sortDescriptors = @[dateSort];
    
    _resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:appDelegate.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    _resultsController.delegate = self;
    
    NSError *fetchingError;
    if ([_resultsController performFetch:&fetchingError]) {
        NSLog(@"successfully fetched");
    }
    else {
        NSLog(@"failed to fetch: %@", fetchingError);
    }

    // set up collection view size based on screen size
    CGFloat screenWidth = [[UIScreen mainScreen]bounds].size.width;
    
    CGFloat cellWidthAndHeight = (screenWidth - 2) / 3;
    CGSize cellSize = CGSizeMake(cellWidthAndHeight, cellWidthAndHeight);
    
    // set up collection view flow layout
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.minimumLineSpacing = 1.0f;
    flowLayout.minimumInteritemSpacing = 1.0f;
    flowLayout.itemSize = cellSize;
    flowLayout.sectionInset = UIEdgeInsetsMake(0, 0, 0, 0);
    flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    
    self.collectionView.collectionViewLayout = flowLayout;
    self.collectionView.scrollEnabled = YES;
    self.collectionView.backgroundColor = [_tung bkgdGrayColor];
    
    // preload feeds, check for no subs
    NSError *error;
    NSArray *result = [appDelegate.managedObjectContext executeFetchRequest:request error:&error];
    if (result.count > 0) {
        for (int i = 0; i < result.count; i++) {
            PodcastEntity *podcastEntity = [result objectAtIndex:i];
            //NSLog(@"podcast at index: %d", i);
            // entity -> dict
            NSArray *keys = [[[podcastEntity entity] attributesByName] allKeys];
            NSDictionary *podcastDict = [podcastEntity dictionaryWithValuesForKeys:keys];
            //NSLog(@"%@", podcastDict);
            [_podcast.podcastArray insertObject:podcastDict atIndex:i];
        }
        [_podcast preloadFeedsWithLimit:0];
    }
    
}
#pragma mark - tungObjects/tungPodcasts delegate methods

// ControlButtonDelegate required method
- (void) initiateSearch {
    if ([_findPodcastsHere isDescendantOfView:self.view]) {
        [UIView animateWithDuration:.35
                              delay:0
                            options:UIViewAnimationOptionCurveLinear
                         animations:^{
                             _findPodcastsHere.alpha = 0;
                         }
                         completion:nil
         ];
    }
    
    [_podcast.searchController setActive:YES];
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"revealSearch"];
    
    self.navigationItem.titleView = _podcast.searchController.searchBar;
    [self.navigationItem setRightBarButtonItem:nil animated:YES];
    	
    [_podcast.searchController.searchBar becomeFirstResponder];
    
}
// ControlButtonDelegate required method
-(void) dismissPodcastSearch {
    if ([_findPodcastsHere isDescendantOfView:self.view]) {
        [UIView animateWithDuration:.35
                              delay:0
                            options:UIViewAnimationOptionCurveLinear
                         animations:^{
                             _findPodcastsHere.alpha = 1;
                         }
                         completion:nil
         ];
    }
    [_podcast.searchController setActive:NO];
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"hideSearch"];
    
    self.navigationItem.titleView = nil;
    UIBarButtonItem *searchBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiateSearch)];
    [self.navigationItem setRightBarButtonItem:searchBtn animated:YES];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - NSFetchedResultsController delegate methods

- (void) controllerWillChangeContent:(NSFetchedResultsController *)controller {
    //NSLog(@"controller will change content");
    _sectionChanges = [[NSMutableArray alloc] init];
    _itemChanges = [[NSMutableArray alloc] init];
}
- (void) controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    //NSLog(@"controller did change section");
    
    NSMutableDictionary *change = [[NSMutableDictionary alloc] init];
    change[@(type)] = @(sectionIndex);
    [_sectionChanges addObject:change];
}
- (void) controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    //NSLog(@"controller did change object");
    
    NSMutableDictionary *change = [[NSMutableDictionary alloc] init];
    switch(type) {
        case NSFetchedResultsChangeInsert:
            change[@(type)] = newIndexPath;
            break;
        case NSFetchedResultsChangeDelete:
            change[@(type)] = indexPath;
            break;
        case NSFetchedResultsChangeUpdate:
            change[@(type)] = indexPath;
            break;
        case NSFetchedResultsChangeMove:
            change[@(type)] = @[indexPath, newIndexPath];
            break;
    }
    [_itemChanges addObject:change];
}

- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {
    //NSLog(@"controller did change content");
    [self.collectionView performBatchUpdates:^{
        for (NSDictionary *change in _sectionChanges) {
            [change enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                NSFetchedResultsChangeType type = [key unsignedIntegerValue];
                switch(type) {
                    case NSFetchedResultsChangeInsert:
                        [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                        break;
                    case NSFetchedResultsChangeDelete:
                        [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                        break;
                    default:
                        break;
                }
            }];
        }
        for (NSDictionary *change in _itemChanges) {
            [change enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                NSFetchedResultsChangeType type = [key unsignedIntegerValue];
                switch(type) {
                    case NSFetchedResultsChangeInsert:
                        [self.collectionView insertItemsAtIndexPaths:@[obj]];
                        break;
                    case NSFetchedResultsChangeDelete:
                        [self.collectionView deleteItemsAtIndexPaths:@[obj]];
                        break;
                    case NSFetchedResultsChangeUpdate:
                        [self.collectionView reloadItemsAtIndexPaths:@[obj]];
                        break;
                    case NSFetchedResultsChangeMove:
                        [self.collectionView moveItemAtIndexPath:obj[0] toIndexPath:obj[1]];
                        break;
                }
            }];
        }
    } completion:^(BOOL finished) {
        _sectionChanges = nil;
        _itemChanges = nil;
    }];
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {

    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    //NSLog(@"collection view number of items in section");

    id <NSFetchedResultsSectionInfo> sectionInfo = _resultsController.sections[section];
    if (sectionInfo.numberOfObjects == 0) {
        /*
        UILabel *noSubsLabel = [[UILabel alloc] init];
        noSubsLabel.text = @"You haven't subscribed to any podcasts yet";
        noSubsLabel.textColor = [UIColor grayColor];
        noSubsLabel.textAlignment = NSTextAlignmentCenter;
         */
        UIImage *findPodcastsImage = [UIImage imageNamed:@"find-podcasts-here.png"];
        _findPodcastsHere = [[UIImageView alloc] initWithImage:findPodcastsImage];
        CGRect imageRect = CGRectMake(self.view.bounds.size.width - 220, 70, 200, 173);
        _findPodcastsHere.frame = imageRect;
        if (![_findPodcastsHere isDescendantOfView:self.view]) [self.view addSubview:_findPodcastsHere];
    }
    else {
        if ([_findPodcastsHere isDescendantOfView:self.view]) [_findPodcastsHere removeFromSuperview];
    }
    return sectionInfo.numberOfObjects;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"collection view cell for item at index path %ld", (long)indexPath.row);
    
    //NSLog(@"cell for row at index: %ld", (long)indexPath.row);
    SubscriptionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    PodcastEntity *podcastEntity = [_resultsController objectAtIndexPath:indexPath];
    // entity -> dict
    //NSArray *keys = [[[podcastEntity entity] attributesByName] allKeys];
    //NSDictionary *podcastDict = [podcastEntity dictionaryWithValuesForKeys:keys];
    
    NSData *artImageData = [TungCommonObjects retrievePodcastArtDataWithUrlString:podcastEntity.artworkUrl600];
    UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
    
    cell.artImageView.image = artImage;
    cell.contentView.backgroundColor = [UIColor whiteColor];
    
    return cell;
}

#pragma mark <UICollectionViewDelegate>

/*
// Uncomment this method to specify if the specified item should be highlighted during tracking
- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}
*/

/*
// Uncomment this method to specify if the specified item should be selected
- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}
*/
- (void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    PodcastEntity *podcastEntity = [_resultsController objectAtIndexPath:indexPath];
    // entity -> dict
    NSDictionary *podcastDict = [TungCommonObjects podcastEntityToDict:podcastEntity];
    
    [self resignFirstResponder];
    PodcastViewController *podcastView = [self.storyboard instantiateViewControllerWithIdentifier:@"podcastView"];
    podcastView.podcastDict = [podcastDict mutableCopy];
    [self.navigationController pushViewController:podcastView animated:YES];
}

/*
// Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
- (BOOL)collectionView:(UICollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath {
	return NO;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
	return NO;
}

- (void)collectionView:(UICollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
	
}
*/

@end
