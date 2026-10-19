#!/bin/bash
# Rebuilds the FFmpeg static libraries VidGrab links (iOS arm64, iOS 15+)
set -euo pipefail

# Determine toolchain path
T=${THEOS:-/root/theos}/toolchain/linux/iphone/bin
if [ ! -x "$T/clang" ]; then
  T=$(dirname $(which clang))
fi
echo "Using toolchain: $T"
echo "Clang: $T/clang"
$T/clang --version || true

SDK=${THEOS:-/root/theos}/sdks/iPhoneOS17.0.sdk
SRC=${FFMPEG_SRC:-/root/ffmpeg-src}
DEST=${FFMPEG_DEST:-/root/ffmpeg-ios}
BUILD=$(mktemp -d /tmp/ffmpeg-ios-build.XXXXXX)
STAGE=$BUILD/stage

echo "SDK: $SDK"
echo "Source: $SRC"
echo "Destination: $DEST"
echo "Build dir: $BUILD"
ls -la "$SDK" | head -5

mkdir -p "$BUILD" "$DEST/lib" "$DEST/include"
cd "$BUILD"

# Run configure with error handling
set +e
"$SRC/configure" --prefix="$STAGE" --enable-cross-compile --target-os=darwin --arch=aarch64 \
  --cc="$T/clang" --ar="$T/ar" --ranlib="$T/ranlib" --nm="$T/nm" --strip="$T/strip" --sysroot="$SDK" \
  --extra-cflags="-target arm64-apple-ios15.0 -isysroot $SDK -O3" \
  --extra-ldflags="-target arm64-apple-ios15.0 -isysroot $SDK -fuse-ld=lld" \
  --disable-everything --disable-programs --disable-doc --disable-avdevice --disable-swscale --disable-postproc --disable-avfilter \
  --disable-network --disable-debug --enable-static --disable-shared --enable-pthreads --enable-swresample \
  --disable-videotoolbox --disable-audiotoolbox --disable-iconv --disable-zlib --disable-bzlib --disable-lzma --disable-securetransport \
  --disable-xlib --disable-sdl2 --disable-libxcb --disable-neon --disable-asm \
  --enable-decoder='vp9,vp8,h264,hevc,opus,vorbis,aac,aac_latm,mp3float,mp3,flac,ac3,eac3,mp2float' \
  --enable-encoder='aac' \
  --enable-demuxer='matroska,mpegts,mov,flv,mp3,aac,ogg,wav,flac' \
  --enable-muxer='mp4,ipod,mov,mp3' \
  --enable-parser='h264,hevc,aac,aac_latm,vp9,vp8,opus,vorbis,mpegaudio,av1,flac' \
  --enable-bsf='aac_adtstoasc,vp9_superframe_split,extract_extradata' \
  --enable-protocol=file 2>&1 | tee configure.log
CONFIGURE_EXIT=$?
set -e

if [ $CONFIGURE_EXIT -ne 0 ]; then
  echo "=== Configure failed with exit code $CONFIGURE_EXIT ==="
  echo "=== Last 100 lines of config.log ==="
  tail -100 "$BUILD/ffbuild/config.log" 2>/dev/null || tail -100 config.log 2>/dev/null || echo "No config.log found"
  exit $CONFIGURE_EXIT
fi

echo "=== Configure succeeded ==="
make -j8 2>&1 | tail -50
make install

cp "$STAGE"/lib/libavcodec.a "$STAGE"/lib/libavformat.a "$STAGE"/lib/libavutil.a "$STAGE"/lib/libswresample.a "$DEST/lib/"
# Run ranlib to ensure archive has index (required by lld)
echo "=== Running ranlib on static libraries ==="
for lib in "$DEST"/lib/*.a; do
  echo "  ranlib $lib"
  ranlib "$lib" 2>&1 || "$T/ranlib" "$lib" 2>&1 || true
done
mkdir -p "$DEST/lib/pkgconfig"
cp "$STAGE"/lib/pkgconfig/*.pc "$DEST/lib/pkgconfig/" 2>/dev/null || true
for d in libavcodec libavformat libavutil libswresample; do
  rm -rf "$DEST/include/$d"
  cp -a "$STAGE/include/$d" "$DEST/include/$d" 2>/dev/null || true
done
echo "FFmpeg installed into $DEST"
ls -la "$DEST/lib/"
