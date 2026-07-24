#import "K4LMediaEditorViewController.h"
#import "K4LMediaProcessor.h"
#import "K4LVaultStore.h"
#import "K4LPendingSendStore.h"
#import "K4LSystem.h"
#import <AVFoundation/AVFoundation.h>

@interface K4LMediaEditorViewController () <UITextFieldDelegate>
@property (nonatomic, strong) NSURL *sourceURL;
@property (nonatomic, copy) NSString *mediaType;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UITextField *captionField;
@property (nonatomic, strong) UITextField *accountField;
@property (nonatomic, strong) UITextField *friendField;
@property (nonatomic, strong) UITextField *categoryField;
@property (nonatomic, strong) UISegmentedControl *cropControl;
@property (nonatomic, strong) UISegmentedControl *sizeControl;
@property (nonatomic, strong) UITextField *trimStartField;
@property (nonatomic, strong) UITextField *trimEndField;
@property (nonatomic, strong) UISwitch *wholeStorySwitch;
@property (nonatomic, strong) UISwitch *shareAfterSaveSwitch;
@property (nonatomic, strong) UIButton *rotateButton;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic) NSInteger quarterTurns;
@end

@implementation K4LMediaEditorViewController

- (instancetype)initWithSourceURL:(NSURL *)sourceURL mediaType:(NSString *)mediaType {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _sourceURL = sourceURL;
        _mediaType = [mediaType copy];
        _quarterTurns = 0;
        self.title = [mediaType isEqualToString:@"video"] ? @"Prepare Video" : @"Prepare Image";
    }
    return self;
}

- (void)dealloc {
    if ([self.sourceURL.path hasPrefix:K4LTemporaryDirectory()]) {
        [NSFileManager.defaultManager removeItemAtURL:self.sourceURL error:nil];
    }
}

- (UILabel *)sectionLabel:(NSString *)text {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    label.textColor = UIColor.labelColor;
    return label;
}

- (UITextField *)textFieldWithPlaceholder:(NSString *)placeholder {
    UITextField *field = [UITextField new];
    field.placeholder = placeholder;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.delegate = self;
    field.returnKeyType = UIReturnKeyDone;
    return field;
}

- (UIStackView *)switchRowWithTitle:(NSString *)title control:(UISwitch *)control {
    UILabel *label = [UILabel new];
    label.text = title;
    label.numberOfLines = 0;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[label, control]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.distribution = UIStackViewDistributionFill;
    row.spacing = 12;
    return row;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEditor)];

    UIScrollView *scrollView = [UIScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];

    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.layoutMargins = UIEdgeInsetsMake(18, 18, 30, 18);
    stack.layoutMarginsRelativeArrangement = YES;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor]
    ]];

    self.previewImageView = [UIImageView new];
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.previewImageView.backgroundColor = UIColor.blackColor;
    self.previewImageView.layer.cornerRadius = 12;
    self.previewImageView.clipsToBounds = YES;
    self.previewImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.previewImageView.heightAnchor constraintEqualToConstant:280].active = YES;
    [stack addArrangedSubview:self.previewImageView];

    [stack addArrangedSubview:[self sectionLabel:@"Destination metadata"]];
    self.captionField = [self textFieldWithPlaceholder:@"Caption (optional)"];
    self.captionField.autocorrectionType = UITextAutocorrectionTypeYes;
    self.accountField = [self textFieldWithPlaceholder:@"Account ID (optional)"];
    self.friendField = [self textFieldWithPlaceholder:@"Friend ID (optional)"];
    self.categoryField = [self textFieldWithPlaceholder:@"Category"];
    self.categoryField.text = @"Gallery Upload";
    [stack addArrangedSubview:self.captionField];
    [stack addArrangedSubview:self.accountField];
    [stack addArrangedSubview:self.friendField];
    [stack addArrangedSubview:self.categoryField];

    if ([self.mediaType isEqualToString:@"video"]) {
        [stack addArrangedSubview:[self sectionLabel:@"Trim"]];
        self.trimStartField = [self textFieldWithPlaceholder:@"Start seconds"];
        self.trimEndField = [self textFieldWithPlaceholder:@"End seconds"];
        self.trimStartField.keyboardType = UIKeyboardTypeDecimalPad;
        self.trimEndField.keyboardType = UIKeyboardTypeDecimalPad;
        self.trimStartField.text = @"0";
        [stack addArrangedSubview:self.trimStartField];
        [stack addArrangedSubview:self.trimEndField];
    } else {
        [stack addArrangedSubview:[self sectionLabel:@"Image transform"]];
        self.cropControl = [[UISegmentedControl alloc] initWithItems:@[@"Original", @"Square", @"9:16"]];
        self.cropControl.selectedSegmentIndex = 0;
        [stack addArrangedSubview:self.cropControl];

        self.sizeControl = [[UISegmentedControl alloc] initWithItems:@[@"Original", @"1080", @"2048"]];
        self.sizeControl.selectedSegmentIndex = 1;
        [stack addArrangedSubview:self.sizeControl];

        self.rotateButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.rotateButton setTitle:@"Rotate 90° clockwise" forState:UIControlStateNormal];
        self.rotateButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [self.rotateButton addTarget:self action:@selector(rotatePreview) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:self.rotateButton];
    }

    self.wholeStorySwitch = [UISwitch new];
    [stack addArrangedSubview:[self switchRowWithTitle:@"Mark as whole-story draft" control:self.wholeStorySwitch]];
    self.shareAfterSaveSwitch = [UISwitch new];
    self.shareAfterSaveSwitch.on = YES;
    [stack addArrangedSubview:[self switchRowWithTitle:@"Open share sheet after saving" control:self.shareAfterSaveSwitch]];

    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.saveButton setTitle:@"Process and Save to Vault" forState:UIControlStateNormal];
    self.saveButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.saveButton.backgroundColor = UIColor.systemBlueColor;
    [self.saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.saveButton.layer.cornerRadius = 12;
    self.saveButton.contentEdgeInsets = UIEdgeInsetsMake(14, 18, 14, 18);
    [self.saveButton addTarget:self action:@selector(processAndSave) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:self.saveButton];

    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activityIndicator.hidesWhenStopped = YES;
    [stack addArrangedSubview:self.activityIndicator];

    [self loadPreview];
}

- (void)cancelEditor {
    if (self.saveButton.enabled) [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)loadPreview {
    if ([self.mediaType isEqualToString:@"video"]) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:self.sourceURL options:nil];
        NSTimeInterval duration = CMTimeGetSeconds(asset.duration);
        if (isfinite(duration) && duration > 0) self.trimEndField.text = [NSString stringWithFormat:@"%.2f", duration];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *error = nil;
            UIImage *poster = [K4LMediaProcessor posterImageForVideoURL:self.sourceURL atTime:0 error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.previewImageView.image = poster ?: [UIImage systemImageNamed:@"film"];
            });
        });
    } else {
        self.previewImageView.image = [UIImage imageWithContentsOfFile:self.sourceURL.path];
    }
}

- (void)rotatePreview {
    self.quarterTurns = (self.quarterTurns + 1) % 4;
    self.previewImageView.transform = CGAffineTransformMakeRotation(self.quarterTurns * M_PI_2);
    [self.rotateButton setTitle:[NSString stringWithFormat:@"Rotate 90° clockwise · %ld°", (long)(self.quarterTurns * 90)] forState:UIControlStateNormal];
}

- (NSString *)trimmedText:(UITextField *)field {
    NSString *value = [field.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return value.length ? value : nil;
}

- (void)setBusy:(BOOL)busy {
    self.saveButton.enabled = !busy;
    self.navigationItem.leftBarButtonItem.enabled = !busy;
    if (busy) [self.activityIndicator startAnimating];
    else [self.activityIndicator stopAnimating];
}

- (void)processAndSave {
    [self.view endEditing:YES];
    K4LMediaProcessingOptions *options = [K4LMediaProcessingOptions new];
    options.clockwiseQuarterTurns = self.quarterTurns;
    if (![self.mediaType isEqualToString:@"video"]) {
        options.cropPreset = (K4LCropPreset)self.cropControl.selectedSegmentIndex;
        if (self.sizeControl.selectedSegmentIndex == 1) options.maximumDimension = 1080;
        else if (self.sizeControl.selectedSegmentIndex == 2) options.maximumDimension = 2048;
    } else {
        options.trimStart = self.trimStartField.text.doubleValue;
        options.trimEnd = self.trimEndField.text.doubleValue;
    }

    [self setBusy:YES];
    [K4LMediaProcessor processURL:self.sourceURL mediaType:self.mediaType options:options completion:^(K4LMediaProcessingResult *result, NSError *processingError) {
        if (!result) {
            [self setBusy:NO];
            [self presentError:processingError];
            return;
        }

        NSError *vaultError = nil;
        NSString *caption = [self trimmedText:self.captionField];
        K4LVaultItem *item = [[K4LVaultStore shared] importPreparedFileAtURL:result.mediaURL
                                                               thumbnailURL:result.thumbnailURL
                                                                  accountID:[self trimmedText:self.accountField]
                                                                   friendID:[self trimmedText:self.friendField]
                                                                   category:[self trimmedText:self.categoryField]
                                                                    caption:caption
                                                                   duration:result.duration
                                                                      error:&vaultError];
        [NSFileManager.defaultManager removeItemAtURL:result.mediaURL error:nil];
        [NSFileManager.defaultManager removeItemAtURL:result.thumbnailURL error:nil];
        if (!item) {
            [self setBusy:NO];
            [self presentError:vaultError];
            return;
        }

        NSError *draftError = nil;
        if (![[K4LPendingSendStore shared] setPendingItem:item caption:caption wholeStory:self.wholeStorySwitch.isOn error:&draftError]) {
            [self setBusy:NO];
            [self presentError:draftError];
            return;
        }

        [self setBusy:NO];
        NSURL *storedURL = [NSURL fileURLWithPath:[K4LMediaDirectory() stringByAppendingPathComponent:item.relativePath]];
        if (self.shareAfterSaveSwitch.isOn) {
            UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[storedURL] applicationActivities:nil];
            if (activity.popoverPresentationController) {
                activity.popoverPresentationController.sourceView = self.view;
                activity.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
            }
            activity.completionWithItemsHandler = ^(__unused UIActivityType activityType, __unused BOOL completed, __unused NSArray *returnedItems, __unused NSError *activityError) {
                [self showSavedMessage];
            };
            [self presentViewController:activity animated:YES completion:nil];
        } else {
            [self showSavedMessage];
        }
    }];
}

- (void)showSavedMessage {
    if (self.presentedViewController) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Saved"
                                                                   message:@"The processed media is in the vault and is now the current pending-send draft."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        if (self.navigationController.presentingViewController) [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        else [self.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentError:(NSError *)error {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"K4LSnap"
                                                                   message:error.localizedDescription ?: @"The operation failed"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
