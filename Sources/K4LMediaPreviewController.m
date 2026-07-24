#import "K4LMediaPreviewController.h"
#import "K4LVaultStore.h"
#import "K4LSystem.h"
#import "K4LMetadataEditorViewController.h"
#import <AVKit/AVKit.h>

@interface K4LMediaPreviewController ()
@property (nonatomic, strong) K4LVaultItem *item;
@property (nonatomic, strong, nullable) AVPlayerViewController *playerController;
@end

@implementation K4LMediaPreviewController

- (instancetype)initWithItem:(K4LVaultItem *)item {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _item = item;
        self.title = item.category.length ? item.category : @"Preview";
    }
    return self;
}

- (NSURL *)mediaURL {
    return [NSURL fileURLWithPath:[K4LMediaDirectory() stringByAppendingPathComponent:self.item.relativePath]];
}

- (void)refreshMetadataDisplay {
    self.title = self.item.category.length ? self.item.category : @"Preview";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (self.item.caption.length) [parts addObject:self.item.caption];
    if (self.item.friendID.length) [parts addObject:[@"Friend: " stringByAppendingString:self.item.friendID]];
    else if (self.item.accountID.length) [parts addObject:[@"Account: " stringByAppendingString:self.item.accountID]];
    self.navigationItem.prompt = parts.count ? [parts componentsJoinedByString:@" · "] : nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UIBarButtonItem *share = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareItem)];
    UIBarButtonItem *edit = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editMetadata)];
    self.navigationItem.rightBarButtonItems = @[share, edit];
    [self refreshMetadataDisplay];

    NSURL *url = [self mediaURL];
    if ([self.item.mediaType isEqualToString:@"video"]) {
        AVPlayerViewController *playerController = [AVPlayerViewController new];
        playerController.player = [AVPlayer playerWithURL:url];
        self.playerController = playerController;
        [self addChildViewController:playerController];
        playerController.view.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:playerController.view];
        [NSLayoutConstraint activateConstraints:@[
            [playerController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [playerController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [playerController.view.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
            [playerController.view.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
        ]];
        [playerController didMoveToParentViewController:self];
    } else {
        UIImage *image = [UIImage imageWithContentsOfFile:url.path];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.backgroundColor = UIColor.blackColor;
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:imageView];
        [NSLayoutConstraint activateConstraints:@[
            [imageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [imageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [imageView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
            [imageView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
        ]];

        if (!image) {
            UILabel *label = [UILabel new];
            label.text = @"This file cannot be previewed.";
            label.textAlignment = NSTextAlignmentCenter;
            label.textColor = UIColor.secondaryLabelColor;
            label.translatesAutoresizingMaskIntoConstraints = NO;
            [self.view addSubview:label];
            [NSLayoutConstraint activateConstraints:@[
                [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
                [label.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
            ]];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshMetadataDisplay];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.playerController.player play];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.playerController.player pause];
}

- (void)editMetadata {
    [self.navigationController pushViewController:[[K4LMetadataEditorViewController alloc] initWithItem:self.item] animated:YES];
}

- (void)shareItem {
    NSURL *url = [self mediaURL];
    if (![NSFileManager.defaultManager fileExistsAtPath:url.path]) return;
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if (activity.popoverPresentationController) {
        activity.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    }
    [self presentViewController:activity animated:YES completion:nil];
}

@end
