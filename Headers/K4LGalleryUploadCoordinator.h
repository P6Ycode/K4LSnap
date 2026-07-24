#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface K4LGalleryUploadCoordinator : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate>
+ (instancetype)sharedCoordinator;
- (void)presentGalleryFromViewController:(UIViewController *)presenter;
- (void)presentFilesFromViewController:(UIViewController *)presenter;
@end

NS_ASSUME_NONNULL_END
