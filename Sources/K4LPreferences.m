#import "K4LPreferences.h"
#import "K4LSystem.h"

@interface K4LPreferences ()
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic, copy) NSDictionary *values;
@end

@implementation K4LPreferences

+ (instancetype)shared {
    static id value;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ value = [self new]; });
    return value;
}

- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("com.p6ycode.k4lsnap.preferences", DISPATCH_QUEUE_SERIAL);
        [self reload];
    }
    return self;
}

- (void)reload {
    dispatch_sync(self.queue, ^{
        NSDictionary *raw = [NSDictionary dictionaryWithContentsOfFile:K4LPreferencesPath()];
        self.values = [raw isKindOfClass:NSDictionary.class] ? raw : @{};
    });
}

- (NSDictionary *)snapshot {
    __block NSDictionary *copy;
    dispatch_sync(self.queue, ^{ copy = self.values.copy; });
    return copy ?: @{};
}

- (id)objectForKey:(NSString *)key { return [self snapshot][key]; }
- (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)fallback {
    id value = [self objectForKey:key];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : fallback;
}
- (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)fallback {
    id value = [self objectForKey:key];
    return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : fallback;
}

- (void)setObject:(id)value forKey:(NSString *)key {
    if (key.length == 0) return;
    __block BOOL committed = NO;
    dispatch_sync(self.queue, ^{
        NSMutableDictionary *next = self.values.mutableCopy ?: [NSMutableDictionary dictionary];
        if (value) next[key] = value;
        else [next removeObjectForKey:key];

        NSError *error = nil;
        if (!K4LEnsureSystemDirectories(&error)) {
            NSLog(@"[K4LSnap] preference directory error: %@", error);
            return;
        }
        NSString *temporary = [K4LPreferencesPath() stringByAppendingString:@".tmp"];
        [NSFileManager.defaultManager removeItemAtPath:temporary error:nil];
        if (![next writeToFile:temporary atomically:YES]) {
            NSLog(@"[K4LSnap] failed to serialize preferences");
            return;
        }
        NSFileManager *fm = NSFileManager.defaultManager;
        [fm removeItemAtPath:K4LPreferencesPath() error:nil];
        if (![fm moveItemAtPath:temporary toPath:K4LPreferencesPath() error:&error]) {
            NSLog(@"[K4LSnap] preference commit error: %@", error);
            return;
        }
        self.values = next.copy;
        committed = YES;
    });
    if (committed) K4LPostDarwinNotification(K4LNotifyReload);
}

@end
