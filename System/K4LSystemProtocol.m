#import "K4LSystemProtocol.h"
#import <CoreFoundation/CoreFoundation.h>

NSString * const K4LProtocolVersion = @"1";
NSString * const K4LNotifyCommandAvailable = @"com.p6ycode.k4lsnap/command-available";
NSString * const K4LNotifyCommandResult = @"com.p6ycode.k4lsnap/command-result";
NSString * const K4LNotifyStateChanged = @"com.p6ycode.k4lsnap/state-changed";
NSString * const K4LNotifyContainerChanged = @"com.p6ycode.k4lsnap/container-changed";

static NSString *K4LRoot(void) { return @"/var/mobile/Library/Application Support/K4LSnap"; }
NSString *K4LCommandsDirectory(void) { return [K4LRoot() stringByAppendingPathComponent:@"Commands"]; }
NSString *K4LResultsDirectory(void) { return [K4LRoot() stringByAppendingPathComponent:@"Results"]; }
NSString *K4LDiagnosticsDirectory(void) { return [K4LRoot() stringByAppendingPathComponent:@"Diagnostics"]; }
NSString *K4LBackupsDirectory(void) { return [K4LRoot() stringByAppendingPathComponent:@"Backups"]; }

@implementation K4LSystemProtocol

+ (void)post:(NSString *)name {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)name, NULL, NULL, true);
}

+ (BOOL)ensureDirectories:(NSError **)error {
    NSDictionary *attributes = @{NSFilePosixPermissions: @0755};
    for (NSString *path in @[K4LCommandsDirectory(), K4LResultsDirectory(), K4LDiagnosticsDirectory(), K4LBackupsDirectory()]) {
        if (![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:attributes error:error]) return NO;
    }
    return YES;
}

+ (BOOL)writeDictionary:(NSDictionary *)dictionary path:(NSString *)path error:(NSError **)error {
    NSString *temporary = [path stringByAppendingFormat:@".%@.tmp", NSUUID.UUID.UUIDString];
    if (![dictionary writeToFile:temporary atomically:YES]) {
        if (error) *error = [NSError errorWithDomain:@"com.p6ycode.k4lsnap.protocol" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Unable to serialize protocol envelope"}];
        return NO;
    }
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    if (![NSFileManager.defaultManager moveItemAtPath:temporary toPath:path error:error]) {
        [NSFileManager.defaultManager removeItemAtPath:temporary error:nil];
        return NO;
    }
    return YES;
}

+ (NSString *)enqueueCommand:(NSString *)command payload:(NSDictionary *)payload error:(NSError **)error {
    if (!command.length || ![self ensureDirectories:error]) return nil;
    NSString *identifier = NSUUID.UUID.UUIDString;
    NSDictionary *envelope = @{ @"protocolVersion": K4LProtocolVersion,
                                @"id": identifier,
                                @"command": command,
                                @"payload": payload ?: @{},
                                @"createdAt": @(NSDate.date.timeIntervalSince1970) };
    NSString *path = [K4LCommandsDirectory() stringByAppendingPathComponent:[identifier stringByAppendingPathExtension:@"plist"]];
    if (![self writeDictionary:envelope path:path error:error]) return nil;
    [self post:K4LNotifyCommandAvailable];
    return identifier;
}

+ (NSArray<NSDictionary *> *)pendingCommands:(NSError **)error {
    if (![self ensureDirectories:error]) return @[];
    NSArray *names = [NSFileManager.defaultManager contentsOfDirectoryAtPath:K4LCommandsDirectory() error:error];
    NSMutableArray *commands = [NSMutableArray array];
    for (NSString *name in [names sortedArrayUsingSelector:@selector(compare:)]) {
        if (![name.pathExtension isEqualToString:@"plist"]) continue;
        NSString *path = [K4LCommandsDirectory() stringByAppendingPathComponent:name];
        NSDictionary *value = [NSDictionary dictionaryWithContentsOfFile:path];
        if ([value isKindOfClass:NSDictionary.class] && [value[@"protocolVersion"] isEqual:K4LProtocolVersion]) {
            NSMutableDictionary *withPath = value.mutableCopy;
            withPath[@"_path"] = path;
            [commands addObject:withPath];
        }
    }
    return commands;
}

+ (BOOL)completeCommand:(NSDictionary *)envelope result:(NSDictionary *)result error:(NSError **)error {
    NSString *identifier = envelope[@"id"];
    NSString *sourcePath = envelope[@"_path"];
    if (!identifier.length || ![self ensureDirectories:error]) return NO;
    NSDictionary *reply = @{ @"protocolVersion": K4LProtocolVersion,
                             @"id": identifier,
                             @"command": envelope[@"command"] ?: @"",
                             @"completedAt": @(NSDate.date.timeIntervalSince1970),
                             @"result": result ?: @{} };
    NSString *path = [K4LResultsDirectory() stringByAppendingPathComponent:[identifier stringByAppendingPathExtension:@"plist"]];
    if (![self writeDictionary:reply path:path error:error]) return NO;
    if (sourcePath.length) [NSFileManager.defaultManager removeItemAtPath:sourcePath error:nil];
    [self post:K4LNotifyCommandResult];
    return YES;
}

+ (NSDictionary *)resultForIdentifier:(NSString *)identifier error:(NSError **)error {
    if (!identifier.length) return nil;
    NSString *path = [K4LResultsDirectory() stringByAppendingPathComponent:[identifier stringByAppendingPathExtension:@"plist"]];
    NSDictionary *result = [NSDictionary dictionaryWithContentsOfFile:path];
    if (!result && error) *error = [NSError errorWithDomain:@"com.p6ycode.k4lsnap.protocol" code:2 userInfo:@{NSLocalizedDescriptionKey:@"No result exists for that command"}];
    return result;
}

+ (BOOL)appendDiagnosticEvent:(NSString *)event details:(NSDictionary *)details error:(NSError **)error {
    if (!event.length || ![self ensureDirectories:error]) return NO;
    NSString *day = [[NSDateFormatter localizedStringFromDate:NSDate.date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle] stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    NSString *path = [K4LDiagnosticsDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"events-%@.plist", day]];
    NSMutableArray *events = [[NSArray arrayWithContentsOfFile:path] mutableCopy] ?: [NSMutableArray array];
    [events addObject:@{ @"event": event, @"timestamp": @(NSDate.date.timeIntervalSince1970), @"details": details ?: @{} }];
    if (events.count > 500) [events removeObjectsInRange:NSMakeRange(0, events.count - 500)];
    return [self writeDictionary:@{ @"events": events } path:path error:error];
}

@end
