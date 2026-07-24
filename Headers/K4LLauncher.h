#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface K4LLauncher : NSObject
+ (instancetype)shared;
- (void)install;
- (void)reloadVisibility;
@end

NS_ASSUME_NONNULL_END
