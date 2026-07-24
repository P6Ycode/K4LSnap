#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface K4LPreferences : NSObject
+ (instancetype)shared;
- (id _Nullable)objectForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)fallback;
- (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)fallback;
- (void)setObject:(id _Nullable)value forKey:(NSString *)key;
- (NSDictionary *)snapshot;
- (void)reload;
@end

NS_ASSUME_NONNULL_END
