#import <UIKit/UIKit.h>


@interface CIImageManager : NSObject
+ (CIImageManager *)sharedManager;
- (UIImage *)imageOfURL:(NSString *)url;
- (UIImage *)imageOfURL:(NSString *)url username:(NSString *)username password:(NSString *)password;
- (void)cancelAllOperation;
- (void)clearImages;
- (void)truncateStore;
@end


@interface CICachedImageView : UIImageView
@property (nonatomic) UIImage *defaultImage;
@property (nonatomic) UIImage *errorImage;
@property (nonatomic) NSString *url;
@property (nonatomic) NSString *username;
@property (nonatomic) NSString *password;
- (void)setUrl:(NSString *)url username:(NSString *)username password:(NSString *)password;
@end

