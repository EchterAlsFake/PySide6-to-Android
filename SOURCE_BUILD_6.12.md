# Source-build Qt 6.12 and PySide6 Android wheels

This is the reproducible source-build path for Qt/PySide 6.12.0. It targets
Android AArch64 (`arm64-v8a` / wheel platform `android_aarch64`), ARMv7 (`armeabi-v7a`),
x86 (`i686`), and x86_64, supporting separate wheel builds for CPython 3.10 through 3.14.

The patched helper lives in the companion
[`pyside-setup`](https://github.com/EchterAlsFake/pyside-setup)
fork on branch `android-cross-build-fixes`. The local checkout is expected at
`../pyside-setup-android`.

For a CPython runtime with Android builds of OpenSSL, libffi, bzip2, xz, and
SQLite, use the [runtime build helper](RUNTIME_BUILD.md). It populates the same
versioned target prefix used by the companion fork and can run the wheel build
after the native dependencies and Python are ready.

## Toolchain versions

Use matching Qt and PySide sources. This build was tested with:

| Component | Version | Notes |
| --- | --- | --- |
| Qt and Qt for Python | 6.12.0 | Upstream 6.12 release |
| JDK | 21 | Qt 6.12 requires JDK 21 or newer |
| Android SDK platform | 36 | Required by Qt 6.12 Java sources (`android.jar`) |
| Android build tools | 36.0.0 | Qt 6.12 documented version |
| Android NDK | r27c / r28c | r27c for Qt libraries; r28c supported |
| CPython native API | 35 | NDK r27c native compiler wrapper API |
| Qt minimum Android API | 28 | Android runtime minimum API |

SDK API 36 and native API 35 are deliberately different. Qt 6.12's Java
sources need `platforms/android-36/android.jar`, while NDK r27c ships native
compiler wrappers through API 35. Passing API 36 to the CPython build therefore
fails because `aarch64-linux-android36-clang` does not exist in NDK r27c.

In addition to a C/C++ build toolchain, CMake, Ninja, Git, and `zip`, each
wheel build needs a host Python with the same major/minor version as the
target. The host Python must have working SSL support so it can download build
requirements.

## Fetch and verify Qt 6.12.0

Run from this guide repository:

```bash
export QT_VERSION=6.12.0
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
curl -fLO "https://download.qt.io/official_releases/qt/6.12/$QT_VERSION/single/qt-everywhere-src-$QT_VERSION.tar.xz"
echo "98ff4f44bac6ec3e1e62ee2a4316ae0e3d15badb015d753cc0268a20db52f165  qt-everywhere-src-$QT_VERSION.tar.xz" | sha256sum -c -
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
`lottietoqml`, plus their exported host-tool CMake packages.

## Build Qt for Android AArch64

```bash
ALIGN_FLAGS='-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384'
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
    -submodules qtbase,qtdeclarative,qtshadertools,qtsvg,qttools,qtconnectivity,qtcharts,qtdatavis3d,qtgraphs,qthttpserver,qtlocation,qtmultimedia,qtnetworkauth,qtpositioning,qtquick3d,qtremoteobjects,qtscxml,qtsensors,qtserialbus,qtserialport,qtspeech,qtwebchannel,qtwebsockets,qtwebview,qt3d,qtcanvaspainter,qtquick3dphysics,qtlottie,qtquicktimeline,qtvirtualkeyboard \
    -- "-DCMAKE_SHARED_LINKER_FLAGS:STRING=$ALIGN_FLAGS" \
       "-DCMAKE_MODULE_LINKER_FLAGS:STRING=$ALIGN_FLAGS" \
       "-DCMAKE_EXE_LINKER_FLAGS:STRING=$ALIGN_FLAGS"
cmake --build . --parallel 4
cmake --install .
```

`-skip qtwebengine` is required even though it is absent from `-submodules`.
`qtwebview` otherwise pulls it in as an optional dependency and Android
cross-configuration stops looking for a host `gn` executable.

## Build the wheels with the fork

Create virtual environments per Python version and install dependencies:

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

Run the cross-compiler driver:

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

To build official-style Limited API (`cp310-abi3`) wheels that run across all
Python versions 3.10–3.14 on aarch64 and x86_64, pass `--limited-api=yes`.

## Matrix Automation

Use the automated orchestration scripts:

```bash
# Build complete 4 ABIs x 5 Python versions matrix
bash scripts/rebuild-android-matrix.sh

# Validate the entire matrix
bash scripts/check-android-matrix.sh
```

## Known limitations

- **Upstream 32-bit drop**: Upstream Qt 6.12 dropped `armv7a` and `i686` support.
  The companion fork restores `PlatformData` and CMake template logic for 32-bit ABIs.
- **SSL wrapper gating**: Upstream QtNetwork CMake still lists `qsslellipticcurve_wrapper.cpp`
  and `qsslkeyingmaterial_wrapper.cpp` unconditionally. The companion fork moves both
  into the SSL-enabled branch so Qt builds without Android OpenSSL can compile.
- **16 KiB Page Size**: Android 15 requires 16 KiB ELF alignment. The companion fork
  enforces `-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384` on all shared
  libraries and Shiboken wrappers.
