#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface K4LVaultItem : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *relativePath;
@property (nonatomic, copy, nullable) NSString *thumbnailRelativePath;
@property (nonatomic, copy, nullable) NSString *accountID;
@property (nonatomic, copy, nullable) NSString *friendID;
@property (nonatomic, copy, nullable) NSString *category;
@property (nonatomic, copy, nullable) NSString *caption;
@property (nonatomic, copy) NSString *mediaType;
@property (nonatomic) NSTimeInterval createdAt;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) unsigned long long byteSize;
@end

@interface K4LVaultStore : NSObject
+ (instancetype)shared;
- (BOOL)open:(NSError **)error;
- (K4LVaultItem * _Nullable)importFileAtURL:(NSURL *)sourceURL
                                 accountID:(NSString * _Nullable)accountID
                                  friendID:(NSString * _Nullable)friendID
                                  category:(NSString * _Nullable)category
                                     error:(NSError **)error;
- (K4LVaultItem * _Nullable)importPreparedFileAtURL:(NSURL *)sourceURL
                                      thumbnailURL:(NSURL * _Nullable)thumbnailURL
                                         accountID:(NSString * _Nullable)accountID
                                          friendID:(NSString * _Nullable)friendID
                                          category:(NSString * _Nullable)category
                                           caption:(NSString * _Nullable)caption
                                          duration:(NSTimeInterval)duration
                                             error:(NSError **)error;
- (NSArray<K4LVaultItem *> *)itemsForAccount:(NSString * _Nullable)accountID
                                    friendID:(NSString * _Nullable)friendID
                                    category:(NSString * _Nullable)category
                                       error:(NSError **)error;
- (BOOL)updateMetadataForItem:(K4LVaultItem *)item
                    accountID:(NSString * _Nullable)accountID
                     friendID:(NSString * _Nullable)friendID
                     category:(NSString * _Nullable)category
                      caption:(NSString * _Nullable)caption
                        error:(NSError **)error;
- (BOOL)deleteItem:(K4LVaultItem *)item error:(NSError **)error;
- (NSDictionary<NSString *, NSNumber *> *)categoryCountsForAccount:(NSString * _Nullable)accountID error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
