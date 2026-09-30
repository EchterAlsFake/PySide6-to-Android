#!/usr/bin/env bash
# Check that a packaged Android CPython prefix has its native modules and
# 16 KiB ELF load alignment. Run after build-android-runtime.sh.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK_ROOT=${WORK_ROOT:-"$ROOT/work"}
API=${ANDROID_NATIVE_API:-35}
PYTHON_VERSION=${1:?Usage: check-android-runtime.sh PYTHON_VERSION [ABI]}
ABI=${2:-aarch64}
PYTAG=${PYTHON_VERSION/./_}
PREFIX="$WORK_ROOT/cache/py${PYTHON_VERSION/./}/Python-$ABI-linux-android-$PYTAG/_install"

case "$ABI" in
    aarch64) MACHINE='AArch64' ;;
    armv7a) MACHINE='ARM' ;;
    i686) MACHINE='Intel 80386' ;;
    x86_64) MACHINE='Advanced Micro Devices X86-64' ;;
    *) echo "Unknown ABI: $ABI" >&2; exit 2 ;;
esac

test -f "$PREFIX/lib/libpython$PYTHON_VERSION.so" || {
    echo "Missing libpython in $PREFIX" >&2; exit 1;
}
for module in _ssl _hashlib _ctypes _bz2 _lzma _sqlite3; do
    if ! find "$PREFIX/lib/python$PYTHON_VERSION/lib-dynload" -maxdepth 1 \
        -name "$module.*.so" -print -quit | grep -q .; then
        echo "Missing Android Python module: $module" >&2
        exit 1
    fi
done
for library in libssl.so libcrypto.so libffi.so liblzma.so libsqlite3.so; do
    test -e "$PREFIX/lib/$library" || {
        echo "Missing native library in runtime: $library" >&2; exit 1;
    }
done

count=0
while IFS= read -r -d '' shared_object; do
    machine=$(readelf -h "$shared_object" | sed -n 's/^[[:space:]]*Machine:[[:space:]]*//p')
    if [[ "$machine" != "$MACHINE" ]]; then
        echo "Wrong architecture: $shared_object ($machine)" >&2
        exit 1
    fi
    alignments=$(readelf -Wl "$shared_object" | awk '$1 == "LOAD" { print $NF }')
    test -n "$alignments" || { echo "No LOAD segments: $shared_object" >&2; exit 1; }
    while read -r alignment; do
        if (( alignment < 0x4000 )); then
            echo "ELF alignment below 16 KiB: $shared_object ($alignment)" >&2
            exit 1
        fi
    done <<< "$alignments"
    ((count += 1))
done < <(find "$PREFIX/lib" -type f -name '*.so*' -print0)

echo "Validated $count Android $ABI ELF files and CPython $PYTHON_VERSION native modules (API $API)."
