#import "K4LGalleryUploadCoordinator.h"
#import "K4LVaultStore.h"
#import "K4LFeaturePolicy.h"
#import "K4LSystem.h"
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface K4LGalleryUploadCoordinator () <PHPickerViewControllerDelegate>
@property (nonatomic, weak) UIViewController *presenter;
@end

@implementation K4LGalleryUploadCoordinator
+ (instancetype)sharedCoordinator { static id value; static dispatch_once_t once; dispatch_once(&once, ^{ value = [self new]; }); return value; }
- (void)presentGalleryFromViewController:(UIViewController *)presenter {
    if (![[K4LFeaturePolicy sharedPolicy] galleryUploadEnabled]) return;
    self.presenter = presenter;
    PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary];
    configuration.selectionLimit = 1;
    configuration.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[PHPickerFilter.imagesFilter, PHPickerFilter.videosFilter]];
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
    picker.delegate = self;
    [presenter presentViewController:picker animated:YES completion:nil];
}
- (void)presentFilesFromViewController:(UIViewController *)presenter {
    if (![[K4LFeaturePolicy sharedPolicy] galleryUploadEnabled]) return;
    self.presenter = presenter;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeImage, UTTypeMovie] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [presenter presentViewController:picker animated:YES completion:nil];
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSItemProvider *provider = results.firstObject.itemProvider;
    if (!provider) return;
    NSString *typeIdentifier = [provider hasItemConformingToTypeIdentifier:UTTypeMovie.identifier] ? UTTypeMovie.identifier : UTTypeImage.identifier;
    [provider loadFileRepresentationForTypeIdentifier:typeIdentifier completionHandler:^(NSURL *url, NSError *error) {
        if (!url || error) { [self presentError:error ?: [NSError errorWithDomain:@"com.p6ycode.k4lsnap.gallery" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Unable to load selected media"}]]; return; }
        NSString *extension = url.pathExtension.length ? url.pathExtension : @"bin";
        NSURL *temporary = [NSURL fileURLWithPath:[K4LTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:extension]]];
        NSError *copyError = nil;
        [NSFileManager.defaultManager removeItemAtURL:temporary error:nil];
        [NSFileManager.defaultManager copyItemAtURL:url toURL:temporary error:&copyError];
        if (copyError) { [self presentError:copyError]; return; }
        [self importAndShareURL:temporary];
    }];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls { NSURL *url = urls.firstObject; if (url) [self importAndShareURL:url]; }
- (void)importAndShareURL:(NSURL *)url {
    NSError *error = nil;
    K4LVaultItem *item = [[K4LVaultStore shared] importFileAtURL:url accountID:nil friendID:nil category:@"Gallery Upload" error:&error];
    if (!item) { [self presentError:error]; return; }
    NSURL *storedURL = [NSURL fileURLWithPath:[K4LMediaDirectory() stringByAppendingPathComponent:item.relativePath]];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = self.presenter;
        if (!presenter) return;
        UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[storedURL] applicationActivities:nil];
        if (share.popoverPresentationController) { share.popoverPresentationController.sourceView = presenter.view; share.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1); }
        [presenter presentViewController:share animated:YES completion:nil];
    });
}
- (void)presentError:(NSError *)error { dispatch_async(dispatch_get_main_queue(), ^{ UIViewController *presenter=self.presenter; if(!presenter)return; UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"K4LSnap" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert]; [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]]; [presenter presentViewController:alert animated:YES completion:nil]; }); }
@end
