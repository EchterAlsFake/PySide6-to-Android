#!/usr/bin/env bash
# Build Qt, CPython runtimes, and Qt for Python wheels for the full Android matrix.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK_ROOT=${WORK_ROOT:-"$ROOT/work"}
PYSIDE_FORK=${PYSIDE_FORK:-"$ROOT/../pyside-setup-android"}
QT_VERSION=${QT_VERSION:-6.12.0}
ABIS=${ABIS:-"aarch64 armv7a i686 x86_64"}
PYTHON_VERSIONS=${PYTHON_VERSIONS:-"3.10 3.11 3.12 3.13 3.14"}
JOBS=${JOBS:-$(nproc 2>/dev/null || echo 4)}
export JOBS
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

run_logged "qt-host" bash "$ROOT/scripts/build-qt-host.sh"

for abi in $ABIS; do
    run_logged "qt-$abi" bash "$ROOT/scripts/build-qt-android.sh" "$abi"
    for version in $PYTHON_VERSIONS; do
        short=${version/./}
        if [[ "$RESUME" == 1 ]]; then
            shopt -s nullglob
            wheels=("$WORK_ROOT/wheels/py$short/"*"android_$abi.whl")
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
        # Ensure clean state for build
        rm -rf "$PYSIDE_FORK/build"
        run_logged "py$short-$abi" bash "$ROOT/scripts/build-android-runtime.sh" \
            --python-version "$version" --abi "$abi" --with-wheels
        # Clean up temporary build trees to conserve disk space
        rm -rf "$PYSIDE_FORK/build"
        rm -rf "$PYSIDE_FORK/dist"
        rm -rf "$WORK_ROOT/runtime-build"
        echo "[$(date -u +%FT%TZ)] Cleaned build cache for py$short-$abi; free space: $(df -h / | awk 'NR==2{print $4}')"
    done
done

echo "All requested Qt, runtime, and wheel builds passed. Logs: $LOG_DIR"
