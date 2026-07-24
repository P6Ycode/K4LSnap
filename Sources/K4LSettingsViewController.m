#import "K4LSettingsViewController.h"
#import "K4LPreferences.h"
#import "K4LVaultStore.h"
#import "K4LSystem.h"
#import "K4LSnapVersionAdapter.h"

@interface K4LSettingsViewController ()
@property (nonatomic, copy) NSArray<K4LVaultItem *> *vaultItems;
@property (nonatomic) unsigned long long vaultBytes;
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
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 2;
        case 1: return 3;
        default: return 3;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"Features", @"Storage", @"Diagnostics"][section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"The launcher is local to the app and can be dragged out of the way.";
    if (section == 1) return K4LRootDirectory();
    return @"Compatibility reports the installed host version; private send integration is intentionally kept behind the version adapter.";
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
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = @"Clear Temporary Files";
        cell.textLabel.textColor = self.view.tintColor;
        return cell;
    }

    K4LSnapVersionAdapter *adapter = [K4LSnapVersionAdapter sharedAdapter];
    if (indexPath.row == 0) return [self detailCellWithTitle:@"Host Version" value:adapter.snapchatVersion ?: @"Unknown"];
    if (indexPath.row == 1) return [self detailCellWithTitle:@"Compatibility" value:adapter.isSupportedVersion ? @"Supported" : @"Unverified"];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = @"Reload K4LSnap State";
    cell.textLabel.textColor = self.view.tintColor;
    return cell;
}

- (void)toggleChanged:(UISwitch *)sender {
    NSString *key = sender.accessibilityIdentifier;
    if (key.length == 0) return;
    [[K4LPreferences shared] setObject:@(sender.on) forKey:key];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1 && indexPath.row == 2) {
        NSError *error = nil;
        NSArray<NSString *> *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:K4LTemporaryDirectory() error:&error];
        if (!error) {
            for (NSString *entry in contents) {
                [NSFileManager.defaultManager removeItemAtPath:[K4LTemporaryDirectory() stringByAppendingPathComponent:entry] error:nil];
            }
        }
        [self showMessage:error ? error.localizedDescription : @"Temporary files cleared."];
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
