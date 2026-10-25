//
//  DownloadManager.mm
//  AniAnglia
//
//  Created for iOS 10.3.3 offline viewing support.
//

#import "DownloadManager.h"

static inline Float64 safe_CMTimeGetSeconds(CMTime t) {
    if ((t.flags & 1) == 0 || t.timescale <= 0) return 0.0;
    return (Float64)t.value / (Float64)t.timescale;
}

NSString *const DownloadManagerProgressNotification = @"DownloadManagerProgressNotification";
NSString *const DownloadManagerStatusChangedNotification = @"DownloadManagerStatusChangedNotification";

@implementation DownloadItem

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _status = DownloadItemStatusIdle;
        _progress = 0.0f;
        _date_added = [NSDate date];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [self init];
    if (self && [dict isKindOfClass:[NSDictionary class]]) {
        _release_id = [dict[@"release_id"] longLongValue];
        _source_id = [dict[@"source_id"] longLongValue];
        _position = [dict[@"position"] longLongValue];
        _release_title = [dict[@"release_title"] copy] ?: @"";
        _episode_title = [dict[@"episode_title"] copy] ?: @"";
        _source_name = [dict[@"source_name"] copy] ?: @"";
        _remote_url = [dict[@"remote_url"] copy] ?: @"";
        _relative_path = [dict[@"relative_path"] copy];
        _file_size = [dict[@"file_size"] longLongValue];
        _progress = [dict[@"progress"] floatValue];
        _status = (DownloadItemStatus)[dict[@"status"] integerValue];
        _error_message = [dict[@"error_message"] copy];
        
        NSTimeInterval dateVal = [dict[@"date_added"] doubleValue];
        if (dateVal > 0) {
            _date_added = [NSDate dateWithTimeIntervalSince1970:dateVal];
        }
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *d = [NSMutableDictionary new];
    d[@"release_id"] = @(_release_id);
    d[@"source_id"] = @(_source_id);
    d[@"position"] = @(_position);
    d[@"release_title"] = _release_title ?: @"";
    d[@"episode_title"] = _episode_title ?: @"";
    d[@"source_name"] = _source_name ?: @"";
    d[@"remote_url"] = _remote_url ?: @"";
    if (_relative_path) d[@"relative_path"] = _relative_path;
    d[@"file_size"] = @(_file_size);
    d[@"progress"] = @(_progress);
    d[@"status"] = @((NSInteger)_status);
    if (_error_message) d[@"error_message"] = _error_message;
    if (_date_added) d[@"date_added"] = @([_date_added timeIntervalSince1970]);
    return [d copy];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:[self toDictionary] forKey:@"data"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NSDictionary *d = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], [NSNumber class], nil] forKey:@"data"];
    return [self initWithDictionary:d];
}

@end

@interface DownloadManager () {
    NSMutableDictionary<NSString *, DownloadItem *> *_items;
    NSMutableDictionary<NSString *, NSURLSessionTask *> *_activeTasks;
    dispatch_queue_t _syncQueue;
}

@property (nonatomic, retain) AVAssetDownloadURLSession *hlsSession;
@property (nonatomic, retain) NSURLSession *fileSession;

@end

@implementation DownloadManager

+ (instancetype)sharedInstance {
    static DownloadManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DownloadManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _items = [NSMutableDictionary new];
        _activeTasks = [NSMutableDictionary new];
        _syncQueue = dispatch_queue_create("ru.anixart.download_sync_queue", DISPATCH_QUEUE_SERIAL);
        
        [self ensureDirectoriesExist];
        [self loadDownloadsIndex];
        [self initSessions];
    }
    return self;
}

- (NSString *)downloadsDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [paths firstObject];
    return [docDir stringByAppendingPathComponent:@"Downloads"];
}

- (NSString *)indexFilePath {
    return [[self downloadsDirectory] stringByAppendingPathComponent:@"downloads.json"];
}

- (void)ensureDirectoriesExist {
    NSString *downloadsDir = [self downloadsDirectory];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:downloadsDir]) {
        [fm createDirectoryAtPath:downloadsDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

- (void)initSessions {
    // 1. HLS AVAssetDownloadURLSession (iOS 10+)
    NSURLSessionConfiguration *hlsConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"ru.anixart.AniAnglia.hls_download"];
    hlsConfig.timeoutIntervalForRequest = 60.0;
    self.hlsSession = [AVAssetDownloadURLSession sessionWithConfiguration:hlsConfig
                                                    assetDownloadDelegate:self
                                                            delegateQueue:[NSOperationQueue mainQueue]];
    
    // 2. File NSURLSession
    NSURLSessionConfiguration *fileConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"ru.anixart.AniAnglia.file_download"];
    fileConfig.timeoutIntervalForRequest = 60.0;
    self.fileSession = [NSURLSession sessionWithConfiguration:fileConfig
                                                     delegate:self
                                                delegateQueue:[NSOperationQueue mainQueue]];
    
    // Restore existing tasks if any
    [self.hlsSession getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask *> * _Nonnull tasks) {
        for (NSURLSessionTask *t in tasks) {
            if (t.taskDescription) {
                self->_activeTasks[t.taskDescription] = t;
            }
        }
    }];
    [self.fileSession getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask *> * _Nonnull tasks) {
        for (NSURLSessionTask *t in tasks) {
            if (t.taskDescription) {
                self->_activeTasks[t.taskDescription] = t;
            }
        }
    }];
}

- (NSString *)taskKeyForReleaseID:(long)release_id position:(long)position {
    return [NSString stringWithFormat:@"%ld_%ld", release_id, position];
}

#pragma mark - Persistence

- (void)loadDownloadsIndex {
    dispatch_sync(_syncQueue, ^{
        NSString *path = [self indexFilePath];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data) return;
        
        NSError *err = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
        if (!err && [json isKindOfClass:[NSDictionary class]]) {
            NSArray *itemsArr = json[@"items"];
            if ([itemsArr isKindOfClass:[NSArray class]]) {
                for (NSDictionary *d in itemsArr) {
                    DownloadItem *item = [[DownloadItem alloc] initWithDictionary:d];
                    NSString *key = [self taskKeyForReleaseID:item.release_id position:item.position];
                    
                    // Verify completed items still exist on disk
                    if (item.status == DownloadItemStatusCompleted && item.relative_path) {
                        NSString *fullPath = [NSHomeDirectory() stringByAppendingPathComponent:item.relative_path];
                        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
                            self->_items[key] = item;
                        }
                    } else if (item.status == DownloadItemStatusDownloading) {
                        // Mark as failed if not active across cold boot
                        item.status = DownloadItemStatusFailed;
                        item.error_message = @"Прервано";
                        self->_items[key] = item;
                    } else {
                        self->_items[key] = item;
                    }
                }
            }
        }
    });
}

- (void)saveDownloadsIndex {
    dispatch_sync(_syncQueue, ^{
        NSMutableArray *arr = [NSMutableArray new];
        for (DownloadItem *item in self->_items.allValues) {
            [arr addObject:[item toDictionary]];
        }
        NSDictionary *root = @{@"items": arr};
        NSError *err = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:&err];
        if (data && !err) {
            [data writeToFile:[self indexFilePath] atomically:YES];
        }
    });
}

#pragma mark - Query

- (BOOL)isEpisodeDownloadedWithReleaseID:(long)release_id position:(long)position {
    __block BOOL res = NO;
    dispatch_sync(_syncQueue, ^{
        NSString *key = [self taskKeyForReleaseID:release_id position:position];
        DownloadItem *item = self->_items[key];
        if (item && item.status == DownloadItemStatusCompleted && item.relative_path) {
            NSString *fullPath = [NSHomeDirectory() stringByAppendingPathComponent:item.relative_path];
            res = [[NSFileManager defaultManager] fileExistsAtPath:fullPath];
        }
    });
    return res;
}

- (BOOL)isEpisodeDownloadingWithReleaseID:(long)release_id position:(long)position {
    __block BOOL res = NO;
    dispatch_sync(_syncQueue, ^{
        NSString *key = [self taskKeyForReleaseID:release_id position:position];
        DownloadItem *item = self->_items[key];
        res = (item && item.status == DownloadItemStatusDownloading);
    });
    return res;
}

- (float)downloadProgressForReleaseID:(long)release_id position:(long)position {
    __block float prog = 0.0f;
    dispatch_sync(_syncQueue, ^{
        NSString *key = [self taskKeyForReleaseID:release_id position:position];
        DownloadItem *item = self->_items[key];
        if (item) {
            prog = item.progress;
        }
    });
    return prog;
}

- (NSString *)localFilePathForReleaseID:(long)release_id position:(long)position {
    __block NSString *path = nil;
    dispatch_sync(_syncQueue, ^{
        NSString *key = [self taskKeyForReleaseID:release_id position:position];
        DownloadItem *item = self->_items[key];
        if (item && item.status == DownloadItemStatusCompleted && item.relative_path) {
            NSString *fullPath = [NSHomeDirectory() stringByAppendingPathComponent:item.relative_path];
            if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
                path = fullPath;
            }
        }
    });
    return path;
}

- (DownloadItem *)downloadItemForReleaseID:(long)release_id position:(long)position {
    __block DownloadItem *res = nil;
    dispatch_sync(_syncQueue, ^{
        NSString *key = [self taskKeyForReleaseID:release_id position:position];
        res = self->_items[key];
    });
    return res;
}

- (NSArray<DownloadItem *> *)allCompletedDownloads {
    __block NSMutableArray<DownloadItem *> *arr = [NSMutableArray new];
    dispatch_sync(_syncQueue, ^{
        for (DownloadItem *it in self->_items.allValues) {
            if (it.status == DownloadItemStatusCompleted && it.relative_path) {
                NSString *full = [NSHomeDirectory() stringByAppendingPathComponent:it.relative_path];
                if ([[NSFileManager defaultManager] fileExistsAtPath:full]) {
                    [arr addObject:it];
                }
            }
        }
    });
    [arr sortUsingComparator:^NSComparisonResult(DownloadItem *obj1, DownloadItem *obj2) {
        return [obj2.date_added compare:obj1.date_added];
    }];
    return [arr copy];
}

- (NSArray<DownloadItem *> *)allActiveDownloads {
    __block NSMutableArray<DownloadItem *> *arr = [NSMutableArray new];
    dispatch_sync(_syncQueue, ^{
        for (DownloadItem *it in self->_items.allValues) {
            if (it.status == DownloadItemStatusDownloading) {
                [arr addObject:it];
            }
        }
    });
    return [arr copy];
}

- (int64_t)totalDownloadedBytes {
    NSArray<DownloadItem *> *all = [self allCompletedDownloads];
    int64_t total = 0;
    for (DownloadItem *it in all) {
        total += it.file_size;
    }
    return total;
}

- (NSString *)formattedTotalSize {
    int64_t bytes = [self totalDownloadedBytes];
    if (bytes < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f КБ", bytes / 1024.0];
    } else if (bytes < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f МБ", bytes / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.2f ГБ", bytes / (1024.0 * 1024.0 * 1024.0)];
    }
}

- (int64_t)folderSizeAtPath:(NSString *)folderPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:folderPath isDirectory:&isDir]) return 0;
    if (!isDir) {
        NSDictionary *attrs = [fm attributesOfItemAtPath:folderPath error:nil];
        return [attrs fileSize];
    }
    int64_t total = 0;
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:folderPath];
    NSString *sub = nil;
    while ((sub = [enumerator nextObject])) {
        NSString *fullSub = [folderPath stringByAppendingPathComponent:sub];
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullSub error:nil];
        total += [attrs fileSize];
    }
    return total;
}

#pragma mark - Notifications

- (void)notifyProgressForItem:(DownloadItem *)item {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DownloadManagerProgressNotification
                                                            object:self
                                                          userInfo:@{
                                                              @"release_id": @(item.release_id),
                                                              @"position": @(item.position),
                                                              @"progress": @(item.progress)
                                                          }];
    });
}

- (void)notifyStatusForItem:(DownloadItem *)item {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DownloadManagerStatusChangedNotification
                                                            object:self
                                                          userInfo:@{
                                                              @"release_id": @(item.release_id),
                                                              @"position": @(item.position),
                                                              @"status": @(item.status)
                                                          }];
    });
}

#pragma mark - Actions

- (void)startDownloadWithURL:(NSURL *)streamURL
                   releaseID:(long)release_id
                    sourceID:(long)source_id
                    position:(long)position
                releaseTitle:(NSString *)release_title
                episodeTitle:(NSString *)episode_title
                  sourceName:(NSString *)source_name {
    
    NSString *key = [self taskKeyForReleaseID:release_id position:position];
    
    __block DownloadItem *item = nil;
    dispatch_sync(_syncQueue, ^{
        item = self->_items[key];
        if (!item) {
            item = [DownloadItem new];
            item.release_id = release_id;
            item.source_id = source_id;
            item.position = position;
            self->_items[key] = item;
        }
        item.release_title = release_title ?: @"";
        item.episode_title = episode_title ?: @"";
        item.source_name = source_name ?: @"";
        item.remote_url = streamURL.absoluteString;
        item.status = DownloadItemStatusDownloading;
        item.progress = 0.01f;
        item.error_message = nil;
        item.date_added = [NSDate date];
    });
    
    [self saveDownloadsIndex];
    [self notifyStatusForItem:item];
    
    NSString *urlString = streamURL.absoluteString;
    
    // Check if Kodik direct mp4 is possible
    if ([urlString containsString:@":hls:manifest.m3u8"]) {
        NSString *directMp4Str = [urlString stringByReplacingOccurrencesOfString:@":hls:manifest.m3u8" withString:@""];
        NSURL *directUrl = [NSURL URLWithString:directMp4Str];
        
        NSMutableURLRequest *headReq = [NSMutableURLRequest requestWithURL:directUrl cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:3.0];
        headReq.HTTPMethod = @"HEAD";
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:headReq completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (!error && (http.statusCode == 200 || http.statusCode == 206)) {
                NSLog(@"[DownloadManager] Kodik direct MP4 supported, downloading file directly: %@", directUrl);
                [self startFileDownloadWithURL:directUrl key:key item:item];
            } else {
                NSLog(@"[DownloadManager] Kodik direct MP4 unavailable (%ld), falling back to HLS stream: %@", (long)http.statusCode, streamURL);
                [self startHlsDownloadWithURL:streamURL key:key item:item];
            }
        }] resume];
        return;
    }
    
    // If it's a standard m3u8 playlist
    if ([urlString containsString:@".m3u8"]) {
        [self startHlsDownloadWithURL:streamURL key:key item:item];
    } else {
        // Direct media file
        [self startFileDownloadWithURL:streamURL key:key item:item];
    }
}

- (void)startHlsDownloadWithURL:(NSURL *)url key:(NSString *)key item:(DownloadItem *)item {
    dispatch_async(dispatch_get_main_queue(), ^{
        AVURLAsset *asset = [AVURLAsset assetWithURL:url];
        NSString *assetTitle = [NSString stringWithFormat:@"%@ - %@", item.release_title, item.episode_title];
        AVAssetDownloadTask *task = [self.hlsSession assetDownloadTaskWithURLAsset:asset
                                                                       assetTitle:assetTitle
                                                                 assetArtworkData:nil
                                                                          options:nil];
        task.taskDescription = key;
        self->_activeTasks[key] = task;
        [task resume];
        NSLog(@"[DownloadManager] Started AVAssetDownloadTask for %@", key);
    });
}

- (void)startFileDownloadWithURL:(NSURL *)url key:(NSString *)key item:(DownloadItem *)item {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        [req setValue:@"Mozilla/5.0 (iPad; CPU OS 10_3_3 like Mac OS X) AppleWebKit/603.3.8" forHTTPHeaderField:@"User-Agent"];
        NSURLSessionDownloadTask *task = [self.fileSession downloadTaskWithRequest:req];
        task.taskDescription = key;
        self->_activeTasks[key] = task;
        [task resume];
        NSLog(@"[DownloadManager] Started NSURLSessionDownloadTask for %@", key);
    });
}

- (void)cancelDownloadWithReleaseID:(long)release_id position:(long)position {
    NSString *key = [self taskKeyForReleaseID:release_id position:position];
    NSURLSessionTask *task = _activeTasks[key];
    if (task) {
        [task cancel];
        [_activeTasks removeObjectForKey:key];
    }
    dispatch_sync(_syncQueue, ^{
        [self->_items removeObjectForKey:key];
    });
    [self saveDownloadsIndex];
    
    DownloadItem *item = [DownloadItem new];
    item.release_id = release_id;
    item.position = position;
    item.status = DownloadItemStatusIdle;
    [self notifyStatusForItem:item];
}

- (void)deleteDownloadWithReleaseID:(long)release_id position:(long)position {
    NSString *key = [self taskKeyForReleaseID:release_id position:position];
    NSString *path = [self localFilePathForReleaseID:release_id position:position];
    if (path) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    dispatch_sync(_syncQueue, ^{
        [self->_items removeObjectForKey:key];
    });
    [self saveDownloadsIndex];
    
    DownloadItem *item = [DownloadItem new];
    item.release_id = release_id;
    item.position = position;
    item.status = DownloadItemStatusIdle;
    [self notifyStatusForItem:item];
}

- (void)deleteAllDownloads {
    NSArray<DownloadItem *> *items = [self allCompletedDownloads];
    for (DownloadItem *it in items) {
        [self deleteDownloadWithReleaseID:it.release_id position:it.position];
    }
}

#pragma mark - AVAssetDownloadDelegate (HLS)

- (void)URLSession:(NSURLSession *)session assetDownloadTask:(AVAssetDownloadTask *)assetDownloadTask didLoadTimeRange:(CMTimeRange)timeRange totalTimeRangesLoaded:(NSArray<NSValue *> *)loadedTimeRanges timeRangeExpectedToLoad:(CMTimeRange)timeRangeExpectedToLoad {
    NSTimeInterval loadedSeconds = 0;
    for (NSValue *val in loadedTimeRanges) {
        CMTimeRange range = [val CMTimeRangeValue];
        loadedSeconds += safe_CMTimeGetSeconds(range.duration);
    }
    NSTimeInterval totalSeconds = safe_CMTimeGetSeconds(timeRangeExpectedToLoad.duration);
    float progress = (totalSeconds > 0) ? (float)(loadedSeconds / totalSeconds) : 0.0f;
    if (progress > 1.0f) progress = 1.0f;
    
    NSString *key = assetDownloadTask.taskDescription;
    if (!key) return;
    
    DownloadItem *item = nil;
    @synchronized (self) {
        item = _items[key];
        if (item) {
            item.progress = progress;
        }
    }
    if (item) {
        [self notifyProgressForItem:item];
    }
}

- (void)URLSession:(NSURLSession *)session assetDownloadTask:(AVAssetDownloadTask *)assetDownloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSLog(@"[DownloadManager] AVAssetDownloadTask finished to: %@", location);
    NSString *key = assetDownloadTask.taskDescription;
    if (!key) return;
    
    NSString *fullPath = [location path];
    NSString *home = NSHomeDirectory();
    NSString *relPath = fullPath;
    if ([fullPath hasPrefix:home]) {
        relPath = [fullPath substringFromIndex:home.length];
        if ([relPath hasPrefix:@"/"]) {
            relPath = [relPath substringFromIndex:1];
        }
    }
    
    DownloadItem *item = nil;
    @synchronized (self) {
        item = _items[key];
        if (item) {
            item.relative_path = relPath;
            item.status = DownloadItemStatusCompleted;
            item.progress = 1.0f;
            item.file_size = [self folderSizeAtPath:fullPath];
        }
        [_activeTasks removeObjectForKey:key];
    }
    if (item) {
        [self saveDownloadsIndex];
        [self notifyStatusForItem:item];
    }
}

#pragma mark - NSURLSessionDownloadDelegate (Direct MP4)

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    float progress = (totalBytesExpectedToWrite > 0) ? (float)totalBytesWritten / (float)totalBytesExpectedToWrite : 0.0f;
    if (progress > 1.0f) progress = 1.0f;
    
    NSString *key = downloadTask.taskDescription;
    if (!key) return;
    
    DownloadItem *item = nil;
    @synchronized (self) {
        item = _items[key];
        if (item) {
            item.progress = progress;
            item.file_size = (totalBytesExpectedToWrite > 0) ? totalBytesExpectedToWrite : totalBytesWritten;
        }
    }
    if (item) {
        [self notifyProgressForItem:item];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSString *key = downloadTask.taskDescription;
    if (!key) return;
    
    NSArray *parts = [key componentsSeparatedByString:@"_"];
    if (parts.count < 2) return;
    long rel_id = [parts[0] longLongValue];
    long pos = [parts[1] longLongValue];
    
    NSString *destDir = [self downloadsDirectory];
    NSString *destFilename = [NSString stringWithFormat:@"release_%ld_ep_%ld.mp4", rel_id, pos];
    NSString *destPath = [destDir stringByAppendingPathComponent:destFilename];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:destPath error:nil];
    
    NSError *moveErr = nil;
    [fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:destPath] error:&moveErr];
    if (moveErr) {
        NSLog(@"[DownloadManager] Failed moving downloaded file to %@: %@", destPath, moveErr);
    }
    
    NSString *home = NSHomeDirectory();
    NSString *relPath = destPath;
    if ([destPath hasPrefix:home]) {
        relPath = [destPath substringFromIndex:home.length];
        if ([relPath hasPrefix:@"/"]) {
            relPath = [relPath substringFromIndex:1];
        }
    }
    
    DownloadItem *item = nil;
    @synchronized (self) {
        item = _items[key];
        if (item) {
            item.relative_path = relPath;
            item.status = DownloadItemStatusCompleted;
            item.progress = 1.0f;
            NSDictionary *attrs = [fm attributesOfItemAtPath:destPath error:nil];
            item.file_size = [attrs fileSize];
        }
        [_activeTasks removeObjectForKey:key];
    }
    if (item) {
        [self saveDownloadsIndex];
        [self notifyStatusForItem:item];
    }
}

#pragma mark - General NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    NSString *key = task.taskDescription;
    if (!key) return;
    
    DownloadItem *item = nil;
    @synchronized (self) {
        item = _items[key];
        [_activeTasks removeObjectForKey:key];
        if (item) {
            if (error) {
                if (error.code == NSURLErrorCancelled) {
                    [_items removeObjectForKey:key];
                    item = nil;
                } else {
                    NSLog(@"[DownloadManager] Task failed for %@: %@", key, error);
                    item.status = DownloadItemStatusFailed;
                    item.error_message = error.localizedDescription;
                }
            } else if (item.status != DownloadItemStatusCompleted) {
                item.status = DownloadItemStatusCompleted;
                item.progress = 1.0f;
            }
        }
    }
    [self saveDownloadsIndex];
    if (item) {
        [self notifyStatusForItem:item];
    }
}

@end
