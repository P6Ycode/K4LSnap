#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const K4LPreferenceDomain;
FOUNDATION_EXPORT NSString * const K4LNotifyReload;
FOUNDATION_EXPORT NSString * const K4LNotifyVaultChanged;
FOUNDATION_EXPORT NSString * const K4LNotifyDaemonPing;
FOUNDATION_EXPORT NSString * const K4LNotifyDaemonPong;

FOUNDATION_EXPORT NSString *K4LRootDirectory(void);
FOUNDATION_EXPORT NSString *K4LMediaDirectory(void);
FOUNDATION_EXPORT NSString *K4LTemporaryDirectory(void);
FOUNDATION_EXPORT NSString *K4LDatabasePath(void);
FOUNDATION_EXPORT NSString *K4LPreferencesPath(void);

FOUNDATION_EXPORT BOOL K4LEnsureSystemDirectories(NSError **error);
FOUNDATION_EXPORT void K4LPostDarwinNotification(NSString *name);

NS_ASSUME_NONNULL_END
