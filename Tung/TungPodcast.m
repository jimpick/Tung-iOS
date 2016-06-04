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
#import "DescriptionWebViewController.h"
#import "JPLogRecorder.h"

@interface TungPodcast()

// search
@property (strong, nonatomic) NSURLConnection *podcastSearchConnection;
@property (strong, nonatomic) NSMutableData *podcastSearchResultData;
@property CGFloat screenWidth;

@end

@implementation TungPodcast

- (id)init {
    
    self = [super init];
    if (self) {
        
        _podcastArray = [NSMutableArray array];
        _screenWidth = [TungCommonObjects screenSize].width;
        
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
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(resignKeyboard) userInfo:nil repeats:NO];
    // search
    [self searchForTerm:searchBar.text];
    
}
-(void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    //JPLog(@"search bar text did change: %@", searchText);
    [_searchTimer invalidate];
    if (searchText.length > 1) {
    	_searchTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(keyupSearch:) userInfo:searchText repeats:NO];
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
    //JPLog(@"time-out search for timer: %@", timer);
    [self searchForTerm:timer.userInfo];
}

-(void) searchForTerm:(NSString *)searchTerm {
    
    if (searchTerm.length > 0) {
        
        // so you can search emoji - not needed
        /*
        NSString *unicodeText = [NSString stringWithUTF8String:[searchTerm UTF8String]];
        JPLog(@"unicode: %@", unicodeText);
        JPLog(@"unicode url encoded: %@", [self urlEncodeString:unicodeText]);
        NSData *textData = [unicodeText dataUsingEncoding:NSNonLossyASCIIStringEncoding];
        NSString *encodedText = [[NSString alloc] initWithData:textData encoding:NSUTF8StringEncoding];
        NSString *encoded = [self urlEncodeString:encodedText];
         */
        //JPLog(@"SENDING SEARCH for %@", searchTerm);
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
    //JPLog(@"send request for term: %@", searchTerm);
}

#pragma mark - NSURLConnection delegate methods


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    //JPLog(@"did receive data");

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
                
                //JPLog(@"got results: %lu", (unsigned long)_podcastArray.count);
                //JPLog(@"%@", _podcastArray);
                [self preloadPodcastArtForArray:_podcastArray];
                [self preloadFeedsWithLimit:1]; // preload feed of first result
                
            }
            else {
                _noResults = YES;
                _podcastArray = [NSMutableArray array];
            }
            [_searchTableViewController.tableView reloadData];
        }
    }
    else if ([_podcastSearchResultData length] == 0 && error == nil) {
        JPLog(@"no response for search");
        
    }
    else if (error != nil) {
        
        JPLog(@"search error: %@", error);
    }
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {
    JPLog(@"search connection failed: %@", error);
    
    /* this error pops up occaisionally, probably because of rapid requests.
     makes user think something is wrong when it really isn't.
     
     [_tung showConnectionErrorAlertForError:error];
    */
}

/* unused NSURLConnection delegate methods
 - (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	JPLog(@"connection received response: %@", response);
 }
 
 */

#pragma mark - Podcast Search table

static double leftLabelMargin = 106;
static double rightLabelMargin = 30;
static double maxLabelWidth;
static NSDateFormatter *releaseDateInterpreter = nil;
static NSDateFormatter *releaseDateFormatter = nil;

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //JPLog(@"number of rows in section: %lu", (unsigned long)_podcastArray.count);
    if (section == 0) {
    	return _podcastArray.count;
    } else {
        return 0;
    }
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
    //NSLog(@"---- configure row %ld for search: %@ ",(long)indexPath.row, [podcastDict objectForKey:@"collectionName"]);
    
    // art
    NSString *artUrlString = [podcastDict objectForKey:@"artworkUrl600"];
    NSData *artImageData = [TungCommonObjects retrievePodcastArtDataWithUrlString:artUrlString andCollectionId:[podcastDict objectForKey:@"collectionId"]];
    UIImage *artImage = [[UIImage alloc] initWithData:artImageData];
    podcastCell.podcastArtImageView.image = artImage;
    
    // labels and positioning
    if (!maxLabelWidth) maxLabelWidth = _screenWidth - (leftLabelMargin + rightLabelMargin);
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
    /* for testing key colors
    int x = 90;
    for (int i = 0; i < keyColors.count; i++) {
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(x, 60, 40, 35)];
        view.backgroundColor = keyColors[i];
        [podcastCell addSubview:view];
        x +=40;
    };*/
    UIColor *keyColor1 = [keyColors objectAtIndex:0];
    UIColor *keyColor2 = [keyColors objectAtIndex:1];
    //NSLog(@"key color 1 hex: %@", [TungCommonObjects UIColorToHexString:keyColor1]);
    //NSLog(@"key color 2 hex: %@", [TungCommonObjects UIColorToHexString:keyColor2]);
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
        accessoryFrame.origin.x = _screenWidth - accessoryFrame.size.width - 10;
        accessoryFrame.origin.y = (100 - accessoryFrame.size.height)/2;
        podcastCell.accessory.frame = accessoryFrame;
        [podcastCell addSubview:podcastCell.accessory];
    }
    
    // kill insets for iOS 8+
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 8) {
        podcastCell.preservesSuperviewLayoutMargins = NO;
        [podcastCell setLayoutMargins:UIEdgeInsetsZero];
    }
    
    return podcastCell;

}

#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //JPLog(@"selected cell at row %ld", (long)[indexPath row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // push "show" view
    NSDictionary *podcastDict = [NSDictionary dictionaryWithDictionary:[_podcastArray objectAtIndex:indexPath.row]];
    JPLog(@"selected %@", podcastDict);
    
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
    if (_noResults && section == 1) {
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
    if (_noResults && section == 1) {
        return 92.0;
    }
    else {
        return 0;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
    
    view.backgroundColor = [TungCommonObjects bkgdGrayColor];
    
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
            //NSLog(@"preload art for %@: %@", [[itemArrayCopy objectAtIndex:i] objectForKey:@"collectionName"], artURLString);
        }];
    }
}

#pragma mark - misc

// pushes a new view with webview description of podcast
- (void) pushPodcastDescriptionForEntity:(PodcastEntity *)podcastEntity {
    // podcast description style: DIFFERENT than above
    NSString *keyColor1HexString = [TungCommonObjects UIColorToHexString:podcastEntity.keyColor1];
    NSString *keyColor2HexString = [TungCommonObjects UIColorToHexString:podcastEntity.keyColor2];
    NSString *style = [NSString stringWithFormat:@"<style type=\"text/css\">body { margin:0; color:#666; font: .9em/1.4em -apple-system, Helvetica; } a { color:%@; } img { max-width:100%%; height:auto; } .podcastArt { width:100%%; height:auto; display:block } .header { color:%@; font-weight:300; } div { padding:10px 13px 30px 13px; }</style>\n", keyColor1HexString, keyColor2HexString];
    // description script:
    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"description" ofType:@"js"];
    NSURL *scriptUrl = [NSURL fileURLWithPath:scriptPath];
    NSString *script = [NSString stringWithFormat:@"<script type=\"text/javascript\" src=\"%@\"></script>\n", scriptUrl.path];
    // album art
    NSString *podcastArtPath = [TungCommonObjects getPodcastArtPathWithUrlString:podcastEntity.artworkUrl andCollectionId:podcastEntity.collectionId];
    NSURL *podcastArtUrl = [NSURL fileURLWithPath:podcastArtPath];
    NSString *podcastArtImg = [NSString stringWithFormat:@"<img class=\"podcastArt\" src=\"%@\">", podcastArtUrl];
    // description
    NSString *webViewString = [NSString stringWithFormat:@"%@%@%@<div><h2 class=\"header\">%@</h2>%@</div>", style, script, podcastArtImg, podcastEntity.collectionName, podcastEntity.desc];
    //NSLog(@"webViewString: %@", webViewString);
    DescriptionWebViewController *descView = [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"descWebView"];
    descView.stringToLoad = webViewString;
    [_navController pushViewController:descView animated:YES];
}

#pragma mark - preloading, caching and converting feeds


/* ////////////////////////
 FEED DICTS
 /////////////////////////*/

static NSString *feedDictsDirName = @"feedDicts";

+ (NSString *) getCachedFeedsDirectoryPath {
        
    NSString *feedDir = [NSTemporaryDirectory() stringByAppendingPathComponent:feedDictsDirName];
    NSError *error;
    [[NSFileManager defaultManager] createDirectoryAtPath:feedDir withIntermediateDirectories:YES attributes:nil error:&error];
    return feedDir;
    
}

+ (NSString *) getSavedFeedsDirectoryPath {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *folders = [fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
    NSURL *libraryDir = [folders objectAtIndex:0];
    NSString *savedFeedsDir = [libraryDir.path stringByAppendingPathComponent:feedDictsDirName];
    NSError *error;
    [fileManager createDirectoryAtPath:savedFeedsDir withIntermediateDirectories:YES attributes:nil error:&error];
    return savedFeedsDir;
}

+ (void) cacheFeed:(NSDictionary *)feed forEntity:(PodcastEntity *)entity {
    
    NSString *feedDir = [NSTemporaryDirectory() stringByAppendingPathComponent:feedDictsDirName];
    NSError *error;
    if ([[NSFileManager defaultManager] createDirectoryAtPath:feedDir withIntermediateDirectories:YES attributes:nil error:&error]) {
        
        // cache feed
        NSString *feedFileName = [NSString stringWithFormat:@"%@.txt", entity.collectionId];
        NSString *feedFilePath = [feedDir stringByAppendingPathComponent:feedFileName];

        if ([feed writeToFile:feedFilePath atomically:YES]) {
            
            entity.feedLastCached = [NSDate date];
            
            [TungCommonObjects saveContextWithReason:@"update feedLastCached"];
        }
    }
}

+ (BOOL) saveFeedForEntity:(PodcastEntity *)entity {
    
    // copy to saved from temp
    NSString *feedFileName = [NSString stringWithFormat:@"%@.txt", entity.collectionId];
    NSString *cachedFeedPath = [[self getCachedFeedsDirectoryPath] stringByAppendingPathComponent:feedFileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:cachedFeedPath]) {
        
        NSString *savedFeedPath = [[self getSavedFeedsDirectoryPath] stringByAppendingPathComponent:feedFileName];
        NSError *error;
        if ([fileManager fileExistsAtPath:savedFeedPath]) [fileManager removeItemAtPath:savedFeedPath error:&error];
        error = nil;
        if ([fileManager moveItemAtPath:cachedFeedPath toPath:savedFeedPath error:&error]) {
            return YES;
        } else {
            JPLog(@"Error saving feed dict: %@", error.localizedDescription);
            return NO;
        }

    } else {
        JPLog(@"could not save feed dict, does not exist in temp");
        return NO;
    }
}

+ (void) unsaveFeedForEntity:(PodcastEntity *)entity {
    
    NSString *feedFileName = [NSString stringWithFormat:@"%@.txt", entity.collectionId];
    NSString *savedFeedPath = [[self getSavedFeedsDirectoryPath] stringByAppendingPathComponent:feedFileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:savedFeedPath]) {
        NSString *cachedFeedPath = [[self getCachedFeedsDirectoryPath] stringByAppendingPathComponent:feedFileName];
        NSError *error;
        // move to cached but prefer cached if it exists
        if ([fileManager fileExistsAtPath:cachedFeedPath]) {
            [fileManager removeItemAtPath:savedFeedPath error:&error];
        } else {
        	[fileManager moveItemAtPath:savedFeedPath toPath:cachedFeedPath error:&error];
        }
    }
}

// Will retrieve a cached feed no older than a day, if reachable, else refetches. Caches feed.
+ (NSDictionary*) retrieveAndCacheFeedForPodcastEntity:(PodcastEntity *)entity forceNewest:(BOOL)forceNewest reachable:(BOOL)reachable {
    NSDictionary *feedDict;
    //NSLog(@"retrieve feed dict for url: %@", entity.feedUrl);
    if (!entity.feedUrl) {
        JPLog(@"Error: Cannot retrieve feed - no feed url");
        return nil;
    }
    
    if (forceNewest && reachable) {
        //JPLog(@"- - - retrieve cached feed for entity :: force newest");
        feedDict = [self requestAndConvertPodcastFeedDataWithFeedUrl:entity.feedUrl];
    }
    else if (entity.feedLastCached) {
        long timeSinceLastCached = fabs([entity.feedLastCached timeIntervalSinceNow]);
        if (timeSinceLastCached > 60 * 60 * 24 && reachable) {
            // cached feed dict was stale - refetch
            //JPLog(@"- - - cached feed dict was stale - refetch");
            feedDict = [self requestAndConvertPodcastFeedDataWithFeedUrl:entity.feedUrl];
        }
        else {
            // pull feed dict from cache
            NSString *feedDir = [NSTemporaryDirectory() stringByAppendingPathComponent:feedDictsDirName];
            NSError *error;
            NSFileManager *fileManager = [NSFileManager defaultManager];
            [fileManager createDirectoryAtPath:feedDir withIntermediateDirectories:YES attributes:nil error:&error];
            NSString *feedFileName = [NSString stringWithFormat:@"%@.txt", entity.collectionId];
            NSString *feedFilePath = [feedDir stringByAppendingPathComponent:feedFileName];
            
            if ([fileManager fileExistsAtPath:feedFilePath]) {
            	NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:feedFilePath];
                //JPLog(@"- - - retrieved cached feed dict");
                return dict;
            }
            else {
                // look for saved feed dict
                NSString *savedFeedPath = [[self getSavedFeedsDirectoryPath] stringByAppendingPathComponent:feedFileName];
                if ([fileManager fileExistsAtPath:savedFeedPath]) {
                    
                    NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:savedFeedPath];
                    if (dict) {
                        //JPLog(@"- - - retrieved SAVED feed dict");
                        return dict;
                    } else {
                        // no file in saved or temp. fetch feed
                        //JPLog(@"- - - saved dict missing, fetch feed");
                        feedDict = [self requestAndConvertPodcastFeedDataWithFeedUrl:entity.feedUrl];
                    }
                }
                else {
                    // no file in saved or temp. fetch feed
                    //JPLog(@"- - - feedLastCached present but no feed. refetch");
                    feedDict = [self requestAndConvertPodcastFeedDataWithFeedUrl:entity.feedUrl];
                }
            }
        }
    }
    else if (reachable) {
        // need to request new
        //JPLog(@"- - - fetch feed");
        feedDict = [self requestAndConvertPodcastFeedDataWithFeedUrl:entity.feedUrl];
    }
    
    if (feedDict && feedDict[@"channel"]) {
        
        // update entity with properties from the feed
        
        // check for new art
        NSString *artworkUrlString;
        if (feedDict[@"channel"][@"itunes:image"] && feedDict[@"channel"][@"itunes:image"][@"el:attributes"]) {
            id artworkUrl = feedDict[@"channel"][@"itunes:image"][@"el:attributes"][@"href"];
            if ([artworkUrl isKindOfClass:[NSString class]]) artworkUrlString = artworkUrl;
        }
        if (!artworkUrlString && feedDict[@"channel"][@"image"] && feedDict[@"channel"][@"image"][@"url"]) {
            id artworkUrl = feedDict[@"channel"][@"image"][@"url"];
            if ([artworkUrl isKindOfClass:[NSString class]]) artworkUrlString = artworkUrl;
        }
        if (!artworkUrlString && feedDict[@"channel"][@"media:thumbnail"] && feedDict[@"channel"][@"media:thumbnail"][@"el:attributes"]) {
            id artworkUrl = feedDict[@"channel"][@"media:thumbnail"][@"el:attributes"][@"url"];
            if ([artworkUrl isKindOfClass:[NSString class]]) artworkUrlString = artworkUrl;
        }
        // DEV: test new artwork
        
        // startup
        //artworkUrlString = @"http://is1.mzstatic.com/image/thumb/Music18/v4/df/29/18/df291805-e376-a9b3-64e1-7b120f517a8e/source/600x600bb.jpg";
        // song exploder
        //artworkUrlString = @"http://is4.mzstatic.com/image/thumb/Music7/v4/d6/d5/c9/d6d5c9d9-c0ed-c486-11f8-a2abc917630b/source/600x600bb.jpg";
        
        if (artworkUrlString) {
            // if art has changed
            if (entity.artworkUrl && ![entity.artworkUrl isEqualToString:artworkUrlString]) {
                // replaces cached art, saves entity and checks if podcast art needs to be updated on server
                //NSLog(@"ART HAS CHANGED");
                [TungCommonObjects replaceCachedPodcastArtForEntity:entity withNewArt:artworkUrlString];
            }
            else if (!entity.artworkUrl) {
                entity.artworkUrl = artworkUrlString;
            }
        } else {
            JPLog(@"Feed error - no artwork url");
        }
        // link and email
        if (feedDict[@"channel"][@"link"]) {
            id website = feedDict[@"channel"][@"link"];
            if ([website isKindOfClass:[NSString class]]) {
                entity.website = website;
            }
        }
        if (feedDict[@"channel"][@"itunes:owner"] && feedDict[@"channel"][@"itunes:owner"][@"itunes:email"]) {
            id email = feedDict[@"channel"][@"itunes:owner"][@"itunes:email"];
            if ([email isKindOfClass:[NSString class]]) {
                entity.email = email;
            }
        }
        // description
        NSString *descrip;
        if ([[feedDict objectForKey:@"channel"] objectForKey:@"itunes:summary"]) {
            id desc = [[feedDict objectForKey:@"channel"] objectForKey:@"itunes:summary"];
            if ([desc isKindOfClass:[NSString class]]) {
                descrip = (NSString *)desc;
            }
        }
        if (!descrip && [[feedDict objectForKey:@"channel"] objectForKey:@"description"]) {
            id descr = [[feedDict objectForKey:@"channel"] objectForKey:@"description"];
            if ([descr isKindOfClass:[NSString class]]) {
                descrip = (NSString *)descr;
            }
        }
        if (!descrip && [[feedDict objectForKey:@"channel"] objectForKey:@"itunes:subtitle"]) {
            id descr = [[feedDict objectForKey:@"channel"] objectForKey:@"itunes:subtitle"];
            if ([descr isKindOfClass:[NSString class]]) {
                descrip = (NSString *)descr;
            }
        }
        if (!descrip) {
            descrip = @"This podcast has no description.";
        }
        entity.desc = descrip;
        
        //NSLog(@"entity after additions from feed: %@", [TungCommonObjects entityToDict:entity]);
        [self cacheFeed:feedDict forEntity:entity];
    	return feedDict;
    }
    else {
        return feedDict;
    }
    
}

// used for preloading feeds in _podcastArray (from search results)
-(void) preloadFeedsWithLimit:(NSUInteger)limit {
    
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
            //JPLog(@"** preload feed at index: %d", i);
            PodcastEntity *podEntity = [TungCommonObjects getEntityForPodcast:[podcastArrayCopy objectAtIndex:i] save:NO];
            [TungPodcast retrieveAndCacheFeedForPodcastEntity:podEntity forceNewest:YES reachable:YES];
        }];
    }
}

// get raw feed and return converted data.
+ (NSDictionary *) requestAndConvertPodcastFeedDataWithFeedUrl:(NSString *)feedUrl {
    
    NSData *feedData = [NSData dataWithContentsOfURL:[NSURL URLWithString: feedUrl]];
    JPXMLtoDictionary *xmlToDict = [[JPXMLtoDictionary alloc] init];
    return [xmlToDict xmlDataToDictionary:feedData];
}

// get an episode array from a feed dict. First line of defense against bad feeds
+ (NSArray *) extractFeedArrayFromFeedDict:(NSDictionary *)feedDict {
    
    if (feedDict) {
        if ([feedDict objectForKey:@"channel"]) {
            if ([[feedDict objectForKey:@"channel"] objectForKey:@"item"]) {
                id item = [[feedDict objectForKey:@"channel"] objectForKey:@"item"];
                if ([item isKindOfClass:[NSArray class]]) {
                    NSArray *array = item;
                    return array;
                } else {
                    return @[item];
                }
            } else {
                return @[@{@"error": @"Bad feed: No items"}];
            }
        } else {
            return @[@{@"error": @"Bad feed: No channel node"}];
        }
    } else {
        return @[@{@"error": @"Empty feed"}];
    }
}

@end
