#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <signal.h>
#import <unistd.h>
#import "K4LMaintenance.h"

static NSString * const K4LDaemonPing = @"com.p6ycode.k4lsnap/daemon-ping";
static NSString * const K4LDaemonPong = @"com.p6ycode.k4lsnap/daemon-pong";

static void K4LPingCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSError *error = nil;
    NSMutableDictionary *status = [[K4LMaintenance healthReport:&error] mutableCopy];
    status[@"daemonPID"] = @(getpid());
    status[@"running"] = @YES;
    if (error) status[@"error"] = error.localizedDescription;
    [K4LMaintenance writeStatus:status error:nil];
    [K4LMaintenance postNotification:K4LDaemonPong];
}

static void K4LRunMaintenance(void) {
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *prune = [K4LMaintenance pruneFilesOlderThan:24.0 * 60.0 * 60.0 error:&error];
        NSDictionary *repair = error ? @{} : [K4LMaintenance repairThumbnails:&error];
        NSMutableDictionary *status = [[K4LMaintenance healthReport:nil] mutableCopy];
        status[@"daemonPID"] = @(getpid());
        status[@"running"] = @YES;
        status[@"lastPrune"] = prune ?: @{};
        status[@"lastThumbnailRepair"] = repair ?: @{};
        if (error) status[@"error"] = error.localizedDescription;
        [K4LMaintenance writeStatus:status error:nil];
    }
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        signal(SIGPIPE, SIG_IGN);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        K4LPingCallback,
                                        (__bridge CFStringRef)K4LDaemonPing,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        K4LRunMaintenance();
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer,
                                  dispatch_time(DISPATCH_TIME_NOW, 6ull * 60ull * 60ull * NSEC_PER_SEC),
                                  6ull * 60ull * 60ull * NSEC_PER_SEC,
                                  5ull * 60ull * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timer, ^{ K4LRunMaintenance(); });
        dispatch_resume(timer);
        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
