#import "K4LFeaturePolicy.h"
#import "K4LPreferences.h"

@implementation K4LFeaturePolicy
+ (instancetype)sharedPolicy { static id value; static dispatch_once_t once; dispatch_once(&once, ^{ value = [self new]; }); return value; }
- (BOOL)flag:(NSString *)key fallback:(BOOL)fallback { return [[K4LPreferences shared] boolForKey:key defaultValue:fallback]; }
- (BOOL)galleryUploadEnabled { return [self flag:@"galleryUploadEnabled" fallback:YES]; }
- (BOOL)screenshotSuppressionEnabled { return [self flag:@"screenshotSuppressionEnabled" fallback:NO]; }
- (NSString *)suffixForKind:(K4LContentKind)kind { switch (kind) { case K4LContentKindChat: return @"Chat"; case K4LContentKindRemix: return @"Remix"; default: return @"Snap"; } }
- (BOOL)shouldSuppressSaveForKind:(K4LContentKind)kind { return [self flag:[@"suppressSave" stringByAppendingString:[self suffixForKind:kind]] fallback:NO]; }
- (BOOL)shouldDisableTapToSaveForKind:(K4LContentKind)kind { return [self flag:[@"disableTapToSave" stringByAppendingString:[self suffixForKind:kind]] fallback:NO]; }
- (BOOL)shouldGateSnapshotWrite { return [self flag:@"gateSnapshotWrite" fallback:NO]; }
- (BOOL)shouldDeferSnapshotWrite { return [self flag:@"deferSnapshotWrite" fallback:NO]; }
- (BOOL)shouldSuppressDiskWrite { return [self flag:@"suppressDiskWrite" fallback:NO]; }
- (BOOL)shouldKeepDeletedContent { return [self flag:@"keepDeletedContent" fallback:NO]; }
- (BOOL)shouldSuppressReplayAcknowledgement { return [self flag:@"suppressReplayAcknowledgement" fallback:NO]; }
- (BOOL)ghostModeEnabledForKind:(K4LContentKind)kind { return [self flag:[@"ghostMode" stringByAppendingString:[self suffixForKind:kind]] fallback:NO]; }
@end
