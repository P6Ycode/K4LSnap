#import <Foundation/Foundation.h>
#import <stdlib.h>
#import <unistd.h>
#import "K4LMaintenance.h"
#import "K4LSystemProtocol.h"

static void K4LPrintObject(id object) { NSData *data=[NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted error:nil]; if(data)fprintf(stdout,"%s\n",[[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]UTF8String]); }
static NSDictionary *K4LSubmit(NSString *command, NSDictionary *payload, NSError **error) {
    NSString *identifier=[K4LSystemProtocol enqueueCommand:command payload:payload error:error]; if(!identifier)return nil;
    for(NSUInteger attempt=0;attempt<50;attempt++){ NSDictionary *result=[K4LSystemProtocol resultForIdentifier:identifier error:nil]; if(result)return result; usleep(100000); }
    if(error)*error=[NSError errorWithDomain:@"com.p6ycode.k4lsnap.ctl" code:4 userInfo:@{NSLocalizedDescriptionKey:@"Daemon command timed out"}]; return nil;
}
static void K4LUsage(void) { fprintf(stderr,
"Usage: k4lsnapctl <command>\n"
"  health | status | ping | reload | restart-app\n"
"  prune [hours] | repair-thumbnails | vacuum\n"
"  container [bundle-id]\n"
"  backup-create | backup-list | backup-restore <name>\n"
"  account-masks | account-mask-set <account-id> <mask>\n"
"  command-result <id>\n"); }

int main(int argc,char *argv[]){ @autoreleasepool {
    if(argc<2){K4LUsage();return 64;} NSString *command=@(argv[1]); NSError *error=nil; id output=nil;
    if([command isEqualToString:@"health"]) output=K4LSubmit(@"health",@{},&error);
    else if([command isEqualToString:@"prune"]){ double hours=argc>=3?MAX(0,atof(argv[2])):24; output=K4LSubmit(@"prune",@{ @"ageSeconds":@(hours*3600) },&error); }
    else if([command isEqualToString:@"repair-thumbnails"]) output=K4LSubmit(@"repair-thumbnails",@{},&error);
    else if([command isEqualToString:@"vacuum"]) output=K4LSubmit(@"vacuum",@{},&error);
    else if([command isEqualToString:@"container"]) output=K4LSubmit(@"discover-container",@{ @"bundleIdentifier":argc>=3?@(argv[2]):@"com.toyopagroup.picaboo" },&error);
    else if([command isEqualToString:@"backup-create"]) output=K4LSubmit(@"backup-create",@{},&error);
    else if([command isEqualToString:@"backup-list"]) output=K4LSubmit(@"backup-list",@{},&error);
    else if([command isEqualToString:@"backup-restore"]&&argc>=3) output=K4LSubmit(@"backup-restore",@{ @"name":@(argv[2]) },&error);
    else if([command isEqualToString:@"account-masks"]) output=K4LSubmit(@"account-mask-snapshot",@{},&error);
    else if([command isEqualToString:@"account-mask-set"]&&argc>=4) output=K4LSubmit(@"account-mask-set",@{ @"accountID":@(argv[2]), @"mask":@((NSUInteger)strtoull(argv[3],NULL,0)) },&error);
    else if([command isEqualToString:@"command-result"]&&argc>=3) output=[K4LSystemProtocol resultForIdentifier:@(argv[2]) error:&error];
    else if([command isEqualToString:@"reload"]){ [K4LMaintenance postNotification:@"com.p6ycode.k4lsnap/reload"]; [K4LMaintenance postNotification:@"com.p6ycode.k4lsnap/vault-changed"]; fprintf(stdout,"Reload notifications posted.\n"); }
    else if([command isEqualToString:@"ping"]){ [K4LMaintenance postNotification:@"com.p6ycode.k4lsnap/daemon-ping"]; fprintf(stdout,"Daemon ping posted.\n"); }
    else if([command isEqualToString:@"status"]){ output=[NSDictionary dictionaryWithContentsOfFile:K4LMaintenanceStatusPath()]; if(!output)error=[NSError errorWithDomain:@"com.p6ycode.k4lsnap.ctl" code:2 userInfo:@{NSLocalizedDescriptionKey:@"No daemon status file exists yet"}]; }
    else if([command isEqualToString:@"restart-app"]){ int result=system("/usr/bin/killall Snapchat >/dev/null 2>&1"); if(result==0)fprintf(stdout,"Snapchat terminated.\n"); else error=[NSError errorWithDomain:@"com.p6ycode.k4lsnap.ctl" code:3 userInfo:@{NSLocalizedDescriptionKey:@"Unable to terminate Snapchat, or it was not running"}]; }
    else { K4LUsage(); return 64; }
    if(output)K4LPrintObject(output); if(error){fprintf(stderr,"k4lsnapctl: %s\n",error.localizedDescription.UTF8String);return 1;} return 0;
} }
