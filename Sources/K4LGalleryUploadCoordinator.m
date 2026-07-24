#import "K4LGalleryUploadCoordinator.h"
#import "K4LFeaturePolicy.h"
#import "K4LSystem.h"
#import "K4LMediaEditorViewController.h"
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface K4LGalleryUploadCoordinator () <PHPickerViewControllerDelegate>
@property (nonatomic, weak) UIViewController *presenter;
@end

@implementation K4LGalleryUploadCoordinator

+ (instancetype)sharedCoordinator {
    static id value;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ value = [self new]; });
    return value;
}

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

- (NSString *)mediaTypeForURL:(NSURL *)url preferredTypeIdentifier:(NSString *)typeIdentifier {
    UTType *type = typeIdentifier.length ? [UTType typeWithIdentifier:typeIdentifier] : [UTType typeWithFilenameExtension:url.pathExtension];
    return [type conformsToType:UTTypeMovie] ? @"video" : @"image";
}

- (NSURL *)stageURL:(NSURL *)sourceURL error:(NSError **)error {
    if (!K4LEnsureSystemDirectories(error)) return nil;
    NSString *extension = sourceURL.pathExtension.length ? sourceURL.pathExtension.lowercaseString : @"bin";
    NSURL *destination = [NSURL fileURLWithPath:[K4LTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:extension]]];
    [NSFileManager.defaultManager removeItemAtURL:destination error:nil];
    BOOL accessed = [sourceURL startAccessingSecurityScopedResource];
    BOOL copied = [NSFileManager.defaultManager copyItemAtURL:sourceURL toURL:destination error:error];
    if (accessed) [sourceURL stopAccessingSecurityScopedResource];
    return copied ? destination : nil;
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSItemProvider *provider = results.firstObject.itemProvider;
    if (!provider) return;
    NSString *typeIdentifier = [provider hasItemConformingToTypeIdentifier:UTTypeMovie.identifier] ? UTTypeMovie.identifier : UTTypeImage.identifier;
    [provider loadFileRepresentationForTypeIdentifier:typeIdentifier completionHandler:^(NSURL *url, NSError *error) {
        if (!url || error) {
            [self presentError:error ?: [NSError errorWithDomain:@"com.p6ycode.k4lsnap.gallery" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Unable to load selected media"}]];
            return;
        }
        NSError *stageError = nil;
        NSURL *stagedURL = [self stageURL:url error:&stageError];
        if (!stagedURL) {
            [self presentError:stageError];
            return;
        }
        [self presentEditorForURL:stagedURL mediaType:[self mediaTypeForURL:url preferredTypeIdentifier:typeIdentifier]];
    }];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    NSError *stageError = nil;
    NSURL *stagedURL = [self stageURL:url error:&stageError];
    if (!stagedURL) {
        [self presentError:stageError];
        return;
    }
    [self presentEditorForURL:stagedURL mediaType:[self mediaTypeForURL:url preferredTypeIdentifier:nil]];
}

- (void)presentEditorForURL:(NSURL *)url mediaType:(NSString *)mediaType {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = self.presenter;
        if (!presenter) {
            [NSFileManager.defaultManager removeItemAtURL:url error:nil];
            return;
        }
        K4LMediaEditorViewController *editor = [[K4LMediaEditorViewController alloc] initWithSourceURL:url mediaType:mediaType];
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:editor];
        navigation.modalPresentationStyle = UIModalPresentationPageSheet;
        [presenter presentViewController:navigation animated:YES completion:nil];
    });
}

- (void)presentError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = self.presenter;
        if (!presenter) return;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"K4LSnap"
                                                                       message:error.localizedDescription
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [presenter presentViewController:alert animated:YES completion:nil];
    });
}

@end
