#import "K4LAccountCategoryStore.h"
#import <CoreFoundation/CoreFoundation.h>

static NSString *K4LAccountMaskPath(void) { return @"/var/mobile/Library/Application Support/K4LSnap/account-category-masks.plist"; }
static NSString * const K4LAccountMaskChanged = @"com.p6ycode.k4lsnap/account-mask-changed";

@interface K4LAccountCategoryStore ()
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic, copy) NSDictionary *state;
@end

@implementation K4LAccountCategoryStore
+ (instancetype)shared { static id value; static dispatch_once_t once; dispatch_once(&once, ^{ value = [self new]; }); return value; }
- (instancetype)init { if ((self=[super init])) { _queue=dispatch_queue_create("com.p6ycode.k4lsnap.account-masks", DISPATCH_QUEUE_SERIAL); NSDictionary *raw=[NSDictionary dictionaryWithContentsOfFile:K4LAccountMaskPath()]; _state=[raw isKindOfClass:NSDictionary.class]?raw:@{}; } return self; }
- (NSUInteger)sanitizeSeed:(NSUInteger)mask { return mask & K4LAccountCategoryDefaultSeed; }
- (NSUInteger)sanitizeAccount:(NSUInteger)mask { return mask & (K4LAccountCategoryCustom | K4LAccountCategoryAllRows); }
- (void)commit:(NSDictionary *)next { NSString *directory=[K4LAccountMaskPath() stringByDeletingLastPathComponent]; [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:nil]; [next writeToFile:K4LAccountMaskPath() atomically:YES]; self.state=next; }
- (NSUInteger)globalDefaultMask { __block NSUInteger value; dispatch_sync(self.queue, ^{ value=[self sanitizeSeed:[self.state[@"globalDefaultMask"] unsignedIntegerValue]]; }); return value; }
- (void)setGlobalDefaultMask:(NSUInteger)mask { dispatch_sync(self.queue, ^{ NSMutableDictionary *next=self.state.mutableCopy?:[NSMutableDictionary dictionary]; next[@"globalDefaultMask"]=@([self sanitizeSeed:mask]); [self commit:next.copy]; }); CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)K4LAccountMaskChanged, NULL, NULL, true); }
- (NSUInteger)storedMaskForAccount:(NSString *)accountID { if(!accountID.length)return 0; __block NSUInteger value; dispatch_sync(self.queue, ^{ NSDictionary *accounts=self.state[@"accounts"]; value=[self sanitizeAccount:[accounts[accountID] unsignedIntegerValue]]; }); return value; }
- (NSUInteger)effectiveMaskForAccount:(NSString *)accountID { NSUInteger stored=[self storedMaskForAccount:accountID]; if(stored & K4LAccountCategoryCustom) return stored & K4LAccountCategoryAllRows; return [self globalDefaultMask]; }
- (void)setMask:(NSUInteger)mask forAccount:(NSString *)accountID { if(!accountID.length)return; dispatch_sync(self.queue, ^{ NSMutableDictionary *next=self.state.mutableCopy?:[NSMutableDictionary dictionary]; NSMutableDictionary *accounts=[next[@"accounts"] mutableCopy]?:[NSMutableDictionary dictionary]; accounts[accountID]=@([self sanitizeAccount:mask]); next[@"accounts"]=accounts.copy; [self commit:next.copy]; }); CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)K4LAccountMaskChanged, NULL, NULL, true); }
- (NSDictionary *)snapshot { __block NSDictionary *copy; dispatch_sync(self.queue, ^{ copy=self.state.copy; }); return copy; }
@end
