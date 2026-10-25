//
//  DownloadManager.h
//  AniAnglia
//
//  Created for iOS 10.3.3 offline viewing support.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const DownloadManagerProgressNotification;
extern NSString *const DownloadManagerStatusChangedNotification;

typedef NS_ENUM(NSInteger, DownloadItemStatus) {
    DownloadItemStatusIdle = 0,
    DownloadItemStatusDownloading = 1,
    DownloadItemStatusCompleted = 2,
    DownloadItemStatusFailed = 3
};

@interface DownloadItem : NSObject <NSSecureCoding>

@property (nonatomic, assign) long release_id;
@property (nonatomic, assign) long source_id;
@property (nonatomic, assign) long position;
@property (nonatomic, copy) NSString *release_title;
@property (nonatomic, copy) NSString *episode_title;
@property (nonatomic, copy) NSString *source_name;
@property (nonatomic, copy) NSString *remote_url;
@property (nonatomic, copy, nullable) NSString *relative_path;
@property (nonatomic, assign) int64_t file_size;
@property (nonatomic, assign) float progress;
@property (nonatomic, assign) DownloadItemStatus status;
@property (nonatomic, copy, nullable) NSString *error_message;
@property (nonatomic, retain) NSDate *date_added;

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;

@end

@interface DownloadManager : NSObject <AVAssetDownloadDelegate, NSURLSessionDownloadDelegate>

+ (instancetype)sharedInstance;

// Query
- (BOOL)isEpisodeDownloadedWithReleaseID:(long)release_id position:(long)position;
- (BOOL)isEpisodeDownloadingWithReleaseID:(long)release_id position:(long)position;
- (float)downloadProgressForReleaseID:(long)release_id position:(long)position;
- (nullable NSString *)localFilePathForReleaseID:(long)release_id position:(long)position;
- (nullable DownloadItem *)downloadItemForReleaseID:(long)release_id position:(long)position;

- (NSArray<DownloadItem *> *)allCompletedDownloads;
- (NSArray<DownloadItem *> *)allActiveDownloads;
- (int64_t)totalDownloadedBytes;
- (NSString *)formattedTotalSize;

// Actions
- (void)startDownloadWithURL:(NSURL *)streamURL
                   releaseID:(long)release_id
                    sourceID:(long)source_id
                    position:(long)position
                releaseTitle:(NSString *)release_title
                episodeTitle:(NSString *)episode_title
                  sourceName:(NSString *)source_name;

- (void)cancelDownloadWithReleaseID:(long)release_id position:(long)position;
- (void)deleteDownloadWithReleaseID:(long)release_id position:(long)position;
- (void)deleteAllDownloads;

@end

NS_ASSUME_NONNULL_END
