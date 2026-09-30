#!/usr/bin/env bash
# Build the same Qt module set for one Android ABI using the installed host Qt.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK_ROOT=${WORK_ROOT:-"$ROOT/work"}
QT_VERSION=${QT_VERSION:-6.11.2}
JOBS=${JOBS:-4}
ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-"$WORK_ROOT/android-sdk"}
ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT:-"$HOME/.pyside6_android_deploy/android-ndk/android-ndk-r27c"}
JAVA_HOME=${JAVA_HOME:-"$WORK_ROOT/jdk21"}
export ANDROID_SDK_ROOT ANDROID_NDK_ROOT JAVA_HOME PATH="$JAVA_HOME/bin:$PATH"

if (($# != 1)); then
    echo "Usage: $0 {aarch64|armv7a|i686|x86_64}" >&2
    exit 2
fi
case "$1" in
    aarch64) QT_ABI=arm64-v8a; QT_SUFFIX=arm64_v8a ;;
    armv7a) QT_ABI=armeabi-v7a; QT_SUFFIX=armv7 ;;
    i686) QT_ABI=x86; QT_SUFFIX=x86 ;;
    x86_64) QT_ABI=x86_64; QT_SUFFIX=x86_64 ;;
    *) echo "Unsupported ABI: $1" >&2; exit 2 ;;
esac

SOURCE="$WORK_ROOT/qt-everywhere-src-$QT_VERSION"
HOST="$WORK_ROOT/qt/$QT_VERSION/gcc_64"
TARGET="$WORK_ROOT/qt/$QT_VERSION/android_$QT_SUFFIX"
BUILD="$WORK_ROOT/qt-build/android-$QT_SUFFIX"
ALIGN_FLAGS='-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384'
test -x "$SOURCE/configure"
test -x "$HOST/bin/qt-cmake"
test -f "$ANDROID_SDK_ROOT/platforms/android-36/android.jar"
test -d "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64"

qt_prefix_complete() {
    local module
    for module in Qt6Core Qt6Qml         Qt6Charts Qt6VirtualKeyboard; do
        [[ -f "$TARGET/lib/cmake/$module/${module}Config.cmake" ]] || return 1
    done
}

if qt_prefix_complete; then
    echo "Qt prefix already installed: $TARGET"
    exit 0
fi
mkdir -p "$BUILD"
cd "$BUILD"
"$SOURCE/configure" \
    -prefix "$TARGET" \
    -qt-host-path "$HOST" \
    -android-abis "$QT_ABI" \
    -android-sdk "$ANDROID_SDK_ROOT" \
    -android-ndk "$ANDROID_NDK_ROOT" \
    -release -opensource -confirm-license \
    -nomake tests -nomake examples \
    -skip qtwebengine \
    -submodules qtbase,qtdeclarative,qtshadertools,qtsvg,qttools,qtconnectivity,qtcharts,qtdatavis3d,qtgraphs,qthttpserver,qtlocation,qtmultimedia,qtnetworkauth,qtpositioning,qtquick3d,qtremoteobjects,qtscxml,qtsensors,qtserialbus,qtserialport,qtspeech,qtwebchannel,qtwebsockets,qtwebview,qt3d,qtcanvaspainter,qtquick3dphysics,qtlottie,qtquicktimeline,qtvirtualkeyboard \
    -- "-DCMAKE_SHARED_LINKER_FLAGS:STRING=$ALIGN_FLAGS" \
       "-DCMAKE_MODULE_LINKER_FLAGS:STRING=$ALIGN_FLAGS" \
       "-DCMAKE_EXE_LINKER_FLAGS:STRING=$ALIGN_FLAGS"
cmake --build . --parallel "$JOBS"
cmake --install .
qt_prefix_complete
echo "Qt prefix installed: $TARGET"
