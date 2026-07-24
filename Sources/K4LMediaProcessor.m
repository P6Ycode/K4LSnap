#import "K4LMediaProcessor.h"
#import "K4LSystem.h"
#import <AVFoundation/AVFoundation.h>

@implementation K4LMediaProcessingOptions
- (instancetype)init {
    if ((self = [super init])) {
        _cropPreset = K4LCropPresetOriginal;
        _clockwiseQuarterTurns = 0;
        _maximumDimension = 0;
        _trimStart = 0;
        _trimEnd = 0;
    }
    return self;
}
@end

@implementation K4LMediaProcessingResult
@end

@implementation K4LMediaProcessor

+ (dispatch_queue_t)processingQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("com.p6ycode.k4lsnap.media-processing", DISPATCH_QUEUE_SERIAL); });
    return queue;
}

+ (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [NSError errorWithDomain:@"com.p6ycode.k4lsnap.media-processing"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Media processing failed"}];
}

+ (UIImage *)normalizedImage:(UIImage *)image {
    if (image.imageOrientation == UIImageOrientationUp) return image;
    UIGraphicsBeginImageContextWithOptions(image.size, NO, 1.0);
    [image drawInRect:(CGRect){CGPointZero, image.size}];
    UIImage *normalized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalized ?: image;
}

+ (UIImage *)image:(UIImage *)image rotatedClockwiseQuarterTurns:(NSInteger)quarterTurns {
    NSInteger turns = ((quarterTurns % 4) + 4) % 4;
    if (turns == 0) return image;
    BOOL swapsDimensions = (turns % 2) == 1;
    CGSize outputSize = swapsDimensions ? CGSizeMake(image.size.height, image.size.width) : image.size;
    UIGraphicsBeginImageContextWithOptions(outputSize, NO, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, outputSize.width / 2.0, outputSize.height / 2.0);
    CGContextRotateCTM(context, turns * M_PI_2);
    [image drawInRect:CGRectMake(-image.size.width / 2.0, -image.size.height / 2.0, image.size.width, image.size.height)];
    UIImage *rotated = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return rotated ?: image;
}

+ (UIImage *)image:(UIImage *)image croppedToPreset:(K4LCropPreset)preset {
    CGFloat targetAspect = 0;
    if (preset == K4LCropPresetSquare) targetAspect = 1.0;
    else if (preset == K4LCropPresetPortraitNineBySixteen) targetAspect = 9.0 / 16.0;
    if (targetAspect <= 0 || image.size.width <= 0 || image.size.height <= 0) return image;

    CGFloat currentAspect = image.size.width / image.size.height;
    CGRect cropRect = CGRectMake(0, 0, image.size.width, image.size.height);
    if (currentAspect > targetAspect) {
        CGFloat width = image.size.height * targetAspect;
        cropRect.origin.x = (image.size.width - width) / 2.0;
        cropRect.size.width = width;
    } else {
        CGFloat height = image.size.width / targetAspect;
        cropRect.origin.y = (image.size.height - height) / 2.0;
        cropRect.size.height = height;
    }

    CGImageRef croppedCGImage = CGImageCreateWithImageInRect(image.CGImage, cropRect);
    if (!croppedCGImage) return image;
    UIImage *cropped = [UIImage imageWithCGImage:croppedCGImage scale:1.0 orientation:UIImageOrientationUp];
    CGImageRelease(croppedCGImage);
    return cropped ?: image;
}

+ (UIImage *)image:(UIImage *)image resizedToMaximumDimension:(CGFloat)maximumDimension {
    CGFloat largestDimension = MAX(image.size.width, image.size.height);
    if (maximumDimension <= 0 || largestDimension <= maximumDimension) return image;
    CGFloat scale = maximumDimension / largestDimension;
    CGSize size = CGSizeMake(MAX(1, floor(image.size.width * scale)), MAX(1, floor(image.size.height * scale)));
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0);
    [image drawInRect:(CGRect){CGPointZero, size}];
    UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resized ?: image;
}

+ (NSURL *)temporaryURLWithExtension:(NSString *)extension {
    NSString *filename = [NSUUID.UUID.UUIDString stringByAppendingPathExtension:extension];
    return [NSURL fileURLWithPath:[K4LDraftDirectory() stringByAppendingPathComponent:filename]];
}

+ (BOOL)writeJPEGImage:(UIImage *)image toURL:(NSURL *)url quality:(CGFloat)quality error:(NSError **)error {
    NSData *data = UIImageJPEGRepresentation(image, quality);
    if (!data.length) {
        if (error) *error = [self errorWithCode:3 message:@"Unable to encode the image"];
        return NO;
    }
    [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    if (![data writeToURL:url options:NSDataWritingAtomic error:error]) return NO;
    return YES;
}

+ (void)complete:(void (^)(K4LMediaProcessingResult *, NSError *))completion
          result:(K4LMediaProcessingResult *)result
           error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{ completion(result, error); });
}

+ (void)processImageURL:(NSURL *)sourceURL
                options:(K4LMediaProcessingOptions *)options
             completion:(void (^)(K4LMediaProcessingResult *, NSError *))completion {
    UIImage *source = [UIImage imageWithContentsOfFile:sourceURL.path];
    if (!source) {
        [self complete:completion result:nil error:[self errorWithCode:1 message:@"The selected image could not be decoded"]];
        return;
    }

    UIImage *image = [self normalizedImage:source];
    image = [self image:image rotatedClockwiseQuarterTurns:options.clockwiseQuarterTurns];
    image = [self image:image croppedToPreset:options.cropPreset];
    image = [self image:image resizedToMaximumDimension:options.maximumDimension];

    NSURL *outputURL = [self temporaryURLWithExtension:@"jpg"];
    NSError *writeError = nil;
    if (![self writeJPEGImage:image toURL:outputURL quality:0.92 error:&writeError]) {
        [self complete:completion result:nil error:writeError];
        return;
    }

    UIImage *thumbnail = [self image:image resizedToMaximumDimension:360];
    NSURL *thumbnailURL = [self temporaryURLWithExtension:@"jpg"];
    if (![self writeJPEGImage:thumbnail toURL:thumbnailURL quality:0.78 error:&writeError]) {
        [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];
        [self complete:completion result:nil error:writeError];
        return;
    }

    K4LMediaProcessingResult *result = [K4LMediaProcessingResult new];
    result.mediaURL = outputURL;
    result.thumbnailURL = thumbnailURL;
    result.mediaType = @"image";
    result.duration = 0;
    [self complete:completion result:result error:nil];
}

+ (UIImage *)posterImageForVideoURL:(NSURL *)url atTime:(NSTimeInterval)time error:(NSError **)error {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    generator.maximumSize = CGSizeMake(720, 720);
    CMTime requestedTime = CMTimeMakeWithSeconds(MAX(0, time), 600);
    CGImageRef imageRef = [generator copyCGImageAtTime:requestedTime actualTime:nil error:error];
    if (!imageRef) return nil;
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return image;
}

+ (void)processVideoURL:(NSURL *)sourceURL
                options:(K4LMediaProcessingOptions *)options
             completion:(void (^)(K4LMediaProcessingResult *, NSError *))completion {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:sourceURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES}];
    NSTimeInterval totalDuration = CMTimeGetSeconds(asset.duration);
    if (!isfinite(totalDuration) || totalDuration <= 0) {
        [self complete:completion result:nil error:[self errorWithCode:4 message:@"The selected video has no readable duration"]];
        return;
    }

    NSTimeInterval start = MAX(0, options.trimStart);
    NSTimeInterval end = options.trimEnd > 0 ? MIN(options.trimEnd, totalDuration) : totalDuration;
    if (start >= totalDuration || end - start < 0.1) {
        [self complete:completion result:nil error:[self errorWithCode:5 message:@"The trim range must contain at least 0.1 seconds"]];
        return;
    }

    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHighestQuality];
    if (!exportSession) {
        [self complete:completion result:nil error:[self errorWithCode:6 message:@"Unable to create a video export session"]];
        return;
    }

    NSURL *outputURL = [self temporaryURLWithExtension:@"mp4"];
    [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];
    exportSession.outputURL = outputURL;
    exportSession.shouldOptimizeForNetworkUse = YES;
    exportSession.timeRange = CMTimeRangeFromTimeToTime(CMTimeMakeWithSeconds(start, 600), CMTimeMakeWithSeconds(end, 600));
    if ([exportSession.supportedFileTypes containsObject:AVFileTypeMPEG4]) exportSession.outputFileType = AVFileTypeMPEG4;
    else exportSession.outputFileType = exportSession.supportedFileTypes.firstObject;

    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        if (exportSession.status != AVAssetExportSessionStatusCompleted) {
            NSError *error = exportSession.error ?: [self errorWithCode:7 message:@"Video export failed"];
            [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];
            [self complete:completion result:nil error:error];
            return;
        }

        dispatch_async([self processingQueue], ^{
            NSError *posterError = nil;
            UIImage *poster = [self posterImageForVideoURL:outputURL atTime:0 error:&posterError];
            if (!poster) {
                [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];
                [self complete:completion result:nil error:posterError ?: [self errorWithCode:8 message:@"Unable to generate a video poster frame"]];
                return;
            }
            poster = [self image:poster resizedToMaximumDimension:360];
            NSURL *thumbnailURL = [self temporaryURLWithExtension:@"jpg"];
            NSError *writeError = nil;
            if (![self writeJPEGImage:poster toURL:thumbnailURL quality:0.78 error:&writeError]) {
                [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];
                [self complete:completion result:nil error:writeError];
                return;
            }

            K4LMediaProcessingResult *result = [K4LMediaProcessingResult new];
            result.mediaURL = outputURL;
            result.thumbnailURL = thumbnailURL;
            result.mediaType = @"video";
            result.duration = end - start;
            [self complete:completion result:result error:nil];
        });
    }];
}

+ (void)processURL:(NSURL *)sourceURL
         mediaType:(NSString *)mediaType
           options:(K4LMediaProcessingOptions *)options
        completion:(void (^)(K4LMediaProcessingResult *, NSError *))completion {
    if (!completion) return;
    if (!sourceURL.isFileURL || ![NSFileManager.defaultManager fileExistsAtPath:sourceURL.path]) {
        [self complete:completion result:nil error:[self errorWithCode:2 message:@"The selected media file does not exist"]];
        return;
    }
    K4LMediaProcessingOptions *effectiveOptions = options ?: [K4LMediaProcessingOptions new];
    dispatch_async([self processingQueue], ^{
        if ([mediaType isEqualToString:@"video"]) [self processVideoURL:sourceURL options:effectiveOptions completion:completion];
        else [self processImageURL:sourceURL options:effectiveOptions completion:completion];
    });
}

@end
