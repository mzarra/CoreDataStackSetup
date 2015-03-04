#import "OTSDatabaseManager.h"
@import CoreData;

@interface OTSDatabaseManager()

@property (strong, nonatomic) NSManagedObjectContext *mainThreadManagedObjectContext;
@property (strong, nonatomic) NSManagedObjectContext *saveManagedObjectContext;

@end

@implementation OTSDatabaseManager

- (void)setupCoreDataStackWithCompletionHandler:(OTSDatabaseManagerStackSetupCompletionHandler)handler {
  if ([self saveManagedObjectContext]) return;
  NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"MyDataModel" withExtension:@"momd"];
  if (!modelURL) {
    NSError *customError = nil; //Return a custom error
    handler(NO, customError);
    return;
  }
  
  NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
  if (!mom) {
    NSError *customError = nil; //Return a custom error
    handler(NO, customError);
    return;
  }
  
  NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
  if (!psc) {
    NSError *customError = nil; //Return a custom error
    handler(NO, customError);
    return;
  }
  
  NSManagedObjectContext *saveMoc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
  [saveMoc setPersistentStoreCoordinator:psc];
  [self setSaveManagedObjectContext:saveMoc];
  
  NSManagedObjectContext *mainThreadMoc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
  [mainThreadMoc setParentContext:[self saveManagedObjectContext]];
  [self setMainThreadManagedObjectContext:mainThreadMoc];

  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_async(queue, ^{
    NSArray *directoryArray = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    NSURL *storeURL = [directoryArray lastObject];
    
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:storeURL withIntermediateDirectories:YES attributes:nil error:&error]) {
      NSError *customError = nil; //Return a custom error
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(NO, customError);
      });
    }
    storeURL = [storeURL URLByAppendingPathComponent:@"MyDataFile.sqlite"];
    
    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption: @YES, NSInferMappingModelAutomaticallyOption: @YES };
    NSPersistentStore *store = [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error];
    
    if (!store) {
      NSError *customError = nil; //Return a custom error
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(NO, customError);
      });
    } else {
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(YES, nil);
      });
    }
  });
}

- (void)saveDataWithCompletionHandler:(OTSDatabaseManagerSaveCompletionHandler)handler {
  [[self mainThreadManagedObjectContext] performBlock:^{
    if ([[self mainThreadManagedObjectContext] hasChanges]) {
      NSError *error = nil;
      if ([[self mainThreadManagedObjectContext] save:&error]) {
        if ([[self saveManagedObjectContext] save:&error]) {
          dispatch_async(dispatch_get_main_queue(), ^{
            handler(YES, nil);
          });
        } else {
          dispatch_async(dispatch_get_main_queue(), ^{
            NSError *customError = nil; //Return a custom error
            handler(NO, customError);
          });
        }
      } else {
        dispatch_async(dispatch_get_main_queue(), ^{
          NSError *customError = nil; //Return a custom error
          handler(NO, customError);
        });
      }
    } else {
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(YES, nil);
      });
    }
  }];
}

@end
