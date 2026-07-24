#import "K4LVaultStore.h"
#import "K4LSystem.h"
#import <sqlite3.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation K4LVaultItem
@end

@interface K4LVaultStore ()
@property (nonatomic) sqlite3 *db;
@property (nonatomic) dispatch_queue_t queue;
@end

@implementation K4LVaultStore

+ (instancetype)shared {
    static id value;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ value = [self new]; });
    return value;
}

- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("com.p6ycode.k4lsnap.vault", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [NSError errorWithDomain:@"com.p6ycode.k4lsnap.vault"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Vault error"}];
}

- (BOOL)executeSQL:(const char *)sql error:(NSError **)error {
    char *message = NULL;
    if (sqlite3_exec(self.db, sql, NULL, NULL, &message) == SQLITE_OK) return YES;
    NSString *detail = message ? @(message) : @(sqlite3_errmsg(self.db));
    sqlite3_free(message);
    if (error) *error = [self errorWithCode:2 message:detail];
    return NO;
}

- (BOOL)columnExists:(NSString *)column {
    sqlite3_stmt *stmt = NULL;
    BOOL found = NO;
    if (sqlite3_prepare_v2(self.db, "PRAGMA table_info(media_items)", -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            const unsigned char *name = sqlite3_column_text(stmt, 1);
            if (name && [column isEqualToString:@((const char *)name)]) {
                found = YES;
                break;
            }
        }
    }
    sqlite3_finalize(stmt);
    return found;
}

- (BOOL)migrateSchema:(NSError **)error {
    const char *baseSchema =
        "PRAGMA journal_mode=WAL;"
        "PRAGMA foreign_keys=ON;"
        "CREATE TABLE IF NOT EXISTS schema_meta(version INTEGER NOT NULL);"
        "INSERT INTO schema_meta(version) SELECT 1 WHERE NOT EXISTS(SELECT 1 FROM schema_meta);"
        "CREATE TABLE IF NOT EXISTS media_items("
        "id TEXT PRIMARY KEY, relative_path TEXT NOT NULL UNIQUE, account_id TEXT, friend_id TEXT, category TEXT,"
        "media_type TEXT NOT NULL, created_at REAL NOT NULL, byte_size INTEGER NOT NULL DEFAULT 0,"
        "caption TEXT, thumbnail_path TEXT, duration REAL NOT NULL DEFAULT 0);"
        "CREATE INDEX IF NOT EXISTS idx_media_scope ON media_items(account_id, friend_id, category, created_at DESC);";
    if (![self executeSQL:baseSchema error:error]) return NO;

    if (![self executeSQL:"BEGIN IMMEDIATE" error:error]) return NO;
    NSArray<NSArray<NSString *> *> *columns = @[
        @[@"caption", @"ALTER TABLE media_items ADD COLUMN caption TEXT"],
        @[@"thumbnail_path", @"ALTER TABLE media_items ADD COLUMN thumbnail_path TEXT"],
        @[@"duration", @"ALTER TABLE media_items ADD COLUMN duration REAL NOT NULL DEFAULT 0"]
    ];
    for (NSArray<NSString *> *entry in columns) {
        if (![self columnExists:entry[0]] && ![self executeSQL:entry[1].UTF8String error:error]) {
            [self executeSQL:"ROLLBACK" error:nil];
            return NO;
        }
    }
    if (![self executeSQL:"DELETE FROM schema_meta; INSERT INTO schema_meta(version) VALUES(2); COMMIT" error:error]) {
        [self executeSQL:"ROLLBACK" error:nil];
        return NO;
    }
    return YES;
}

- (BOOL)open:(NSError **)error {
    __block BOOL ok = YES;
    __block NSError *blockError = nil;
    dispatch_sync(self.queue, ^{
        if (self.db) return;
        NSError *directoryError = nil;
        if (!K4LEnsureSystemDirectories(&directoryError)) {
            ok = NO;
            blockError = directoryError;
            return;
        }
        if (sqlite3_open_v2(K4LDatabasePath().fileSystemRepresentation,
                            &_db,
                            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
                            NULL) != SQLITE_OK) {
            ok = NO;
            blockError = [self errorWithCode:1 message:@(sqlite3_errmsg(self.db))];
            if (self.db) sqlite3_close(self.db);
            self.db = NULL;
            return;
        }
        sqlite3_busy_timeout(self.db, 3000);
        if (![self migrateSchema:&blockError]) {
            ok = NO;
            sqlite3_close(self.db);
            self.db = NULL;
        }
    });
    if (!ok && error) *error = blockError;
    return ok;
}

- (NSString *)mediaTypeForURL:(NSURL *)url {
    UTType *type = [UTType typeWithFilenameExtension:url.pathExtension];
    if ([type conformsToType:UTTypeMovie]) return @"video";
    if ([type conformsToType:UTTypeImage]) return @"image";
    return @"file";
}

static void K4LBindNullableText(sqlite3_stmt *stmt, int index, NSString *value) {
    if (value.length) sqlite3_bind_text(stmt, index, value.UTF8String, -1, SQLITE_TRANSIENT);
    else sqlite3_bind_null(stmt, index);
}

static NSString *K4LColumnText(sqlite3_stmt *stmt, int index) {
    const unsigned char *text = sqlite3_column_text(stmt, index);
    return text ? @((const char *)text) : nil;
}

- (K4LVaultItem *)importFileAtURL:(NSURL *)sourceURL
                         accountID:(NSString *)accountID
                          friendID:(NSString *)friendID
                          category:(NSString *)category
                             error:(NSError **)error {
    return [self importPreparedFileAtURL:sourceURL
                            thumbnailURL:nil
                               accountID:accountID
                                friendID:friendID
                                category:category
                                 caption:nil
                                duration:0
                                   error:error];
}

- (K4LVaultItem *)importPreparedFileAtURL:(NSURL *)sourceURL
                              thumbnailURL:(NSURL *)thumbnailURL
                                 accountID:(NSString *)accountID
                                  friendID:(NSString *)friendID
                                  category:(NSString *)category
                                   caption:(NSString *)caption
                                  duration:(NSTimeInterval)duration
                                     error:(NSError **)error {
    if (![self open:error]) return nil;
    if (!sourceURL.isFileURL || ![NSFileManager.defaultManager fileExistsAtPath:sourceURL.path]) {
        if (error) *error = [self errorWithCode:3 message:@"Prepared media file does not exist"];
        return nil;
    }

    __block K4LVaultItem *result = nil;
    __block NSError *blockError = nil;
    dispatch_sync(self.queue, ^{
        NSString *identifier = NSUUID.UUID.UUIDString;
        NSString *extension = sourceURL.pathExtension.length ? sourceURL.pathExtension.lowercaseString : @"bin";
        NSString *relativePath = [identifier stringByAppendingPathExtension:extension];
        NSString *destination = [K4LMediaDirectory() stringByAppendingPathComponent:relativePath];
        NSString *thumbnailRelativePath = nil;
        NSString *thumbnailDestination = nil;
        NSError *copyError = nil;

        [NSFileManager.defaultManager removeItemAtPath:destination error:nil];
        if (![NSFileManager.defaultManager copyItemAtPath:sourceURL.path toPath:destination error:&copyError]) {
            blockError = copyError;
            return;
        }

        if (thumbnailURL.isFileURL && [NSFileManager.defaultManager fileExistsAtPath:thumbnailURL.path]) {
            NSString *thumbnailExtension = thumbnailURL.pathExtension.length ? thumbnailURL.pathExtension.lowercaseString : @"jpg";
            thumbnailRelativePath = [identifier stringByAppendingPathExtension:thumbnailExtension];
            thumbnailDestination = [K4LThumbnailDirectory() stringByAppendingPathComponent:thumbnailRelativePath];
            [NSFileManager.defaultManager removeItemAtPath:thumbnailDestination error:nil];
            if (![NSFileManager.defaultManager copyItemAtPath:thumbnailURL.path toPath:thumbnailDestination error:&copyError]) {
                [NSFileManager.defaultManager removeItemAtPath:destination error:nil];
                blockError = copyError;
                return;
            }
        }

        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:destination error:nil];
        const char *sql =
            "INSERT INTO media_items(id,relative_path,account_id,friend_id,category,media_type,created_at,byte_size,caption,thumbnail_path,duration) "
            "VALUES(?,?,?,?,?,?,?,?,?,?,?)";
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(self.db, sql, -1, &stmt, NULL) != SQLITE_OK) {
            [NSFileManager.defaultManager removeItemAtPath:destination error:nil];
            if (thumbnailDestination) [NSFileManager.defaultManager removeItemAtPath:thumbnailDestination error:nil];
            blockError = [self errorWithCode:4 message:@(sqlite3_errmsg(self.db))];
            return;
        }

        NSString *mediaType = [self mediaTypeForURL:sourceURL];
        NSTimeInterval createdAt = NSDate.date.timeIntervalSince1970;
        sqlite3_bind_text(stmt, 1, identifier.UTF8String, -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 2, relativePath.UTF8String, -1, SQLITE_TRANSIENT);
        K4LBindNullableText(stmt, 3, accountID);
        K4LBindNullableText(stmt, 4, friendID);
        K4LBindNullableText(stmt, 5, category);
        sqlite3_bind_text(stmt, 6, mediaType.UTF8String, -1, SQLITE_TRANSIENT);
        sqlite3_bind_double(stmt, 7, createdAt);
        sqlite3_bind_int64(stmt, 8, (sqlite3_int64)attributes.fileSize);
        K4LBindNullableText(stmt, 9, caption);
        K4LBindNullableText(stmt, 10, thumbnailRelativePath);
        sqlite3_bind_double(stmt, 11, MAX(0, duration));

        if (sqlite3_step(stmt) == SQLITE_DONE) {
            result = [K4LVaultItem new];
            result.identifier = identifier;
            result.relativePath = relativePath;
            result.thumbnailRelativePath = thumbnailRelativePath;
            result.accountID = accountID;
            result.friendID = friendID;
            result.category = category;
            result.caption = caption;
            result.mediaType = mediaType;
            result.createdAt = createdAt;
            result.duration = MAX(0, duration);
            result.byteSize = attributes.fileSize;
        } else {
            [NSFileManager.defaultManager removeItemAtPath:destination error:nil];
            if (thumbnailDestination) [NSFileManager.defaultManager removeItemAtPath:thumbnailDestination error:nil];
            blockError = [self errorWithCode:5 message:@(sqlite3_errmsg(self.db))];
        }
        sqlite3_finalize(stmt);
    });

    if (!result && error) *error = blockError;
    if (result) K4LPostDarwinNotification(K4LNotifyVaultChanged);
    return result;
}

- (NSArray<K4LVaultItem *> *)itemsForAccount:(NSString *)accountID
                                     friendID:(NSString *)friendID
                                     category:(NSString *)category
                                        error:(NSError **)error {
    if (![self open:error]) return @[];
    __block NSMutableArray<K4LVaultItem *> *items = [NSMutableArray array];
    __block NSError *blockError = nil;
    dispatch_sync(self.queue, ^{
        NSMutableString *sql = [@"SELECT id,relative_path,account_id,friend_id,category,media_type,created_at,byte_size,caption,thumbnail_path,duration FROM media_items WHERE 1=1" mutableCopy];
        NSMutableArray<NSString *> *bindings = [NSMutableArray array];
        NSArray<NSArray *> *pairs = @[
            @[@"account_id", accountID ?: NSNull.null],
            @[@"friend_id", friendID ?: NSNull.null],
            @[@"category", category ?: NSNull.null]
        ];
        for (NSArray *pair in pairs) {
            if (pair[1] != NSNull.null) {
                [sql appendFormat:@" AND %@=?", pair[0]];
                [bindings addObject:pair[1]];
            }
        }
        [sql appendString:@" ORDER BY created_at DESC"];

        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(self.db, sql.UTF8String, -1, &stmt, NULL) != SQLITE_OK) {
            blockError = [self errorWithCode:6 message:@(sqlite3_errmsg(self.db))];
            return;
        }
        for (NSInteger index = 0; index < bindings.count; index++) {
            sqlite3_bind_text(stmt, (int)index + 1, bindings[index].UTF8String, -1, SQLITE_TRANSIENT);
        }
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            K4LVaultItem *item = [K4LVaultItem new];
            item.identifier = K4LColumnText(stmt, 0);
            item.relativePath = K4LColumnText(stmt, 1);
            item.accountID = K4LColumnText(stmt, 2);
            item.friendID = K4LColumnText(stmt, 3);
            item.category = K4LColumnText(stmt, 4);
            item.mediaType = K4LColumnText(stmt, 5) ?: @"file";
            item.createdAt = sqlite3_column_double(stmt, 6);
            item.byteSize = (unsigned long long)sqlite3_column_int64(stmt, 7);
            item.caption = K4LColumnText(stmt, 8);
            item.thumbnailRelativePath = K4LColumnText(stmt, 9);
            item.duration = sqlite3_column_double(stmt, 10);
            [items addObject:item];
        }
        sqlite3_finalize(stmt);
    });
    if (blockError && error) *error = blockError;
    return items;
}

- (BOOL)updateMetadataForItem:(K4LVaultItem *)item
                    accountID:(NSString *)accountID
                     friendID:(NSString *)friendID
                     category:(NSString *)category
                      caption:(NSString *)caption
                        error:(NSError **)error {
    if (![self open:error]) return NO;
    __block BOOL ok = NO;
    __block NSError *blockError = nil;
    dispatch_sync(self.queue, ^{
        sqlite3_stmt *stmt = NULL;
        const char *sql = "UPDATE media_items SET account_id=?,friend_id=?,category=?,caption=? WHERE id=?";
        if (sqlite3_prepare_v2(self.db, sql, -1, &stmt, NULL) != SQLITE_OK) {
            blockError = [self errorWithCode:7 message:@(sqlite3_errmsg(self.db))];
            return;
        }
        K4LBindNullableText(stmt, 1, accountID);
        K4LBindNullableText(stmt, 2, friendID);
        K4LBindNullableText(stmt, 3, category);
        K4LBindNullableText(stmt, 4, caption);
        sqlite3_bind_text(stmt, 5, item.identifier.UTF8String, -1, SQLITE_TRANSIENT);
        ok = sqlite3_step(stmt) == SQLITE_DONE && sqlite3_changes(self.db) == 1;
        if (!ok) blockError = [self errorWithCode:8 message:@(sqlite3_errmsg(self.db))];
        sqlite3_finalize(stmt);
    });
    if (!ok && error) *error = blockError;
    if (ok) {
        item.accountID = accountID;
        item.friendID = friendID;
        item.category = category;
        item.caption = caption;
        K4LPostDarwinNotification(K4LNotifyVaultChanged);
    }
    return ok;
}

- (BOOL)deleteItem:(K4LVaultItem *)item error:(NSError **)error {
    if (![self open:error]) return NO;
    __block BOOL ok = NO;
    __block NSError *blockError = nil;
    dispatch_sync(self.queue, ^{
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(self.db, "DELETE FROM media_items WHERE id=?", -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, item.identifier.UTF8String, -1, SQLITE_TRANSIENT);
            ok = sqlite3_step(stmt) == SQLITE_DONE && sqlite3_changes(self.db) == 1;
        }
        if (!ok) blockError = [self errorWithCode:9 message:@(sqlite3_errmsg(self.db))];
        sqlite3_finalize(stmt);
        if (ok) {
            [NSFileManager.defaultManager removeItemAtPath:[K4LMediaDirectory() stringByAppendingPathComponent:item.relativePath] error:nil];
            if (item.thumbnailRelativePath.length) {
                [NSFileManager.defaultManager removeItemAtPath:[K4LThumbnailDirectory() stringByAppendingPathComponent:item.thumbnailRelativePath] error:nil];
            }
        }
    });
    if (!ok && error) *error = blockError;
    if (ok) K4LPostDarwinNotification(K4LNotifyVaultChanged);
    return ok;
}

- (NSDictionary<NSString *, NSNumber *> *)categoryCountsForAccount:(NSString *)accountID error:(NSError **)error {
    if (![self open:error]) return @{};
    __block NSMutableDictionary<NSString *, NSNumber *> *output = [NSMutableDictionary dictionary];
    __block NSError *blockError = nil;
    dispatch_sync(self.queue, ^{
        const char *sql = accountID
            ? "SELECT COALESCE(category,''),COUNT(*) FROM media_items WHERE account_id=? GROUP BY category"
            : "SELECT COALESCE(category,''),COUNT(*) FROM media_items GROUP BY category";
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(self.db, sql, -1, &stmt, NULL) != SQLITE_OK) {
            blockError = [self errorWithCode:10 message:@(sqlite3_errmsg(self.db))];
            return;
        }
        if (accountID.length) sqlite3_bind_text(stmt, 1, accountID.UTF8String, -1, SQLITE_TRANSIENT);
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            NSString *category = K4LColumnText(stmt, 0) ?: @"";
            output[category] = @(sqlite3_column_int64(stmt, 1));
        }
        sqlite3_finalize(stmt);
    });
    if (blockError && error) *error = blockError;
    return output;
}

@end
