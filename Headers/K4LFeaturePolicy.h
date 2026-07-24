#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface K4LFeaturePolicy : NSObject
+ (instancetype)sharedPolicy;
- (BOOL)galleryUploadEnabled;
- (BOOL)launcherEnabled;
@end

NS_ASSUME_NONNULL_END
