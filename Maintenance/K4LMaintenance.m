#import "K4LMaintenance.h"
#import <CoreFoundation/CoreFoundation.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <sqlite3.h>

static NSString * const K4LReloadNotification = @"com.p6ycode.k4lsnap/reload";
static NSString * const K4LVaultChangedNotification = @"com.p6ycode.k4lsnap/vault-changed";

NSString *K4LMaintenanceRootDirectory(void) {
    return @"/var/mobile/Library/Application Support/K4LSnap";
}

NSString *K4LMaintenanceStatusPath(void) {
    return [K4LMaintenanceRootDirectory() stringByAppendingPathComponent:@"daemon-status.plist"];
}

static NSString *K4LPath(NSString *component) {
    return [K4LMaintenanceRootDirectory() stringByAppendingPathComponent:component];
}

static NSError *K4LError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"com.p6ycode.k4lsnap.maintenance"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Maintenance operation failed"}];
}

static BOOL K4LEnsureDirectories(NSError **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *path in @[K4LMaintenanceRootDirectory(), K4LPath(@"Media"), K4LPath(@"Thumbnails"), K4LPath(@"Temp"), K4LPath(@"Drafts")]) {
        if (![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0755} error:error]) return NO;
    }
    return YES;
}

static sqlite3 *K4LOpenDatabase(NSError **error) {
    sqlite3 *db = NULL;
    NSString *path = K4LPath(@"vault.sqlite3");
    if (sqlite3_open_v2(path.fileSystemRepresentation, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, NULL) != SQLITE_OK) {
        NSString *message = db ? @(sqlite3_errmsg(db)) : @"Unable to open vault database";
        if (error) *error = K4LError(1, message);
        if (db) sqlite3_close(db);
        return NULL;
    }
    sqlite3_busy_timeout(db, 3000);
    return db;
}

static NSString *K4LScalarText(sqlite3 *db, const char *sql) {
    sqlite3_stmt *stmt = NULL;
    NSString *value = nil;
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK && sqlite3_step(stmt) == SQLITE_ROW) {
        const unsigned char *text = sqlite3_column_text(stmt, 0);
        if (text) value = @((const char *)text);
    }
    sqlite3_finalize(stmt);
    return value;
}

static long long K4LScalarInteger(sqlite3 *db, const char *sql) {
    sqlite3_stmt *stmt = NULL;
    long long value = 0;
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK && sqlite3_step(stmt) == SQLITE_ROW) value = sqlite3_column_int64(stmt, 0);
    sqlite3_finalize(stmt);
    return value;
}

static unsigned long long K4LDirectorySize(NSString *path) {
    unsigned long long total = 0;
    NSDirectoryEnumerator *enumerator = [NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:path]
                                                          includingPropertiesForKeys:@[NSURLFileSizeKey, NSURLIsRegularFileKey]
                                                                             options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                        errorHandler:nil];
    for (NSURL *url in enumerator) {
        NSNumber *regular = nil, *size = nil;
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        if (!regular.boolValue) continue;
        [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
        total += size.unsignedLongLongValue;
    }
    return total;
}

static BOOL K4LWriteJPEG(CGImageRef image, NSURL *url, NSError **error) {
    if (!image) return NO;
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)url, CFSTR("public.jpeg"), 1, NULL);
    if (!destination) {
        if (error) *error = K4LError(9, @"Unable to create thumbnail destination");
        return NO;
    }
    NSDictionary *options = @{(__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @0.78};
    CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)options);
    BOOL ok = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    if (!ok && error) *error = K4LError(10, @"Unable to encode thumbnail");
    return ok;
}

@implementation K4LMaintenance

+ (NSDictionary *)healthReport:(NSError **)error {
    if (!K4LEnsureDirectories(error)) return @{};
    sqlite3 *db = K4LOpenDatabase(error);
    if (!db) return @{};

    NSString *integrity = K4LScalarText(db, "PRAGMA quick_check") ?: @"unknown";
    long long schemaVersion = K4LScalarInteger(db, "SELECT COALESCE(MAX(version),0) FROM schema_meta");
    long long itemCount = K4LScalarInteger(db, "SELECT COUNT(*) FROM media_items");
    long long missingMedia = K4LScalarInteger(db, "SELECT COUNT(*) FROM media_items WHERE relative_path IS NULL OR relative_path='' ");

    NSMutableArray<NSString *> *missingFiles = [NSMutableArray array];
    NSMutableArray<NSString *> *missingThumbnails = [NSMutableArray array];
    sqlite3_stmt *stmt = NULL;
    const char *sql = "SELECT id,relative_path,thumbnail_path FROM media_items";
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            NSString *identifier = @((const char *)sqlite3_column_text(stmt, 0));
            const unsigned char *mediaText = sqlite3_column_text(stmt, 1);
            const unsigned char *thumbText = sqlite3_column_text(stmt, 2);
            NSString *media = mediaText ? @((const char *)mediaText) : nil;
            NSString *thumb = thumbText ? @((const char *)thumbText) : nil;
            if (!media.length || ![NSFileManager.defaultManager fileExistsAtPath:[K4LPath(@"Media") stringByAppendingPathComponent:media]]) [missingFiles addObject:identifier];
            if (!thumb.length || ![NSFileManager.defaultManager fileExistsAtPath:[K4LPath(@"Thumbnails") stringByAppendingPathComponent:thumb]]) [missingThumbnails addObject:identifier];
        }
    }
    sqlite3_finalize(stmt);
    sqlite3_close(db);

    NSDictionary *report = @{
        @"timestamp": @([NSDate date].timeIntervalSince1970),
        @"integrity": integrity,
        @"schemaVersion": @(schemaVersion),
        @"itemCount": @(itemCount),
        @"invalidMediaRows": @(missingMedia),
        @"missingMediaIDs": missingFiles,
        @"missingThumbnailIDs": missingThumbnails,
        @"mediaBytes": @(K4LDirectorySize(K4LPath(@"Media"))),
        @"thumbnailBytes": @(K4LDirectorySize(K4LPath(@"Thumbnails"))),
        @"temporaryBytes": @(K4LDirectorySize(K4LPath(@"Temp")) + K4LDirectorySize(K4LPath(@"Drafts")))
    };
    [self writeStatus:report error:nil];
    return report;
}

+ (NSDictionary *)pruneFilesOlderThan:(NSTimeInterval)age error:(NSError **)error {
    if (!K4LEnsureDirectories(error)) return @{};
    NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-MAX(0, age)];
    NSUInteger removed = 0;
    unsigned long long bytes = 0;
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *directory in @[K4LPath(@"Temp"), K4LPath(@"Drafts")]) {
        NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:directory error:error];
        if (!entries && error && *error) return @{};
        for (NSString *entry in entries) {
            NSString *path = [directory stringByAppendingPathComponent:entry];
            NSDictionary *attributes = [fm attributesOfItemAtPath:path error:nil];
            NSDate *modified = attributes[NSFileModificationDate];
            if (modified && [modified compare:cutoff] == NSOrderedDescending) continue;
            bytes += [attributes[NSFileSize] unsignedLongLongValue];
            if ([fm removeItemAtPath:path error:nil]) removed++;
        }
    }
    return @{ @"removedFiles": @(removed), @"removedBytes": @(bytes), @"olderThanSeconds": @(age) };
}

+ (NSDictionary *)repairThumbnails:(NSError **)error {
    if (!K4LEnsureDirectories(error)) return @{};
    sqlite3 *db = K4LOpenDatabase(error);
    if (!db) return @{};
    NSUInteger repaired = 0, failed = 0;
    sqlite3_stmt *stmt = NULL;
    const char *sql = "SELECT id,relative_path,media_type,thumbnail_path FROM media_items";
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        if (error) *error = K4LError(11, @(sqlite3_errmsg(db)));
        sqlite3_close(db);
        return @{};
    }
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        NSString *identifier = @((const char *)sqlite3_column_text(stmt, 0));
        NSString *relative = @((const char *)sqlite3_column_text(stmt, 1));
        NSString *mediaType = @((const char *)sqlite3_column_text(stmt, 2));
        const unsigned char *thumbText = sqlite3_column_text(stmt, 3);
        NSString *thumbnail = thumbText ? @((const char *)thumbText) : nil;
        NSString *thumbnailName = thumbnail.length ? thumbnail : [identifier stringByAppendingPathExtension:@"jpg"];
        NSString *thumbnailPath = [K4LPath(@"Thumbnails") stringByAppendingPathComponent:thumbnailName];
        if ([NSFileManager.defaultManager fileExistsAtPath:thumbnailPath]) continue;
        NSURL *mediaURL = [NSURL fileURLWithPath:[K4LPath(@"Media") stringByAppendingPathComponent:relative]];
        if (![NSFileManager.defaultManager fileExistsAtPath:mediaURL.path]) { failed++; continue; }

        CGImageRef image = NULL;
        if ([mediaType isEqualToString:@"video"]) {
            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:mediaURL options:nil];
            AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
            generator.appliesPreferredTrackTransform = YES;
            generator.maximumSize = CGSizeMake(360, 360);
            image = [generator copyCGImageAtTime:kCMTimeZero actualTime:nil error:nil];
        } else {
            CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)mediaURL, NULL);
            if (source) {
                NSDictionary *options = @{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                                          (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @360,
                                          (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES};
                image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
                CFRelease(source);
            }
        }
        NSError *writeError = nil;
        if (image && K4LWriteJPEG(image, [NSURL fileURLWithPath:thumbnailPath], &writeError)) {
            sqlite3_stmt *update = NULL;
            if (sqlite3_prepare_v2(db, "UPDATE media_items SET thumbnail_path=? WHERE id=?", -1, &update, NULL) == SQLITE_OK) {
                sqlite3_bind_text(update, 1, thumbnailName.UTF8String, -1, SQLITE_TRANSIENT);
                sqlite3_bind_text(update, 2, identifier.UTF8String, -1, SQLITE_TRANSIENT);
                if (sqlite3_step(update) == SQLITE_DONE) repaired++; else failed++;
            } else failed++;
            sqlite3_finalize(update);
        } else failed++;
        if (image) CGImageRelease(image);
    }
    sqlite3_finalize(stmt);
    sqlite3_close(db);
    if (repaired) [self postNotification:K4LVaultChangedNotification];
    return @{ @"repaired": @(repaired), @"failed": @(failed) };
}

+ (BOOL)vacuumDatabase:(NSError **)error {
    sqlite3 *db = K4LOpenDatabase(error);
    if (!db) return NO;
    char *message = NULL;
    BOOL ok = sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE); VACUUM;", NULL, NULL, &message) == SQLITE_OK;
    if (!ok && error) *error = K4LError(12, message ? @(message) : @(sqlite3_errmsg(db)));
    sqlite3_free(message);
    sqlite3_close(db);
    return ok;
}

+ (BOOL)writeStatus:(NSDictionary *)status error:(NSError **)error {
    if (!K4LEnsureDirectories(error)) return NO;
    NSString *temporary = [K4LMaintenanceStatusPath() stringByAppendingString:@".tmp"];
    if (![status writeToFile:temporary atomically:YES]) {
        if (error) *error = K4LError(13, @"Unable to serialize daemon status");
        return NO;
    }
    [NSFileManager.defaultManager removeItemAtPath:K4LMaintenanceStatusPath() error:nil];
    return [NSFileManager.defaultManager moveItemAtPath:temporary toPath:K4LMaintenanceStatusPath() error:error];
}

+ (void)postNotification:(NSString *)name {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)name, NULL, NULL, true);
}

@end
