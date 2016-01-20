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
@property BOOL editingNotifications;
@property UIBarButtonItem *editAlertsBarButtonItem;
@property UILabel *noSubsLabel;
@property UIImageView *findPodcastsHere;

@end

@implementation SubscriptionsCollectionView

static NSString * const reuseIdentifier = @"artCell";
CGFloat screenWidth;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Subscriptions";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiateSearch)];
    _editAlertsBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Alerts" style:UIBarButtonItemStylePlain target:self action:@selector(toggleEditNotifySettings)];
    self.navigationItem.leftBarButtonItem = _editAlertsBarButtonItem;
    
    _tung = [TungCommonObjects establishTungObjects];
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
    NSSortDescriptor *dateSort = [[NSSortDescriptor alloc] initWithKey:@"timeSubscribed" ascending:YES];
    request.sortDescriptors = @[dateSort];
    _resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:appDelegate.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    _resultsController.delegate = self;
    
    NSError *fetchingError;
    if (![_resultsController performFetch:&fetchingError]) {
        CLS_LOG(@"failed to fetch: %@", fetchingError);
    }

    // set up collection view size based on screen size
    screenWidth = [[UIScreen mainScreen]bounds].size.width;
    
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
    self.collectionView.backgroundColor = [TungCommonObjects bkgdGrayColor];
    // background view
    _noSubsLabel = [[UILabel alloc] init];
    _noSubsLabel.text = @"You haven't subscribed to\nany podcasts yet";
    _noSubsLabel.numberOfLines = 2;
    _noSubsLabel.textColor = [UIColor grayColor];
    _noSubsLabel.textAlignment = NSTextAlignmentCenter;
    self.collectionView.backgroundView = _noSubsLabel;
    /*
    UIImage *findPodcastsImage = [UIImage imageNamed:@"find-podcasts-here.png"];
    _findPodcastsHere = [[UIImageView alloc] initWithImage:findPodcastsImage];
    CGRect imageRect = CGRectMake(self.view.bounds.size.width - 220, 6, 200, 173);
    _findPodcastsHere.frame = imageRect;
    self.collectionView.backgroundView = _findPodcastsHere;
    self.collectionView.backgroundView.contentMode = UIViewContentModeTopRight;
    */
}

NSTimer *promptTimer;

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    _tung.ctrlBtnDelegate = self;
    _tung.viewController = self;
    
    SettingsEntity *settings = [TungCommonObjects settings];
    
    // prompt for notifications delay
    if (!settings.hasSeenNewEpisodesPrompt.boolValue && ![TungCommonObjects hasGrantedNotificationPermissions]) {
    	promptTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:_tung selector:@selector(promptForNotificationsForEpisodes) userInfo:nil repeats:NO];
    }
    
    // clear subscriptions badge and adjust app badge
    if (settings.numPodcastNotifications.integerValue > 0) {
        NSInteger startingVal = settings.numPodcastNotifications.integerValue;
        if ([UIApplication sharedApplication].applicationIconBadgeNumber > 0) {
            [UIApplication sharedApplication].applicationIconBadgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber - settings.numPodcastNotifications.integerValue;
        }
        settings.numPodcastNotifications = [NSNumber numberWithInteger:0];
        [TungCommonObjects saveContextWithReason:@"adjust subscriptions badge number"];
        // adjust app icon badge number
        NSInteger newBadgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber - startingVal;
        newBadgeNumber = MAX(0, newBadgeNumber);
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:newBadgeNumber];
    }
    
}



- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [promptTimer invalidate];
    if (_editingNotifications) [self toggleEditNotifySettings];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    /*
    if (_podcast.searchController.active) {
        [_podcast.searchController setActive:NO];
        [self dismissPodcastSearch];
    }*/
}
                                             
#pragma mark - Editing notification stuff
                                             
- (void) toggleEditNotifySettings {
 
    _editingNotifications = !_editingNotifications;
    
    if (_editingNotifications) {
    	_editAlertsBarButtonItem.title = @"Done";
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotifyPrefChangedNotification:) name:@"notifyPrefChanged" object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    	_editAlertsBarButtonItem.title = @"Alerts";
    }
    
    [self.collectionView performBatchUpdates:^{
    	[self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
    } completion:nil];
 
}

- (void) handleNotifyPrefChangedNotification:(NSNotification *)notification {
    
    if (notification.userInfo[@"message"]) {
        [TungCommonObjects showBannerAlertForText:notification.userInfo[@"message"] andWidth:screenWidth];
    }
}

#pragma mark - tungObjects/tungPodcasts delegate methods


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
    //CLS_LOG(@"controller will change content");
    _sectionChanges = [[NSMutableArray alloc] init];
    _itemChanges = [[NSMutableArray alloc] init];
}
- (void) controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    //CLS_LOG(@"controller did change section");
    
    NSMutableDictionary *change = [[NSMutableDictionary alloc] init];
    change[@(type)] = @(sectionIndex);
    [_sectionChanges addObject:change];
}
- (void) controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    //CLS_LOG(@"controller did change object");
    
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
    //CLS_LOG(@"controller did change content");
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
    //CLS_LOG(@"collection view number of items in section");

    id <NSFetchedResultsSectionInfo> sectionInfo = _resultsController.sections[section];
    if (sectionInfo.numberOfObjects == 0) {
        //_findPodcastsHere.hidden = NO;
		self.collectionView.backgroundView = _noSubsLabel;
        self.navigationItem.leftBarButtonItem = nil;
    }
    else {
        //_findPodcastsHere.hidden = YES;
        self.collectionView.backgroundView = nil;
        self.navigationItem.leftBarButtonItem = _editAlertsBarButtonItem;
    }
    return sectionInfo.numberOfObjects;
}

UILabel static *prototypeBadge;

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    //CLS_LOG(@"collection view cell for item at index path %ld", (long)indexPath.row);
    
    //CLS_LOG(@"cell for row at index: %ld", (long)indexPath.row);
    SubscriptionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    PodcastEntity *podcastEntity = [_resultsController objectAtIndexPath:indexPath];
    
    cell.collectionId = podcastEntity.collectionId;
    NSData *artImageData = [TungCommonObjects retrieveSSLPodcastArtDataWithUrlString:podcastEntity.artworkUrlSSL];
    UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
    
    // podcast art
    cell.artImageView.image = artImage;
    cell.contentView.backgroundColor = [UIColor whiteColor];
    
    // new episodes badge
    cell.badge.type = kMiscViewTypeSubscribeBadge;
    cell.badge.text = @"";
    if (podcastEntity.numNewEpisodes.integerValue > 0) {
        cell.badge.hidden = NO;
        if (podcastEntity.numNewEpisodes.integerValue > 20) {
            cell.badge.text = @"20+";
        } else {
            cell.badge.text = [NSString stringWithFormat:@"%@", podcastEntity.numNewEpisodes];
        }
    } else {
        cell.badge.hidden = YES;
    }
    
    // adjust badge width if necessary
    if (!prototypeBadge) {
        prototypeBadge = [[UILabel alloc] init];
        prototypeBadge.font = [UIFont systemFontOfSize:15];
        prototypeBadge.numberOfLines = 1;
    }
    prototypeBadge.text = cell.badge.text;
    CGSize badgeSize = [prototypeBadge sizeThatFits:CGSizeMake(80, 30)];
    CGFloat margins = 20;
    if ((badgeSize.width + margins) > 30) {
        cell.badgeWidthContstraint.constant = badgeSize.width + margins;
    } else {
        cell.badgeWidthContstraint.constant = 30;
    }
    [cell.badge layoutIfNeeded];
    [cell.badge setNeedsDisplay];
    
    // editing notification settings
    cell.notifySwitch.onTintColor = podcastEntity.keyColor1;
    cell.notifySwitch.on = podcastEntity.notifyOfNewEpisodes.boolValue;
    [cell.switchBkgdView.layer setCornerRadius:17];
    
    if (_editingNotifications) {
        cell.editView.hidden = NO;
        cell.editView.alpha = 1;
    } else {
        cell.editView.hidden = YES;
        cell.editView.alpha = 0;
    }
    
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
    
    if (_editingNotifications) {
        [self toggleEditNotifySettings];
        return;
    }
    
    
    PodcastEntity *podcastEntity = [_resultsController objectAtIndexPath:indexPath];
    // entity -> dict
    NSDictionary *podcastDict = [TungCommonObjects entityToDict:podcastEntity];
    
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
