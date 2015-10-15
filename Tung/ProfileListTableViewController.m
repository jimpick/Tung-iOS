//
//  ProfileListTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 11/3/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "ProfileListTableViewController.h"
#import "TungCommonObjects.h"
#import "TungPeople.h"
#import "ProfileListCell.h"
//#import "ProfileViewController.h"

@interface ProfileListTableViewController ()

@property (nonatomic, retain) TungCommonObjects *tungObjects;
@property (strong, nonatomic) TungPeople *tungPeople;

@property (nonatomic, assign) BOOL feedRefreshed;
@property (strong, nonatomic) UIActivityIndicatorView *loadMoreIndicator;

@end

@implementation ProfileListTableViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    _tungObjects = [TungCommonObjects establishTungObjects];
    _tungObjects.viewController = self;
    
    // set defaults for required properties
    if (_queryType == NULL) _queryType = @"Activity";
    if (_target_id == NULL) _target_id = _tungObjects.tungId;
    
    _tungPeople = [[TungPeople alloc] init];
    _tungPeople.tableView = self.tableView;
    _tungPeople.viewController = self;
    _tungPeople.queryType = _queryType;
    
    // navigation title
    self.navigationItem.title = _queryType;
    
    // table view
    UIActivityIndicatorView *behindTable = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    behindTable.alpha = 1;
    [behindTable startAnimating];
    self.tableView.backgroundView = behindTable;
    self.tableView.backgroundColor = _tungObjects.bkgdGrayColor;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.separatorColor = [UIColor grayColor];
    self.tableView.scrollsToTop = YES;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    
    // refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
    _tungPeople.refreshControl = self.refreshControl;
    
    
    // get feed
    [self refreshFeed];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) refreshFeed {
    
    [TungCommonObjects checkReachabilityWithCallback:^(BOOL reachable) {
        if (reachable) {
        	// query users
            _feedRefreshed = YES;
            NSNumber *mostRecent;
            if (_tungPeople.itemArray.count > 0) {
                NSLog(@"profile list: refresh feed");
                [self.refreshControl beginRefreshing];
                mostRecent = [[_tungPeople.itemArray objectAtIndex:0] objectForKey:@"time_secs"];
            } else {
                NSLog(@"profile list: get feed");
                mostRecent = [NSNumber numberWithInt:0];
            }
            [_tungPeople requestProfileListWithQuery:_queryType
                                           forTarget:_target_id
                                        orSearchTerm:@""
                                           newerThan:mostRecent
                                         orOlderThan:[NSNumber numberWithInt:0]];
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

#pragma mark - Table view delegate methods

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {

    return 60;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSLog(@"selected cell at row %ld", (long)[indexPath row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [_tungPeople pushProfileForUserAtIndex:indexPath.row];
    
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (_tungPeople.noMoreItemsToGet && section == 1) {
        UILabel *noMoreLabel = [[UILabel alloc] init];
        NSString *thatsAll = ([_queryType isEqualToString:@"activity"]) ? @"That's everything" : @"That's everyone";
        noMoreLabel.text = thatsAll;
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
                [_tungPeople requestProfileListWithQuery:_queryType
                                               forTarget:_target_id
                                            orSearchTerm:@""
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
