#import "OTSMainViewController.h"
#import "OTSDatabaseManager.h"

@import CoreData;

@interface OTSMainViewController () <UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) OTSDatabaseManager *databaseManager;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

- (void)addDataItem:(id)sender;
- (void)addMultipleDataItems:(id)sender;

@end

@implementation OTSMainViewController

#pragma mark - Property Overrides

- (NSFetchedResultsController *)fetchedResultsController {
  if (_fetchedResultsController) return _fetchedResultsController;
  
  NSManagedObjectContext *moc = [[self databaseManager] mainThreadManagedObjectContext];
  NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"OTSDataItem"];
  NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"dataItem" ascending:NO];
  [fetchRequest setSortDescriptors:@[ sort ]];
  
  NSFetchedResultsController *frc = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:moc sectionNameKeyPath:nil cacheName:@"MainCache"];
  [self setFetchedResultsController:frc];
  [[self fetchedResultsController] setDelegate:self];
  
  NSError *error = nil;
  NSAssert([_fetchedResultsController performFetch:&error], @"Unresolved error %@\n%@", [error localizedDescription], [error userInfo]);
  return _fetchedResultsController;
}

#pragma mark - Method Overrides

- (void)viewDidLoad {
  [super viewDidLoad];

  [self setTitle:@"Core Data Stack"];
  
  UIBarButtonItem *newItemBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addDataItem:)];
  [[self navigationItem] setRightBarButtonItem:newItemBarButtonItem];
  [[[self navigationItem] rightBarButtonItem] setEnabled:NO];

  UIBarButtonItem *batchAddItemaBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"++" style:UIBarButtonItemStylePlain target:self action:@selector(addMultipleDataItems:)];
  [[self navigationItem] setLeftBarButtonItem:batchAddItemaBarButtonItem];
  [[[self navigationItem] leftBarButtonItem] setEnabled:NO];

  [self setDatabaseManager:[[OTSDatabaseManager alloc] init]];
  [[self databaseManager] setupCoreDataStackWithCompletionHandler:^(BOOL suceeded, NSError *error) {
    if (suceeded) {
      [[[self navigationItem] leftBarButtonItem] setEnabled:YES];
      [[[self navigationItem] rightBarButtonItem] setEnabled:YES];
      [[self tableView] reloadData];
    } else {
      NSLog(@"Core Data stack setup failed.");
    }
  }];
 
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
  [self setDateFormatter:dateFormatter];
}

#pragma mark - Private Methods

- (void)addDataItem:(id)sender {
  NSManagedObject *moDataItem = [[NSManagedObject alloc] initWithEntity:[NSEntityDescription entityForName:@"OTSDataItem" inManagedObjectContext:[[self databaseManager] mainThreadManagedObjectContext]] insertIntoManagedObjectContext:[[self databaseManager] mainThreadManagedObjectContext]];
  [moDataItem setValue:[[self dateFormatter] stringFromDate:[NSDate date]] forKey:@"dataItem"];
  [[self databaseManager] saveDataWithCompletionHandler:^(BOOL suceeded, NSError *error) {
    if (!suceeded) {
      NSLog(@"Core Data save failed.");
    }
  }];
}

- (void)addMultipleDataItems:(id)sender {
  NSManagedObjectContext *batchAddContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
  [batchAddContext setParentContext:[[self databaseManager] mainThreadManagedObjectContext]];
  [batchAddContext performBlock:^{
    for (NSInteger itemCount = 0; itemCount < 10; itemCount++) {
      NSManagedObject *moDataItem = [[NSManagedObject alloc] initWithEntity:[NSEntityDescription entityForName:@"OTSDataItem" inManagedObjectContext:batchAddContext] insertIntoManagedObjectContext:batchAddContext];
      [moDataItem setValue:[NSString stringWithFormat:@"++ %@", [[self dateFormatter] stringFromDate:[NSDate date]]] forKey:@"dataItem"];
    }
    
    // Save the batchAddContext which pushes the items onto the main thread context
    NSError *error;
    if (![batchAddContext save:&error]) {
      NSLog(@"Unable to save batch added items: %@", [error localizedDescription]);
      return;
    }
    
    // Save the main thead context... saveDataWithCompletionHandler: uses the right thread
    [[self databaseManager] saveDataWithCompletionHandler:^(BOOL suceeded, NSError *error) {
      if (!suceeded) {
        NSLog(@"Core Data save failed.");
      }
    }];
  }];
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return [[[self fetchedResultsController] sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  NSArray *sections = [[self fetchedResultsController] sections];
  id <NSFetchedResultsSectionInfo> sectionInfo = [sections objectAtIndex:section];
  return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  NSManagedObject *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
  }
  [[cell textLabel] setText:[object valueForKey:@"dataItem"]];
  return cell;
}

#pragma mark - UITableViewDelegate Methods

#pragma mark - NSFetchedResultsControllerDelegate Methods

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
  [[self tableView] beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
  NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:sectionIndex];
  switch(type) {
    case NSFetchedResultsChangeInsert:
      [[self tableView] insertSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
      break;
    case NSFetchedResultsChangeDelete:
      [[self tableView] deleteSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
      break;
    case NSFetchedResultsChangeMove:
      break;
    case NSFetchedResultsChangeUpdate:
      break;
  }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
  NSArray *newArray = nil;
  NSArray *oldArray = nil;
  
  if (newIndexPath) {
    newArray = [NSArray arrayWithObject:newIndexPath];
  }
  
  if (indexPath) {
    oldArray = [NSArray arrayWithObject:indexPath];
  }
  
  switch(type) {
    case NSFetchedResultsChangeInsert:
      [[self tableView] insertRowsAtIndexPaths:newArray withRowAnimation:UITableViewRowAnimationFade];
      break;
    case NSFetchedResultsChangeDelete:
      [[self tableView] deleteRowsAtIndexPaths:oldArray withRowAnimation:UITableViewRowAnimationFade];
      break;
    case NSFetchedResultsChangeUpdate:
    {
      UITableViewCell *cell = [[self tableView] cellForRowAtIndexPath:indexPath];
      NSManagedObject *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
      [[cell textLabel] setText:[object valueForKey:@"dataItem"]];
      break;
    }
    case NSFetchedResultsChangeMove:
      [[self tableView] deleteRowsAtIndexPaths:oldArray withRowAnimation:UITableViewRowAnimationFade];
      [[self tableView] insertRowsAtIndexPaths:newArray withRowAnimation:UITableViewRowAnimationFade];
      break;
  }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
  [[self tableView] endUpdates];
}

@end
