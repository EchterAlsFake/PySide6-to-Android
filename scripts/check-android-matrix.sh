#!/usr/bin/env bash
# Audit every built runtime and wheel pair in the 5 x 4 Android matrix.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK_ROOT=${WORK_ROOT:-"$ROOT/work"}
ABIS=${ABIS:-"aarch64 armv7a i686 x86_64"}
PYTHON_VERSIONS=${PYTHON_VERSIONS:-"3.10 3.11 3.12 3.13 3.14"}
shopt -s nullglob

for abi in $ABIS; do
    case "$abi" in
        aarch64) suffix=arm64_v8a ;;
        armv7a) suffix=armv7 ;;
        i686) suffix=x86 ;;
        x86_64) suffix=x86_64 ;;
        *) echo "Unsupported ABI: $abi" >&2; exit 2 ;;
    esac
    test -f "$WORK_ROOT/qt/6.11.2/android_$suffix/lib/cmake/Qt6Core/Qt6CoreConfig.cmake"
    for version in $PYTHON_VERSIONS; do
        short=${version/./}
        bash "$ROOT/scripts/check-android-runtime.sh" "$version" "$abi"
        wheels=("$WORK_ROOT/wheels/py$short/"*"cp$short-cp$short-android_$abi.whl")
        python3 "$ROOT/scripts/check-android-wheels.py" \
            --python-version "$version" --abi "$abi" "${wheels[@]}"
    done
done

echo "All requested Android runtime and wheel pairs passed."
