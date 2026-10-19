TARGET := iphone:clang:17.0:15.0
ARCHS = arm64

PYFW_DIR ?= $(PWD)/vendor/ios-arm64
FFMPEG_DIR ?= /home/runner/ffmpeg-ios

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = VidGrab

VidGrab_FILES = $(wildcard Sources/*.m) Sources/vgconvert.c whisper/ggml.c whisper/ggml-alloc.c whisper/ggml-backend.c whisper/ggml-quants.c whisper/whisper.cpp
VidGrab_FRAMEWORKS = Accelerate PhotosUI UIKit Foundation AVFoundation AVKit CoreMedia Photos JavaScriptCore CoreVideo WebKit LocalAuthentication MediaPlayer UserNotifications Security AudioToolbox UniformTypeIdentifiers Network
VidGrab_CFLAGS = -fobjc-arc -target arm64-apple-ios15.0 -F$(PYFW_DIR) -Wno-deprecated-declarations -Wno-unused-function -I$(FFMPEG_DIR)/include -Iwhisper -DGGML_USE_ACCELERATE -DNDEBUG -O3
VidGrab_LDFLAGS = -fuse-ld=lld -target arm64-apple-ios15.0 -F$(PYFW_DIR) -framework Python -Wl,-rpath,@executable_path/Frameworks -Wl,-all_load -L$(FFMPEG_DIR)/lib -lavformat -lavcodec -lswresample -lavutil -lc++
VidGrab_CODESIGN_FLAGS = -S

include $(THEOS_MAKE_PATH)/application.mk
