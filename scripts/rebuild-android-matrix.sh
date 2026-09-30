#!/usr/bin/env bash
# Build Qt, CPython runtimes, and Qt for Python wheels for the full Android matrix.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK_ROOT=${WORK_ROOT:-"$ROOT/work"}
PYSIDE_FORK=${PYSIDE_FORK:-"$ROOT/../pyside-setup-android"}
ABIS=${ABIS:-"aarch64 armv7a i686 x86_64"}
PYTHON_VERSIONS=${PYTHON_VERSIONS:-"3.10 3.11 3.12 3.13 3.14"}
RESUME=${RESUME:-0}
RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)
LOG_DIR="$WORK_ROOT/logs/matrix-$RUN_ID"
mkdir -p "$LOG_DIR" "$WORK_ROOT/previous-target-builds"

run_logged() {
    local label=$1
    shift
    echo "[$(date -u +%FT%TZ)] Starting $label"
    if "$@" > "$LOG_DIR/$label.log" 2>&1; then
        echo "[$(date -u +%FT%TZ)] Passed $label"
    else
        echo "[$(date -u +%FT%TZ)] Failed $label; see $LOG_DIR/$label.log" >&2
        tail -40 "$LOG_DIR/$label.log" >&2
        exit 1
    fi
}

for abi in $ABIS; do
    run_logged "qt-$abi" bash "$ROOT/scripts/build-qt-android.sh" "$abi"
    for version in $PYTHON_VERSIONS; do
        short=${version/./}
        if [[ "$RESUME" == 1 ]]; then
            shopt -s nullglob
            wheels=("$WORK_ROOT/wheels/py$short/"*"cp$short-cp$short-android_$abi.whl")
            shopt -u nullglob
            if bash "$ROOT/scripts/check-android-runtime.sh" "$version" "$abi" \
                > /dev/null 2>&1 && \
                python3 "$ROOT/scripts/check-android-wheels.py" \
                    --python-version "$version" --abi "$abi" "${wheels[@]}" \
                    > /dev/null 2>&1; then
                echo "[$(date -u +%FT%TZ)] Already validated py$short-$abi"
                continue
            fi
        fi
        # setup.py can reuse CMake cache entries containing old link flags or
        # target paths. Keep the prior tree for diagnosis and configure afresh.
        old_build="$PYSIDE_FORK/build/qfp-py$version-qt6.11.2-android_$abi-release"
        if [[ "$RESUME" != 1 && -d "$old_build" ]]; then
            mv "$old_build" "$WORK_ROOT/previous-target-builds/$(basename "$old_build")-$RUN_ID"
        fi
        run_logged "py$short-$abi" bash "$ROOT/scripts/build-android-runtime.sh" \
            --python-version "$version" --abi "$abi" --with-wheels
    done
done

echo "All requested Qt, runtime, and wheel builds passed. Logs: $LOG_DIR"
