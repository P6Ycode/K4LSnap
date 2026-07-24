#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const K4LProtocolVersion;
FOUNDATION_EXPORT NSString * const K4LNotifyCommandAvailable;
FOUNDATION_EXPORT NSString * const K4LNotifyCommandResult;
FOUNDATION_EXPORT NSString * const K4LNotifyStateChanged;
FOUNDATION_EXPORT NSString * const K4LNotifyContainerChanged;

FOUNDATION_EXPORT NSString *K4LCommandsDirectory(void);
FOUNDATION_EXPORT NSString *K4LResultsDirectory(void);
FOUNDATION_EXPORT NSString *K4LDiagnosticsDirectory(void);
FOUNDATION_EXPORT NSString *K4LBackupsDirectory(void);

@interface K4LSystemProtocol : NSObject
+ (BOOL)ensureDirectories:(NSError **)error;
+ (NSString * _Nullable)enqueueCommand:(NSString *)command
                               payload:(NSDictionary * _Nullable)payload
                                 error:(NSError **)error;
+ (NSArray<NSDictionary *> *)pendingCommands:(NSError **)error;
+ (BOOL)completeCommand:(NSDictionary *)envelope
                 result:(NSDictionary *)result
                  error:(NSError **)error;
+ (NSDictionary * _Nullable)resultForIdentifier:(NSString *)identifier error:(NSError **)error;
+ (BOOL)appendDiagnosticEvent:(NSString *)event
                      details:(NSDictionary * _Nullable)details
                        error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
