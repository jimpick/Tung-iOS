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

@interface SubscriptionsCollectionView ()

@property NSFetchRequest *subscribedQuery;
@property TungPodcast *tungPodcast;
@property TungCommonObjects *tung;
@property NSMutableArray *sectionChanges;
@property NSMutableArray *itemChanges;
@property UISearchController *searchController;
@property BOOL editingNotifications;
@property UIBarButtonItem *editAlertsBarButtonItem;
@property UILabel *noSubsLabel;
@property UIImageView *findPodcastsHere;
@property NSTimer *promptTimer;
@property NSIndexPath *selectedIndexPath;
@property NSArray *podcasts;

@end

@implementation SubscriptionsCollectionView

static NSString * const reuseIdentifier = @"artCell";


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Subscriptions";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(initiateSearch)];
    _editAlertsBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Alerts" style:UIBarButtonItemStylePlain target:self action:@selector(toggleEditNotifySettings)];
    self.navigationItem.leftBarButtonItem = _editAlertsBarButtonItem;
    
    _tung = [TungCommonObjects establishTungObjects];
    _tungPodcast = [TungPodcast new];
    
    // for search controller
    self.definesPresentationContext = YES;
    _tungPodcast.navController = [self navigationController];
    _tungPodcast.delegate = self;
    
    // set up collection view size based on screen size    
    CGFloat cellWidthAndHeight = ([TungCommonObjects screenSize].width - 2) / 3;
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
    // background view for no subscriptions
    _noSubsLabel = [[UILabel alloc] init];
    _noSubsLabel.text = @"You haven't subscribed to\nany podcasts yet";
    _noSubsLabel.numberOfLines = 2;
    _noSubsLabel.textColor = [UIColor grayColor];
    _noSubsLabel.textAlignment = NSTextAlignmentCenter;
    
    UIActivityIndicatorView *bkgdSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    bkgdSpinner.alpha = 1;
    [bkgdSpinner startAnimating];
    self.collectionView.backgroundView = bkgdSpinner;
    //self.collectionView.backgroundView = _noSubsLabel;
    /*
    UIImage *findPodcastsImage = [UIImage imageNamed:@"find-podcasts-here.png"];
    _findPodcastsHere = [[UIImageView alloc] initWithImage:findPodcastsImage];
    CGRect imageRect = CGRectMake(self.view.bounds.size.width - 220, 6, 200, 173);
    _findPodcastsHere.frame = imageRect;
    self.collectionView.backgroundView = _findPodcastsHere;
    self.collectionView.backgroundView.contentMode = UIViewContentModeTopRight;
    */
    
    _podcasts = [NSArray array];
    
    // get subscribed podcasts
    _subscribedQuery = [[NSFetchRequest alloc] initWithEntityName:@"PodcastEntity"];
    //NSPredicate *predicate = [NSPredicate predicateWithFormat: @"isSubscribed == %@", [NSNumber numberWithBool:YES]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isSubscribed == YES"];
    _subscribedQuery.predicate = predicate;
    NSSortDescriptor *dateSort = [[NSSortDescriptor alloc] initWithKey:@"timeSubscribed" ascending:YES];
    NSSortDescriptor *orderSort = [[NSSortDescriptor alloc] initWithKey:@"sortOrder" ascending:YES];
    _subscribedQuery.sortDescriptors = @[orderSort, dateSort];
    
    // notifs
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareView) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(performFetchAndReload) name:@"refreshSubscribeStatus" object:nil];
    
    // re-ordering: long press recognizer
    NSInteger majorVersion = [[NSProcessInfo processInfo] operatingSystemVersion].majorVersion;
    if (majorVersion >= 9) {
        UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPressRecognizer.minimumPressDuration = 0.6; //seconds
        longPressRecognizer.delegate = self;
        [self.collectionView addGestureRecognizer:longPressRecognizer];
    }
}

- (void) prepareView {
    
    [self.collectionView reloadData];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    _tung.viewController = self;
    
    SettingsEntity *settings = [TungCommonObjects settings];
    
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
    
    // perform fetch
    [self performFetchAndReload];
    
}

- (void) performFetchAndReload {
    
    AppDelegate *appDelegate =  (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSError *error = nil;
    _podcasts = [appDelegate.managedObjectContext executeFetchRequest:_subscribedQuery error:&error];
    
    [self.collectionView reloadData];
    
    if (_podcasts.count == 0) {
        //_findPodcastsHere.hidden = NO;
        self.collectionView.backgroundView = _noSubsLabel;
        self.navigationItem.leftBarButtonItem = nil;
    }
    else {
        //_findPodcastsHere.hidden = YES;
        self.collectionView.backgroundView = nil;
        self.navigationItem.leftBarButtonItem = _editAlertsBarButtonItem;
    }
}


- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_promptTimer invalidate];
    if (_editingNotifications) [self toggleEditNotifySettings];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    /*
    if (_tungPodcast.searchController.active) {
        [_tungPodcast.searchController setActive:NO];
        [self dismissPodcastSearch];
    }*/
}
                                             
#pragma mark - Editing notification stuff
                                             
- (void) toggleEditNotifySettings {
 
    _editingNotifications = !_editingNotifications;
    
    if (_editingNotifications) {
    	_editAlertsBarButtonItem.title = @"Done";
        //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotifyPrefChangedNotification:) name:@"notifyPrefChanged" object:nil];
    } else {
        //[[NSNotificationCenter defaultCenter] removeObserver:self];
    	_editAlertsBarButtonItem.title = @"Alerts";
    }
    
    // reloads with fade instead of instantly
    [self.collectionView performBatchUpdates:^{
    	[self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
    } completion:nil];
 
}

- (void) handleNotifyPrefChangedNotification:(NSNotification *)notification {
    
    if (notification.userInfo[@"message"]) {
        [TungCommonObjects showBannerAlertForText:notification.userInfo[@"message"]];
    }
}

#pragma mark - tungObjects/tungPodcasts delegate methods


- (void) initiateSearch {
    
    if (_editingNotifications) {
        [self toggleEditNotifySettings];
    }    
    
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
    
    [_tungPodcast.searchController setActive:YES];
    
    CATransition *animation = [CATransition animation];
    animation.duration = .4;
    // kCATransitionFade, kCATransitionMoveIn, kCATransitionPush, kCATransitionReveal
    animation.type = kCATransitionFade;
    [self.navigationController.navigationBar.layer addAnimation: animation forKey: @"revealSearch"];
    
    self.navigationItem.titleView = _tungPodcast.searchController.searchBar;
    [self.navigationItem setRightBarButtonItem:nil animated:YES];
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    	
    [_tungPodcast.searchController.searchBar becomeFirstResponder];
    
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
    [self.navigationItem setLeftBarButtonItem:_editAlertsBarButtonItem animated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {

    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    
    return _podcasts.count;
}

UILabel static *prototypeBadge;

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    SubscriptionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    PodcastEntity *podcastEntity = [_podcasts objectAtIndex:indexPath.row];
    //JPLog(@"collection view cell for item at index path %ld. sort order: %ld - %@", (long)indexPath.row, podcastEntity.sortOrder.integerValue, podcastEntity.collectionName);
    
    cell.collectionId = podcastEntity.collectionId;
    NSData *artImageData = [TungCommonObjects retrievePodcastArtDataForEntity:podcastEntity];
    UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
    
    // podcast art
    cell.artImageView.image = artImage;
    cell.contentView.backgroundColor = [UIColor whiteColor];
    
    // new episodes badge
    cell.badge.type = kMiscViewTypeSubscribeBadge;
    cell.badge.text = @"";
    if (podcastEntity.notifyOfNewEpisodes.boolValue && podcastEntity.numNewEpisodes.integerValue > 0) {
        cell.badge.hidden = NO;
        if (podcastEntity.numNewEpisodes.integerValue > 20) {
            cell.badge.text = @"20+";
        } else {
            cell.badge.text = [NSString stringWithFormat:@"%@", podcastEntity.numNewEpisodes];
        }
    } else {
        cell.badge.hidden = YES;
    }
    
    // subs for screenshot
    /*
    int i = arc4random_uniform(5);
    if (i > 0) {
        cell.badge.text = [NSString stringWithFormat:@"%d", i];
        cell.badge.hidden = NO;
    }
    else {
        cell.badge.hidden = YES;
    }
    */
    
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
    cell.notifySwitch.onTintColor = (UIColor *)podcastEntity.keyColor1;
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
    
    PodcastEntity *podcastEntity = [_podcasts objectAtIndex:indexPath.row];
    
    // entity -> dict
    NSDictionary *podcastDict = [TungCommonObjects entityToDict:podcastEntity];
    //NSLog(@"selected %@", podcastDict);
    
    [self resignFirstResponder];
    PodcastViewController *podcastView = [self.storyboard instantiateViewControllerWithIdentifier:@"podcastView"];
    podcastView.podcastDict = [podcastDict mutableCopy];
    [self.navigationController pushViewController:podcastView animated:YES];
}

- (void) handleLongPress:(UILongPressGestureRecognizer *)gesture {
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            _selectedIndexPath = [self.collectionView indexPathForItemAtPoint:[gesture locationInView:self.view]];
            break;
        case UIGestureRecognizerStateChanged:
            [self.collectionView updateInteractiveMovementTargetPosition:[gesture locationInView:self.view]];
            break;
        case UIGestureRecognizerStateEnded:
            [self.collectionView endInteractiveMovement];
            break;
        default:
            [self.collectionView cancelInteractiveMovement];
            break;
    }
}

- (void) collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(nonnull NSIndexPath *)sourceIndexPath toIndexPath:(nonnull NSIndexPath *)destinationIndexPath {
    
    // set new order
    
    for (int i = 0; i < _podcasts.count; i++) {
        PodcastEntity *podEntity = [_podcasts objectAtIndex:i];
        //podEntity.sortOrder = [NSNumber numberWithInt:999]; // reset
        
        if (i < sourceIndexPath.row) {
            if (i >= destinationIndexPath.row) {
        		podEntity.sortOrder = [NSNumber numberWithInt:i + 1];
        	}
            else {
                podEntity.sortOrder = [NSNumber numberWithInt:i];
            }
        }
        else if (i > sourceIndexPath.row) {
            if (i <= destinationIndexPath.row) {
                podEntity.sortOrder = [NSNumber numberWithInt:i - 1];
            }
            else {
                podEntity.sortOrder = [NSNumber numberWithInt:i];
            }
        }
        else {
            podEntity.sortOrder = [NSNumber numberWithInteger:destinationIndexPath.row];
        }
    }
    [TungCommonObjects saveContextWithReason:@"updated sort order of subscribed podcasts"];
    
    [self performFetchAndReload];
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
