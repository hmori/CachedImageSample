#import "TableViewCell.h"
#import "IMCachedImageView.h"

@implementation TableViewCell {
    IMCachedImageView *_cachedImageView;
}

-(id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        [self initialize];
    }
    return self;
}

- (void)initialize {
    _cachedImageView = [[IMCachedImageView alloc] initWithFrame:(CGRect){10, 10, 68, 68}];
    _cachedImageView.defaultImage = [UIImage imageNamed:@"DefaultImage"];
    _cachedImageView.errorImage = [UIImage imageNamed:@"ErrorImage"];
    [self addSubview:_cachedImageView];
    
    self.indentationWidth = 80.0f;
    self.indentationLevel = 1;
    self.textLabel.font = [UIFont systemFontOfSize:10];
    self.textLabel.numberOfLines = 4;
}

#pragma mark - Setter

- (void)setImageUrl:(NSString *)imageUrl {
    _imageUrl = imageUrl;
    [_cachedImageView setUrl:imageUrl];
}

@end
