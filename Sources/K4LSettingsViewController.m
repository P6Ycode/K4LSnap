#import "K4LSettingsViewController.h"
#import "K4LPreferences.h"
#import "K4LVaultStore.h"
#import "K4LPendingSendStore.h"
#import "K4LSystem.h"
#import "K4LSnapVersionAdapter.h"

@interface K4LSettingsViewController ()
@property (nonatomic, copy) NSArray<K4LVaultItem *> *vaultItems;
@property (nonatomic) unsigned long long vaultBytes;
@property (nonatomic, strong, nullable) K4LPendingSend *pendingSend;
@end

@implementation K4LSettingsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"K4LSnap Settings";
    [self reloadDiagnostics];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadDiagnostics];
}

- (void)reloadDiagnostics {
    NSError *error = nil;
    self.vaultItems = [[K4LVaultStore shared] itemsForAccount:nil friendID:nil category:nil error:&error];
    unsigned long long bytes = 0;
    for (K4LVaultItem *item in self.vaultItems) bytes += item.byteSize;
    self.vaultBytes = bytes;
    self.pendingSend = [[K4LPendingSendStore shared] currentDraft];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 2;
        case 1: return 5;
        default: return 3;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"Features", @"Storage and Draft", @"Diagnostics"][section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"The launcher is local to the app and can be dragged out of the way.";
    if (section == 1) return K4LRootDirectory();
    return @"Compatibility reports the installed host version; private send integration remains behind the version adapter.";
}

- (UITableViewCell *)switchCellWithTitle:(NSString *)title key:(NSString *)key fallback:(BOOL)fallback {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = title;
    UISwitch *toggle = [UISwitch new];
    toggle.on = [[K4LPreferences shared] boolForKey:key defaultValue:fallback];
    toggle.accessibilityIdentifier = key;
    [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)detailCellWithTitle:(NSString *)title value:(NSString *)value {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.detailTextLabel.text = value;
    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (NSString *)pendingDraftDescription {
    if (!self.pendingSend) return @"None";
    NSString *identifier = self.pendingSend.itemIdentifier;
    if (identifier.length > 8) identifier = [identifier substringToIndex:8];
    if (self.pendingSend.caption.length) return [NSString stringWithFormat:@"%@ · %@", identifier, self.pendingSend.caption];
    return identifier;
}

- (UITableViewCell *)actionCell:(NSString *)title destructive:(BOOL)destructive {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.textLabel.textColor = destructive ? UIColor.systemRedColor : self.view.tintColor;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) return [self switchCellWithTitle:@"Gallery Upload" key:@"galleryUploadEnabled" fallback:YES];
        return [self switchCellWithTitle:@"Floating Launcher" key:@"launcherEnabled" fallback:YES];
    }

    if (indexPath.section == 1) {
        if (indexPath.row == 0) return [self detailCellWithTitle:@"Vault Items" value:[NSString stringWithFormat:@"%lu", (unsigned long)self.vaultItems.count]];
        if (indexPath.row == 1) {
            NSByteCountFormatter *formatter = [NSByteCountFormatter new];
            formatter.countStyle = NSByteCountFormatterCountStyleFile;
            return [self detailCellWithTitle:@"Vault Size" value:[formatter stringFromByteCount:(long long)self.vaultBytes]];
        }
        if (indexPath.row == 2) return [self detailCellWithTitle:@"Pending Draft" value:[self pendingDraftDescription]];
        if (indexPath.row == 3) return [self actionCell:@"Clear Pending Draft" destructive:self.pendingSend != nil];
        return [self actionCell:@"Clear Temporary and Draft Files" destructive:NO];
    }

    K4LSnapVersionAdapter *adapter = [K4LSnapVersionAdapter sharedAdapter];
    if (indexPath.row == 0) return [self detailCellWithTitle:@"Host Version" value:adapter.snapchatVersion ?: @"Unknown"];
    if (indexPath.row == 1) return [self detailCellWithTitle:@"Compatibility" value:adapter.isSupportedVersion ? @"Supported" : @"Unverified"];
    return [self actionCell:@"Reload K4LSnap State" destructive:NO];
}

- (void)toggleChanged:(UISwitch *)sender {
    NSString *key = sender.accessibilityIdentifier;
    if (key.length == 0) return;
    [[K4LPreferences shared] setObject:@(sender.on) forKey:key];
}

- (void)clearDirectory:(NSString *)directory error:(NSError **)error {
    NSArray<NSString *> *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:error];
    if (*error) return;
    for (NSString *entry in contents) {
        if (![NSFileManager.defaultManager removeItemAtPath:[directory stringByAppendingPathComponent:entry] error:error]) return;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1 && indexPath.row == 3) {
        if (!self.pendingSend) return;
        NSError *error = nil;
        BOOL ok = [[K4LPendingSendStore shared] clear:&error];
        [self reloadDiagnostics];
        [self showMessage:ok ? @"Pending draft cleared." : error.localizedDescription];
    } else if (indexPath.section == 1 && indexPath.row == 4) {
        NSError *error = nil;
        [self clearDirectory:K4LTemporaryDirectory() error:&error];
        if (!error) [self clearDirectory:K4LDraftDirectory() error:&error];
        [self showMessage:error ? error.localizedDescription : @"Temporary and uncommitted draft files cleared."];
    } else if (indexPath.section == 2 && indexPath.row == 2) {
        [[K4LPreferences shared] reload];
        K4LPostDarwinNotification(K4LNotifyReload);
        [self reloadDiagnostics];
        [self showMessage:@"Preferences and local state reloaded."];
    }
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"K4LSnap" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
