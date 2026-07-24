#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface K4LSnapVersionAdapter : NSObject
+ (instancetype)sharedAdapter;
@property (nonatomic, readonly) NSString *snapchatVersion;
@property (nonatomic, readonly) NSString *bundleIdentifier;
- (BOOL)isSupportedVersion;
@end

NS_ASSUME_NONNULL_END
