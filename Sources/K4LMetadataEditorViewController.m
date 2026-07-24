#import "K4LMetadataEditorViewController.h"
#import "K4LVaultStore.h"
#import "K4LPendingSendStore.h"

@interface K4LMetadataEditorViewController () <UITextFieldDelegate>
@property (nonatomic, strong) K4LVaultItem *item;
@property (nonatomic, strong) UITextField *accountField;
@property (nonatomic, strong) UITextField *friendField;
@property (nonatomic, strong) UITextField *categoryField;
@property (nonatomic, strong) UITextField *captionField;
@end

@implementation K4LMetadataEditorViewController

- (instancetype)initWithItem:(K4LVaultItem *)item {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _item = item;
        self.title = @"Edit Metadata";
    }
    return self;
}

- (UITextField *)fieldWithTitle:(NSString *)title value:(NSString *)value {
    UITextField *field = [UITextField new];
    field.placeholder = title;
    field.text = value;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.autocorrectionType = [title isEqualToString:@"Caption"] ? UITextAutocorrectionTypeYes : UITextAutocorrectionTypeNo;
    field.returnKeyType = UIReturnKeyDone;
    field.delegate = self;
    return field;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveMetadata)];

    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.layoutMargins = UIEdgeInsetsMake(24, 18, 24, 18);
    stack.layoutMarginsRelativeArrangement = YES;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor]
    ]];

    UILabel *help = [UILabel new];
    help.text = @"These values control how the item is grouped and found in the Media Vault.";
    help.numberOfLines = 0;
    help.textColor = UIColor.secondaryLabelColor;
    help.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    [stack addArrangedSubview:help];

    self.accountField = [self fieldWithTitle:@"Account ID" value:self.item.accountID];
    self.friendField = [self fieldWithTitle:@"Friend ID" value:self.item.friendID];
    self.categoryField = [self fieldWithTitle:@"Category" value:self.item.category];
    self.captionField = [self fieldWithTitle:@"Caption" value:self.item.caption];
    [stack addArrangedSubview:self.accountField];
    [stack addArrangedSubview:self.friendField];
    [stack addArrangedSubview:self.categoryField];
    [stack addArrangedSubview:self.captionField];
}

- (NSString *)clean:(UITextField *)field {
    NSString *value = [field.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return value.length ? value : nil;
}

- (void)saveMetadata {
    [self.view endEditing:YES];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    NSString *caption = [self clean:self.captionField];
    NSError *error = nil;
    BOOL ok = [[K4LVaultStore shared] updateMetadataForItem:self.item
                                                  accountID:[self clean:self.accountField]
                                                   friendID:[self clean:self.friendField]
                                                   category:[self clean:self.categoryField]
                                                    caption:caption
                                                      error:&error];
    if (ok) {
        K4LPendingSend *pending = [[K4LPendingSendStore shared] currentDraft];
        if ([pending.itemIdentifier isEqualToString:self.item.identifier]) {
            ok = [[K4LPendingSendStore shared] setPendingItem:self.item caption:caption wholeStory:pending.wholeStory error:&error];
        }
    }
    self.navigationItem.rightBarButtonItem.enabled = YES;
    if (!ok) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"K4LSnap"
                                                                       message:error.localizedDescription ?: @"Unable to update metadata"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
