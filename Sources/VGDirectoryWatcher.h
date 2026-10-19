#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A kernel-level directory watcher based on GCD vnode sources (kqueue/kevent).
///
/// It watches a directory for writes (new files, deletions, renames) and fires
/// the handler on a dedicated serial queue. vnode watches are non-recursive:
/// only direct children of the watched path trigger events, so the handler
/// should re-scan recursively when a change is reported.
///
/// This is the same mechanism used by the classic MHWDirectoryWatcher and by
/// apps that keep their Documents folder in sync with the system Files app.
@interface VGDirectoryWatcher : NSObject

/// The directory being watched.
@property (nonatomic, copy, readonly) NSString *watchedPath;

/// Creates a watcher but does not start it. Call -start to begin.
/// @param path The directory to watch (must exist).
/// @param handler Called on a dedicated serial queue whenever the directory changes.
- (instancetype)initWithPath:(NSString *)path handler:(void (^)(void))handler;

/// Begins watching. Returns NO if the directory cannot be opened.
- (BOOL)start;

/// Stops watching and releases the file descriptor. Safe to call multiple times.
- (void)stop;

@end

NS_ASSUME_NONNULL_END
