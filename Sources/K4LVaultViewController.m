#import "K4LVaultViewController.h"
#import "K4LVaultStore.h"
#import "K4LMediaPreviewController.h"
#import "K4LMetadataEditorViewController.h"
#import "K4LGalleryUploadCoordinator.h"
#import "K4LSystem.h"

static void K4LVaultChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    K4LVaultViewController *controller = (__bridge K4LVaultViewController *)observer;
    dispatch_async(dispatch_get_main_queue(), ^{ [controller performSelector:@selector(reloadVault)]; });
}

@interface K4LVaultViewController () <UISearchResultsUpdating>
@property (nonatomic, copy) NSArray<K4LVaultItem *> *items;
@property (nonatomic, copy) NSArray<K4LVaultItem *> *filteredItems;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSByteCountFormatter *byteFormatter;
@end

@implementation K4LVaultViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Media Vault";
    self.items = @[];
    self.filteredItems = @[];

    self.dateFormatter = [NSDateFormatter new];
    self.dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    self.dateFormatter.timeStyle = NSDateFormatterShortStyle;
    self.byteFormatter = [NSByteCountFormatter new];
    self.byteFormatter.countStyle = NSByteCountFormatterCountStyleFile;

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchResultsUpdater = self;
    self.searchController.searchBar.placeholder = @"Search caption, account, friend, category, or type";
    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = YES;
    self.definesPresentationContext = YES;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showImportMenu)];
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(reloadVault) forControlEvents:UIControlEventValueChanged];

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), K4LVaultChangedCallback, (__bridge CFStringRef)K4LNotifyVaultChanged, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    [self reloadVault];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadVault];
}

- (void)dealloc {
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), (__bridge CFStringRef)K4LNotifyVaultChanged, NULL);
}

- (void)reloadVault {
    NSError *error = nil;
    NSArray *items = [[K4LVaultStore shared] itemsForAccount:nil friendID:nil category:nil error:&error];
    [self.refreshControl endRefreshing];
    if (error) {
        [self presentError:error];
        return;
    }
    self.items = items;
    [self applySearchText:self.searchController.searchBar.text];
}

- (void)showImportMenu {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Import Media" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Photos" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [[K4LGalleryUploadCoordinator sharedCoordinator] presentGalleryFromViewController:self];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Files" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [[K4LGalleryUploadCoordinator sharedCoordinator] presentFilesFromViewController:self];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self applySearchText:searchController.searchBar.text];
}

- (void)applySearchText:(NSString *)searchText {
    NSString *needle = [searchText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
    if (needle.length == 0) {
        self.filteredItems = self.items;
    } else {
        self.filteredItems = [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(K4LVaultItem *item, NSDictionary *bindings) {
            NSArray<NSString *> *fields = @[
                item.caption ?: @"",
                item.accountID ?: @"",
                item.friendID ?: @"",
                item.category ?: @"",
                item.mediaType ?: @"",
                item.relativePath ?: @""
            ];
            for (NSString *field in fields) if ([field.lowercaseString containsString:needle]) return YES;
            return NO;
        }]];
    }
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.filteredItems.count; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [NSString stringWithFormat:@"%lu item%@", (unsigned long)self.filteredItems.count, self.filteredItems.count == 1 ? @"" : @"s"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.filteredItems.count ? nil : @"Import an image or video to begin.";
}

- (NSString *)durationTextForItem:(K4LVaultItem *)item {
    if (![item.mediaType isEqualToString:@"video"] || item.duration <= 0) return nil;
    NSInteger totalSeconds = (NSInteger)llround(item.duration);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(totalSeconds / 60), (long)(totalSeconds % 60)];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"K4LVaultCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];

    K4LVaultItem *item = self.filteredItems[indexPath.row];
    NSString *scope = item.category.length ? item.category : @"Uncategorized";
    if (item.friendID.length) scope = [scope stringByAppendingFormat:@" · %@", item.friendID];
    else if (item.accountID.length) scope = [scope stringByAppendingFormat:@" · %@", item.accountID];
    cell.textLabel.text = item.caption.length ? item.caption : scope;

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:item.createdAt];
    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObjects:
        item.mediaType.capitalizedString,
        [self.byteFormatter stringFromByteCount:(long long)item.byteSize],
        [self.dateFormatter stringFromDate:date], nil];
    NSString *duration = [self durationTextForItem:item];
    if (duration.length) [details insertObject:duration atIndex:1];
    if (item.caption.length) [details insertObject:scope atIndex:0];
    cell.detailTextLabel.text = [details componentsJoinedByString:@" · "];

    UIImage *thumbnail = nil;
    if (item.thumbnailRelativePath.length) {
        NSString *path = [K4LThumbnailDirectory() stringByAppendingPathComponent:item.thumbnailRelativePath];
        thumbnail = [UIImage imageWithContentsOfFile:path];
    }
    cell.imageView.image = thumbnail ?: [UIImage systemImageNamed:[item.mediaType isEqualToString:@"video"] ? @"film" : @"photo"];
    cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
    cell.imageView.clipsToBounds = YES;
    cell.imageView.layer.cornerRadius = 7;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    K4LVaultItem *item = self.filteredItems[indexPath.row];
    [self.navigationController pushViewController:[[K4LMediaPreviewController alloc] initWithItem:item] animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    K4LVaultItem *item = self.filteredItems[indexPath.row];
    UIContextualAction *share = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Share" handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        NSURL *url = [NSURL fileURLWithPath:[K4LMediaDirectory() stringByAppendingPathComponent:item.relativePath]];
        UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
        if (activity.popoverPresentationController) activity.popoverPresentationController.sourceView = self.view;
        [self presentViewController:activity animated:YES completion:nil];
        completionHandler(YES);
    }];
    UIContextualAction *edit = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Edit" handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        [self.navigationController pushViewController:[[K4LMetadataEditorViewController alloc] initWithItem:item] animated:YES];
        completionHandler(YES);
    }];
    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete" handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completionHandler)(BOOL)) {
        NSError *error = nil;
        BOOL ok = [[K4LVaultStore shared] deleteItem:item error:&error];
        if (!ok && error) [self presentError:error];
        [self reloadVault];
        completionHandler(ok);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[delete, edit, share]];
}

- (void)presentError:(NSError *)error {
    if (!self.view.window) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"K4LSnap" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
