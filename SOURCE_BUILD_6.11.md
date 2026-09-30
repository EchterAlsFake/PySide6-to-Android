# Source-build Qt 6.11 and PySide6 Android wheels

This is the reproducible source-build path for Qt/PySide 6.11.2. It targets
Android AArch64 (`arm64-v8a` / wheel platform `android_aarch64`) and supports
separate wheel builds for CPython 3.10 through 3.14.

The patched helper lives in the companion
[`pyside-setup-android`](https://github.com/EchterAlsFake/pyside-setup-android)
fork. Until that GitHub repository is created, the prepared checkout is the
local sibling directory `../pyside-setup-android` on branch
`android-cross-build-fixes`.

For a CPython runtime with Android builds of OpenSSL, libffi, bzip2, xz, and
SQLite, use the [runtime build helper](RUNTIME_BUILD.md). It populates the same
versioned target prefix used by the companion fork and can run the wheel build
after the native dependencies and Python are ready.

## Toolchain versions

Use matching Qt and PySide sources. This build was tested with:

| Component | Version |
| --- | --- |
| Qt and Qt for Python | 6.11.2 |
| JDK | 21 |
| Android SDK platform | 36 |
| Android build tools | 36.0.0 |
| Android NDK | r27c (`27.2.12479018`) |
| CPython native API | 35 |
| Qt minimum Android API | 28 |

SDK API 36 and native API 35 are deliberately different. Qt 6.11's Java
sources need `platforms/android-36/android.jar`, while NDK r27c only ships
native compiler wrappers through API 35. Passing API 36 to the CPython build
therefore cannot work.

In addition to a C/C++ build toolchain, CMake, Ninja, Git, and `zip`, each
wheel build needs a host Python with the same major/minor version as the
target. The host Python must have working SSL support so it can download build
requirements.

## Fetch and verify Qt

Run from this guide repository:

```bash
export QT_VERSION=6.11.2
export GUIDE_ROOT="$PWD"
export BUILD_ROOT="$GUIDE_ROOT/work"
export PYSIDE_FORK="$GUIDE_ROOT/../pyside-setup-android"
export QT_SOURCE="$BUILD_ROOT/qt-everywhere-src-$QT_VERSION"
export QT_PREFIX="$BUILD_ROOT/qt/$QT_VERSION"
export QT_HOST_PREFIX="$QT_PREFIX/gcc_64"
export QT_ANDROID_PREFIX="$QT_PREFIX/android_arm64_v8a"
export ANDROID_SDK_ROOT="$BUILD_ROOT/android-sdk"
export ANDROID_NDK_ROOT="$HOME/.pyside6_android_deploy/android-ndk/android-ndk-r27c"
export JAVA_HOME="$BUILD_ROOT/jdk21"
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"
curl -fLO "https://download.qt.io/official_releases/qt/6.11/$QT_VERSION/single/qt-everywhere-src-$QT_VERSION.tar.xz"
echo "6dcfbca271d76a6502741a2c0dc6fc98ef7dd0b7b4cfd0abcebb285a86a26f33  qt-everywhere-src-$QT_VERSION.tar.xz" | sha256sum -c -
tar -xf "qt-everywhere-src-$QT_VERSION.tar.xz"
```

Install SDK platform 36 and build-tools 36.0.0 with `sdkmanager`, and verify
that these paths exist before compiling:

```bash
test -f "$ANDROID_SDK_ROOT/platforms/android-36/android.jar"
test -x "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android35-clang"
java -version
```

## Build the host Qt tools

An Android Qt build is not self-hosting. It needs same-version Linux tools.
The base host build provides tools such as `moc`, `rcc`, `qmlcachegen`, `qsb`,
and `lconvert`:

```bash
mkdir -p "$BUILD_ROOT/qt-build/host"
cd "$BUILD_ROOT/qt-build/host"
"$QT_SOURCE/configure" \
    -prefix "$QT_HOST_PREFIX" \
    -release -opensource -confirm-license \
    -nomake examples -nomake tests \
    -skip qtwebengine \
    -submodules qtbase,qtdeclarative,qtshadertools,qttools
cmake --build . --parallel 4
cmake --install .
```

The larger target module set also invokes module-specific host generators.
Build and install these standalone host modules in this order:

```bash
for module in qtquicktimeline qtquick3d qtscxml qtremoteobjects qtcanvaspainter qtlottie; do
    mkdir -p "$BUILD_ROOT/qt-build/host-$module"
    cd "$BUILD_ROOT/qt-build/host-$module"
    "$QT_HOST_PREFIX/bin/qt-configure-module" "$QT_SOURCE/$module" -- -DCMAKE_BUILD_TYPE=Release
    cmake --build . --parallel 4
    cmake --install .
done
```

These modules provide `balsam`, `qscxmlc`, `repc`, `qcshadergen`, and
`lottietoqml`, plus their exported host-tool CMake packages. Omitting them
causes target configuration to fail even though the corresponding tools never
run on Android.

## Build Qt for Android AArch64

```bash
mkdir -p "$BUILD_ROOT/qt-build/android-arm64"
cd "$BUILD_ROOT/qt-build/android-arm64"
"$QT_SOURCE/configure" \
    -prefix "$QT_ANDROID_PREFIX" \
    -qt-host-path "$QT_HOST_PREFIX" \
    -android-abis arm64-v8a \
    -android-sdk "$ANDROID_SDK_ROOT" \
    -android-ndk "$ANDROID_NDK_ROOT" \
    -release -opensource -confirm-license \
    -nomake tests -nomake examples \
    -skip qtwebengine \
    -submodules qtbase,qtdeclarative,qtshadertools,qtsvg,qttools,qtconnectivity,qtcharts,qtdatavis3d,qtgraphs,qthttpserver,qtlocation,qtmultimedia,qtnetworkauth,qtpositioning,qtquick3d,qtremoteobjects,qtscxml,qtsensors,qtserialbus,qtserialport,qtspeech,qtwebchannel,qtwebsockets,qtwebview,qt3d,qtcanvaspainter,qtquick3dphysics,qtlottie,qtquicktimeline,qtvirtualkeyboard
cmake --build . --parallel 4
cmake --install .
```

`-skip qtwebengine` is required even though it is absent from `-submodules`.
`qtwebview` otherwise pulls it in as an optional dependency and the Android
cross-configure stops looking for a host `gn` executable.

## Build the wheels with the fork

Create one virtual environment per Python version and install both requirement
sets into each:

```bash
cd "$PYSIDE_FORK"
python3.10 -m venv "$BUILD_ROOT/venvs/py310"
python3.11 -m venv "$BUILD_ROOT/venvs/py311"
python3.12 -m venv "$BUILD_ROOT/venvs/py312"
python3.13 -m venv "$BUILD_ROOT/venvs/py313"
python3.14 -m venv "$BUILD_ROOT/venvs/py314"

for venv in py310 py311 py312 py313 py314; do
    "$BUILD_ROOT/venvs/$venv/bin/pip" install \
        -r requirements.txt \
        -r tools/cross_compile_android/requirements.txt
done
```

Then run this command with the matching venv, `--python-version`, and cache
directory. This example is for Python 3.14:

```bash
"$BUILD_ROOT/venvs/py314/bin/python" \
    tools/cross_compile_android/main.py \
    --plat-name aarch64 \
    --python-version 3.14 \
    --cache-dir "$BUILD_ROOT/cache/py314" \
    --ndk-path "$ANDROID_NDK_ROOT" \
    --sdk-path "$ANDROID_SDK_ROOT" \
    --api-level 35 \
    --sdk-api-level 36 \
    --qt-install-path "$QT_PREFIX" \
    --qt-host-path "$QT_HOST_PREFIX" \
    --parallel 4 \
    --verbose
```

Repeat with `py310` / `3.10`, `py311` / `3.11`, `py312` / `3.12`, and
`py313` / `3.13`. The fork keeps each
CPython checkout, target installation, and generated toolchain versioned, so
the builds no longer overwrite or silently reuse one another.

Successful wheels are written to the fork's `dist/` directory. Preserve each
version before starting another build if you use a clean build directory. The
tested artifacts in this checkout are also grouped below
`work/wheels/py310`, `work/wheels/py311`, and `work/wheels/py314`.

## Verified result

On 10 September 2026, the procedure above completed for all three requested
Python versions:

| Python | Wheel tag | PySide6 size | Shiboken6 size |
| --- | --- | ---: | ---: |
| 3.10 | `cp310-cp310-android_aarch64` | 86,372,509 bytes | 273,412 bytes |
| 3.11 | `cp311-cp311-android_aarch64` | 86,372,918 bytes | 273,431 bytes |
| 3.14 | `cp314-cp314-android_aarch64` | 86,402,309 bytes | 274,228 bytes |

Each archive passed `unzip -t`. The extension modules are AArch64 Android 35
ELF binaries built by NDK r27c and link against the matching versioned
`libpython3.x.so`. A later full-archive audit found that the Shiboken shared
objects in these older wheels have 4 KiB load alignment; rebuild them with
the updated fork for 16 KiB support. No host-architecture ELF was
found among the 1,038 files audited in the three packaged trees. Exact hashes
and the failure history are recorded in
[CURRENT_BUILD_NOTES.md](CURRENT_BUILD_NOTES.md).

On 29 September 2026, the [runtime helper](RUNTIME_BUILD.md) built Python
3.12 and 3.13 AArch64 runtimes with Android OpenSSL, libffi, bzip2, xz, and
SQLite, then produced matching PySide6 and Shiboken6 wheels. Both wheel pairs
passed full-archive architecture and 16 KiB alignment checks. Their hashes
and the correction to the earlier Shiboken alignment claim are in
[CURRENT_BUILD_NOTES.md](CURRENT_BUILD_NOTES.md#29-september-2026-update).

## Known limitations

- This procedure currently covers AArch64. The fork fixes the x86-only
  `-msse4.2`, `-m<bits>`, and `-mpopcnt` flags being emitted for ARM, but the
  other ABIs still need full artifact testing.
- The generic CPython build omits optional modules whose Android dependencies
  were not supplied, including OpenSSL, libffi, bzip2, and lzma. This is enough
  as a development prefix for compiling PySide, but not a complete production
  Python runtime. The separate [runtime helper](RUNTIME_BUILD.md) supplies
  these dependencies and SQLite for new builds.
- The Qt configuration above also has no Android OpenSSL build, so QtNetwork
  HTTPS is not enabled. The fork fixes PySide's incorrect unconditional
  `QSslEllipticCurve` wrapper source for this configuration. Supply an Android
  OpenSSL prefix and reconfigure Qt for production networking.
- Python 3.14 has an official CPython Android build workflow under
  `Platforms/Android`; integrating that runtime is preferable for production
  packaging even when this helper is used to build the PySide wheels.
- The wheels have been compiled and statically inspected, but have not been
  run inside an APK on a device or emulator. Treat that as a required release
  test for every source-built Python version.

See [CURRENT_BUILD_NOTES.md](CURRENT_BUILD_NOTES.md) for the exact failures
reproduced while bringing the old guide forward.
