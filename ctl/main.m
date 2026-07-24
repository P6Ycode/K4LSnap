#import <Foundation/Foundation.h>
#import <stdlib.h>
#import "K4LMaintenance.h"

static void K4LPrintObject(id object) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted error:nil];
    if (data) fprintf(stdout, "%s\n", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] UTF8String]);
}

static void K4LUsage(void) {
    fprintf(stderr,
            "Usage: k4lsnapctl <command>\n"
            "  health              Print database, media, and daemon health\n"
            "  prune [hours]       Remove uncommitted Temp/Drafts older than N hours (default 24)\n"
            "  repair-thumbnails   Regenerate missing image/video thumbnails\n"
            "  vacuum              Checkpoint WAL and vacuum the vault database\n"
            "  reload              Broadcast preference and vault reload notifications\n"
            "  ping                Ask the daemon to refresh its status\n"
            "  status              Print the daemon status plist\n"
            "  restart-app         Terminate Snapchat so it relaunches cleanly\n");
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc < 2) { K4LUsage(); return 64; }
        NSString *command = @(argv[1]);
        NSError *error = nil;

        if ([command isEqualToString:@"health"]) {
            NSDictionary *report = [K4LMaintenance healthReport:&error];
            if (!error) K4LPrintObject(report);
        } else if ([command isEqualToString:@"prune"]) {
            double hours = argc >= 3 ? MAX(0, atof(argv[2])) : 24.0;
            NSDictionary *report = [K4LMaintenance pruneFilesOlderThan:hours * 3600.0 error:&error];
            if (!error) K4LPrintObject(report);
        } else if ([command isEqualToString:@"repair-thumbnails"]) {
            NSDictionary *report = [K4LMaintenance repairThumbnails:&error];
            if (!error) K4LPrintObject(report);
        } else if ([command isEqualToString:@"vacuum"]) {
            if ([K4LMaintenance vacuumDatabase:&error]) fprintf(stdout, "Database vacuum complete.\n");
        } else if ([command isEqualToString:@"reload"]) {
            [K4LMaintenance postNotification:@"com.p6ycode.k4lsnap/reload"];
            [K4LMaintenance postNotification:@"com.p6ycode.k4lsnap/vault-changed"];
            fprintf(stdout, "Reload notifications posted.\n");
        } else if ([command isEqualToString:@"ping"]) {
            [K4LMaintenance postNotification:@"com.p6ycode.k4lsnap/daemon-ping"];
            fprintf(stdout, "Daemon ping posted.\n");
        } else if ([command isEqualToString:@"status"]) {
            NSDictionary *status = [NSDictionary dictionaryWithContentsOfFile:K4LMaintenanceStatusPath()];
            if (status) K4LPrintObject(status);
            else error = [NSError errorWithDomain:@"com.p6ycode.k4lsnap.ctl" code:2 userInfo:@{NSLocalizedDescriptionKey: @"No daemon status file exists yet"}];
        } else if ([command isEqualToString:@"restart-app"]) {
            int result = system("/usr/bin/killall Snapchat >/dev/null 2>&1");
            if (result == 0) fprintf(stdout, "Snapchat terminated.\n");
            else error = [NSError errorWithDomain:@"com.p6ycode.k4lsnap.ctl" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Unable to terminate Snapchat, or it was not running"}];
        } else {
            K4LUsage();
            return 64;
        }

        if (error) {
            fprintf(stderr, "k4lsnapctl: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        return 0;
    }
}
