#import "K4LSystem.h"
#import <CoreFoundation/CoreFoundation.h>

NSString * const K4LPreferenceDomain = @"com.p6ycode.k4lsnap";
NSString * const K4LNotifyReload = @"com.p6ycode.k4lsnap/reload";
NSString * const K4LNotifyVaultChanged = @"com.p6ycode.k4lsnap/vault-changed";
NSString * const K4LNotifyDaemonPing = @"com.p6ycode.k4lsnap/daemon-ping";
NSString * const K4LNotifyDaemonPong = @"com.p6ycode.k4lsnap/daemon-pong";

NSString *K4LRootDirectory(void) {
    return [@"/var/mobile/Library/Application Support" stringByAppendingPathComponent:@"K4LSnap"];
}

NSString *K4LMediaDirectory(void) { return [K4LRootDirectory() stringByAppendingPathComponent:@"Media"]; }
NSString *K4LThumbnailDirectory(void) { return [K4LRootDirectory() stringByAppendingPathComponent:@"Thumbnails"]; }
NSString *K4LTemporaryDirectory(void) { return [K4LRootDirectory() stringByAppendingPathComponent:@"Temp"]; }
NSString *K4LDraftDirectory(void) { return [K4LRootDirectory() stringByAppendingPathComponent:@"Drafts"]; }
NSString *K4LDatabasePath(void) { return [K4LRootDirectory() stringByAppendingPathComponent:@"vault.sqlite3"]; }
NSString *K4LPendingSendPath(void) { return [K4LRootDirectory() stringByAppendingPathComponent:@"pending-send.plist"]; }
NSString *K4LPreferencesPath(void) {
    return [@"/var/mobile/Library/Preferences" stringByAppendingPathComponent:[K4LPreferenceDomain stringByAppendingString:@".plist"]];
}

BOOL K4LEnsureSystemDirectories(NSError **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSDictionary *attrs = @{NSFilePosixPermissions: @0755};
    NSArray<NSString *> *paths = @[
        K4LRootDirectory(),
        K4LMediaDirectory(),
        K4LThumbnailDirectory(),
        K4LTemporaryDirectory(),
        K4LDraftDirectory()
    ];
    for (NSString *path in paths) {
        if (![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:attrs error:error]) return NO;
    }
    return YES;
}

void K4LPostDarwinNotification(NSString *name) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)name, NULL, NULL, true);
}
