#import "K4LFeaturePolicy.h"
#import "K4LPreferences.h"

@implementation K4LFeaturePolicy
+ (instancetype)sharedPolicy { static id value; static dispatch_once_t once; dispatch_once(&once, ^{ value = [self new]; }); return value; }
- (BOOL)flag:(NSString *)key fallback:(BOOL)fallback { return [[K4LPreferences shared] boolForKey:key defaultValue:fallback]; }
- (BOOL)galleryUploadEnabled { return [self flag:@"galleryUploadEnabled" fallback:YES]; }
- (BOOL)launcherEnabled { return [self flag:@"launcherEnabled" fallback:YES]; }
@end
