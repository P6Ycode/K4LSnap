#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <signal.h>
#import <unistd.h>
#import "K4LMaintenance.h"
#import "K4LSystemProtocol.h"
#import "K4LContainerLocator.h"
#import "K4LBackupManager.h"
#import "K4LAccountCategoryStore.h"

static NSString * const K4LDaemonPing = @"com.p6ycode.k4lsnap/daemon-ping";
static NSString * const K4LDaemonPong = @"com.p6ycode.k4lsnap/daemon-pong";

static NSDictionary *K4LCommandResult(NSDictionary *envelope) {
    NSString *command = envelope[@"command"];
    NSDictionary *payload = envelope[@"payload"] ?: @{};
    NSError *error = nil;
    id value = nil;
    if ([command isEqualToString:@"health"]) value = [K4LMaintenance healthReport:&error];
    else if ([command isEqualToString:@"prune"]) value = [K4LMaintenance pruneFilesOlderThan:[payload[@"ageSeconds"] doubleValue] error:&error];
    else if ([command isEqualToString:@"repair-thumbnails"]) value = [K4LMaintenance repairThumbnails:&error];
    else if ([command isEqualToString:@"vacuum"]) value = @{ @"ok": @([K4LMaintenance vacuumDatabase:&error]) };
    else if ([command isEqualToString:@"discover-container"]) {
        NSDictionary *record = [K4LContainerLocator containerRecordForBundleIdentifier:payload[@"bundleIdentifier"] ?: @"com.toyopagroup.picaboo" error:&error];
        if (record && [K4LContainerLocator writeCachedRecord:record error:&error]) value = record;
    } else if ([command isEqualToString:@"backup-create"]) value = [K4LBackupManager createBackup:&error];
    else if ([command isEqualToString:@"backup-list"]) value = @{ @"backups": [K4LBackupManager availableBackups:&error] };
    else if ([command isEqualToString:@"backup-restore"]) value = @{ @"ok": @([K4LBackupManager restoreBackupNamed:payload[@"name"] error:&error]) };
    else if ([command isEqualToString:@"account-mask-snapshot"]) value = [[K4LAccountCategoryStore shared] snapshot];
    else if ([command isEqualToString:@"account-mask-set"]) {
        NSString *accountID = payload[@"accountID"];
        if (accountID.length) [[K4LAccountCategoryStore shared] setMask:[payload[@"mask"] unsignedIntegerValue] forAccount:accountID];
        value = @{ @"effectiveMask": @([[K4LAccountCategoryStore shared] effectiveMaskForAccount:accountID ?: @""]) };
    } else {
        error = [NSError errorWithDomain:@"com.p6ycode.k4lsnap.daemon" code:64 userInfo:@{NSLocalizedDescriptionKey:@"Unknown daemon command"}];
    }
    return error ? @{ @"ok":@NO, @"error":error.localizedDescription ?: @"Command failed" } : @{ @"ok":@YES, @"value":value ?: @{} };
}

static void K4LProcessCommands(void) {
    @autoreleasepool {
        NSError *error = nil;
        for (NSDictionary *envelope in [K4LSystemProtocol pendingCommands:&error]) {
            NSDictionary *result = K4LCommandResult(envelope);
            [K4LSystemProtocol completeCommand:envelope result:result error:nil];
            [K4LSystemProtocol appendDiagnosticEvent:@"daemon.command" details:@{ @"command":envelope[@"command"] ?: @"", @"result":result } error:nil];
        }
    }
}

static void K4LPingCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSError *error = nil;
    NSMutableDictionary *status = [[K4LMaintenance healthReport:&error] mutableCopy];
    status[@"daemonPID"] = @(getpid()); status[@"running"] = @YES;
    status[@"protocolVersion"] = K4LProtocolVersion;
    status[@"container"] = [K4LContainerLocator cachedRecord] ?: @{};
    if (error) status[@"error"] = error.localizedDescription;
    [K4LMaintenance writeStatus:status error:nil];
    [K4LMaintenance postNotification:K4LDaemonPong];
}

static void K4LCommandCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) { K4LProcessCommands(); }

static void K4LRunMaintenance(void) {
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *prune = [K4LMaintenance pruneFilesOlderThan:24.0 * 60.0 * 60.0 error:&error];
        NSDictionary *repair = error ? @{} : [K4LMaintenance repairThumbnails:&error];
        NSDictionary *container = [K4LContainerLocator containerRecordForBundleIdentifier:@"com.toyopagroup.picaboo" error:nil];
        if (container) [K4LContainerLocator writeCachedRecord:container error:nil];
        NSMutableDictionary *status = [[K4LMaintenance healthReport:nil] mutableCopy];
        status[@"daemonPID"] = @(getpid()); status[@"running"] = @YES; status[@"protocolVersion"] = K4LProtocolVersion;
        status[@"lastPrune"] = prune ?: @{}; status[@"lastThumbnailRepair"] = repair ?: @{}; status[@"container"] = container ?: @{};
        if (error) status[@"error"] = error.localizedDescription;
        [K4LMaintenance writeStatus:status error:nil];
        [K4LSystemProtocol appendDiagnosticEvent:@"daemon.maintenance" details:status error:nil];
        K4LProcessCommands();
    }
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        signal(SIGPIPE, SIG_IGN);
        [K4LSystemProtocol ensureDirectories:nil];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, K4LPingCallback, (__bridge CFStringRef)K4LDaemonPing, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, K4LCommandCallback, (__bridge CFStringRef)K4LNotifyCommandAvailable, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        K4LRunMaintenance();
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 6ull * 60ull * 60ull * NSEC_PER_SEC), 6ull * 60ull * 60ull * NSEC_PER_SEC, 5ull * 60ull * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timer, ^{ K4LRunMaintenance(); }); dispatch_resume(timer);
        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
