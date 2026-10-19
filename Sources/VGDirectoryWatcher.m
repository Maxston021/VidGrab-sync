#import "VGDirectoryWatcher.h"
#include <sys/types.h>
#include <sys/event.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

@interface VGDirectoryWatcher ()
@property (nonatomic, copy) NSString *watchedPath;
@property (nonatomic, copy) void (^handler)(void);
@property (nonatomic) int dirFD;
@property (nonatomic, strong) dispatch_source_t source;
@property (nonatomic, strong) dispatch_queue_t watcherQueue;
@end

@implementation VGDirectoryWatcher

- (instancetype)initWithPath:(NSString *)path handler:(void (^)(void))handler {
    self = [super init];
    if (self) {
        _watchedPath = [path copy];
        _handler = [handler copy];
        _dirFD = -1;
        _watcherQueue = dispatch_queue_create("com.t4mag0.vidgrab.directorywatcher", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)start {
    if (self.source) return YES;   // already running
    if (!self.watchedPath.length) return NO;

    // Open the directory to get a file descriptor for kqueue.
    const char *path = [self.watchedPath fileSystemRepresentation];
    int fd = open(path, O_EVTONLY);
    if (fd == -1) return NO;
    self.dirFD = fd;

    // Create a GCD vnode source: the kernel fires it when directory entries are written.
    // DISPATCH_VNODE_WRITE covers creates, deletes, renames and writes inside the directory.
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,
                                                      (uintptr_t)fd,
                                                      DISPATCH_VNODE_WRITE,
                                                      self.watcherQueue);
    if (!source) {
        close(fd);
        self.dirFD = -1;
        return NO;
    }

    __weak typeof(self) ws = self;
    dispatch_source_set_event_handler(source, ^{
        __strong typeof(ws) s = ws;
        if (!s) return;
        // Drain any pending events, then call the handler.
        // vnode events are coalesced; a single callback may represent multiple changes.
        if (s.handler) s.handler();
    });

    dispatch_source_set_cancel_handler(source, ^{
        __strong typeof(ws) s = ws;
        if (!s) return;
        if (s.dirFD != -1) {
            close(s.dirFD);
            s.dirFD = -1;
        }
    });

    self.source = source;
    dispatch_resume(source);
    return YES;
}

- (void)stop {
    if (self.source) {
        dispatch_source_cancel(self.source);
        self.source = nil;
    }
}

- (void)dealloc {
    [self stop];
}

@end
