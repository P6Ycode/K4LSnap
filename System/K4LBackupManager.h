#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface K4LBackupManager : NSObject
+ (NSDictionary * _Nullable)createBackup:(NSError **)error;
+ (NSArray<NSDictionary *> *)availableBackups:(NSError **)error;
+ (BOOL)restoreBackupNamed:(NSString *)name error:(NSError **)error;
+ (BOOL)removeBackupNamed:(NSString *)name error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
