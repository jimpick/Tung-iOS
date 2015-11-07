//
//  tungPodcasts.m
//  Tung
//
//  Created by Jamie Perkins on 3/16/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "TungPodcast.h"
#import "TungCommonObjects.h"
#import "PodcastResultCell.h"
#import "CCColorCube.h"
#import "EpisodeCell.h"
#import "PodcastViewController.h"
#import "EpisodeViewController.h"

@interface TungPodcast()

// search
@property (strong, nonatomic) NSURLConnection *podcastSearchConnection;
@property (strong, nonatomic) NSMutableData *podcastSearchResultData;

@end

@implementation TungPodcast

- (id)init {
    
    self = [super init];
    if (self) {
        
        _podcastArray = [NSMutableArray array];
        
        // podcasts search
        _searchTableViewController = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"searchTableViewController"];
        _searchTableViewController.tableView.delegate = self;
        _searchTableViewController.tableView.dataSource = self;
        _searchTableViewController.tableView.scrollsToTop = YES;
        _searchTableViewController.tableView.bounces = NO;
        _searchTableViewController.tableView.separatorInset = UIEdgeInsetsMake(0, 9, 0, 9);
        _searchTableViewController.tableView.contentInset = UIEdgeInsetsMake(0, 0, 10, 0);
        _searchTableViewController.tableView.backgroundColor = [UIColor clearColor];
        _searchTableViewController.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
        _searchTableViewController.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectZero];
        //_searchTableViewController.definesPresentationContext = YES; // does nothing
        
        
        _searchController = [[UISearchController alloc] initWithSearchResultsController:_searchTableViewController];
        _searchController.delegate = self;
        _searchController.hidesNavigationBarDuringPresentation = NO;
        
        _searchController.searchBar.delegate = self;
        _searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
        _searchController.searchBar.tintColor = [TungCommonObjects tungColor];
        _searchController.searchBar.showsCancelButton = YES;
        _searchController.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _searchController.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
        _searchController.searchBar.placeholder = @"Find a podcast";
        _searchController.searchBar.frame = CGRectMake(self.searchController.searchBar.frame.origin.x, self.searchController.searchBar.frame.origin.y, self.searchController.searchBar.frame.size.width, 44.0);
        
    }
    
    return self;
}

#pragma mark - Search Bar delegate methods

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {

    [_searchTimer invalidate];
    // timeout to resign keyboard
    CLS_LOG(@"SET SELECTOR resignKeyboard");
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(resignKeyboard) userInfo:nil repeats:NO];
    // search
    [self searchForTerm:searchBar.text];
    
}
-(void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    //CLS_LOG(@"search bar text did change: %@", searchText);
    [_searchTimer invalidate];
    if (searchText.length > 1) {
    	_searchTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(keyupSearch:) userInfo:searchText repeats:NO];
    }
    else {
        [_podcastArray removeAllObjects];
        [_searchTableViewController.tableView reloadData];
    }
    
}

- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar {
    return YES;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {

    _searchController.searchBar.text = @""; // clear search
    
    [_delegate dismissPodcastSearch];
}

#pragma mark - UISearchControllerDelegate methods

- (void) didDismissSearchController:(UISearchController *)searchController {

    _searchController.searchBar.text = @""; // clear search
    [_delegate dismissPodcastSearch];
}

#pragma mark - Search general methods

-(void) keyupSearch:(NSTimer *)timer {
    //CLS_LOG(@"time-out search for timer: %@", timer);
    [self searchForTerm:timer.userInfo];
}

-(void) searchForTerm:(NSString *)searchTerm {
    
    if (searchTerm.length > 0) {
        
        // so you can search emoji
        /*
        NSString *unicodeText = [NSString stringWithUTF8String:[searchTerm UTF8String]];
        CLS_LOG(@"unicode: %@", unicodeText);
        CLS_LOG(@"unicode url encoded: %@", [self urlEncodeString:unicodeText]);
        NSData *textData = [unicodeText dataUsingEncoding:NSNonLossyASCIIStringEncoding];
        NSString *encodedText = [[NSString alloc] initWithData:textData encoding:NSUTF8StringEncoding];
        NSString *encoded = [self urlEncodeString:encodedText];
         */
        CLS_LOG(@"SENDING SEARCH for %@", searchTerm);
		_queryExecuted = NO;
        [self searchItunesPodcastDirectoryWithTerm:searchTerm];
        
    }
}

- (void) resignKeyboard {
    [_searchController.searchBar resignFirstResponder];
}

/*
- (NSString *) urlEncodeString:(NSString *)string {
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[string UTF8String];
    int sourceLen = strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}
 */

// PODCAST SEARCH
-(void) searchItunesPodcastDirectoryWithTerm:(NSString *)searchTerm {
    
    _noResults = NO;
    NSString *encodedTerm = [searchTerm stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    NSDictionary *params = @{ @"media": @"podcast",
                              @"term": encodedTerm,
                              @"limit": @"25",
                              @"explicit": @"Yes" };
    
    NSString *itunesURL = @"https://itunes.apple.com/search";
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", itunesURL, [TungCommonObjects serializeParamsForGetRequest:params]]];
    NSMutableURLRequest *podcastSearchRequest = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:6.0f];
    [podcastSearchRequest setHTTPMethod:@"GET"];
    
    // reset data and connection
    _podcastSearchResultData = nil;
    _podcastSearchResultData = [NSMutableData new];
    
    if (_podcastSearchConnection) {
    	[_podcastSearchConnection cancel];
        _podcastSearchConnection = nil;
    }
    _podcastSearchConnection = [[NSURLConnection alloc] initWithRequest:podcastSearchRequest delegate:self];
    CLS_LOG(@"send request for term: %@", searchTerm);
}

#pragma mark - NSURLConnection delegate methods


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    //CLS_LOG(@"did receive data");
    [_podcastSearchResultData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    NSError *error;
    id jsonData = [NSJSONSerialization JSONObjectWithData:_podcastSearchResultData options:NSJSONReadingAllowFragments error:&error];
    if (jsonData != nil && error == nil) {
        if ([jsonData isKindOfClass:[NSDictionary class]]) {
            NSDictionary *responseDict = jsonData;
            
            _queryExecuted = YES;
            
            if ([responseDict objectForKey:@"resultCount"] && [[responseDict objectForKey:@"resultCount"] integerValue] > 0) {
                
                _podcastArray = [[responseDict objectForKey:@"results"] mutableCopy];
                
                //CLS_LOG(@"got results: %lu", (unsigned long)_podcastArray.count);
                //CLS_LOG(@"%@", _podcastArray);
                [self preloadPodcastArtForArray:_podcastArray];
                [self preloadFeedsWithLimit:1]; // preload feed of first result
                [_searchTableViewController.tableView reloadData];
                
            }
            else {
                _noResults = YES;
                //CLS_LOG(@"NO RESULTS");
            }
        }
    }
    else if ([_podcastSearchResultData length] == 0 && error == nil) {
        CLS_LOG(@"no response for search");
        
    }
    else if (error != nil) {
        
        CLS_LOG(@"search error: %@", error);
    }
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {
    CLS_LOG(@"search connection failed: %@", error);
    
    /* this error pops up occaisionally, probably because of rapid requests.
     makes user think something is wrong when it really isn't.
    UIAlertView *connectionErrorAlert = [[UIAlertView alloc] initWithTitle:@"Connection error" message:[error localizedDescription] delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    //self.tableView.backgroundView = nil;
    [connectionErrorAlert show];
    */
}

/* unused NSURLConnection delegate methods
 - (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	CLS_LOG(@"connection received response: %@", response);
 }
 
 */

- (void) showNoConnectionAlert {
    UIAlertView *noConnectionErrorAlert = [[UIAlertView alloc] initWithTitle:@"No connection" message:@"Please try again when you're connected to the internet." delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [noConnectionErrorAlert show];
}

#pragma mark - Podcast Search table

static double screenWidth;
static double leftLabelMargin = 106;
static double rightLabelMargin = 30;
static double maxLabelWidth;
static NSDateFormatter *releaseDateInterpreter = nil;
static NSDateFormatter *releaseDateFormatter = nil;

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //CLS_LOG(@"number of rows in section: %lu", (unsigned long)_podcastArray.count);
    return _podcastArray.count;
}

static NSString *cellIdentifier = @"PodcastResultCell";

// podcast search result cell
- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    PodcastResultCell *podcastCell = (PodcastResultCell *)cell;
    
    // cell data
    NSMutableDictionary *podcastDict;
    // search
    podcastDict = [NSMutableDictionary dictionaryWithDictionary:[_podcastArray objectAtIndex:indexPath.row]];
    NSLog(@"---- configure row %ld for search: %@ ",(long)indexPath.row, [podcastDict objectForKey:@"collectionName"]);
    
    // art
    NSString *artUrlString = [podcastDict objectForKey:@"artworkUrl600"];
    NSLog(@"%@", artUrlString);
    NSData *artImageData = [TungCommonObjects retrievePodcastArtDataWithUrlString:artUrlString andCollectionId:[podcastDict objectForKey:@"collectionId"]];
    UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
    podcastCell.podcastArtImageView.image = artImage;
    
    // labels and positioning
    if (!screenWidth) screenWidth = [[UIScreen mainScreen]bounds].size.width;
    if (!maxLabelWidth) maxLabelWidth = screenWidth - (leftLabelMargin + rightLabelMargin);
    // title
    if (!podcastCell.podcastTitle) {
        podcastCell.podcastTitle = [[UILabel alloc] init];
        podcastCell.podcastTitle.preferredMaxLayoutWidth = maxLabelWidth;
        podcastCell.podcastTitle.numberOfLines = 3;
    }
    // adjust type size for long titles
    NSString *title = [podcastDict objectForKey:@"collectionName"];
    if (title.length > 60) {
        podcastCell.podcastTitle.font = [UIFont systemFontOfSize:13];
    }
    else if (title.length > 30) {
        podcastCell.podcastTitle.font = [UIFont systemFontOfSize:16];
    }
    else {
        podcastCell.podcastTitle.font = [UIFont systemFontOfSize:17];
    }
    podcastCell.podcastTitle.text = title;
    CGSize titleSize = [podcastCell.podcastTitle sizeThatFits:CGSizeMake(maxLabelWidth, 55)];
    // artist
    if (!podcastCell.podcastArtist) {
        podcastCell.podcastArtist = [[UILabel alloc] init];
        podcastCell.podcastArtist.font = [UIFont systemFontOfSize:11];
        podcastCell.podcastArtist.textColor = [UIColor grayColor];
        podcastCell.podcastArtist.preferredMaxLayoutWidth = maxLabelWidth;
        podcastCell.podcastArtist.numberOfLines = 2;
    }
    podcastCell.podcastArtist.text = [podcastDict objectForKey:@"artistName"];
    CGSize artistSize = [podcastCell.podcastArtist sizeThatFits:CGSizeMake(maxLabelWidth, 35)];
    
    // release date
    if ([podcastDict objectForKey:@"releaseDate"]) {
        if (!releaseDateInterpreter) {
            releaseDateInterpreter = [[NSDateFormatter alloc] init];
            [releaseDateInterpreter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZ"];
        }
        NSDate *releaseDate = [releaseDateInterpreter dateFromString:[podcastDict objectForKey:@"releaseDate"]];
        if (!releaseDateFormatter) {
            releaseDateFormatter = [[NSDateFormatter alloc] init];
            [releaseDateFormatter setDateStyle:NSDateFormatterShortStyle];
        }
        podcastCell.releaseDateLabel.text = [NSString stringWithFormat:@"New %@", [releaseDateFormatter stringFromDate:releaseDate]];
    }
    else {
        podcastCell.releaseDateLabel.text = @"";
    }
    
    double totalHeight = titleSize.height + artistSize.height;
    CGPoint titlePoint = CGPointMake(leftLabelMargin, (100 - totalHeight)/2);
    CGPoint artistPoint = CGPointMake(leftLabelMargin, titlePoint.y + titleSize.height);
    CGRect titleRect = {titlePoint, titleSize};
    CGRect artistRect = {artistPoint, artistSize};
    podcastCell.podcastTitle.frame = titleRect;
    podcastCell.podcastArtist.frame = artistRect;
    if (![podcastCell.podcastTitle isDescendantOfView:podcastCell]) [podcastCell addSubview:podcastCell.podcastTitle];
    if (![podcastCell.podcastArtist isDescendantOfView:podcastCell]) [podcastCell addSubview:podcastCell.podcastArtist];
    
    // find key color
    NSArray *keyColors = [TungCommonObjects determineKeyColorsFromImage:artImage];
    UIColor *keyColor1 = [keyColors objectAtIndex:0];
    UIColor *keyColor2 = [keyColors objectAtIndex:1];
    podcastCell.podcastTitle.textColor = keyColor1;
    [podcastDict setObject:keyColor1 forKey:@"keyColor1"];
    [podcastDict setObject:keyColor2 forKey:@"keyColor2"];
    // replace podcast dict at index bc we added key color
    [_podcastArray replaceObjectAtIndex:indexPath.row withObject:podcastDict];
    
    // accessory
    //podcastCell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"UITableNext.png"]];
    if (!podcastCell.accessory) {
        podcastCell.accessory = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"UITableNext.png"]];
        CGRect accessoryFrame = podcastCell.accessory.frame;
        accessoryFrame.origin.x = screenWidth - accessoryFrame.size.width - 10;
        accessoryFrame.origin.y = (100 - accessoryFrame.size.height)/2;
        podcastCell.accessory.frame = accessoryFrame;
        [podcastCell addSubview:podcastCell.accessory];
    }
    
    // kill insets for iOS 8
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 8) {
        podcastCell.preservesSuperviewLayoutMargins = NO;
        [podcastCell setLayoutMargins:UIEdgeInsetsZero];
    }
    // iOS 7
    //    if ([podcastCell respondsToSelector:@selector(setSeparatorInset:)])
    //        [podcastCell setSeparatorInset:UIEdgeInsetsZero];
    
    return podcastCell;

}

#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //CLS_LOG(@"selected cell at row %ld", (long)[indexPath row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // push "show" view
    NSDictionary *podcastDict = [NSDictionary dictionaryWithDictionary:[_podcastArray objectAtIndex:indexPath.row]];
    CLS_LOG(@"selected %@", [podcastDict objectForKey:@"collectionName"]);
    
    [self resignKeyboard];
    PodcastViewController *podcastView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"podcastView"];
    podcastView.podcastDict = [podcastDict mutableCopy];
    [_navController pushViewController:podcastView animated:YES];
    
}

//- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return 100;
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (_podcastArray.count > 0 && section == 1) {
        UILabel *noMoreLabel = [[UILabel alloc] init];
        noMoreLabel.text = @"That's everything.";
        noMoreLabel.textColor = [UIColor grayColor];
        noMoreLabel.textAlignment = NSTextAlignmentCenter;
        return noMoreLabel;
    }
    else if (_noResults && section == 1) {
        UILabel *noResultsLabel = [[UILabel alloc] init];
        noResultsLabel.text = @"No results.";
        noResultsLabel.textColor = [UIColor grayColor];
        noResultsLabel.textAlignment = NSTextAlignmentCenter;
        return noResultsLabel;
    }
    else {
        return nil;
    }
}

-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 1) {
        return 92.0;
    }
    else {
        return 0;
    }
}


#pragma mark - Preloading

-(void) preloadPodcastArtForArray:(NSArray*)itemArray {
        
    NSArray *itemArrayCopy = [itemArray copy];
    
    NSOperationQueue *preloadQueue = [[NSOperationQueue alloc] init];
    preloadQueue.maxConcurrentOperationCount = 3;
    // download and save podcast art to temp directory if it doesn't exist
    
    for (int i = 0; i < itemArrayCopy.count; i++) {
        
        [preloadQueue addOperationWithBlock:^{
            NSString *artURLString = [[itemArrayCopy objectAtIndex:i] objectForKey:@"artworkUrl600"];
            NSNumber *collectionId = [[itemArrayCopy objectAtIndex:i] objectForKey:@"collectionId"];
            [TungCommonObjects retrievePodcastArtDataWithUrlString:artURLString andCollectionId:collectionId];
        }];
    }
}

#pragma mark - preloading, caching and converting feeds


/* ////////////////////////
 FEED DICTS
 /////////////////////////*/

static NSString *feedDictsDirName = @"feedDicts";

+ (void) cacheFeed:(NSDictionary *)feed forEntity:(PodcastEntity *)entity {
    
    CLS_LOG(@"cache feed for entity");
    NSString *feedDir = [NSTemporaryDirectory() stringByAppendingPathComponent:feedDictsDirName];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:feedDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        
        // cache feed
        NSString *feedFileName = [NSString stringWithFormat:@"%@.txt", entity.collectionId];
        NSString *feedFilePath = [feedDir stringByAppendingPathComponent:feedFileName];
        // delete file if exists.
        if ([[NSFileManager defaultManager] fileExistsAtPath:feedFilePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:feedFilePath error:nil];
        }
        if ([feed writeToFile:feedFilePath atomically:YES]) {
            
            entity.feedLastCached = [NSDate date];
            
            [TungCommonObjects saveContextWithReason:@"update feedLastCached"];
        }
    }
    
}

/* 
 Will retrieve a feed no older than a day, optionally force refetch. Caches feed if feed was not freshly cached.
 */
+ (NSDictionary*) retrieveAndCacheFeedForPodcastEntity:(PodcastEntity *)entity forceNewest:(BOOL)forceNewest {
    
    NSDictionary *feedDict;
    
    if (forceNewest) {
        CLS_LOG(@"retrieve cached feed for entity :: force newest");
        feedDict = [self requestAndConvertPodcastFeedDataWithCollectionId:entity.collectionId
                                                               andFeedUrl:entity.feedUrl];
    }
    else if (entity.feedLastCached) {
        long timeSinceLastCached = fabs([entity.feedLastCached timeIntervalSinceNow]);
        if (timeSinceLastCached > 60 * 60 * 24) {
            CLS_LOG(@"retrieve cached feed for entity :: cached feed dict was stale - refetch");
            feedDict = [self requestAndConvertPodcastFeedDataWithCollectionId:entity.collectionId
                                                               andFeedUrl:entity.feedUrl];
        } else {
            NSString *feedDir = [NSTemporaryDirectory() stringByAppendingPathComponent:feedDictsDirName];
            NSError *error;
            [[NSFileManager defaultManager] createDirectoryAtPath:feedDir withIntermediateDirectories:YES attributes:nil error:&error];
            NSString *feedFileName = [NSString stringWithFormat:@"%@.txt", entity.collectionId];
            NSString *feedFilePath = [feedDir stringByAppendingPathComponent:feedFileName];
            NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:feedFilePath];
            if (dict) {
                // return cached feed
                CLS_LOG(@"retrieve cached feed for entity :: found fresh cached feed dictionary");
                return dict;
            } else {
                CLS_LOG(@"retrieve cached feed for entity :: tmp dir must have been cleared, fetching feed");
                feedDict = [self requestAndConvertPodcastFeedDataWithCollectionId:entity.collectionId
                                                                   andFeedUrl:entity.feedUrl];
            }
        }
    } else {
        CLS_LOG(@"retrieve cached feed for entity :: ");
        feedDict = [self retrieveAndConvertPodcastFeedDataWithCollectionId:entity.collectionId
                                                           andFeedUrl:entity.feedUrl];
    }
    [self cacheFeed:feedDict forEntity:entity];
    return feedDict;
    
}


/* ////////////////////////
 RAW FEEDS
 /////////////////////////*/

static NSString *rawFeedsDirName = @"rawFeeds";

// used for preloading feeds from search results
-(void) preloadFeedsWithLimit:(NSUInteger)limit {
    
    CLS_LOG(@"preload feeds");
    NSString *rawFeedsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:rawFeedsDirName];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:rawFeedsDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        
        NSArray *podcastArrayCopy = [_podcastArray copy];
        
        if (_feedPreloadQueue) {
            [_feedPreloadQueue cancelAllOperations];
            _feedPreloadQueue = nil;
        }
        
        _feedPreloadQueue = [[NSOperationQueue alloc] init];
        _feedPreloadQueue.maxConcurrentOperationCount = 1; // only 1 so streaming is smooth
        
        NSUInteger maxNumToPreload;
        if (limit == 0) { // 0 limit means no limit
            maxNumToPreload = podcastArrayCopy.count;
        } else {
        	maxNumToPreload = (podcastArrayCopy.count < limit) ? podcastArrayCopy.count : limit;
        }
        
        for (int i = 0; i < maxNumToPreload; i++) {
            
            [_feedPreloadQueue addOperationWithBlock:^{
                CLS_LOG(@"** preload feed at index: %d", i);
                NSString *feedURLString = [[podcastArrayCopy objectAtIndex:i] objectForKey:@"feedUrl"];
                NSNumber *collectionId = [[podcastArrayCopy objectAtIndex:i] objectForKey:@"collectionId"];
                NSString *feedDataFilename = [NSString stringWithFormat:@"%@", collectionId];
                NSString *feedDataFilepath = [rawFeedsDir stringByAppendingPathComponent:feedDataFilename];
                
                NSData *feedData = [NSData dataWithContentsOfURL:[NSURL URLWithString:feedURLString]];
                //CLS_LOG(@"write feed data at index %d", i);
                [feedData writeToFile:feedDataFilepath atomically:YES];
                
            }];
        }
    }
}

/*
 if there is cached data, the feed is retrieved from it. If not it is requested and converted.
 */
+ (NSDictionary *) retrieveAndConvertPodcastFeedDataWithCollectionId:(NSNumber *)collectionId andFeedUrl:(NSString *)feedUrl {
    
    NSString *rawFeedsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:rawFeedsDirName];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:rawFeedsDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        
        NSString *feedDataFilename = [NSString stringWithFormat:@"%@", collectionId];
        NSString *feedDataFilepath = [rawFeedsDir stringByAppendingPathComponent:feedDataFilename];
        NSData *feedData;
        // get cached copy, or download if necessary
        if ([[NSFileManager defaultManager] fileExistsAtPath:feedDataFilepath]) {
            CLS_LOG(@"raw feed data was cached");
            feedData = [NSData dataWithContentsOfFile:feedDataFilepath];
        } else {
            CLS_LOG(@"had to download feed");
            feedData = [NSData dataWithContentsOfURL:[NSURL URLWithString: feedUrl]];
            [feedData writeToFile:feedDataFilepath atomically:YES];
        }
        
        JPXMLtoDictionary *xmlToDict = [[JPXMLtoDictionary alloc] init];
        return [xmlToDict xmlDataToDictionary:feedData];
    }
    return nil;
}
/*
 forces re-fetch of the feed, returns converted data.
 */
+ (NSDictionary *) requestAndConvertPodcastFeedDataWithCollectionId:(NSNumber *)collectionId andFeedUrl:(NSString *)feedUrl {
    
    NSString *rawFeedsDir = [NSTemporaryDirectory() stringByAppendingPathComponent:rawFeedsDirName];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:rawFeedsDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        
        NSString *feedDataFilename = [NSString stringWithFormat:@"%@", collectionId];
        NSString *feedDataFilepath = [rawFeedsDir stringByAppendingPathComponent:feedDataFilename];
        NSData *feedData = [NSData dataWithContentsOfURL:[NSURL URLWithString: feedUrl]];
        [feedData writeToFile:feedDataFilepath atomically:YES];
        
        JPXMLtoDictionary *xmlToDict = [[JPXMLtoDictionary alloc] init];
        return [xmlToDict xmlDataToDictionary:feedData];
    }
    return nil;
}

+ (NSArray *) extractFeedArrayFromFeedDict:(NSDictionary *)feedDict {
    id item = [[feedDict objectForKey:@"channel"] objectForKey:@"item"];
    if ([item isKindOfClass:[NSArray class]]) {
        NSArray *array = item;
        return array;
    } else {
        return @[item];
    }
}

@end
