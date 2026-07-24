#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "K4LSystem.h"
#import "K4LPreferences.h"
#import "K4LVaultStore.h"

static void K4LReloadCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[K4LPreferences shared] reload];
    NSLog(@"[K4LSnap] preferences reloaded");
}

%ctor {
    @autoreleasepool {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        if (![bundleID isEqualToString:@"com.toyopagroup.picaboo"]) return;

        NSError *error = nil;
        if (!K4LEnsureSystemDirectories(&error)) {
            NSLog(@"[K4LSnap] directory bootstrap failed: %@", error);
            return;
        }
        if (![[K4LVaultStore shared] open:&error]) {
            NSLog(@"[K4LSnap] vault bootstrap failed: %@", error);
        }
        (void)[K4LPreferences shared];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, K4LReloadCallback, (__bridge CFStringRef)K4LNotifyReload, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        NSLog(@"[K4LSnap] system online");
    }
}
