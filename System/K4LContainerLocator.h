#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface K4LContainerLocator : NSObject
+ (NSDictionary * _Nullable)containerRecordForBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error;
+ (BOOL)writeCachedRecord:(NSDictionary *)record error:(NSError **)error;
+ (NSDictionary * _Nullable)cachedRecord;
@end

NS_ASSUME_NONNULL_END
