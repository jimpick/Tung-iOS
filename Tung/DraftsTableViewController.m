//
//  DraftsTableViewController.m
//  Tung
//
//  Created by Jamie Perkins on 7/18/14.
//  Copyright (c) 2014 Jamie Perkins. All rights reserved.
//

#import "DraftsTableViewController.h"
#import "tungCommonObjects.h"

static NSString *TableViewCellIdentifier = @"draftCell";

@interface DraftsTableViewController ()

@property (nonatomic, retain) tungCommonObjects *tungObjects;
@property (strong, nonatomic) NSMutableArray *tungDrafts;
@property (strong, nonatomic) NSDateFormatter *draftTitleDateFormatter;
@property (strong, nonatomic) NSMutableDictionary *recordingInfoDictionary;
@property (nonatomic, assign) BOOL noDrafts;

@end

@implementation DraftsTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _noDrafts = NO;
    
    _tungObjects = [tungCommonObjects establishTungObjects];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // table properties
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:TableViewCellIdentifier];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = _tungObjects.bkgdGrayColor;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.scrollsToTop = YES;
    self.tableView.separatorColor = [UIColor whiteColor];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0);
    self.tableView.bounces = NO;
    
    // check if drafts folders exist
    BOOL draftsFoldersExist = NO;
    NSError *error = nil;
    NSArray *folders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSArray *appFolderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[folders objectAtIndex:0] error:&error];
    if ([appFolderContents count] > 0 && error == nil) {
		for (NSString *item in appFolderContents) {
            if ([item isEqualToString:@"drafts"])
                draftsFoldersExist = YES;
        }
    }
    _tungDrafts = [[NSMutableArray alloc] init];
    
    if (draftsFoldersExist) {
        // drafts data source
        NSString *draftsPath = [NSString stringWithFormat:@"%@/drafts", [folders objectAtIndex:0]];
        NSString *draftsPathEncoded = [draftsPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSURL *draftsPathURL = [NSURL URLWithString:draftsPathEncoded];
        // draft metas path
        NSString *draftsMetaPath = [NSString stringWithFormat:@"%@/draftsMeta", [folders objectAtIndex:0]];
        NSArray *desiredProperties = @[NSURLIsReadableKey, NSURLCreationDateKey];
        NSArray *drafts = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:draftsPathURL includingPropertiesForKeys:desiredProperties options:0 error:&error];
        NSArray *draftMetas = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:draftsMetaPath error:&error];
        NSLog(@"draft metas: %@", draftMetas);
        // enumerate files in drafts folders
        for (NSURL *item in drafts) {
            NSMutableDictionary *draftDict = [[NSMutableDictionary alloc] init];
            // draftFilename
            NSString *draftFilename = [item lastPathComponent];
            // is readable
            NSNumber *isReadableBoolValue = nil;
            [item getResourceValue:&isReadableBoolValue forKey:NSURLIsReadableKey error:&error];
            if ([isReadableBoolValue isEqualToNumber:@YES]) {
                // name
                [draftDict setValue:draftFilename forKey:@"draftFilename"];
                // creation date
                NSDate *creationDate = nil;
                [item getResourceValue:&creationDate forKey:NSURLCreationDateKey error:&error];
                [draftDict setValue:creationDate forKey:@"creationDate"];
                // meta
                NSString *name = [draftFilename stringByDeletingPathExtension];
                NSString *metaFilename = [NSString stringWithFormat:@"%@.txt", name];
                NSString *metaFilePath = [NSString stringWithFormat:@"%@/%@", draftsMetaPath, metaFilename];
                NSMutableDictionary *metaData = [[NSMutableDictionary alloc] initWithContentsOfFile:metaFilePath];
                // current reference to file
                NSString *convertedFilepath = [NSString stringWithFormat:@"%@/%@", draftsPath, [metaData objectForKey:@"convertedFile"]];
                [metaData setObject:convertedFilepath forKey:@"convertedFile"];
                NSLog(@"meta data: %@", metaData);
                [draftDict addEntriesFromDictionary:metaData];
                
                // insert into first position of data source array
                [_tungDrafts insertObject:draftDict atIndex:0];
                // meta
            } else {
                NSLog(@"unreadable item: %@", draftFilename);
            }
        }
    }
    
    if ([_tungDrafts count] == 0) {
        _noDrafts = YES;
        NSDictionary *draftDict = @{@"creationDate": @"No drafts", @"captionText": @"Tap \"Cancel\" from Share to create a draft"};
        [_tungDrafts addObject:draftDict];
        self.tableView.separatorColor = _tungObjects.bkgdGrayColor;
    }
    //NSLog(@"tung drafts: %@", _tungDrafts);
    
    // show edit button if there are drafts to delete
    if (!_noDrafts) self.navigationItem.rightBarButtonItem = self.editButtonItem;

    // date formatter
    _draftTitleDateFormatter = [[NSDateFormatter alloc] init];
    [_draftTitleDateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [_draftTitleDateFormatter setTimeStyle:NSDateFormatterShortStyle];

}

// iOS 8 edge insets fix
-(void)viewDidLayoutSubviews
{
    if ([self.tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        [self.tableView setSeparatorInset:UIEdgeInsetsZero];
    }
    if ([self.tableView respondsToSelector:@selector(setLayoutMargins:)]) {
        [self.tableView setLayoutMargins:UIEdgeInsetsZero];
    }
}
- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.titleTextAttributes = @{ NSForegroundColorAttributeName: _tungObjects.tungColor };
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

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [_tungDrafts count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Configure the cell...
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:TableViewCellIdentifier];
    // cell data
    NSDictionary *draftDict = [NSDictionary dictionaryWithDictionary:[_tungDrafts objectAtIndex:indexPath.row]];
    // @{@"convertedFile": draftDestinationPath, @"selectedCategory": _selectedCategory, @"captionText": self.captionTextView.text};
    // cell title
    id title = [draftDict objectForKey:@"creationDate"];
    NSString *cellTitle;
    if ([title isKindOfClass:[NSDate class]]) {
    	NSDate *creationDate = [draftDict objectForKey:@"creationDate"];
    	cellTitle = [_draftTitleDateFormatter stringFromDate:creationDate];
    } else {
        cellTitle = title;
    }
    cell.textLabel.text = cellTitle;
    // cell subtitle
    NSString *caption = [draftDict valueForKey:@"captionText"];
    cell.detailTextLabel.text = caption;
    // is it a draft?
    if ([draftDict objectForKey:@"selectedCategory"] != nil) {
        int selCat = [[draftDict objectForKey:@"selectedCategory"] intValue];
        // caption
        if ([caption length] == 0) caption = [_tungObjects.categoryHashtags objectAtIndex:selCat];
        cell.detailTextLabel.text = caption;
        // cell accessory
        cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"UITableNext.png"]];
        // background color
    	cell.backgroundColor = [_tungObjects.categoryColors objectAtIndex:selCat];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
        // selected color
        UIView *bgColorView = [[UIView alloc] init];
        bgColorView.backgroundColor = [_tungObjects.darkCategoryColors objectAtIndex:selCat];
        [cell setSelectedBackgroundView:bgColorView];
    } else {
        // "no drafts" message
        cell.backgroundColor = [UIColor colorWithRed:230.0/255.0 green:230.0/255.0 blue:230.0/255.0 alpha:1];
        cell.textLabel.textColor = [UIColor darkGrayColor];
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }
    
    return cell;
}
// iOS 8 edge insets fix
-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        [cell setSeparatorInset:UIEdgeInsetsZero];
    }
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return 66.0;
}

#pragma mark - Table view delegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSLog(@"selected cell at row %ld", (long)[indexPath row]);
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!_noDrafts) {
        NSUInteger row = [indexPath row];
        self.recordingInfoDictionary = [NSMutableDictionary dictionaryWithDictionary:[_tungDrafts objectAtIndex:row]];
        [self performSegueWithIdentifier:@"toPostView" sender:self];
    }
}

#pragma mark - Table view editing


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!_noDrafts) return YES;
    else return NO;
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"commit editing style");
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // there are drafts to delete
        if (!_noDrafts) {
            // delete the drafts file
            NSUInteger row = [indexPath row];
            NSDictionary *draftDict = [NSDictionary dictionaryWithDictionary:[_tungDrafts objectAtIndex:row]];
            NSString *draftFilename = [draftDict objectForKey:@"draftFilename"];
            NSString *name = [draftFilename stringByDeletingPathExtension];
            NSLog(@"attempting to delete %@", name);
            NSArray *folders = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *draftDestPath = [NSString stringWithFormat:@"%@/drafts/%@.m4a", [folders objectAtIndex:0], name];
            NSString *draftMetaDestPath = [NSString stringWithFormat:@"%@/draftsMeta/%@.txt", [folders objectAtIndex:0], name];
            NSError *error = nil;
            if ([[NSFileManager defaultManager] removeItemAtPath:draftDestPath error:&error]) {
                NSLog(@"deleted draft: %@.m4a", name);
            } else {
                NSLog(@"error deleting sound file: %@", error);
            }
            if ([[NSFileManager defaultManager] removeItemAtPath:draftMetaDestPath error:&error]) {
                NSLog(@"deleted draft meta: %@.txt", name);
            } else {
                NSLog(@"error deleting meta file: %@", error);
            }
            // delete from data source
            [_tungDrafts removeObjectAtIndex:row];
            // delete row from table
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationRight];
            // if the last draft is deleted, display "no drafts" message
            if ([_tungDrafts count] == 0) {
                _noDrafts = YES;
                NSDictionary *draftDict = @{@"creationDate": @"No drafts", @"captionText": @"Tap \"Cancel\" from Share to create a draft"};
                [_tungDrafts addObject:draftDict];
                [tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationLeft];
                self.tableView.separatorColor = _tungObjects.bkgdGrayColor;
            }
        }
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark - Navigation

- (IBAction)unwindToDrafts:(UIStoryboardSegue*)sender {
    
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UIViewController *destination = segue.destinationViewController;
    if ([[segue identifier] isEqualToString:@"toPostView"]) {
    	[destination setValue:self.recordingInfoDictionary forKey:@"recordingInfoDictionary"];
    }
}


- (IBAction)cancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
