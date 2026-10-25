//
//  EpisodeSelectViewController.m
//  iOSAnixart
//
//  Created by Toilettrauma on 30.09.2024.
//

#import "EpisodeSelectViewController.h"
#import "LibanixartApi.h"
#import "AppColor.h"
#import "StringCvt.h"
#import "PlayerViewController.h"
#import "LoadableView.h"
#import "DownloadManager.h"
#import "DownloadsViewController.h"

static const std::string_view preferred_quality = "720";
static inline std::string choose_quality(const std::unordered_map<std::string, std::string>& quals, const std::string_view preferred) {
    if (quals.empty()) {
        return "";
    }
    std::string pref_str(preferred.data(), preferred.size());
    for (const auto& item : quals) {
        if (item.first == pref_str) {
            return item.second;
        }
    }
    long best_quality = -1;
    std::string best_url;
    for (const auto& item : quals) {
        long q_val = strtol(item.first.c_str(), nullptr, 10);
        if (q_val > best_quality || best_url.empty()) {
            best_quality = q_val;
            best_url = item.second;
        }
    }
    return best_url;
}

@interface EpisodeViewCell : UITableViewCell
@property(nonatomic, retain) UILabel* name_label;
@property(nonatomic, retain) UIImageView* watched_image_view;
@property(nonatomic, retain) UIButton* download_button;
@property(nonatomic, retain) UILabel* download_status_label;
@property(nonatomic, copy) void (^onDownloadTapped)(void);

+(NSString*)getIndentifier;

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuse_identifier;

-(void)setName:(NSString*)name;
-(void)setWatchedStatus:(BOOL)is_wached;
-(void)setDownloadStatusWithDownloaded:(BOOL)is_downloaded downloading:(BOOL)is_downloading progress:(float)progress;
@end

@interface EpisodeSelectViewController () {
    anixart::ReleaseID _release_id;
    anixart::EpisodeTypeID _type_id;
    anixart::EpisodeSourceID _source_id;
    std::vector<anixart::Episode::Ptr> _episodes;
}
@property(nonatomic, retain) NSString* type_name;
@property(nonatomic, retain) NSString* source_name;
@property(nonatomic, retain) LibanixartApi* api_proxy;
@property(nonatomic, retain) UIView* header_view;
@property(nonatomic, retain) UILabel* type_name_label;
@property(nonatomic, retain) UITableView* table_view;
@property(nonatomic, retain) LoadableView* loadable_view;

@property(nonatomic, retain) PlayerController* player_controller;
@end

@implementation EpisodeViewCell

+(NSString*)getIndentifier {
    return @"EpisodeViewCell";
}
-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuse_identifier {
    self = [super initWithStyle:style reuseIdentifier:reuse_identifier];
    
    [self setup];
    [self setupLayout];
    
    return self;
}
-(void)setup {
    _name_label = [UILabel new];
    
    _watched_image_view = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"eye"]];
    _watched_image_view.hidden = YES;
    
    _download_button = [UIButton buttonWithType:UIButtonTypeSystem];
    [_download_button setImage:[UIImage systemImageNamed:@"arrow.down.to.line"] forState:UIControlStateNormal];
    [_download_button addTarget:self action:@selector(downloadButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    
    _download_status_label = [UILabel new];
    _download_status_label.font = [UIFont systemFontOfSize:13];
    _download_status_label.textAlignment = NSTextAlignmentRight;
    _download_status_label.hidden = YES;
    
    [self.contentView addSubview:_name_label];
    [self.contentView addSubview:_download_status_label];
    [self.contentView addSubview:_download_button];
    [self.contentView addSubview:_watched_image_view];
    
    _name_label.translatesAutoresizingMaskIntoConstraints = NO;
    _watched_image_view.translatesAutoresizingMaskIntoConstraints = NO;
    _download_button.translatesAutoresizingMaskIntoConstraints = NO;
    _download_status_label.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [_name_label.leadingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
        [_name_label.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_name_label.trailingAnchor constraintLessThanOrEqualToAnchor:_download_status_label.leadingAnchor constant:-8],
        
        [_download_status_label.trailingAnchor constraintEqualToAnchor:_download_button.leadingAnchor constant:-6],
        [_download_status_label.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        
        [_download_button.trailingAnchor constraintEqualToAnchor:_watched_image_view.leadingAnchor constant:-10],
        [_download_button.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_download_button.widthAnchor constraintEqualToConstant:32],
        [_download_button.heightAnchor constraintEqualToConstant:32],
        
        [_watched_image_view.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],
        [_watched_image_view.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_watched_image_view.widthAnchor constraintEqualToConstant:28],
        [_watched_image_view.heightAnchor constraintEqualToConstant:20]
    ]];
}
-(void)setupLayout {
    self.backgroundColor = [AppColorProvider backgroundColor];
    _name_label.textColor = [AppColorProvider textColor];
    _watched_image_view.tintColor = [AppColorProvider textSecondaryColor];
    _download_button.tintColor = [AppColorProvider primaryColor];
}

-(void)downloadButtonAction:(id)sender {
    if (self.onDownloadTapped) {
        self.onDownloadTapped();
    }
}

-(void)setName:(NSString*)name {
    _name_label.text = name;
}

-(void)setWatchedStatus:(BOOL)is_wached {
    _watched_image_view.hidden = !is_wached;
}

-(void)setDownloadStatusWithDownloaded:(BOOL)is_downloaded downloading:(BOOL)is_downloading progress:(float)progress {
    if (is_downloaded) {
        _download_status_label.hidden = NO;
        _download_status_label.text = @"✓ Скачано";
        _download_status_label.textColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.4 alpha:1.0];
        _download_button.hidden = YES;
    } else if (is_downloading) {
        _download_status_label.hidden = NO;
        _download_status_label.text = [NSString stringWithFormat:@"%d%%", (int)(progress * 100)];
        _download_status_label.textColor = [UIColor systemBlueColor];
        _download_button.hidden = NO;
    } else {
        _download_status_label.hidden = YES;
        _download_button.hidden = NO;
    }
}

@end

@implementation EpisodeSelectViewController

-(instancetype)initWithReleaseID:(anixart::ReleaseID)release_id typeID:(anixart::EpisodeTypeID)type_id typeName:(NSString*)type_name sourceID:(anixart::EpisodeSourceID)source_id sourceName:(NSString*) source_name {
    self = [super init];
    
    _release_id = release_id;
    _type_id = type_id;
    _type_name = type_name;
    _source_id = source_id;
    _source_name = source_name;
    _api_proxy = [LibanixartApi sharedInstance];
    
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    
    [self preSetup];
    [self preSetupLayout];
    [self loadEpisodes];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)preSetup {
    self.navigationItem.title = NSLocalizedString(@"app.episode_select.nav_item.title", "");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.down.circle"]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(openDownloadsList:)];
    
    _loadable_view = [LoadableView new];
    
    [self.view addSubview:_loadable_view];
    
    _loadable_view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_loadable_view.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_loadable_view.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDownloadProgressNotification:) name:DownloadManagerProgressNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDownloadStatusChangedNotification:) name:DownloadManagerStatusChangedNotification object:nil];
}

-(void)openDownloadsList:(id)sender {
    [self.navigationController pushViewController:[DownloadsViewController new] animated:YES];
}

-(void)onDownloadProgressNotification:(NSNotification *)note {
    NSDictionary *ui = note.userInfo;
    if (!ui) return;
    long rel_id = [ui[@"release_id"] longLongValue];
    if (rel_id != _release_id) return;
    long pos = [ui[@"position"] longLongValue];
    
    for (NSInteger i = 0; i < (NSInteger)_episodes.size(); i++) {
        if (_episodes[i]->position == pos) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:i inSection:0];
            EpisodeViewCell *cell = [_table_view cellForRowAtIndexPath:ip];
            if (cell) {
                float prog = [ui[@"progress"] floatValue];
                [cell setDownloadStatusWithDownloaded:NO downloading:YES progress:prog];
            }
            break;
        }
    }
}

-(void)onDownloadStatusChangedNotification:(NSNotification *)note {
    NSDictionary *ui = note.userInfo;
    if (!ui) return;
    long rel_id = [ui[@"release_id"] longLongValue];
    if (rel_id != _release_id) return;
    long pos = [ui[@"position"] longLongValue];
    
    for (NSInteger i = 0; i < (NSInteger)_episodes.size(); i++) {
        if (_episodes[i]->position == pos) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:i inSection:0];
            [_table_view reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
            break;
        }
    }
}

-(void)setup {
    _table_view = [UITableView new];
    [_table_view registerClass:EpisodeViewCell.class forCellReuseIdentifier:[EpisodeViewCell getIndentifier]];
    _table_view.dataSource = self;
    _table_view.delegate = self;
    
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    _header_view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 55)];
    
    _type_name_label = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, screenWidth - 32, 35)];
    _type_name_label.text = [NSString stringWithFormat:@"%@ (%@)", _type_name, _source_name];
    _type_name_label.font = [UIFont boldSystemFontOfSize:25];
    _type_name_label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_header_view addSubview:_type_name_label];
    
    _table_view.tableHeaderView = _header_view;
    [self.view addSubview:_table_view];
    
    _table_view.translatesAutoresizingMaskIntoConstraints = NO;
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
        [_table_view.topAnchor constraintEqualToAnchor:topAnchor],
        [_table_view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_table_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_table_view.bottomAnchor constraintEqualToAnchor:bottomAnchor]
    ]];
}

-(void)preSetupLayout {
    self.view.backgroundColor = [AppColorProvider backgroundColor];
}

-(void)setupLayout {
    _table_view.backgroundColor = [AppColorProvider backgroundColor];
    _type_name_label.textColor = [AppColorProvider textColor];
}

-(void)loadEpisodes {
    [_loadable_view startLoading];
    [_api_proxy asyncCall:^BOOL(anixart::Api* api) {
        self->_episodes = api->episodes().get_release_episodes(self->_release_id, self->_type_id, self->_source_id, anixart::Episode::Sort::FromLeast);
        return NO;
    } completion:^(BOOL errored) {
        [self->_loadable_view endLoadingWithErrored:errored];
        if (!errored) {
            [self setup];
        }
    }];
}

-(NSInteger)tableView:(UITableView *)table_view numberOfRowsInSection:(NSInteger)section {
    return _episodes.size();
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}
-(UITableViewCell *)tableView:(UITableView *)table_view cellForRowAtIndexPath:(NSIndexPath *)index_path {
    EpisodeViewCell* cell = [table_view dequeueReusableCellWithIdentifier:[EpisodeViewCell getIndentifier] forIndexPath:index_path];
    NSInteger index = [index_path item];
    anixart::Episode::Ptr episode = _episodes[index];
    
    [cell setName:TO_NSSTRING(episode->name)];
    [cell setWatchedStatus:episode->is_watched];

    DownloadManager *dm = [DownloadManager sharedInstance];
    BOOL isDownloaded = [dm isEpisodeDownloadedWithReleaseID:_release_id position:episode->position];
    BOOL isDownloading = [dm isEpisodeDownloadingWithReleaseID:_release_id position:episode->position];
    float progress = [dm downloadProgressForReleaseID:_release_id position:episode->position];
    [cell setDownloadStatusWithDownloaded:isDownloaded downloading:isDownloading progress:progress];
    
    __weak EpisodeSelectViewController *weakSelf = self;
    cell.onDownloadTapped = ^{
        [weakSelf cellDownloadButtonActionPressed:index_path];
    };

    return cell;
}

-(UISwipeActionsConfiguration *)tableView:(UITableView *)table_view trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)index_path {
    NSInteger index = [index_path item];
    
    UIContextualAction* download_action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction *action, UIView *source_view, void (^completion_handler)(BOOL actionPerformed)) {
        [self cellDownloadButtonActionPressed:index_path];
        completion_handler(true);
    }];
    download_action.backgroundColor = [UIColor colorWithRed:0.37 green:0.62 blue:0.63 alpha:1.0];
    download_action.image = [UIImage systemImageNamed:@"arrow.down.to.line"];
    UIContextualAction* change_viewed_action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:nil handler:^(UIContextualAction *action, UIView *source_view, void (^completion_handler)(BOOL actionPerformed)) {
        [self cellChangeViewedActionPressed:index_path];
        completion_handler(true);
    }];
    if (!_episodes[index]->is_watched) {
        change_viewed_action.image = [UIImage systemImageNamed:@"eye"];
    } else {
        change_viewed_action.image = [UIImage systemImageNamed:@"eye.slash"];
    }
    
    return [UISwipeActionsConfiguration configurationWithActions:@[
        download_action,
        change_viewed_action
    ]];
}

-(NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger index = [indexPath item];
    UITableViewRowAction *downloadAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:NSLocalizedString(@"app.episodes.download", @"Скачать") handler:^(UITableViewRowAction *action, NSIndexPath *ip) {
        [self cellDownloadButtonActionPressed:ip];
        [tableView setEditing:NO animated:YES];
    }];
    downloadAction.backgroundColor = [UIColor colorWithRed:0.37 green:0.62 blue:0.63 alpha:1.0];
    
    NSString *viewedTitle = !_episodes[index]->is_watched ? NSLocalizedString(@"app.episodes.mark_viewed", @"Просмотрено") : NSLocalizedString(@"app.episodes.mark_unviewed", @"Не просмотрено");
    UITableViewRowAction *viewedAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:viewedTitle handler:^(UITableViewRowAction *action, NSIndexPath *ip) {
        [self cellChangeViewedActionPressed:ip];
        [tableView setEditing:NO animated:YES];
    }];
    viewedAction.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.8 alpha:1.0];
    
    return @[viewedAction, downloadAction];
}

-(void)tableView:(UITableView *)table_view didSelectRowAtIndexPath:(NSIndexPath *)index_path {
    NSInteger index = [index_path item];
    EpisodeViewCell* cell = [table_view cellForRowAtIndexPath:index_path];
    [table_view deselectRowAtIndexPath:index_path animated:YES];
    
    if (index < 0 || (size_t)index >= _episodes.size()) {
        return;
    }
    anixart::Episode::Ptr episode = _episodes[index];
    if (!episode) return;
    
    NSString *epTitle = TO_NSSTRING(episode->name);
    DownloadManager *dm = [DownloadManager sharedInstance];
    NSString *localPath = [dm localFilePathForReleaseID:_release_id position:episode->position];
    if (localPath) {
        // Play local file completely offline!
        NSString *fullTitle = [NSString stringWithFormat:@"%@ - %@", _type_name ?: @"", epTitle];
        [[PlayerController sharedInstance] playLocalFileURL:[NSURL fileURLWithPath:localPath] title:fullTitle];
        
        episode->is_watched = YES;
        [cell setWatchedStatus:YES];
        
        [_api_proxy performAsyncBlock:^BOOL(anixart::Api* api) {
            @try {
                api->episodes().add_watched_episode(self->_release_id, self->_source_id, episode->position);
            } @catch (id) {}
            return YES;
        } withUICompletion:nil];
        return;
    }
    
    @try {
        [[PlayerController sharedInstance] playWithReleaseID:_release_id sourceID:_source_id position:episode->position autoShow:YES completion:^(BOOL errored){
            if (errored) {
                return;
            }
            episode->is_watched = YES;
            [cell setWatchedStatus:YES];
            
            [self->_api_proxy performAsyncBlock:^BOOL(anixart::Api* api) {
                @try {
                    api->episodes().add_watched_episode(self->_release_id, self->_source_id, episode->position);
                } @catch (id) {}
                return YES;
            } withUICompletion:^{
                episode->is_watched = YES;
                [cell setWatchedStatus:YES];
            }];
        }];
    } @catch (NSException *e) {
        NSLog(@"[EpisodeSelectViewController] Exception starting player: %@", e);
    }
}

-(void)cellDownloadButtonActionPressed:(NSIndexPath*)index_path {
    NSInteger index = [index_path item];
    if (index < 0 || (size_t)index >= _episodes.size()) return;
    anixart::Episode::Ptr episode = _episodes[index];
    if (!episode) return;
    
    DownloadManager *dm = [DownloadManager sharedInstance];
    NSString *epTitle = TO_NSSTRING(episode->name);
    
    if ([dm isEpisodeDownloadedWithReleaseID:_release_id position:episode->position]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:epTitle
                                                                       message:NSLocalizedString(@"app.download.already_downloaded", @"Эта серия уже сохранена на устройстве.")
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"app.download.play_offline", @"Смотреть оффлайн")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            NSString *localPath = [dm localFilePathForReleaseID:self->_release_id position:episode->position];
            if (localPath) {
                NSString *fullTitle = [NSString stringWithFormat:@"%@ - %@", self->_type_name ?: @"", epTitle];
                [[PlayerController sharedInstance] playLocalFileURL:[NSURL fileURLWithPath:localPath] title:fullTitle];
            }
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"app.download.delete", @"Удалить загрузку")
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction * _Nonnull action) {
            [dm deleteDownloadWithReleaseID:self->_release_id position:episode->position];
            [self->_table_view reloadRowsAtIndexPaths:@[index_path] withRowAnimation:UITableViewRowAnimationNone];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"app.cancel", @"Отмена")
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        
        if (alert.popoverPresentationController) {
            UITableViewCell *cell = [self->_table_view cellForRowAtIndexPath:index_path];
            alert.popoverPresentationController.sourceView = cell ?: self.view;
            alert.popoverPresentationController.sourceRect = cell ? cell.bounds : CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
        }
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    if ([dm isEpisodeDownloadingWithReleaseID:_release_id position:episode->position]) {
        float prog = [dm downloadProgressForReleaseID:_release_id position:episode->position];
        NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"app.download.in_progress_msg", @"Серия скачивается... (%d%%)"), (int)(prog * 100)];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:epTitle
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"app.download.cancel_download", @"Отменить скачивание")
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction * _Nonnull action) {
            [dm cancelDownloadWithReleaseID:self->_release_id position:episode->position];
            [self->_table_view reloadRowsAtIndexPaths:@[index_path] withRowAnimation:UITableViewRowAnimationNone];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"app.close", @"Закрыть")
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        
        if (alert.popoverPresentationController) {
            UITableViewCell *cell = [self->_table_view cellForRowAtIndexPath:index_path];
            alert.popoverPresentationController.sourceView = cell ?: self.view;
            alert.popoverPresentationController.sourceRect = cell ? cell.bounds : CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
        }
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Start downloading
    EpisodeViewCell *cell = [_table_view cellForRowAtIndexPath:index_path];
    [cell setDownloadStatusWithDownloaded:NO downloading:YES progress:0.01f];
    
    __weak EpisodeSelectViewController *weakSelf = self;
    [_api_proxy performAsyncBlock:^BOOL(anixart::Api* api){
        try {
            auto ep_target = weakSelf->_api_proxy.api->episodes().get_episode_target(weakSelf->_release_id, weakSelf->_source_id, static_cast<int32_t>(episode->position));
            if (!ep_target || ep_target->url.empty()) {
                return NO;
            }
            auto streams_arr = weakSelf->_api_proxy.parsers->extract_info(ep_target->url);
            auto selected_stream = choose_quality(streams_arr, preferred_quality);
            if (selected_stream.empty()) {
                return NO;
            }
            NSURL *url = [NSURL URLWithString:TO_NSSTRING(selected_stream)];
            dispatch_async(dispatch_get_main_queue(), ^{
                [dm startDownloadWithURL:url
                               releaseID:weakSelf->_release_id
                                sourceID:weakSelf->_source_id
                                position:episode->position
                            releaseTitle:weakSelf->_type_name
                            episodeTitle:epTitle
                              sourceName:weakSelf->_source_name];
                [weakSelf->_table_view reloadRowsAtIndexPaths:@[index_path] withRowAnimation:UITableViewRowAnimationNone];
            });
            return YES;
        } catch (...) {
            return NO;
        }
    } withUICompletion:^{
        // finished
    }];
}

-(void)cellChangeViewedActionPressed:(NSIndexPath*)index_path {
    NSInteger index = [index_path item];
    EpisodeViewCell* cell = [_table_view cellForRowAtIndexPath:index_path];
    anixart::Episode::Ptr episode = _episodes[index];
    
    BOOL to_set_watched = !_episodes[index]->is_watched;
    /* pre set just for instant UI update. Then update to real state */
    episode->is_watched = to_set_watched;
    [cell setWatchedStatus:to_set_watched];
    
    [_api_proxy performAsyncBlock:^BOOL(anixart::Api* api) {
        if (to_set_watched) {
            api->episodes().add_watched_episode(self->_release_id, self->_source_id, episode->position);
        } else {
            api->episodes().remove_watched_episode(self->_release_id, self->_source_id, episode->position);
        }
        return YES;
    } withUICompletion:^{
        episode->is_watched = to_set_watched;
        [cell setWatchedStatus:to_set_watched];
    }];
}

@end
