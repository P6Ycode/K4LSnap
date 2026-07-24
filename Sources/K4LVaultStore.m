#import "K4LVaultStore.h"
#import "K4LSystem.h"
#import <sqlite3.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation K4LVaultItem
@end

@interface K4LVaultStore ()
@property (nonatomic) sqlite3 *db;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) BOOL ready;
@end

@implementation K4LVaultStore
+ (instancetype)shared { static id value; static dispatch_once_t once; dispatch_once(&once, ^{ value = [self new]; }); return value; }
- (instancetype)init { if ((self = [super init])) _queue = dispatch_queue_create("com.p6ycode.k4lsnap.vault", DISPATCH_QUEUE_SERIAL); return self; }
- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message { return [NSError errorWithDomain:@"com.p6ycode.k4lsnap.vault" code:code userInfo:@{NSLocalizedDescriptionKey: message ?: @"Vault error"}]; }
- (void)closeDatabaseLocked { if (self.db) sqlite3_close(self.db); self.db = NULL; self.ready = NO; }
- (BOOL)open:(NSError **)error {
    __block BOOL ok = YES;
    dispatch_sync(self.queue, ^{
        if (self.ready && self.db) return;
        [self closeDatabaseLocked];
        NSError *directoryError = nil;
        if (!K4LEnsureSystemDirectories(&directoryError)) { ok = NO; if (error) *error = directoryError; return; }
        if (sqlite3_open_v2(K4LDatabasePath().fileSystemRepresentation, &_db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, NULL) != SQLITE_OK) {
            NSString *detail = self.db ? [NSString stringWithUTF8String:sqlite3_errmsg(self.db)] : @"Unable to open vault database";
            [self closeDatabaseLocked];
            ok = NO; if (error) *error = [self errorWithCode:1 message:detail]; return;
        }
        sqlite3_busy_timeout(self.db, 3000);
        const char *schema =
        "PRAGMA journal_mode=WAL;"
        "PRAGMA synchronous=NORMAL;"
        "PRAGMA foreign_keys=ON;"
        "CREATE TABLE IF NOT EXISTS schema_meta(version INTEGER NOT NULL);"
        "INSERT INTO schema_meta(version) SELECT 1 WHERE NOT EXISTS(SELECT 1 FROM schema_meta);"
        "CREATE TABLE IF NOT EXISTS media_items("
        "id TEXT PRIMARY KEY, relative_path TEXT NOT NULL UNIQUE, account_id TEXT, friend_id TEXT, category TEXT,"
        "media_type TEXT NOT NULL, created_at REAL NOT NULL, byte_size INTEGER NOT NULL DEFAULT 0);"
        "CREATE INDEX IF NOT EXISTS idx_media_scope ON media_items(account_id, friend_id, category, created_at DESC);";
        char *message = NULL;
        if (sqlite3_exec(self.db, schema, NULL, NULL, &message) != SQLITE_OK) {
            NSString *detail = message ? [NSString stringWithUTF8String:message] : @"Schema migration failed";
            sqlite3_free(message);
            [self closeDatabaseLocked];
            ok = NO; if (error) *error = [self errorWithCode:2 message:detail]; return;
        }
        self.ready = YES;
    });
    return ok;
}
- (NSString *)mediaTypeForURL:(NSURL *)url {
    UTType *type = [UTType typeWithFilenameExtension:url.pathExtension];
    if ([type conformsToType:UTTypeMovie]) return @"video";
    if ([type conformsToType:UTTypeImage]) return @"image";
    return @"file";
}
- (K4LVaultItem *)importFileAtURL:(NSURL *)sourceURL accountID:(NSString *)accountID friendID:(NSString *)friendID category:(NSString *)category error:(NSError **)error {
    if (![self open:error]) return nil;
    __block K4LVaultItem *result = nil;
    dispatch_sync(self.queue, ^{
        NSString *identifier = NSUUID.UUID.UUIDString;
        NSString *extension = sourceURL.pathExtension.length ? sourceURL.pathExtension.lowercaseString : @"bin";
        NSString *relative = [identifier stringByAppendingPathExtension:extension];
        NSString *destination = [K4LMediaDirectory() stringByAppendingPathComponent:relative];
        NSError *copyError = nil;
        if (![NSFileManager.defaultManager copyItemAtPath:sourceURL.path toPath:destination error:&copyError]) { if (error) *error = copyError; return; }
        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:destination error:nil];
        sqlite3_stmt *stmt = NULL;
        const char *sql = "INSERT INTO media_items(id,relative_path,account_id,friend_id,category,media_type,created_at,byte_size) VALUES(?,?,?,?,?,?,?,?)";
        if (sqlite3_prepare_v2(self.db, sql, -1, &stmt, NULL) != SQLITE_OK) { [NSFileManager.defaultManager removeItemAtPath:destination error:nil]; if (error) *error = [self errorWithCode:3 message:[NSString stringWithUTF8String:sqlite3_errmsg(self.db)]]; return; }
        sqlite3_bind_text(stmt,1,identifier.UTF8String,-1,SQLITE_TRANSIENT); sqlite3_bind_text(stmt,2,relative.UTF8String,-1,SQLITE_TRANSIENT);
        if (accountID) sqlite3_bind_text(stmt,3,accountID.UTF8String,-1,SQLITE_TRANSIENT); else sqlite3_bind_null(stmt,3);
        if (friendID) sqlite3_bind_text(stmt,4,friendID.UTF8String,-1,SQLITE_TRANSIENT); else sqlite3_bind_null(stmt,4);
        if (category) sqlite3_bind_text(stmt,5,category.UTF8String,-1,SQLITE_TRANSIENT); else sqlite3_bind_null(stmt,5);
        NSString *mediaType = [self mediaTypeForURL:sourceURL]; sqlite3_bind_text(stmt,6,mediaType.UTF8String,-1,SQLITE_TRANSIENT);
        NSTimeInterval created = NSDate.date.timeIntervalSince1970; sqlite3_bind_double(stmt,7,created); sqlite3_bind_int64(stmt,8,(sqlite3_int64)[attributes fileSize]);
        if (sqlite3_step(stmt) == SQLITE_DONE) { result = [K4LVaultItem new]; result.identifier=identifier; result.relativePath=relative; result.accountID=accountID; result.friendID=friendID; result.category=category; result.mediaType=mediaType; result.createdAt=created; result.byteSize=[attributes fileSize]; }
        else { [NSFileManager.defaultManager removeItemAtPath:destination error:nil]; if (error) *error = [self errorWithCode:4 message:[NSString stringWithUTF8String:sqlite3_errmsg(self.db)]]; }
        sqlite3_finalize(stmt);
    });
    if (result) K4LPostDarwinNotification(K4LNotifyVaultChanged);
    return result;
}
- (NSArray<K4LVaultItem *> *)itemsForAccount:(NSString *)accountID friendID:(NSString *)friendID category:(NSString *)category error:(NSError **)error {
    if (![self open:error]) return @[];
    __block NSMutableArray *items = [NSMutableArray array];
    dispatch_sync(self.queue, ^{
        NSMutableString *sql=[@"SELECT id,relative_path,account_id,friend_id,category,media_type,created_at,byte_size FROM media_items WHERE 1=1" mutableCopy];
        NSMutableArray *bind=[NSMutableArray array];
        for (NSArray *pair in @[@[@"account_id",accountID ?: NSNull.null],@[@"friend_id",friendID ?: NSNull.null],@[@"category",category ?: NSNull.null]]) if (pair[1] != NSNull.null) { [sql appendFormat:@" AND %@=?",pair[0]]; [bind addObject:pair[1]]; }
        [sql appendString:@" ORDER BY created_at DESC"];
        sqlite3_stmt *stmt=NULL; if (sqlite3_prepare_v2(self.db,sql.UTF8String,-1,&stmt,NULL)!=SQLITE_OK) { if(error)*error=[self errorWithCode:5 message:[NSString stringWithUTF8String:sqlite3_errmsg(self.db)]]; return; }
        for (NSInteger i=0;i<bind.count;i++) sqlite3_bind_text(stmt,(int)i+1,[bind[i] UTF8String],-1,SQLITE_TRANSIENT);
        while (sqlite3_step(stmt)==SQLITE_ROW) { K4LVaultItem *item=[K4LVaultItem new]; item.identifier=[NSString stringWithUTF8String:(const char*)sqlite3_column_text(stmt,0)]; item.relativePath=[NSString stringWithUTF8String:(const char*)sqlite3_column_text(stmt,1)]; const unsigned char *a=sqlite3_column_text(stmt,2),*f=sqlite3_column_text(stmt,3),*c=sqlite3_column_text(stmt,4); item.accountID=a?[NSString stringWithUTF8String:(const char*)a]:nil; item.friendID=f?[NSString stringWithUTF8String:(const char*)f]:nil; item.category=c?[NSString stringWithUTF8String:(const char*)c]:nil; item.mediaType=[NSString stringWithUTF8String:(const char*)sqlite3_column_text(stmt,5)]; item.createdAt=sqlite3_column_double(stmt,6); item.byteSize=(unsigned long long)sqlite3_column_int64(stmt,7); [items addObject:item]; }
        sqlite3_finalize(stmt);
    });
    return items;
}
- (BOOL)deleteItem:(K4LVaultItem *)item error:(NSError **)error { if (![self open:error]) return NO; __block BOOL ok=NO; dispatch_sync(self.queue, ^{ sqlite3_stmt *stmt=NULL; if(sqlite3_prepare_v2(self.db,"DELETE FROM media_items WHERE id=?",-1,&stmt,NULL)==SQLITE_OK){ sqlite3_bind_text(stmt,1,item.identifier.UTF8String,-1,SQLITE_TRANSIENT); ok=sqlite3_step(stmt)==SQLITE_DONE; } sqlite3_finalize(stmt); if(ok)[NSFileManager.defaultManager removeItemAtPath:[K4LMediaDirectory() stringByAppendingPathComponent:item.relativePath] error:nil]; else if(error)*error=[self errorWithCode:6 message:[NSString stringWithUTF8String:sqlite3_errmsg(self.db)]]; }); if(ok)K4LPostDarwinNotification(K4LNotifyVaultChanged); return ok; }
- (NSDictionary<NSString *,NSNumber *> *)categoryCountsForAccount:(NSString *)accountID error:(NSError **)error { if(![self open:error])return @{}; __block NSMutableDictionary *out=[NSMutableDictionary dictionary]; dispatch_sync(self.queue, ^{ const char *sql=accountID?"SELECT COALESCE(category,''),COUNT(*) FROM media_items WHERE account_id=? GROUP BY category":"SELECT COALESCE(category,''),COUNT(*) FROM media_items GROUP BY category"; sqlite3_stmt *stmt=NULL; if(sqlite3_prepare_v2(self.db,sql,-1,&stmt,NULL)!=SQLITE_OK){if(error)*error=[self errorWithCode:7 message:[NSString stringWithUTF8String:sqlite3_errmsg(self.db)]];return;} if(accountID)sqlite3_bind_text(stmt,1,accountID.UTF8String,-1,SQLITE_TRANSIENT); while(sqlite3_step(stmt)==SQLITE_ROW) out[[NSString stringWithUTF8String:(const char*)sqlite3_column_text(stmt,0)]]=@(sqlite3_column_int64(stmt,1)); sqlite3_finalize(stmt); }); return out; }
@end
