# VidGrab 1.3.6d — 储存逻辑重写说明

## 本次修改内容

参考「文件App与解压专家双向同步」的实现原理，对 VidGrab 的文件储存逻辑进行了重写，实现了与系统「文件」App 的双向实时同步。

### 1. 新增文件

| 文件 | 作用 |
|------|------|
| `Sources/VGDirectoryWatcher.h` | 目录监控器头文件 |
| `Sources/VGDirectoryWatcher.m` | 基于 GCD vnode (kqueue) 的内核级目录监控实现 |

### 2. 修改文件

| 文件 | 变更 |
|------|------|
| `Sources/VGEngine.h` | 更新保险库注释说明 |
| `Sources/VGEngine.m` | 核心储存逻辑重写（详见下方） |
| `assemble.py` | 硬编码路径改为环境变量可配置 |
| `.github/workflows/build.yml` | 新增 GitHub Actions 云端编译配置 |

### 3. 储存逻辑变更

#### 保险库路径迁移

**旧路径**（1.3.6c 及之前）：
```
<App Sandbox>/Library/Application Support/vault/
```

**新路径**（1.3.6d）：
```
<App Sandbox>/Documents/.vault/
```

- 以 `.` 开头的隐藏目录，系统「文件」App 默认不显示
- 保留 `NSFileProtectionComplete` 数据保护
- 应用首次启动时自动从旧路径迁移文件到新路径

#### 双向同步机制（四级架构）

```
用户在文件 App 中操作文件
        │
        ▼
内核检测到 Documents/ 目录条目变化
        │
        ▼  第1级：GCD vnode (kqueue) 实时监控
VGDirectoryWatcher 触发回调
        │
        ▼  第2级：防抖合并（0.8秒）
scheduleScanAfterDelay 合并高频事件
        │
        ▼  第3级：差异扫描（后台线程）
performFullScan 枚举目录，与 library.json 对比
        │
        ├──→ 新文件：自动添加到媒体库（site = "Files"）
        ├──→ 已删除：从媒体库中移除
        └──→ 无变化：不做任何操作
        │
        ▼  第4级：UI 刷新（主线程）
saveLibrary → VGLibraryDidChangeNotification → 列表刷新
```

#### 兜底机制

- **应用回到前台**：监听 `UIApplicationWillEnterForegroundNotification`，0.3秒后全量重扫（防止后台期间 vnode 事件丢失）
- **应用启动时**：0.5秒后执行初始全量扫描
- **防重入**：`scanning` 标记防止扫描重叠
- **线程安全**：后台线程仅做文件 I/O 和比较，主线程统一提交变更

---

## 编译环境要求

### 必需依赖

| 依赖 | 版本 | 说明 |
|------|------|------|
| Theos | latest | iOS 交叉编译工具链 |
| iOS SDK | 16.5 | `TARGET := iphone:clang:16.5:15.0` |
| Python.xcframework | 3.14 | 含 Headers 的完整 framework |
| FFmpeg | 7.1.1 | iOS arm64 静态库（avcodec/avformat/avutil/swresample） |
| LAME | 3.100 | iOS arm64 静态库（libmp3lame） |
| yt-dlp | 2026.08.19 | Python 下载引擎 |
| Python 包 | latest | requests, certifi, urllib3, websockets 等 |
| uv | latest | Python 包管理器 |
| ldid | latest | 签名工具 |

### 目录结构约定

```
/root/
├── theos/                    # Theos 工具链
│   ├── sdks/
│   │   └── iPhoneOS16.5.sdk/
│   └── toolchain/linux/iphone/bin/
├── pyios/
│   └── Python.xcframework/   # 含 Headers
│       └── ios-arm64/
│           └── Python.framework/
├── ffmpeg-ios/               # FFmpeg + LAME 预编译库
│   ├── include/
│   │   ├── lame/lame.h
│   │   ├── libavcodec/
│   │   ├── libavformat/
│   │   ├── libavutil/
│   │   └── libswresample/
│   └── lib/
│       ├── libavcodec.a
│       ├── libavformat.a
│       ├── libavutil.a
│       ├── libswresample.a
│       └── libmp3lame.a
├── app_packages/             # Python 运行时包
│   ├── requests/
│   ├── certifi/
│   ├── urllib3/
│   ├── websockets/
│   ├── yt_dlp/
│   └── ...
└── VidGrab/                  # 本项目源码
    └── Resources/
        └── yt-dlp            # yt-dlp zip 包
```

---

## 方式一：GitHub Actions 云端编译（推荐）

### 步骤

1. **创建 GitHub 仓库**
   ```bash
   cd VidGrab-1.3.6c
   git init
   git add .
   git commit -m "VidGrab 1.3.6d: rewrite storage with Files app two-way sync"
   git branch -M main
   ```

2. **在 GitHub 上创建空仓库**（不要初始化 README），然后推送：
   ```bash
   git remote add origin https://github.com/<你的用户名>/<仓库名>.git
   git push -u origin main
   ```

3. **触发编译**
   - 推送后自动触发 `.github/workflows/build.yml`
   - 或在仓库 Actions 页面手动点击 "Run workflow"

4. **下载 IPA**
   - 编译完成后，在 Actions 运行页面底部的 Artifacts 区域下载 `VidGrab.ipa`
   - 编译时间约 15-30 分钟（主要耗时在 FFmpeg 交叉编译）

### 注意事项

- workflow 中的 Python.xcframework 下载链接可能需要根据实际可用版本调整
- iOS SDK 下载源如果失效，可替换为其他可信镜像
- FFmpeg 编译使用项目自带的 `tools/build_ffmpeg_ios.sh`

---

## 方式二：本地编译（需 Linux + Theos）

### 1. 安装 Theos 和 SDK

```bash
export THEOS=~/theos
git clone --recursive https://github.com/theos/theos.git $THEOS
# 安装 iPhoneOS16.5.sdk 到 $THEOS/sdks/
```

### 2. 准备 Python.xcframework

```bash
mkdir -p ~/pyios
cd ~/pyios
# 从 beeware/Python-Apple-support 下载对应版本
curl -L -o Python.tar.gz https://github.com/beeware/Python-Apple-support/releases/download/3.14.0/Python-3.14.0-iOS-support.tar.gz
tar -xzf Python.tar.gz
```

### 3. 编译 FFmpeg + LAME

```bash
# 先编译 LAME
# 然后运行项目自带脚本
export FFMPEG_SRC=/path/to/ffmpeg-src
export FFMPEG_DEST=/root/ffmpeg-ios
bash tools/build_ffmpeg_ios.sh
```

### 4. 准备 Python 包

```bash
mkdir -p /root/app_packages
uv pip install --target /root/app_packages requests certifi urllib3 websockets
# 下载 yt-dlp 并解压到 app_packages
```

### 5. 编译

```bash
export THEOS=~/theos
export PYFW_DIR=~/pyios/ios-arm64
make clean
make FINALPACKAGE=1
```

### 6. 打包 IPA

```bash
export PYTHON_XCFRAMEWORK=~/pyios/Python.xcframework
export APP_PACKAGES=/root/app_packages
export YTDLP_ZIP=/path/to/yt-dlp
python3 assemble.py
# 生成 VidGrab.ipa
```

---

## 验证修改是否生效

安装编译后的 IPA 后，可通过以下方式验证双向同步：

1. **文件 App → VidGrab**
   - 在「文件」App 中找到 VidGrab 的 Documents 目录
   - 放入一个 mp4/mp3 文件
   - 切回 VidGrab 的 Downloads 页面，文件应自动出现（site 显示 "Files"）

2. **VidGrab → 文件 App**
   - 在 VidGrab 中删除一个下载
   - 切到「文件」App，对应文件应已消失

3. **保险库验证**
   - 将文件移入私密保险库
   - 在「文件」App 中应看不到 `.vault` 目录（默认隐藏）
   - 如开启显示隐藏文件，可看到 `.vault` 目录

4. **后台变更同步**
   - 按 Home 键进入后台
   - 在「文件」App 中删除/添加文件
   - 切回 VidGrab，列表应自动更新

---

## 常见问题

### Q: 编译时提示 "Python/Python.h not found"
A: 确认 `PYFW_DIR` 指向包含 `Python.framework/Headers/` 的目录。IPA 中提取的 framework 不含 Headers，必须使用完整的 xcframework。

### Q: 链接错误 "library not found for -lavcodec"
A: 确认 `/root/ffmpeg-ios/lib/` 下有对应的静态库，且是 arm64 架构（用 `lipo -info libavcodec.a` 检查）。

### Q: vnode 监控不生效
A: GCD vnode 只能监控目录直接子条目的变化，不递归。子目录内部的变化需要单独监控（本项目已分别监控 Documents/ 和 Documents/.vault/）。

### Q: 大文件复制时频繁触发扫描
A: 已设置 0.8 秒防抖。如果仍有问题，可增大 `scheduleScanAfterDelay:0.8` 中的延迟值。

### Q: 旧版保险库文件会丢失吗
A: 不会。应用首次启动时 `migrateVaultIfNeeded` 会自动将 `Application Support/vault/` 中的文件移动到 `Documents/.vault/`，遇到重名会自动加序号。
