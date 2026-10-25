//
//  DownloadsViewController.mm
//  AniAnglia
//
//  Created for iOS 10.3.3 offline viewing support.
//

#import "DownloadsViewController.h"
#import "DownloadManager.h"
#import "PlayerViewController.h"
#import "AppColor.h"

@interface DownloadsViewCell : UITableViewCell

@property (nonatomic, retain) UILabel *titleLabel;
@property (nonatomic, retain) UILabel *subtitleLabel;
@property (nonatomic, retain) UILabel *sizeLabel;
@property (nonatomic, retain) UIImageView *playImageView;

+ (NSString *)getIdentifier;

@end

@implementation DownloadsViewCell

+ (NSString *)getIdentifier {
    return @"DownloadsViewCell";
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [AppColorProvider backgroundColor];
        
        _titleLabel = [UILabel new];
        _titleLabel.font = [UIFont boldSystemFontOfSize:16];
        _titleLabel.textColor = [AppColorProvider textColor];
        _titleLabel.numberOfLines = 1;
        
        _subtitleLabel = [UILabel new];
        _subtitleLabel.font = [UIFont systemFontOfSize:14];
        _subtitleLabel.textColor = [AppColorProvider textSecondaryColor];
        _subtitleLabel.numberOfLines = 1;
        
        _sizeLabel = [UILabel new];
        _sizeLabel.font = [UIFont systemFontOfSize:13];
        _sizeLabel.textColor = [AppColorProvider textSecondaryColor];
        _sizeLabel.textAlignment = NSTextAlignmentRight;
        
        _playImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"play.circle.fill"]];
        _playImageView.tintColor = [AppColorProvider primaryColor];
        
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_subtitleLabel];
        [self.contentView addSubview:_sizeLabel];
        [self.contentView addSubview:_playImageView];
        
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _sizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _playImageView.translatesAutoresizingMaskIntoConstraints = NO;
        
        [NSLayoutConstraint activateConstraints:@[
            [_playImageView.leadingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
            [_playImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_playImageView.widthAnchor constraintEqualToConstant:28],
            [_playImageView.heightAnchor constraintEqualToConstant:28],
            
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_playImageView.trailingAnchor constant:12],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_sizeLabel.leadingAnchor constant:-8],
            
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_playImageView.trailingAnchor constant:12],
            [_subtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
            [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_sizeLabel.leadingAnchor constant:-8],
            
            [_sizeLabel.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],
            [_sizeLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_sizeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:70]
        ]];
    }
    return self;
}

@end

@interface DownloadsViewController ()

@property (nonatomic, retain) UITableView *tableView;
@property (nonatomic, retain) UILabel *emptyLabel;
@property (nonatomic, retain) NSArray<DownloadItem *> *downloads;

@end

@implementation DownloadsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = NSLocalizedString(@"app.downloads.title", @"Загрузки");
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"app.downloads.clear_all", @"Очистить")
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(onClearAllTapped:)];
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = [AppColorProvider backgroundColor];
    [_tableView registerClass:DownloadsViewCell.class forCellReuseIdentifier:[DownloadsViewCell getIdentifier]];
    [self.view addSubview:_tableView];
    
    _emptyLabel = [UILabel new];
    _emptyLabel.text = NSLocalizedString(@"app.downloads.empty", @"Нет скачанных серий.\nВы можете скачать серии для оффлайн-просмотра в списке серий аниме.");
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.textColor = [AppColorProvider textSecondaryColor];
    _emptyLabel.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:_emptyLabel];
    
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSLayoutYAxisAnchor *topAnchor = nil;
    NSLayoutYAxisAnchor *bottomAnchor = nil;
    if (@available(iOS 11.0, *)) {
        topAnchor = self.view.safeAreaLayoutGuide.topAnchor;
        bottomAnchor = self.view.safeAreaLayoutGuide.bottomAnchor;
    } else {
        topAnchor = self.topLayoutGuide.bottomAnchor;
        bottomAnchor = self.bottomLayoutGuide.topAnchor;
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:bottomAnchor],
        
        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [_emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32]
    ]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDownloadsChanged:) name:DownloadManagerStatusChangedNotification object:nil];
    
    [self reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)onDownloadsChanged:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadData];
    });
}

- (void)reloadData {
    _downloads = [[DownloadManager sharedInstance] allCompletedDownloads];
    _emptyLabel.hidden = (_downloads.count > 0);
    _tableView.hidden = (_downloads.count == 0);
    self.navigationItem.rightBarButtonItem.enabled = (_downloads.count > 0);
    
    if (_downloads.count > 0) {
        NSString *sizeStr = [[DownloadManager sharedInstance] formattedTotalSize];
        self.navigationItem.prompt = [NSString stringWithFormat:@"Всего: %lu сер. (%@)", (unsigned long)_downloads.count, sizeStr];
    } else {
        self.navigationItem.prompt = nil;
    }
    
    [_tableView reloadData];
}

- (void)onClearAllTapped:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"app.downloads.clear_confirm.title", @"Удалить все загрузки?")
                                                                   message:NSLocalizedString(@"app.downloads.clear_confirm.msg", @"Все сохраненные серии будут удалены с устройства.")
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"app.downloads.clear_all", @"Очистить")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction * _Nonnull action) {
        [[DownloadManager sharedInstance] deleteAllDownloads];
        [self reloadData];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"app.cancel", @"Отмена")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Table View Data Source & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _downloads.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 64.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DownloadsViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[DownloadsViewCell getIdentifier] forIndexPath:indexPath];
    if (indexPath.row < _downloads.count) {
        DownloadItem *item = _downloads[indexPath.row];
        cell.titleLabel.text = item.release_title.length > 0 ? item.release_title : @"Аниме";
        
        NSString *src = item.source_name.length > 0 ? [NSString stringWithFormat:@" • %@", item.source_name] : @"";
        cell.subtitleLabel.text = [NSString stringWithFormat:@"%@%@", item.episode_title, src];
        
        int64_t bytes = item.file_size;
        if (bytes < 1024 * 1024) {
            cell.sizeLabel.text = [NSString stringWithFormat:@"%.1f КБ", bytes / 1024.0];
        } else if (bytes < 1024 * 1024 * 1024) {
            cell.sizeLabel.text = [NSString stringWithFormat:@"%.1f МБ", bytes / (1024.0 * 1024.0)];
        } else {
            cell.sizeLabel.text = [NSString stringWithFormat:@"%.2f ГБ", bytes / (1024.0 * 1024.0 * 1024.0)];
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= _downloads.count) return;
    
    DownloadItem *item = _downloads[indexPath.row];
    NSString *localPath = [[DownloadManager sharedInstance] localFilePathForReleaseID:item.release_id position:item.position];
    if (localPath) {
        NSString *title = [NSString stringWithFormat:@"%@ - %@", item.release_title, item.episode_title];
        [[PlayerController sharedInstance] playLocalFileURL:[NSURL fileURLWithPath:localPath] title:title];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Файл не найден" message:@"Файл был перемещен или удален." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self reloadData];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if (indexPath.row < _downloads.count) {
            DownloadItem *item = _downloads[indexPath.row];
            [[DownloadManager sharedInstance] deleteDownloadWithReleaseID:item.release_id position:item.position];
            [self reloadData];
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return NSLocalizedString(@"app.delete", @"Удалить");
}

@end
