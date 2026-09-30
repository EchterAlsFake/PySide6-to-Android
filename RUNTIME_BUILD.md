# Android Python runtime and native dependencies

The helper [`scripts/build-android-runtime.sh`](scripts/build-android-runtime.sh)
builds a CPython Android prefix with OpenSSL 3.5.8 LTS (`ssl`, `hashlib`), libffi
(`ctypes`), bzip2 (`bz2`), xz (`lzma`), and SQLite (`sqlite3`). It puts the
shared libraries beside `libpython` in the runtime prefix, where an APK
packaging step can collect them. Source archive SHA-256 values are pinned in
the script; downloaded archives are kept under `work/runtime-sources`.

For the existing Qt 6.11.2 AArch64 installation, build a runtime and wheels:

```bash
bash scripts/build-android-runtime.sh --python-version 3.12 --abi aarch64 --with-wheels
bash scripts/build-android-runtime.sh --python-version 3.13 --abi aarch64 --with-wheels
```

Build Qt, runtimes, and both wheels for all four Android ABIs and Python
3.10–3.14 with one command:

```bash
bash scripts/rebuild-android-matrix.sh
```

This uses the source-built host Qt and builds missing Android Qt prefixes
through `scripts/build-qt-android.sh`. It runs each target sequentially and
stores per-target logs under `work/logs/matrix-<UTC timestamp>/`. It moves
prior PySide target build trees into `work/previous-target-builds/` so CMake
does not reuse toolchain settings from an older build. Set `ABIS` or
`PYTHON_VERSIONS` to a space-separated subset to resume part of the matrix,
and `JOBS` to control parallel compilation within each target. Set `RESUME=1`
after an interruption to skip pairs that pass both audits and reuse the
current CMake target build tree for an unfinished pair.
After the build, audit the complete matrix with
`bash scripts/check-android-matrix.sh`; it checks each runtime and wheel pair.

Each call builds a matching host CPython if it is absent, then the Android
libraries and target CPython. Dependencies are shared by Python versions for
the same ABI and native API. The target Python prefix is placed in the cache
path consumed by the companion PySide helper. Wheel outputs are copied to
`work/wheels/py312` or `work/wheels/py313`.

Validate a built runtime with:

```bash
bash scripts/check-android-runtime.sh 3.12 aarch64
```

The check requires the expected extension modules, Android ELF architecture,
and 16 KiB load alignment for every shared object in the runtime prefix.
Wheel builds run `scripts/check-android-wheels.py` automatically. This checks
the wheel tags, archive integrity, architecture, and load alignment of every
packaged shared object, including Shiboken and Qt plugins.

The runtime source checkout's exact CPython commit is written to
`python-source-commit.txt` inside its target prefix. The native library source
versions and archive checksums are pinned in the build script.

Use `--abi armv7a`, `--abi i686`, or `--abi x86_64` when the corresponding Qt
Android prefix is available. Set `ANDROID_NDK_ROOT`, `ANDROID_SDK_ROOT`,
`QT_PREFIX`, `QT_HOST_PREFIX`, `PYSIDE_FORK`, `WORK_ROOT`, `ANDROID_NATIVE_API`,
or `JOBS` to override the defaults. Without `--with-wheels`, only the runtime
and its native libraries are built.

On Arch Linux and derivatives, add `--install-arch-deps` to allow the helper to
install host build packages with `sudo pacman`. This step is optional; normally
the helper just reports missing tools. It does not change installed packages
unless the flag is given.

The build uses NDK r27c native API 35 by default, separate from the SDK API
36 used by Qt's Java sources. The Qt prefix in this checkout was built without
Android OpenSSL, so its QtNetwork HTTPS support remains disabled even when
Python's `ssl` module is present. Rebuilding Qt with an Android OpenSSL prefix
is required to enable that Qt feature. An APK must include the runtime's
shared libraries and standard library, and should be tested on a device or
emulator before release.
