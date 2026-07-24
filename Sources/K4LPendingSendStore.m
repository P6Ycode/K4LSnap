#import "K4LPendingSendStore.h"
#import "K4LVaultStore.h"
#import "K4LSystem.h"

@implementation K4LPendingSend
@end

@interface K4LPendingSendStore ()
@property (nonatomic) dispatch_queue_t queue;
@end

@implementation K4LPendingSendStore

+ (instancetype)shared {
    static id value;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ value = [self new]; });
    return value;
}

- (instancetype)init {
    if ((self = [super init])) _queue = dispatch_queue_create("com.p6ycode.k4lsnap.pending-send", DISPATCH_QUEUE_SERIAL);
    return self;
}

- (K4LPendingSend *)currentDraft {
    __block K4LPendingSend *draft = nil;
    dispatch_sync(self.queue, ^{
        NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:K4LPendingSendPath()];
        NSString *identifier = [dictionary[@"itemIdentifier"] isKindOfClass:NSString.class] ? dictionary[@"itemIdentifier"] : nil;
        if (!identifier.length) return;
        draft = [K4LPendingSend new];
        draft.itemIdentifier = identifier;
        draft.caption = [dictionary[@"caption"] isKindOfClass:NSString.class] ? dictionary[@"caption"] : nil;
        draft.wholeStory = [dictionary[@"wholeStory"] boolValue];
        draft.createdAt = [dictionary[@"createdAt"] doubleValue];
    });
    return draft;
}

- (BOOL)setPendingItem:(K4LVaultItem *)item caption:(NSString *)caption wholeStory:(BOOL)wholeStory error:(NSError **)error {
    if (!item.identifier.length) {
        if (error) *error = [NSError errorWithDomain:@"com.p6ycode.k4lsnap.pending-send"
                                                code:1
                                            userInfo:@{NSLocalizedDescriptionKey: @"The vault item has no identifier"}];
        return NO;
    }
    if (!K4LEnsureSystemDirectories(error)) return NO;

    __block BOOL ok = NO;
    __block NSError *blockError = nil;
    dispatch_sync(self.queue, ^{
        NSMutableDictionary *dictionary = [@{
            @"itemIdentifier": item.identifier,
            @"wholeStory": @(wholeStory),
            @"createdAt": @(NSDate.date.timeIntervalSince1970)
        } mutableCopy];
        if (caption.length) dictionary[@"caption"] = caption;
        ok = [dictionary writeToFile:K4LPendingSendPath() atomically:YES];
        if (!ok) {
            blockError = [NSError errorWithDomain:@"com.p6ycode.k4lsnap.pending-send"
                                             code:2
                                         userInfo:@{NSLocalizedDescriptionKey: @"Unable to persist the pending send draft"}];
        }
    });
    if (!ok && error) *error = blockError;
    return ok;
}

- (BOOL)clear:(NSError **)error {
    __block BOOL ok = YES;
    __block NSError *blockError = nil;
    dispatch_sync(self.queue, ^{
        if (![NSFileManager.defaultManager fileExistsAtPath:K4LPendingSendPath()]) return;
        ok = [NSFileManager.defaultManager removeItemAtPath:K4LPendingSendPath() error:&blockError];
    });
    if (!ok && error) *error = blockError;
    return ok;
}

@end
