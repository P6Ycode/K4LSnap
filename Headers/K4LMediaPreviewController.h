#import <UIKit/UIKit.h>

@class K4LVaultItem;

NS_ASSUME_NONNULL_BEGIN

@interface K4LMediaPreviewController : UIViewController
- (instancetype)initWithItem:(K4LVaultItem *)item NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(NSString * _Nullable)nibNameOrNil bundle:(NSBundle * _Nullable)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
