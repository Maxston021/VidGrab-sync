// VidGrab converter core (plain C on top of FFmpeg).
// Repackages H.264/HEVC videos into MP4 and converts audio to AAC (M4A) or MP3.
#ifndef VGCONVERT_H
#define VGCONVERT_H

#include <stddef.h>

typedef int (*vg_cancel_cb)(void *ctx);
typedef void (*vg_progress_cb)(void *ctx, double fraction);

typedef struct {
    char video[32];      // codec name, "" if none (e.g. "h264", "hevc", "vp9")
    char audio[32];      // codec name, "" if none (e.g. "aac", "opus")
    char container[64];  // e.g. "mpegts", "matroska,webm", "mov,mp4,m4a,3gp,3g2,mj2"
    double duration;     // seconds, 0 if unknown
} VGProbe;

enum { VG_OK = 0, VG_ERROR = -1, VG_CANCELLED = -2 };

typedef struct {
    int width;
    int height;
    int hadAudio;
    char audioIn[32];
    int leadingDropped;
    char strategy[256];
    long videoIn;
    long videoLost;
    long videoOut;
    int discontinuities;
    double expectedDuration;
    double gapSeconds;
} VGMuxInfo;

int vg_probe(const char *path, VGProbe *out);

/// Writes one line per stream in the file (type, codec, size) for diagnostics.
int vg_describe(const char *path, char *buf, size_t n);

/// Scans the first bytes of a file for MPEG-TS characteristics.
int vg_ts_scan(const char *path, char *buf, size_t n, long *scrambled, int *isTS);

/// Cleans junk/padding from an MPEG-TS file before remuxing.
int vg_ts_clean(const char *in, const char *out, long long *junkBytes, long *pieces, int *needed,
                vg_progress_cb progress, vg_cancel_cb cancel, void *ctx,
                char *err, size_t errlen);

/// Copies H.264/HEVC video into an MP4 (no quality loss). Audio is copied if AAC,
/// otherwise converted to AAC. Fails if the video codec can't go in MP4 as-is.
int vg_remux_mp4(const char *in, const char *out,
                 vg_progress_cb progress, vg_cancel_cb cancel, void *ctx,
                 char *err, size_t errlen);

/// Like vg_remux_mp4, but takes the video from videoIn and the sound from audioIn
/// (e.g. YouTube's separate video and audio downloads). audioIn may be NULL.
int vg_mux_mp4(const char *videoIn, const char *audioIn, const char *out,
               vg_progress_cb progress, vg_cancel_cb cancel, void *ctx,
               char *err, size_t errlen);

/// Extended mux that returns detailed info about the muxing process.
int vg_mux_mp4_ex(const char *videoIn, const char *audioIn, const char *out, VGMuxInfo *info,
                  vg_progress_cb progress, vg_cancel_cb cancel, void *ctx,
                  char *err, size_t errlen);

/// Validates that an MP4 file opens, starts on a keyframe, and decodes.
int vg_validate_mp4(const char *path, double expectDur, int wantAudio,
                    char *summary, size_t sumlen, char *err, size_t errlen);

/// Converts the first audio stream to AAC in an .m4a (mp3 = 0) or to MP3 (mp3 = 1).
int vg_audio(const char *in, const char *out, int mp3, int bitrate,
             const char *title, const char *artist,
             vg_progress_cb progress, vg_cancel_cb cancel, void *ctx,
             char *err, size_t errlen);

/// Converts the first audio stream to WAV.
int vg_audio_wav(const char *in, const char *out,
                 vg_progress_cb progress, vg_cancel_cb cancel, void *ctx,
                 char *err, size_t errlen);

#ifdef __OBJC__
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VGConvert : NSObject

+ (NSDictionary<NSString *, NSString *> *)probe:(NSString *)path;
+ (NSString *)describe:(NSString *)path;
+ (NSDictionary<NSString *, id> *)tsScan:(NSString *)path;
+ (nullable NSDictionary<NSString *, id> *)tsClean:(NSString *)path to:(NSString *)output;

- (void)cancel;
- (void)run:(int (^)(char *err, size_t n))work completion:(void (^)(NSString * _Nullable))completion;
- (void)remux:(NSString *)input to:(NSString *)output progress:(void (^)(double))progress completion:(void (^)(NSString * _Nullable))completion;
- (void)mux:(NSString *)video audio:(nullable NSString *)audio to:(NSString *)output progress:(void (^)(double))progress completion:(void (^)(NSString * _Nullable, NSDictionary<NSString *, id> *))completion;
- (void)merge:(NSString *)video audio:(NSString *)audio to:(NSString *)output progress:(void (^)(double))progress completion:(void (^)(NSString * _Nullable))completion;
- (void)audio:(NSString *)input to:(NSString *)output mp3:(BOOL)mp3 title:(nullable NSString *)title artist:(nullable NSString *)artist progress:(void (^)(double))progress completion:(void (^)(NSString * _Nullable))completion;
- (void)wavFrom:(NSString *)input to:(NSString *)output progress:(void (^)(double))progress completion:(void (^)(NSString * _Nullable))completion;

@end

NS_ASSUME_NONNULL_END
#endif

#endif
