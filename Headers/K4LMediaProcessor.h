#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, K4LCropPreset) {
    K4LCropPresetOriginal = 0,
    K4LCropPresetSquare,
    K4LCropPresetPortraitNineBySixteen,
};

@interface K4LMediaProcessingOptions : NSObject
@property (nonatomic) K4LCropPreset cropPreset;
@property (nonatomic) NSInteger clockwiseQuarterTurns;
@property (nonatomic) CGFloat maximumDimension;
@property (nonatomic) NSTimeInterval trimStart;
@property (nonatomic) NSTimeInterval trimEnd;
@end

@interface K4LMediaProcessingResult : NSObject
@property (nonatomic, strong) NSURL *mediaURL;
@property (nonatomic, strong) NSURL *thumbnailURL;
@property (nonatomic, copy) NSString *mediaType;
@property (nonatomic) NSTimeInterval duration;
@end

@interface K4LMediaProcessor : NSObject
+ (void)processURL:(NSURL *)sourceURL
         mediaType:(NSString *)mediaType
           options:(K4LMediaProcessingOptions *)options
        completion:(void (^)(K4LMediaProcessingResult * _Nullable result, NSError * _Nullable error))completion;
+ (UIImage * _Nullable)posterImageForVideoURL:(NSURL *)url atTime:(NSTimeInterval)time error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
