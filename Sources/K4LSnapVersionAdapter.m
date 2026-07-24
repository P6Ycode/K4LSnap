#import "K4LSnapVersionAdapter.h"

@implementation K4LSnapVersionAdapter
+ (instancetype)sharedAdapter { static id value; static dispatch_once_t once; dispatch_once(&once, ^{ value = [self new]; }); return value; }
- (NSString *)snapchatVersion { return [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown"; }
- (NSString *)bundleIdentifier { return NSBundle.mainBundle.bundleIdentifier ?: @"unknown"; }
- (BOOL)isSupportedVersion {
    return [self.bundleIdentifier isEqualToString:@"com.toyopagroup.picaboo"] && ![self.snapchatVersion isEqualToString:@"unknown"];
}
@end
