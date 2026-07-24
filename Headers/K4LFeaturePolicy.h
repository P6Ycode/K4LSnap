#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, K4LContentKind) {
    K4LContentKindSnap,
    K4LContentKindChat,
    K4LContentKindRemix,
};

@interface K4LFeaturePolicy : NSObject
+ (instancetype)sharedPolicy;
- (BOOL)galleryUploadEnabled;
- (BOOL)screenshotSuppressionEnabled;
- (BOOL)shouldSuppressSaveForKind:(K4LContentKind)kind;
- (BOOL)shouldDisableTapToSaveForKind:(K4LContentKind)kind;
- (BOOL)shouldGateSnapshotWrite;
- (BOOL)shouldDeferSnapshotWrite;
- (BOOL)shouldSuppressDiskWrite;
- (BOOL)shouldKeepDeletedContent;
- (BOOL)shouldSuppressReplayAcknowledgement;
- (BOOL)ghostModeEnabledForKind:(K4LContentKind)kind;
@end

NS_ASSUME_NONNULL_END
