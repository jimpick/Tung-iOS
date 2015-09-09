//
//  PodcastTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 7/27/15.
//  Copyright (c) 2015 Jamie Perkins. All rights reserved.
//

#import "EpisodeTableViewController.h"

@interface EpisodeTableViewController ()


@property (nonatomic, retain) TungCommonObjects *tung;

@end

@implementation EpisodeTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tung = [TungCommonObjects establishTungObjects];
    
    // set up table
    self.tableView.backgroundColor = _tung.bkgdGrayColor;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.scrollsToTop = YES;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 9, 0, 9);
    self.tableView.contentInset = UIEdgeInsetsZero;// UIEdgeInsetsMake(0, 0, 0, 0);
    self.tableView.separatorColor = [UIColor lightGrayColor];
    
    UIActivityIndicatorView *tableSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    tableSpinner.alpha = 1;
    [tableSpinner startAnimating];
    self.tableView.backgroundView = tableSpinner;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return _episodeArray.count;
    } else {
        return 0;
    }
}

static NSDateFormatter *airDateFormatter = nil;
static NSString *cellIdentifier = @"EpisodeCell";

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //NSLog(@"cell for row at index path, row: %ld", (long)indexPath.row);
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    EpisodeCell *episodeCell = (EpisodeCell *)cell;
    
    // cell data
    NSDictionary *episodeDict = [NSDictionary dictionaryWithDictionary:[_episodeArray objectAtIndex:indexPath.row]];
    
    // title
    episodeCell.episodeTitle.text = [episodeDict objectForKey:@"title"];
    episodeCell.episodeTitle.textColor = [_podcastDict objectForKey:@"keyColor1"];
    // air date
    if (!airDateFormatter) {
        airDateFormatter = [[NSDateFormatter alloc] init];
        [airDateFormatter setDateFormat:@"MMM d, yyyy"];
    }
    episodeCell.airDate.text = [airDateFormatter stringFromDate:[episodeDict objectForKey:@"pubDate"]];
    
    // kill insets for iOS 8
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 8) {
        episodeCell.preservesSuperviewLayoutMargins = NO;
        [episodeCell setLayoutMargins:UIEdgeInsetsZero];
    }
    
    return episodeCell;
}

#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    //NSLog(@"%@", [_episodeArray objectAtIndex:indexPath.row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // play episode selected
    NSDictionary *episodeDict = [_episodeArray objectAtIndex:indexPath.row];
    NSString *urlString = [[[episodeDict objectForKey:@"enclosure"] objectForKey:@"el:attributes"] objectForKey:@"url"];
    if (urlString) {
        [TungCommonObjects getEntityForPodcast:_podcastDict andEpisode:episodeDict save:YES];
        
        // set now playing feed and podcast dict
        [_tung assignCurrentFeed:_episodeArray];
        _tung.npPodcastDict = _podcastDict;
        
        [_tung queueAndPlaySelectedEpisode:urlString];
    } else {
        
        UIAlertView *badXmlAlert = [[UIAlertView alloc] initWithTitle:@"Can't Play - No URL" message:@"Unfortunately, this feed is missing links to its content." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [badXmlAlert show];
    }
    
}

//- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 74;
}

-(UIView *) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (_episodeArray.count > 0 && section == 1) {
        UILabel *noMoreLabel = [[UILabel alloc] init];
        noMoreLabel.text = @"That's everything.";
        noMoreLabel.textColor = [UIColor grayColor];
        noMoreLabel.textAlignment = NSTextAlignmentCenter;
        return noMoreLabel;
    }
    else if (_noResults && section == 1) {
        UILabel *noEpisodesLabel = [[UILabel alloc] init];
        noEpisodesLabel.text = @"Podcast feed is empty.";
        noEpisodesLabel.textColor = [UIColor grayColor];
        noEpisodesLabel.textAlignment = NSTextAlignmentCenter;
        return noEpisodesLabel;
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

@end
