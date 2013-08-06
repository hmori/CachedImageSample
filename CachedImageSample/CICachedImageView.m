#import "CICachedImageView.h"
#import <CoreData/CoreData.h>

#define CONNECTION_MAX_COUNT 3
#define TIMEOUT_INTERVAL 10.0f

#define kObservingFinish @"_isFinished"
#define kObservingExecuting @"_isExecuting"
#define kNotificationUpdateImage @"kNotificationUpdateImage"
#define kUserInfoUrl @"kUserInfoUrl"
#define kUserInfoImage @"kUserInfoImage"
#define kSqliteNameCachedImage @"CachedImage.sqlite"
#define kModelNameCachedImage @"CachedImage"
#define kEntityNameCachedImage @"CICachedImage"


#pragma mark - CICachedImage

@interface CICachedImage : NSManagedObject
@property (nonatomic, retain) NSData * data;
@property (nonatomic, retain) NSString * url;
@end

@implementation CICachedImage
@dynamic data;
@dynamic url;
@end


#pragma mark - CIImageRequestOperation

@interface CIImageRequestOperation : NSOperation
@property (nonatomic) NSMutableData *data;
@property (nonatomic) NSString *url;
@property (nonatomic, readonly) NSURLRequest *request;
@property (nonatomic, readonly) NSHTTPURLResponse *response;
@property (nonatomic, readonly) NSURLConnection *connection;
- (id)initWithURLString:(NSString *)url;
- (id)initWithURLString:(NSString *)url username:(NSString *)username password:(NSString *)password;
@end


@implementation CIImageRequestOperation {
    NSString *_username;
    NSString *_password;
    BOOL _isExecuting;
    BOOL _isFinished;
}

- (id)initWithURLString:(NSString *)url {
    return [self initWithURLString:url username:nil password:nil];
}

- (id)initWithURLString:(NSString *)url username:(NSString *)username password:(NSString *)password {
    if ((self = [super init])) {
        _data = [NSMutableData dataWithCapacity:0];
        _url = url;
        _username = username;
        _password = password;
        
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:kObservingFinish] || [key isEqualToString:kObservingExecuting]) {
        return YES;
    }
    return [super automaticallyNotifiesObserversForKey:key];
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isExecuting {
    return _isExecuting;
}

- (BOOL)isFinished {
    return _isFinished;
}

- (void)start {
    if (self.isCancelled) {
        [self finish];
        return;
    }
    [self setValue:[NSNumber numberWithBool:YES] forKey:kObservingExecuting];
    _request = [NSURLRequest requestWithURL:[NSURL URLWithString:_url]
                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                            timeoutInterval:TIMEOUT_INTERVAL];
    _connection = [NSURLConnection connectionWithRequest:_request delegate:self];
    if (_connection != nil) {
        do {
            if (self.isCancelled) {
                [_connection cancel];
                [self finish];
            }
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        } while (_isExecuting);
    }
}

#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    _response = (NSHTTPURLResponse *)response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self finish];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self finish];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge proposedCredential]) {
        [connection cancel];
    } else {
        NSURLCredential *credential = [NSURLCredential credentialWithUser:_username
                                                                 password:_password
                                                              persistence:NSURLCredentialPersistenceNone];
        [[challenge sender] useCredential:credential
               forAuthenticationChallenge:challenge];
    }
}

#pragma mark Private

- (void)finish {
    [self setValue:[NSNumber numberWithBool:NO] forKey:kObservingExecuting];
    [self setValue:[NSNumber numberWithBool:YES] forKey:kObservingFinish];
}

@end


#pragma mark - CIImageManager


@implementation CIImageManager {
    NSOperationQueue *_queue;
    NSMutableDictionary *_images;
    
    NSManagedObjectModel *_managedObjectModel;
    NSPersistentStoreCoordinator *_persistentStoreCoordinator;
}

static CIImageManager *_instance = nil; //singleton

+ (CIImageManager *)sharedManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[CIImageManager alloc] init];
    });
    return _instance;
}

- (id)init {
    if ((self = [super init])) {
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = CONNECTION_MAX_COUNT;
        _images = [[NSMutableDictionary alloc] init];
    }
	return self;
}

#pragma mark Getter

- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:kModelNameCachedImage withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            (void)[self persistentStoreCoordinator];
        });
        return _persistentStoreCoordinator;
    }
    
    NSURL *directoryURL = [[[NSFileManager defaultManager]
                            URLsForDirectory:NSDocumentDirectory
                            inDomains:NSUserDomainMask]
                           lastObject];
    NSURL *storeURL = [directoryURL URLByAppendingPathComponent:kSqliteNameCachedImage];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}


#pragma mark Public

- (UIImage *)imageOfURL:(NSString *)url {
    return [self imageOfURL:url username:nil password:nil];
}

- (UIImage *)imageOfURL:(NSString *)url username:(NSString *)username password:(NSString *)password {
    if (!url) {
        return nil;
    }
    
    if ([[_images allKeys] containsObject:url]) {
        LOG(@"load from memory : url=%@", url);
        return _images[url] == [NSNull null] ? nil : _images[url];
    }
    
    __block __weak CIImageManager *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CICachedImage *cachedImage = [weakSelf fetchImageOfURL:url];
        if (cachedImage) {
            LOG(@"load from coredata : url=%@", url);
            UIImage *image = [UIImage imageWithData:cachedImage.data];
            [weakSelf postNotificationForUpdateImage:image url:url];
        } else {
            LOG(@"load from network : url=%@", url);
            [_images setObject:[NSNull null] forKey:url];
            [weakSelf requestWithUrl:url username:nil password:nil];
        }
    });
    return nil;
}

- (void)cancelAllOperation {
    [_queue cancelAllOperations];
    [self cleanUncompleteImage];
}

- (void)clearImages {
    [_images removeAllObjects];
}

- (void)truncateStore {
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            (void)[self truncateStore];
        });
    }
    
    NSManagedObjectContext *managedObjectContext = [self createManagedObjectContext];
    [managedObjectContext lock];
    [managedObjectContext reset];
    
    NSURL *directoryURL = [[[NSFileManager defaultManager]
                            URLsForDirectory:NSDocumentDirectory
                            inDomains:NSUserDomainMask]
                           lastObject];
    NSURL *storeURL = [directoryURL URLByAppendingPathComponent:kSqliteNameCachedImage];
    NSPersistentStore *persistentStore = [self.persistentStoreCoordinator persistentStoreForURL:storeURL];
    NSError *error = nil;
    if (![_persistentStoreCoordinator removePersistentStore:persistentStore error:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    _persistentStoreCoordinator = nil;
    error = nil;
    if (![[NSFileManager defaultManager] removeItemAtURL:storeURL error:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    
    [self persistentStoreCoordinator];
    [managedObjectContext unlock];
}

#pragma mark Private

- (CICachedImage *)fetchImageOfURL:(NSString *)url {
    
    NSManagedObjectContext *managedObjectContext = [self createManagedObjectContext];
    NSFetchRequest *fetchRequest = [self createFetchRequest:managedObjectContext url:url];
    NSArray *results = [managedObjectContext executeFetchRequest:fetchRequest error:nil];
    return results.count ? results[0] : nil;
}

- (void)createImageOfURL:(NSString *)url data:(NSData *)data {
    
    NSManagedObjectContext *managedObjectContext = [self createManagedObjectContext];
    NSFetchRequest *fetchRequest = [self createFetchRequest:managedObjectContext url:url];
    NSArray *results = [managedObjectContext executeFetchRequest:fetchRequest error:nil];
    
    CICachedImage *image = nil;
    if (results.count) {
        image = (CICachedImage *)results[0];
    } else {
        image = [NSEntityDescription insertNewObjectForEntityForName:kEntityNameCachedImage
                                              inManagedObjectContext:managedObjectContext];
    }
    image.url = url;
    image.data = data;
    
    NSError *error = nil;
    if (![managedObjectContext save:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
}

- (NSManagedObjectContext *)createManagedObjectContext {
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] init];
    managedObjectContext.persistentStoreCoordinator = [self persistentStoreCoordinator];
    return managedObjectContext;
}

- (NSFetchRequest *)createFetchRequest:(NSManagedObjectContext *)managedObjectContext url:(NSString *)url {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:kEntityNameCachedImage
                                              inManagedObjectContext:managedObjectContext];
    [fetchRequest setEntity:entity];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"url=%@", url];
    [fetchRequest setPredicate:predicate];
    return fetchRequest;
}

- (void)requestWithUrl:(NSString *)url username:(NSString *)username password:(NSString *)password {
    CIImageRequestOperation *operation = [[CIImageRequestOperation alloc]
                                          initWithURLString:url
                                          username:username
                                          password:password];
    
    __block __weak CIImageRequestOperation *weakOperation = operation;
    __block __weak CIImageManager *weakSelf = self;
    operation.completionBlock = ^{
        
        UIImage *image = nil;
        if (!weakOperation.isCancelled) {
            image = [UIImage imageWithData:weakOperation.data];
            if (image) {
                [weakSelf createImageOfURL:weakOperation.url data:weakOperation.data];
            } else {
                image = [[UIImage alloc] init];
            }
        }
        [weakSelf postNotificationForUpdateImage:image url:weakOperation.url];
    };
    [_queue addOperation:operation];
}

- (void)cleanUncompleteImage {
    for (NSString *key in [_images allKeys]) {
        UIImage *image = [_images objectForKey:key];
        if ((NSNull *)image == [NSNull null] || !image.CGImage) {
            [_images removeObjectForKey:key];
        }
    }
}

- (void)postNotificationForUpdateImage:(UIImage *)image url:(NSString *)url {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:url forKey:kUserInfoUrl];
    if (image) {
        [_images setObject:image forKey:url];
        [userInfo setObject:image forKey:kUserInfoImage];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationUpdateImage
                                                        object:self
                                                      userInfo:userInfo];
}

@end


#pragma mark - CICachedImageView


@implementation CICachedImageView {
    UIActivityIndicatorView *_indicator;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        [self initialize];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void)initialize {
    _indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [_indicator startAnimating];
    _indicator.center = (CGPoint){CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds)};
    [self addSubview:_indicator];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(observingUpdateImage:)
                                                 name:kNotificationUpdateImage
                                               object:nil];
}


#pragma mark Setter

- (void)setUrl:(NSString *)url {
    [self setUrl:url username:nil password:nil];
}

- (void)setUrl:(NSString *)url username:(NSString *)username password:(NSString *)password {
    _url = url;
    _username = username;
    _password = password;

    [self showIndicator];
    
    UIImage *image = [[CIImageManager sharedManager] imageOfURL:url username:username password:password];
    [self updateImage:image];
}

#pragma mark Notification

- (void)observingUpdateImage:(NSNotification *)notification {
    NSString *userInfoUrl = notification.userInfo[kUserInfoUrl];
    UIImage *userInfoImage = notification.userInfo[kUserInfoImage];
    if ([_url isEqualToString:userInfoUrl]) {
        
        __block __weak CICachedImageView *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf updateImage:userInfoImage];
            [weakSelf hideIndicator];
        });
    }
}

#pragma mark Private

- (void)updateImage:(UIImage *)image {
    if (image) {
        [self hideIndicator];
        if (image.CGImage) {
            self.image = image;
        } else {
            self.image = self.errorImage;
        }
    } else {
        self.image = self.defaultImage;
    }
}

- (void)showIndicator {
    _indicator.hidden = NO;
    [_indicator startAnimating];
}

- (void)hideIndicator {
    [_indicator stopAnimating];
    _indicator.hidden = YES;
}

@end








