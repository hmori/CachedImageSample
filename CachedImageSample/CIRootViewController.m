#import "CIRootViewController.h"
#import "CITableViewCell.h"
#import "CICachedImageView.h"

@interface CIRootViewController ()
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation CIRootViewController {
    NSMutableArray *_urls;
    NSOperationQueue *_queue;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _urls = [NSMutableArray array];
    _queue = [[NSOperationQueue alloc] init];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


#pragma mark - UITableViewDelegate & UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _urls.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    CITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DefaultCell"];
    NSString *url = [_urls objectAtIndex:indexPath.row];
    cell.textLabel.text = url;
    cell.imageUrl = url;
    return cell;
}


#pragma mark - Action

- (IBAction)loadAction:(UIBarButtonItem *)sender {
    [self loadOfNo:0];
}

- (IBAction)cancelAction:(UIBarButtonItem *)sender {
    [[CIImageManager sharedManager] cancelAllOperation];
}

- (IBAction)clearMemoryAction:(UIBarButtonItem *)sender {
    [[CIImageManager sharedManager] clearImages];
}

- (IBAction)truncateAction:(UIBarButtonItem *)sender {
    [[CIImageManager sharedManager] truncateStore];
}

- (IBAction)clearTableAction:(UIBarButtonItem *)sender {
    [_urls removeAllObjects];
    [self.tableView reloadData];
}


#pragma mark - Private

- (void)loadOfNo:(NSUInteger)no {
    LOG(@"loadOfNo : no=%d", no);
    if (no == 10) {
        LOG(@"reloadData count=%d", _urls.count);
        [self.tableView performSelectorOnMainThread:@selector(reloadData)
                                         withObject:nil
                                      waitUntilDone:YES];
        return;
    }
    NSString *url = [NSString stringWithFormat:@"http://ajax.googleapis.com/ajax/services/search/images?q=cat&v=1.0&rsz=8&start=%d", no*8];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    __block __weak CIRootViewController *weakSelf = self;
    [NSURLConnection
     sendAsynchronousRequest:request
     queue:_queue
     completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
         if (!error && ((NSHTTPURLResponse *)response).statusCode == 200) {
             NSDictionary *dataDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
             if ((NSNull *)dataDictionary != [NSNull null]) {
                 NSDictionary *responseData = dataDictionary[@"responseData"];
                 if ((NSNull *)responseData != [NSNull null]) {
                     NSArray *results = responseData[@"results"];
                     if ((NSNull *)results != [NSNull null]) {
                         for (NSDictionary *result in results) {
                             NSString *url = result[@"url"];
                             if ((NSNull *)url != [NSNull null]) {
                                 [_urls addObject:url];
                             }
                         }
                     }
                 }
             }
         } else {
             LOG(@"error = %@", error);
         }
         [weakSelf loadOfNo:no+1];
     }];
}


@end
