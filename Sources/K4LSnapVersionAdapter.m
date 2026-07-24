#import "K4LSnapVersionAdapter.h"
#import "K4LVaultStore.h"
#import "K4LSystem.h"

@implementation K4LSnapVersionAdapter
+ (instancetype)sharedAdapter { static id value; static dispatch_once_t once; dispatch_once(&once, ^{ value = [self new]; }); return value; }
- (NSString *)snapchatVersion { return [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown"; }
- (BOOL)isSupportedVersion {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    return [bundleID isEqualToString:@"com.toyopagroup.picaboo"] && ![self.snapchatVersion isEqualToString:@"unknown"];
}
- (void)installPrivateHooks {
    if (![self isSupportedVersion]) { NSLog(@"[K4LSnap] unsupported target %@ %@", NSBundle.mainBundle.bundleIdentifier, self.snapchatVersion); return; }
    NSLog(@"[K4LSnap] compatibility adapter active for Snapchat %@", self.snapchatVersion);
}
- (BOOL)sendImportedMediaAtURL:(NSURL *)url caption:(NSString *)caption wholeStory:(BOOL)wholeStory error:(NSError **)error {
    if (!url.isFileURL || ![NSFileManager.defaultManager fileExistsAtPath:url.path]) {
        if (error) *error = [NSError errorWithDomain:@"com.p6ycode.k4lsnap.adapter" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Imported media file does not exist"}];
        return NO;
    }
    NSString *category = wholeStory ? @"Whole Story" : @"Gallery Upload";
    K4LVaultItem *item = [[K4LVaultStore shared] importFileAtURL:url accountID:nil friendID:nil category:category error:error];
    if (!item) return NO;
    if (caption.length) {
        NSMutableDictionary *metadata = [NSMutableDictionary dictionaryWithContentsOfFile:[K4LRootDirectory() stringByAppendingPathComponent:@"captions.plist"]] ?: [NSMutableDictionary dictionary];
        metadata[item.identifier] = caption;
        [metadata writeToFile:[K4LRootDirectory() stringByAppendingPathComponent:@"captions.plist"] atomically:YES];
    }
    return YES;
}
@end
