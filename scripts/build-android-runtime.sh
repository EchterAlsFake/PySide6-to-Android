#!/usr/bin/env bash
# Build Android native libraries and a CPython development/runtime prefix.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK_ROOT=${WORK_ROOT:-"$ROOT/work"}
NDK_ROOT=${ANDROID_NDK_ROOT:-"$HOME/.pyside6_android_deploy/android-ndk/android-ndk-r27c"}
API=${ANDROID_NATIVE_API:-35}
JOBS=${JOBS:-4}
PYTHON_VERSION=
ABI=aarch64
BUILD_WHEELS=0
INSTALL_ARCH_DEPS=0

usage() {
    cat <<'EOF'
Usage: scripts/build-android-runtime.sh --python-version 3.12 --abi aarch64 [options]

Options:
  --with-wheels          Build PySide6/Shiboken6 wheels with the sibling fork.
  --install-arch-deps    Install missing Arch Linux host packages with pacman.
  --help                 Show this help.

Environment: WORK_ROOT, ANDROID_NDK_ROOT, ANDROID_NATIVE_API (35),
JOBS (4), PYSIDE_FORK, QT_PREFIX, QT_HOST_PREFIX, ANDROID_SDK_ROOT.
The script only manages target libraries and CPython. A matching target Qt
prefix must already exist when --with-wheels is used.
EOF
}

while (($#)); do
    case "$1" in
        --python-version) PYTHON_VERSION=${2:?}; shift 2 ;;
        --abi) ABI=${2:?}; shift 2 ;;
        --with-wheels) BUILD_WHEELS=1; shift ;;
        --install-arch-deps) INSTALL_ARCH_DEPS=1; shift ;;
        --help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

case "$PYTHON_VERSION" in
    3.10|3.11|3.12|3.13|3.14) ;;
    *) echo "Select --python-version from 3.10 through 3.14" >&2; exit 2 ;;
esac

case "$ABI" in
    aarch64) TRIPLET=aarch64-linux-android; OPENSSL_TARGET=android-arm64 ;;
    armv7a) TRIPLET=armv7a-linux-androideabi; OPENSSL_TARGET=android-arm ;;
    i686) TRIPLET=i686-linux-android; OPENSSL_TARGET=android-x86 ;;
    x86_64) TRIPLET=x86_64-linux-android; OPENSSL_TARGET=android-x86_64 ;;
    *) echo "Unsupported ABI: $ABI" >&2; exit 2 ;;
esac

if ((INSTALL_ARCH_DEPS)); then
    if ! command -v pacman >/dev/null || \
        ! grep -Eq '^(ID|ID_LIKE)=.*(arch|endeavouros|manjaro)' /etc/os-release; then
        echo "--install-arch-deps requires an Arch based system" >&2
        exit 2
    fi
    sudo pacman -S --needed --noconfirm base-devel git curl cmake ninja perl autoconf automake libtool pkgconf openssl zlib xz bzip2 libffi sqlite patchelf python zip unzip
fi

for command in git curl make perl pkg-config cmake tar sha256sum python3 readelf; do
    command -v "$command" >/dev/null || { echo "Missing host command: $command" >&2; exit 2; }
done

TOOLBIN="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
CC="$TOOLBIN/$TRIPLET$API-clang"
CXX="$TOOLBIN/$TRIPLET$API-clang++"
test -x "$CC" || { echo "Missing NDK compiler: $CC" >&2; exit 2; }
export PATH="$TOOLBIN:$PATH" ANDROID_NDK_ROOT="$NDK_ROOT"
export CC CXX
export AR="$TOOLBIN/llvm-ar" RANLIB="$TOOLBIN/llvm-ranlib" STRIP="$TOOLBIN/llvm-strip"
export READELF="$TOOLBIN/llvm-readelf"
export PKG_CONFIG=/bin/false
# NDK r27 needs both flags for 16 KiB page-size compatibility.
ALIGN_FLAGS='-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384'
export LDFLAGS="$ALIGN_FLAGS"

SOURCES="$WORK_ROOT/runtime-sources"
BUILDS="$WORK_ROOT/runtime-build/$ABI-api$API"
DEPS="$WORK_ROOT/runtime-deps/$ABI-api$API"
PYTAG=${PYTHON_VERSION/./_}
TARGET="$WORK_ROOT/cache/py${PYTHON_VERSION/./}/Python-$ABI-linux-android-$PYTAG/_install"
HOST="$WORK_ROOT/host-python/$PYTHON_VERSION"
PY_SOURCE="$WORK_ROOT/cache/py${PYTHON_VERSION/./}/cpython-$PYTAG"
mkdir -p "$SOURCES" "$BUILDS" "$DEPS" "$(dirname "$TARGET")" "$(dirname "$HOST")"

fetch_tar() {
    local name=$1 url=$2 expected=$3 archive="$SOURCES/$1.tar.gz"
    if [[ ! -f "$archive" ]]; then
        curl --fail --location --retry 3 --output "$archive.tmp" "$url"
        mv "$archive.tmp" "$archive"
    fi
    printf '%s  %s\n' "$expected" "$archive" | sha256sum -c -
    if [[ ! -d "$SOURCES/$name" ]]; then
        mkdir -p "$SOURCES/$name"
        tar -xf "$archive" -C "$SOURCES/$name" --strip-components=1
    fi
}

build_autotools() {
    local name=$1
    shift
    if [[ -f "$DEPS/.${name}.16k.done" ]]; then return; fi
    mkdir -p "$BUILDS/$name"
    (
        cd "$BUILDS/$name"
        if [[ -f Makefile ]]; then make distclean; fi
        "$SOURCES/$name/configure" --host="$TRIPLET" --prefix="$DEPS" \
            --enable-shared --disable-static "$@"
        make -j "$JOBS"
        make install
    )
    touch "$DEPS/.${name}.16k.done"
}

# Fixed source versions are shared across Python versions of the same ABI.
fetch_tar openssl-3.5.8 https://github.com/openssl/openssl/releases/download/openssl-3.5.8/openssl-3.5.8.tar.gz a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2
fetch_tar libffi-3.4.8 https://github.com/libffi/libffi/releases/download/v3.4.8/libffi-3.4.8.tar.gz bc9842a18898bfacb0ed1252c4febcc7e78fa139fd27fdc7a3e30d9d9356119b
fetch_tar bzip2-1.0.8 https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269
fetch_tar xz-5.8.4 https://github.com/tukaani-project/xz/releases/download/v5.8.4/xz-5.8.4.tar.gz 0014c7886930454fe8bd4228665b51af55eeae560ea135c9c4cd33f55b2591d9
fetch_tar sqlite-autoconf-3500400 https://www.sqlite.org/2025/sqlite-autoconf-3500400.tar.gz a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18

if [[ ! -f "$DEPS/.openssl-3.5.8.16k.done" ]]; then
    (
        cd "$SOURCES/openssl-3.5.8"
        if [[ -f Makefile ]]; then make clean; fi
        ./Configure "$OPENSSL_TARGET" \
            --prefix="$DEPS" --libdir=lib --openssldir="$DEPS/ssl" shared no-tests
        make -j "$JOBS"
        make install_sw
    )
    touch "$DEPS/.openssl-3.5.8.16k.done"
fi
build_autotools libffi-3.4.8
if [[ ! -f "$DEPS/.bzip2.done" ]]; then
    # bzip2 builds in its source tree; clean objects left by another ABI.
    make -C "$SOURCES/bzip2-1.0.8" clean
    make -C "$SOURCES/bzip2-1.0.8" CC="$CC" AR="$AR" RANLIB="$RANLIB" \
        CFLAGS='-O2 -fPIC' -j "$JOBS" libbz2.a
    mkdir -p "$DEPS/include" "$DEPS/lib"
    cp "$SOURCES/bzip2-1.0.8/bzlib.h" "$DEPS/include/"
    cp "$SOURCES/bzip2-1.0.8/libbz2.a" "$DEPS/lib/"
    touch "$DEPS/.bzip2.done"
fi
build_autotools xz-5.8.4
build_autotools sqlite-autoconf-3500400

if [[ ! -x "$HOST/bin/python$PYTHON_VERSION" ]]; then
    if [[ ! -d "$PY_SOURCE/.git" ]]; then
        git clone --depth 1 --branch "$PYTHON_VERSION" \
            https://github.com/python/cpython.git "$PY_SOURCE"
    fi
    # Older helper runs built CPython in its source checkout. An out-of-tree
    # host build refuses to proceed until those generated objects are cleaned.
    if [[ -f "$PY_SOURCE/Makefile" ]]; then
        make -C "$PY_SOURCE" distclean
    fi
    mkdir -p "$BUILDS/python-host-$PYTAG"
    (
        cd "$BUILDS/python-host-$PYTAG"
        unset CC CXX AR RANLIB STRIP READELF PKG_CONFIG LDFLAGS
        "$PY_SOURCE/configure" --prefix="$HOST"
        make -j "$JOBS"
        make install
    )
fi

if [[ ! -f "$TARGET/.runtime-openssl-3.5.8-16k.done" ]]; then
    mkdir -p "$BUILDS/python-target-$PYTAG"
    HOST_TRIPLET=$("$PY_SOURCE/config.guess")
    (
        cd "$BUILDS/python-target-$PYTAG"
        export PATH="$HOST/bin:$PATH"
        if [[ -f Makefile ]]; then make distclean; fi
        export CPPFLAGS="-I$DEPS/include"
        export CFLAGS="-O2 -fPIC -DANDROID"
        export LDFLAGS="-L$DEPS/lib $ALIGN_FLAGS"
        export LIBFFI_CFLAGS="-I$DEPS/include" LIBFFI_LIBS="-L$DEPS/lib -lffi"
        export BZIP2_CFLAGS="-I$DEPS/include" BZIP2_LIBS="-L$DEPS/lib -lbz2"
        export LIBLZMA_CFLAGS="-I$DEPS/include" LIBLZMA_LIBS="-L$DEPS/lib -llzma"
        export LIBSQLITE3_CFLAGS="-I$DEPS/include" LIBSQLITE3_LIBS="-L$DEPS/lib -lsqlite3"
        "$PY_SOURCE/configure" --build="$HOST_TRIPLET" --host="$TRIPLET" \
            --with-build-python="$HOST/bin/python$PYTHON_VERSION" \
            --prefix="$TARGET" --enable-shared --enable-ipv6 --without-ensurepip \
            --with-openssl="$DEPS" ac_cv_file__dev_ptmx=yes ac_cv_file__dev_ptc=no \
            ac_cv_little_endian_double=yes
        # CPython's BLDSHARED includes PY_CORE_LDFLAGS. Overriding it here
        # would silently drop the 16 KiB linker flags from libpython and
        # extension modules.
        make -j "$JOBS" "INSTSONAME=libpython$PYTHON_VERSION.so"
        make install
        for module in _ssl _hashlib _ctypes _bz2 _lzma _sqlite3; do
            if ! find "$TARGET/lib/python$PYTHON_VERSION/lib-dynload" \
                -maxdepth 1 -name "${module}*.so" | grep -q .; then
                echo "Missing target Python module: $module" >&2
                exit 1
            fi
        done
    )
fi

# Keep shared native libraries alongside the runtime for APK packaging.
mkdir -p "$TARGET/lib"
shopt -s nullglob
for library in "$DEPS"/lib/*.so* "$DEPS"/lib64/*.so*; do
    cp -P "$library" "$TARGET/lib/"
done
shopt -u nullglob
if [[ -d "$DEPS/lib/ossl-modules" ]]; then
    cp -a "$DEPS/lib/ossl-modules" "$TARGET/lib/"
fi
bash "$ROOT/scripts/check-android-runtime.sh" "$PYTHON_VERSION" "$ABI"
git -C "$PY_SOURCE" rev-parse HEAD > "$TARGET/python-source-commit.txt"
touch "$TARGET/.runtime-openssl-3.5.8-16k.done"
echo "Runtime prefix: $TARGET"

if ((BUILD_WHEELS)); then
    # The wheel build runs host Python tools; keep the cross compiler confined
    # to native-library and target-runtime compilation above.
    unset CC CXX AR RANLIB STRIP READELF PKG_CONFIG LDFLAGS
    PYSIDE_FORK=${PYSIDE_FORK:-"$ROOT/../pyside-setup-android"}
    QT_PREFIX=${QT_PREFIX:-"$WORK_ROOT/qt/6.11.2"}
    QT_HOST_PREFIX=${QT_HOST_PREFIX:-"$QT_PREFIX/gcc_64"}
    ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-"$WORK_ROOT/android-sdk"}
    case "$ABI" in
        aarch64) QT_ABI=arm64_v8a ;;
        armv7a) QT_ABI=armv7 ;;
        i686) QT_ABI=x86 ;;
        x86_64) QT_ABI=x86_64 ;;
    esac
    test -d "$QT_PREFIX/android_$QT_ABI" || {
        echo "Missing Android Qt prefix: $QT_PREFIX/android_$QT_ABI" >&2; exit 2;
    }
    VENV="$WORK_ROOT/venvs/py${PYTHON_VERSION/./}"
    if [[ ! -x "$VENV/bin/python" ]]; then
        "$HOST/bin/python$PYTHON_VERSION" -m venv "$VENV"
    fi
    "$VENV/bin/python" -m pip install -r "$PYSIDE_FORK/requirements.txt" \
        -r "$PYSIDE_FORK/tools/cross_compile_android/requirements.txt"
    "$VENV/bin/python" "$PYSIDE_FORK/tools/cross_compile_android/main.py" \
        --plat-name "$ABI" --python-version "$PYTHON_VERSION" \
        --cache-dir "$WORK_ROOT/cache/py${PYTHON_VERSION/./}" \
        --ndk-path "$NDK_ROOT" --sdk-path "$ANDROID_SDK_ROOT" \
        --api-level "$API" --sdk-api-level 36 \
        --qt-install-path "$QT_PREFIX" --qt-host-path "$QT_HOST_PREFIX" \
        --parallel "$JOBS"
    mkdir -p "$WORK_ROOT/wheels/py${PYTHON_VERSION/./}"
    cp "$PYSIDE_FORK/dist/"*"cp${PYTHON_VERSION/./}-cp${PYTHON_VERSION/./}-android_$ABI.whl" \
        "$WORK_ROOT/wheels/py${PYTHON_VERSION/./}/"
    python3 "$ROOT/scripts/check-android-wheels.py" \
        --python-version "$PYTHON_VERSION" --abi "$ABI" \
        "$WORK_ROOT/wheels/py${PYTHON_VERSION/./}/"*"cp${PYTHON_VERSION/./}-cp${PYTHON_VERSION/./}-android_$ABI.whl"
fi
