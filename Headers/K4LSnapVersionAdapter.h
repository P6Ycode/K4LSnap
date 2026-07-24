#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface K4LSnapVersionAdapter : NSObject
+ (instancetype)sharedAdapter;
@property (nonatomic, readonly) NSString *snapchatVersion;
- (BOOL)isSupportedVersion;
- (void)installPrivateHooks;
- (BOOL)sendImportedMediaAtURL:(NSURL *)url
                      caption:(nullable NSString *)caption
                   wholeStory:(BOOL)wholeStory
                        error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
