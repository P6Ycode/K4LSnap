#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *K4LMaintenanceRootDirectory(void);
FOUNDATION_EXPORT NSString *K4LMaintenanceStatusPath(void);

@interface K4LMaintenance : NSObject
+ (NSDictionary *)healthReport:(NSError **)error;
+ (NSDictionary *)pruneFilesOlderThan:(NSTimeInterval)age error:(NSError **)error;
+ (NSDictionary *)repairThumbnails:(NSError **)error;
+ (BOOL)vacuumDatabase:(NSError **)error;
+ (BOOL)writeStatus:(NSDictionary *)status error:(NSError **)error;
+ (void)postNotification:(NSString *)name;
@end

NS_ASSUME_NONNULL_END
