#import "K4LContainerLocator.h"
#import "K4LSystemProtocol.h"
#import <CoreFoundation/CoreFoundation.h>

static NSString *K4LContainerCachePath(void) { return @"/var/mobile/Library/Application Support/K4LSnap/container-record.plist"; }

@implementation K4LContainerLocator
+ (NSDictionary *)containerRecordForBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error {
    if (!bundleIdentifier.length) return nil;
    NSString *root=@"/var/mobile/Containers/Data/Application";
    NSArray *entries=[NSFileManager.defaultManager contentsOfDirectoryAtPath:root error:error];
    for(NSString *entry in entries){
        NSString *container=[root stringByAppendingPathComponent:entry];
        NSDictionary *metadata=[NSDictionary dictionaryWithContentsOfFile:[container stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
        id raw=metadata[@"MCMMetadataIdentifier"];
        if(![raw isKindOfClass:NSString.class]){ id info=metadata[@"MCMMetadataInfo"]; if([info isKindOfClass:NSDictionary.class])raw=info[@"MCMMetadataIdentifier"]; }
        NSString *identifier=[raw isKindOfClass:NSString.class]?raw:nil;
        if(![identifier isEqualToString:bundleIdentifier])continue;
        NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:container error:nil]?:@{};
        NSDate *modified=attributes[NSFileModificationDate];
        return @{@"bundleIdentifier":bundleIdentifier,@"containerPath":container,@"containerUUID":entry,@"discoveredAt":@(NSDate.date.timeIntervalSince1970),@"modificationDate":@([modified timeIntervalSince1970])};
    }
    if(error&&!*error)*error=[NSError errorWithDomain:@"com.p6ycode.k4lsnap.container" code:1 userInfo:@{NSLocalizedDescriptionKey:@"No matching application data container was found"}];
    return nil;
}
+ (BOOL)writeCachedRecord:(NSDictionary *)record error:(NSError **)error { if(![record isKindOfClass:NSDictionary.class])return NO; NSString *directory=[K4LContainerCachePath() stringByDeletingLastPathComponent]; if(![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:error])return NO; NSDictionary *old=[self cachedRecord]; BOOL ok=[record writeToFile:K4LContainerCachePath() atomically:YES]; if(!ok&&error)*error=[NSError errorWithDomain:@"com.p6ycode.k4lsnap.container" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Unable to persist the container record"}]; if(ok&&![old[@"containerPath"] isEqual:record[@"containerPath"]])CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),(__bridge CFStringRef)K4LNotifyContainerChanged,NULL,NULL,true); return ok; }
+ (NSDictionary *)cachedRecord { return [NSDictionary dictionaryWithContentsOfFile:K4LContainerCachePath()]; }
@end
