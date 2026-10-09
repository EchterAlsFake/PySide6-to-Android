#!/usr/bin/env bash
# Build the Qt 6.12 host tools prefix required for Android cross-compilation.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK_ROOT=${WORK_ROOT:-"$ROOT/work"}
QT_VERSION=${QT_VERSION:-6.12.0}
JOBS=${JOBS:-$(nproc 2>/dev/null || echo 4)}
SOURCE="$WORK_ROOT/qt-everywhere-src-$QT_VERSION"
HOST="$WORK_ROOT/qt/$QT_VERSION/gcc_64"

host_tools_complete() {
    [[ -x "$HOST/bin/qt-cmake" ]] || return 1
    [[ -x "$HOST/bin/moc" ]] || return 1
    [[ -x "$HOST/bin/rcc" ]] || return 1
    [[ -x "$HOST/bin/qmlcachegen" ]] || return 1
    [[ -x "$HOST/bin/qsb" ]] || return 1
    [[ -x "$HOST/bin/lconvert" ]] || return 1
    [[ -x "$HOST/bin/balsam" ]] || return 1
    [[ -x "$HOST/bin/qscxmlc" ]] || return 1
    [[ -x "$HOST/bin/repc" ]] || return 1
    [[ -x "$HOST/bin/qcshadergen" ]] || return 1
    [[ -x "$HOST/bin/lottietoqml" ]] || return 1
    return 0
}

if host_tools_complete; then
    echo "Host Qt tools already installed: $HOST"
    exit 0
fi

mkdir -p "$WORK_ROOT"

if [[ ! -x "$SOURCE/configure" ]]; then
    ARCHIVE="$WORK_ROOT/qt-everywhere-src-$QT_VERSION.tar.xz"
    EXPECTED_SHA256="98ff4f44bac6ec3e1e62ee2a4316ae0e3d15badb015d753cc0268a20db52f165"
    if [[ ! -f "$ARCHIVE" ]]; then
        echo "Downloading Qt $QT_VERSION source archive..."
        curl -fL --retry 3 --output "$ARCHIVE.tmp" \
            "https://download.qt.io/official_releases/qt/6.12/$QT_VERSION/single/qt-everywhere-src-$QT_VERSION.tar.xz"
        mv "$ARCHIVE.tmp" "$ARCHIVE"
    fi
    echo "Verifying $ARCHIVE..."
    echo "$EXPECTED_SHA256  $ARCHIVE" | sha256sum -c -
    echo "Extracting Qt $QT_VERSION source archive..."
    tar -xf "$ARCHIVE" -C "$WORK_ROOT"
fi

test -x "$SOURCE/configure"

# 1. Base host tools (moc, rcc, qmlcachegen, qsb, lconvert, etc.)
if [[ ! -x "$HOST/bin/qt-cmake" || ! -x "$HOST/bin/lconvert" ]]; then
    echo "Building base host Qt tools (qtbase, qtdeclarative, qtshadertools, qttools)..."
    mkdir -p "$WORK_ROOT/qt-build/host"
    cd "$WORK_ROOT/qt-build/host"
    if [[ ! -f build.ninja && ! -f Makefile ]]; then
        "$SOURCE/configure" \
            -prefix "$HOST" \
            -release -opensource -confirm-license \
            -nomake examples -nomake tests \
            -skip qtwebengine \
            -qt-libmd4c \
            -submodules qtbase,qtdeclarative,qtshadertools,qttools
    fi
    cmake --build . --parallel "$JOBS"
    cmake --install .
fi

# 2. Module-specific host generator tools
HOST_MODULES=(
    qtquicktimeline
    qtquick3d
    qtscxml
    qtremoteobjects
    qtcanvaspainter
    qtlottie
)

for module in "${HOST_MODULES[@]}"; do
    case "$module" in
        qtquick3d) check_bin="balsam" ;;
        qtscxml) check_bin="qscxmlc" ;;
        qtremoteobjects) check_bin="repc" ;;
        qtcanvaspainter) check_bin="qcshadergen" ;;
        qtlottie) check_bin="lottietoqml" ;;
        *) check_bin="" ;;
    esac
    if [[ -n "$check_bin" && -x "$HOST/bin/$check_bin" ]]; then
        echo "Host tool $check_bin already installed."
        continue
    fi
    echo "Building host module $module..."
    mkdir -p "$WORK_ROOT/qt-build/host-$module"
    cd "$WORK_ROOT/qt-build/host-$module"
    "$HOST/bin/qt-configure-module" "$SOURCE/$module" -- -DCMAKE_BUILD_TYPE=Release
    cmake --build . --parallel "$JOBS"
    cmake --install .
done

if ! host_tools_complete; then
    echo "Error: Host Qt tools installation incomplete in $HOST" >&2
    exit 1
fi

echo "Host Qt tools successfully installed: $HOST"
