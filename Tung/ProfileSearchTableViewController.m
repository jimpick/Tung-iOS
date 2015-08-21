//
//  ProfileSearchTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 11/12/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "ProfileListTableViewController.h"
#import "TungCommonObjects.h"
#import "tungPeople.h"
#import "ProfileListCell.h"
#import "ProfileSearchTableViewController.h"

@interface ProfileSearchTableViewController ()

@property (nonatomic, retain) TungCommonObjects *tungObjects;
@property (strong, nonatomic) tungPeople *tungPeople;

@property (nonatomic, assign) BOOL feedRefreshed;
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;
@property (strong, nonatomic) UIActivityIndicatorView *behindTable;

@property (strong, nonatomic) NSTimer *searchTimer;
@property (strong, nonatomic) UIBarButtonItem *headerLabel;

@end

@implementation ProfileSearchTableViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    _tungObjects = [TungCommonObjects establishTungObjects];
    _tungObjects.viewController = self;
    
    _tungPeople = [[tungPeople alloc] init];
    _tungPeople.tableView = self.tableView;
    _tungPeople.viewController = self;
    _tungPeople.queryType = @"";
    
    // search bar
    _searchBar = [[UISearchBar alloc] init];
    _searchBar.delegate = self;
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.tintColor = _tungObjects.tungColor;
    _searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    if (_searchTerm.length > 0) {
        _searchBar.text = _searchTerm;
    }
    self.navigationItem.titleView = _searchBar;
    
    // table view
    _behindTable = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.tableView.backgroundView = _behindTable;
    self.tableView.backgroundColor = _tungObjects.bkgdGrayColor;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.scrollsToTop = YES;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 35, 0);
    
    // refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
    _tungPeople.refreshControl = self.refreshControl;
    
    // set up toolbar
    UIBarButtonItem *btn_seekBack = [_tungPeople generateStereoButtonWithImageName:@"btn-seek-back-disabled.png"];
    UIBarButtonItem *btn_seekForward = [_tungPeople generateStereoButtonWithImageName:@"btn-seek-forward-disabled.png"];
    UIBarButtonItem *btn_playPause = [_tungPeople generateStereoButtonWithImageName:@"btn-play-disabled.png"];
    UIBarButtonItem *btn_loop = [_tungPeople generateStereoButtonWithImageName:@"btn-loop-disabled.png"];
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil];
    fixedSpace.width = 120;
    UIBarButtonItem *fSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    [self setToolbarItems:@[btn_seekBack, fSpace,
                            btn_loop, fSpace,
                            fixedSpace, fSpace,
                            btn_playPause, fSpace,
                            btn_seekForward] animated:NO];
    self.navigationController.toolbar.clipsToBounds = YES;
    
    // get feed
    [self refreshFeed];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void) viewWillDisappear:(BOOL)animated {
    [self resignFirstResponder];
    [super viewWillDisappear:animated];
}

- (void) refreshFeed {
    
    [TungCommonObjects checkReachabilityWithCallback:^(BOOL reachable) {
        if (reachable) {
            _feedRefreshed = YES;
            NSNumber *mostRecent;
            if (_tungPeople.itemArray.count > 0) {
                NSLog(@"profile search: refresh feed");
                [self.refreshControl beginRefreshing];
                mostRecent = [[_tungPeople.itemArray objectAtIndex:0] objectForKey:@"time_secs"];
            } else {
                NSLog(@"profile search: get feed");
                mostRecent = [NSNumber numberWithInt:0];
            }
            if (_searchTerm.length > 0) {
                
                _tungPeople.queryExecuted = NO;
                [_tungPeople requestProfileListWithQuery:@""
                                               forTarget:@""
                                            orSearchTerm:_searchTerm
                                               newerThan:mostRecent
                                             orOlderThan:[NSNumber numberWithInt:0]];
                
                _behindTable.alpha = 1;
                [_behindTable startAnimating];
            } else {
                NSLog(@"...waiting for search to be entered");
                //                NSLog(@"- profiled user: %@", _profiledUser);
                //                NSLog(@"- profiled category: %@", _profiledCategory);
                //                NSLog(@"- search term: %@", _searchTerm);
                _behindTable.alpha = 1;
            }
        }
        // unreachable
        else {
            UIAlertView *noReachabilityAlert = [[UIAlertView alloc] initWithTitle:@"No Connection" message:@"tung requires an internet connection" delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:nil];
            [noReachabilityAlert setTag:49];
            [noReachabilityAlert show];
        }
    }];
    
}
-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 49) [self refreshFeed]; // unreachable, retry
}

#pragma mark - Search Bar delegate methods

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    _searchTerm = searchBar.text;
    [_searchTimer invalidate];
    [self searchForTerm];
}
-(void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    _searchTerm = searchText;
    [_searchTimer invalidate];
    _searchTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(searchForTerm) userInfo:nil repeats:NO];
}

-(void) searchForTerm {
    if (_searchTerm.length > 0) {
        NSLog(@"SENDING SEARCH for %@", _searchTerm);
        _tungPeople.queryExecuted = NO;
        NSString *headerText = [self determineSearchTableHeader];
        _headerLabel.title = headerText;
        [_tungPeople requestProfileListWithQuery:@""
                                       forTarget:@""
                                    orSearchTerm:_searchTerm
                                       newerThan:[NSNumber numberWithInt:0]
                                     orOlderThan:[NSNumber numberWithInt:0]];
    }
}

#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSLog(@"selected cell at row %ld", (long)[indexPath row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [_tungPeople pushProfileForUserAtIndex:indexPath.row];
    
}

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0)
        return 44;
    else
        return 0;
}
-(UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        
        UIToolbar *headerBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 44)];
        headerBar.translucent = YES;
        NSString *headerText = [self determineSearchTableHeader];
        _headerLabel = [[UIBarButtonItem alloc] initWithTitle:headerText style:UIBarButtonItemStylePlain target:self action:nil];
        _headerLabel.tintColor = [UIColor grayColor];
        [headerBar setItems:@[_headerLabel] animated:NO];
        return headerBar;
        
    } else {
        return nil;
    }
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (_tungPeople.noMoreItemsToGet && section == 1) {
        UILabel *noMoreLabel = [[UILabel alloc] init];
        noMoreLabel.text = @"That's everyone";
        noMoreLabel.textColor = [UIColor grayColor];
        noMoreLabel.textAlignment = NSTextAlignmentCenter;
        return noMoreLabel;
    }
    /* only used if search was in title bar (not currently)
     else if (_tungStereo.noResults && section == 1) {
     UILabel *noResultsLabel = [[UILabel alloc] init];
     noResultsLabel.text = @"No clips for that query.";
     noResultsLabel.textColor = [UIColor grayColor];
     noResultsLabel.textAlignment = NSTextAlignmentCenter;
     return noResultsLabel;
     }
     */
    else {
        _loadMoreIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _tungPeople.loadMoreIndicator = _loadMoreIndicator;
        return _loadMoreIndicator;
    }
}

-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (!_tungPeople.noMoreItemsToGet && section == 0)
        return 60.0;
    else if (_tungPeople.noMoreItemsToGet && section == 1)
        return 60.0;
    else
        return 0;
}

- (NSString *) determineSearchTableHeader {
    NSString *result;
    
    if (_tungPeople.queryExecuted) {
        if (_tungPeople.itemArray.count > 0) {
            result = [NSString stringWithFormat:@" Results for “%@”", _searchTerm];
        } else {
            result = [NSString stringWithFormat:@" No results for “%@”", _searchTerm];
        }
    } else {
        result = @" Enter a name or username in the field above";
    }

    return result;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return [_tungPeople.itemArray count];
    } else {
        return 0;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *profileListCellIdentifier = @"ProfileListCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:profileListCellIdentifier];
    [_tungPeople configureProfileListCell:cell forIndexPath:indexPath];
    return cell;
}


#pragma mark - scroll view delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if (scrollView == self.tableView) {
        // detect when user hits bottom of feed
        float bottomOffset = scrollView.contentSize.height - scrollView.frame.size.height;
        if (scrollView.contentOffset.y >= bottomOffset) {
            // request more posts if they didn't reach the end
            if (!_tungPeople.requestingMore && !_tungPeople.noMoreItemsToGet && _tungPeople.itemArray.count > 0) {
                _tungPeople.requestingMore = YES;
                _loadMoreIndicator.alpha = 1;
                [_loadMoreIndicator startAnimating];
                NSNumber *oldest = [[_tungPeople.itemArray objectAtIndex:_tungPeople.itemArray.count-1] objectForKey:@"time_secs"];
                [_tungPeople requestProfileListWithQuery:@""
                                               forTarget:@""
                                            orSearchTerm:_searchTerm
                                               newerThan:[NSNumber numberWithInt:0]
                                             orOlderThan:oldest];
            }
        }
    }
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
