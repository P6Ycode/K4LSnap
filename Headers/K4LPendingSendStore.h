#import <Foundation/Foundation.h>
@class K4LVaultItem;

NS_ASSUME_NONNULL_BEGIN

@interface K4LPendingSend : NSObject
@property (nonatomic, copy) NSString *itemIdentifier;
@property (nonatomic, copy, nullable) NSString *caption;
@property (nonatomic) BOOL wholeStory;
@property (nonatomic) NSTimeInterval createdAt;
@end

@interface K4LPendingSendStore : NSObject
+ (instancetype)shared;
- (K4LPendingSend * _Nullable)currentDraft;
- (BOOL)setPendingItem:(K4LVaultItem *)item caption:(NSString * _Nullable)caption wholeStory:(BOOL)wholeStory error:(NSError **)error;
- (BOOL)clear:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
