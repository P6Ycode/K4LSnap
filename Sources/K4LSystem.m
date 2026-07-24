#import "K4LSystem.h"
#import <CoreFoundation/CoreFoundation.h>

NSString * const K4LPreferenceDomain = @"com.p6ycode.k4lsnap";
NSString * const K4LNotifyReload = @"com.p6ycode.k4lsnap/reload";
NSString * const K4LNotifyVaultChanged = @"com.p6ycode.k4lsnap/vault-changed";
NSString * const K4LNotifyDaemonPing = @"com.p6ycode.k4lsnap/daemon-ping";
NSString * const K4LNotifyDaemonPong = @"com.p6ycode.k4lsnap/daemon-pong";

static NSString *K4LBasePrefix(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    if ([fm fileExistsAtPath:@"/var/jb"]) return @"/var/jb";
    return @"";
}

NSString *K4LRootDirectory(void) {
    return [[K4LBasePrefix() stringByAppendingString:@"/var/mobile/Library/Application Support"] stringByAppendingPathComponent:@"K4LSnap"];
}

NSString *K4LMediaDirectory(void) { return [K4LRootDirectory() stringByAppendingPathComponent:@"Media"]; }
NSString *K4LTemporaryDirectory(void) { return [K4LRootDirectory() stringByAppendingPathComponent:@"Temp"]; }
NSString *K4LDatabasePath(void) { return [K4LRootDirectory() stringByAppendingPathComponent:@"vault.sqlite3"]; }
NSString *K4LPreferencesPath(void) {
    return [[K4LBasePrefix() stringByAppendingString:@"/var/mobile/Library/Preferences"] stringByAppendingPathComponent:[K4LPreferenceDomain stringByAppendingString:@".plist"]];
}

BOOL K4LEnsureSystemDirectories(NSError **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSDictionary *attrs = @{NSFilePosixPermissions: @0755};
    for (NSString *path in @[K4LRootDirectory(), K4LMediaDirectory(), K4LTemporaryDirectory()]) {
        if (![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:attrs error:error]) return NO;
    }
    return YES;
}

void K4LPostDarwinNotification(NSString *name) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)name, NULL, NULL, true);
}
