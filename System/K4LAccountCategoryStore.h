#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, K4LAccountCategoryMask) {
    K4LAccountCategoryCustom = 0x01,
    K4LAccountCategoryRow0 = 0x02,
    K4LAccountCategoryRow1 = 0x04,
    K4LAccountCategoryRow2 = 0x08,
    K4LAccountCategoryRow3 = 0x10,
    K4LAccountCategoryRow4 = 0x20,
    K4LAccountCategoryRow5 = 0x40,
    K4LAccountCategoryDefaultSeed = 0x1E,
    K4LAccountCategoryAllRows = 0x7E,
};

@interface K4LAccountCategoryStore : NSObject
+ (instancetype)shared;
- (NSUInteger)globalDefaultMask;
- (void)setGlobalDefaultMask:(NSUInteger)mask;
- (NSUInteger)storedMaskForAccount:(NSString *)accountID;
- (NSUInteger)effectiveMaskForAccount:(NSString *)accountID;
- (void)setMask:(NSUInteger)mask forAccount:(NSString *)accountID;
- (NSDictionary *)snapshot;
@end

NS_ASSUME_NONNULL_END
