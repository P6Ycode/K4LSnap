#import "K4LBackupManager.h"
#import "K4LSystemProtocol.h"
#import <sqlite3.h>

static NSString *K4LRoot(void) { return @"/var/mobile/Library/Application Support/K4LSnap"; }
static NSString *K4LDatabase(void) { return [K4LRoot() stringByAppendingPathComponent:@"vault.sqlite3"]; }
static NSArray<NSString *> *K4LStateFiles(void) { return @[@"pending-send.plist", @"account-category-masks.plist", @"container-record.plist"]; }

@implementation K4LBackupManager

+ (NSString *)safeName:(NSString *)name { return [name lastPathComponent]; }

+ (BOOL)copyDatabaseFrom:(NSString *)source to:(NSString *)destination error:(NSError **)error {
    sqlite3 *sourceDB = NULL, *destinationDB = NULL;
    if (sqlite3_open_v2(source.fileSystemRepresentation, &sourceDB, SQLITE_OPEN_READONLY, NULL) != SQLITE_OK) goto fail;
    [NSFileManager.defaultManager removeItemAtPath:destination error:nil];
    if (sqlite3_open_v2(destination.fileSystemRepresentation, &destinationDB, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL) != SQLITE_OK) goto fail;
    sqlite3_backup *backup = sqlite3_backup_init(destinationDB, "main", sourceDB, "main");
    if (!backup) goto fail;
    int rc = sqlite3_backup_step(backup, -1);
    sqlite3_backup_finish(backup);
    sqlite3_close(sourceDB); sqlite3_close(destinationDB);
    if (rc == SQLITE_DONE) return YES;
fail:
    if (error) {
        const char *message = destinationDB ? sqlite3_errmsg(destinationDB) : (sourceDB ? sqlite3_errmsg(sourceDB) : "Unable to open backup database");
        *error = [NSError errorWithDomain:@"com.p6ycode.k4lsnap.backup" code:1 userInfo:@{NSLocalizedDescriptionKey:@(message)}];
    }
    if (sourceDB) sqlite3_close(sourceDB);
    if (destinationDB) sqlite3_close(destinationDB);
    return NO;
}

+ (NSDictionary *)createBackup:(NSError **)error {
    if (![K4LSystemProtocol ensureDirectories:error]) return nil;
    NSDateFormatter *formatter = [NSDateFormatter new]; formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; formatter.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *name = [formatter stringFromDate:NSDate.date];
    NSString *directory = [K4LBackupsDirectory() stringByAppendingPathComponent:name];
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:error]) return nil;
    if ([NSFileManager.defaultManager fileExistsAtPath:K4LDatabase()] && ![self copyDatabaseFrom:K4LDatabase() to:[directory stringByAppendingPathComponent:@"vault.sqlite3"] error:error]) return nil;
    for (NSString *file in K4LStateFiles()) {
        NSString *source = [K4LRoot() stringByAppendingPathComponent:file];
        if ([NSFileManager.defaultManager fileExistsAtPath:source]) [NSFileManager.defaultManager copyItemAtPath:source toPath:[directory stringByAppendingPathComponent:file] error:nil];
    }
    NSString *preferences = @"/var/mobile/Library/Preferences/com.p6ycode.k4lsnap.plist";
    if ([NSFileManager.defaultManager fileExistsAtPath:preferences]) [NSFileManager.defaultManager copyItemAtPath:preferences toPath:[directory stringByAppendingPathComponent:@"preferences.plist"] error:nil];
    NSDictionary *manifest = @{ @"name":name, @"createdAt":@(NSDate.date.timeIntervalSince1970), @"protocolVersion":K4LProtocolVersion, @"schemaExpected":@2 };
    [manifest writeToFile:[directory stringByAppendingPathComponent:@"manifest.plist"] atomically:YES];
    [K4LSystemProtocol appendDiagnosticEvent:@"backup.created" details:manifest error:nil];
    return manifest;
}

+ (NSArray<NSDictionary *> *)availableBackups:(NSError **)error {
    if (![K4LSystemProtocol ensureDirectories:error]) return @[];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:K4LBackupsDirectory() error:error]) {
        NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfFile:[[K4LBackupsDirectory() stringByAppendingPathComponent:name] stringByAppendingPathComponent:@"manifest.plist"]];
        if (manifest) [out addObject:manifest];
    }
    return [out sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [b[@"createdAt"] compare:a[@"createdAt"]]; }];
}

+ (BOOL)restoreBackupNamed:(NSString *)name error:(NSError **)error {
    name = [self safeName:name]; if (!name.length) return NO;
    NSString *directory = [K4LBackupsDirectory() stringByAppendingPathComponent:name];
    if (![NSFileManager.defaultManager fileExistsAtPath:directory]) { if(error)*error=[NSError errorWithDomain:@"com.p6ycode.k4lsnap.backup" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Backup not found"}]; return NO; }
    NSString *database = [directory stringByAppendingPathComponent:@"vault.sqlite3"];
    if ([NSFileManager.defaultManager fileExistsAtPath:database] && ![self copyDatabaseFrom:database to:K4LDatabase() error:error]) return NO;
    for (NSString *file in K4LStateFiles()) {
        NSString *source=[directory stringByAppendingPathComponent:file], *destination=[K4LRoot() stringByAppendingPathComponent:file];
        if ([NSFileManager.defaultManager fileExistsAtPath:source]) { [NSFileManager.defaultManager removeItemAtPath:destination error:nil]; if(![NSFileManager.defaultManager copyItemAtPath:source toPath:destination error:error])return NO; }
    }
    NSString *preferences=[directory stringByAppendingPathComponent:@"preferences.plist"];
    if ([NSFileManager.defaultManager fileExistsAtPath:preferences]) { NSString *destination=@"/var/mobile/Library/Preferences/com.p6ycode.k4lsnap.plist"; [NSFileManager.defaultManager removeItemAtPath:destination error:nil]; if(![NSFileManager.defaultManager copyItemAtPath:preferences toPath:destination error:error])return NO; }
    [K4LSystemProtocol appendDiagnosticEvent:@"backup.restored" details:@{ @"name":name } error:nil];
    return YES;
}

+ (BOOL)removeBackupNamed:(NSString *)name error:(NSError **)error { name=[self safeName:name]; if(!name.length)return NO; return [NSFileManager.defaultManager removeItemAtPath:[K4LBackupsDirectory() stringByAppendingPathComponent:name] error:error]; }
@end
