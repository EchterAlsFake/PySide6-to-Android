# Qt 6.11.2 / PySide6 6.11.2 Android investigation

Test host: Arch Linux, 10 September 2026. Target used for the first reproducible
build is `arm64-v8a`.

## Required versions

| Component | Version used | Why |
| --- | --- | --- |
| Qt / Qt for Python | 6.11.2 | Current matching release |
| JDK | Temurin 21.0.12.1 | Qt 6.11 requires JDK 21 or newer |
| Android SDK platform | 36 revision 2 | Qt 6.11 Java sources require `android.jar` from API 36 |
| Android build tools | 36.0.0 | Qt 6.11 documented version |
| Android NDK | r27c (`27.2.12479018`) | Qt 6.11 supported NDK |
| Native API for CPython | 35 | NDK r27c has no API-36 compiler wrapper |

The SDK API and native API must not be represented by one setting. With the
old guide's API 35 SDK, Qt configuration fails because
`platforms/android-36/android.jar` is missing. With native API 36, CPython
fails because `aarch64-linux-android36-clang` does not exist in NDK r27c.

## Confirmed helper defects

The upstream `tools/cross_compile_android/main.py` in the `v6.11.2` tag:

1. hard-codes Python 3.11 in both Python and CMake code;
2. reuses generated scripts and CMake toolchains containing stale absolute
   paths;
3. shares one CPython checkout and one target prefix across Python versions;
4. assumes host and Android Qt use the Qt online installer's directory layout;
5. hard-codes nine parallel jobs;
6. uses one API value for native compilation and automatic SDK installation;
7. emits x86-only compiler flags for ARM targets;
8. breaks Python 3.10 when launched from a virtual environment because the
   venv's `sys._home` redirects old CPython `sysconfig` logic to the installed
   host prefix;
9. allows host `pkg-config` metadata to enable unavailable Android libraries,
   which breaks Python 3.14 at `_bz2` (and potentially other modules);
10. launches each `setup.py` subprocess without activating or adding the
    selected virtual environment to `PATH`, so the target packaging phase
    cannot find the venv-provided `patchelf`; and
11. unconditionally compiles the generated `QSslEllipticCurve` wrapper even
    when Qt's `ssl` feature is disabled and Shiboken therefore does not
    generate that source file.

The fork now also validates the requested SDK `android.jar`, the
architecture/API-specific NDK compiler wrapper, and the matching cached
`libpython` before an expensive build starts.

A clean local fork based on upstream tag `v6.11.2` is prepared at
`../pyside-setup-android`, branch `android-cross-build-fixes`. It addresses the
items above and leaves its `origin` remote free for the maintainer's GitHub
fork. The Qt repository is configured as remote `upstream`.

## CPython target prefixes

Python 3.10, 3.11, and 3.14 have each been cross-compiled for AArch64 with NDK
r27c at native API 35. Their headers and shared libraries are valid, and their
target prefixes contain 59, 60, and 60 extension modules respectively.

The generic NDK build does not provide Android builds of OpenSSL, libffi,
bzip2, lzma, and similar third-party libraries. Corresponding optional stdlib
modules are omitted. This does not prevent using the prefix to compile PySide6,
but it matters when assembling a production Python runtime. Python 3.14 also
offers an official Android build and packaging workflow under
`Platforms/Android`.

## Qt source-build failures reproduced

1. SDK platform 35 is too old for Qt 6.11 Java sources; configuration requires
   `platforms/android-36/android.jar`.
2. A distro Qt 6.11.2 prefix without Qt Linguist Tools is not a sufficient
   cross-build host; the target configure cannot resolve host `lconvert`.
3. A source-built host containing only Base, Declarative, ShaderTools, and
   Tools is still insufficient for the larger target module set. Quick3D,
   SCXML, RemoteObjects, CanvasPainter, and Lottie require the host packages
   exporting `balsam`, `qscxmlc`, `repc`, `qcshadergen`, and `lottietoqml`.
4. Selecting `qtwebview` causes the supermodule to consider its optional
   QtWebEngine dependency. Without an explicit `-skip qtwebengine`, Android
   cross-configuration fails looking for a host `gn` executable.
5. PySide's target packaging subprocess cannot find `patchelf` even though the
   host-generator phase finds the copy installed in the same venv. The helper
   must prepend the invoked interpreter's scripts directory to `PATH` before
   launching either subprocess.
6. A Qt build without Android OpenSSL makes Shiboken omit
   `qsslellipticcurve_wrapper.cpp`, but the QtNetwork CMake source list still
   includes it. Moving that wrapper into the existing `ssl`-enabled source
   branch fixes the generated unity build.

The final configuration succeeds after installing those same-version host
tools and explicitly skipping QtWebEngine. It builds Qt for Android with a
native minimum API of 28 and 16 KiB page-size support. DBus, Hunspell, and
Android OpenSSL are absent in this configuration.

## Build status

- Source-built Qt 6.11.2 host prefix and module-specific tools: complete and
  validated.
- Source-built Qt 6.11.2 `arm64-v8a` prefix: complete and validated (137
  shared Qt libraries; Qt Core is AArch64, Android API 28, NDK r27c).
- PySide6/Shiboken6 AArch64 wheels for Python 3.10, 3.11, and 3.14: complete.

## Wheel validation

| Python | PySide6 SHA-256 | Shiboken6 SHA-256 |
| --- | --- | --- |
| 3.10 | `6961fb15171d2ad689d98d0cd7bc3a5cd1aa23c57486d9282c20484a441d4f0a` | `004df9c2bcf1563b751e9a0e8695243e7a76274fc58a5138b3678abe6b5e1492` |
| 3.11 | `edb08e2c43961050416153d336024f1a5cf100647f775cc8216ba7639d40ebe5` | `f91ce80ce880900e855bfe6f1b11df03cce1a5865d880429490195578c340f65` |
| 3.14 | `730723486baa98f7e35fa7a290e2c9f76aa282f1f6eccafd425481e900afe38b` | `49222bd177aa4bf77dff72d68bf27b6245a38bb7dfe69289769ed17b7ce0e7c7` |

All six archives pass `unzip -t`. Their wheel tags are the matching
`cp310`, `cp311`, or `cp314` plus `android_aarch64`. The PySide and Shiboken
extensions are AArch64 Android 35 ELF objects and depend on the matching
`libpython3.x.so`. A later full-archive audit found that the Shiboken shared
objects in these older wheels have `0x1000` (4 KiB) load alignment; the
companion fork's linker template was corrected on 29 September 2026. An audit
of 1,038 ELF files in the three packaged trees found no host-architecture
binaries.

Artifacts are under `work/wheels/py310`, `work/wheels/py311`, and
`work/wheels/py314`. They have not yet been exercised in an APK on a device or
emulator, so runtime compatibility remains a separate validation step.

Large downloaded sources, SDKs, build trees, and artifacts live below
`work/`, which is intentionally ignored by Git.

## 29 September 2026 update

The new `scripts/build-android-runtime.sh` builds target OpenSSL 3.5.8 LTS,
libffi 3.4.8, bzip2 1.0.8, xz 5.8.4, SQLite 3.50.4, and CPython. Arch Linux
host package installation is available only when `--install-arch-deps` is
requested. AArch64 CPython 3.12 and 3.13 runtimes now include `_ssl`,
`_hashlib`, `_ctypes`, `_bz2`, `_lzma`, and `_sqlite3`. The runtime audit passed
76 and 77 Android shared objects respectively, all with 16 KiB load alignment.

The companion fork's Android linker template now requests 16 KiB alignment
for Shiboken as well. Fresh Qt for Python 6.11.2 AArch64 wheels were built:

| Python | PySide6 SHA-256 | Shiboken6 SHA-256 |
| --- | --- | --- |
| 3.12 | `09c5247845cb74aac32a68746165135c274d32b139ce73393dc4bfc8bd92976a` | `38f0ff1bb427f2e69fde0e5080237b9dec7277d0a404fa268b458602deadc6cd` |
| 3.13 | `f54a077b2a964460b8d5766cea553c5134c072b24be37b5b56ce02eef68ec59a` | `e3f6782b61b12d7d56500857c892739177984033421ca9b2284656bb1faddeec` |

Each wheel pair passed archive integrity, wheel-tag, AArch64 ELF, and 16 KiB
alignment checks across 347 packaged shared objects. Artifacts are under
`work/wheels/py312` and `work/wheels/py313`. They have not been tested in an
APK. The older 3.10, 3.11, and 3.14 Shiboken wheels were subsequently
rebuilt with the updated linker template, as recorded below.

## 30 September 2026 rebuild status

The matrix helpers in `scripts/` now build Qt, native dependencies, CPython,
PySide6, and Shiboken6 for all four Android ABIs and Python 3.10–3.14. The
build is resumable with `RESUME=1`. The completed arm64 and armv7 wheels for
all five Python versions pass runtime and wheel audits, including Android ELF
architecture and 16 KiB alignment. The older
arm64 wheels were rebuilt with the corrected linker flags. armv7 Qt was also
rebuilt with explicit 16 KiB linker flags. All x86 and x86_64 combinations
remain to be built.

The wheel files and Android runtime prefixes are in ignored `work/`; Git
commits contain the scripts and documentation, not those binary artifacts.
Device or emulator execution has not yet been tested. QtNetwork HTTPS still
needs a Qt build configured with Android OpenSSL.

The 20 completed wheel files, SHA-256 list, and compressed Android CPython
runtime prefixes have been backed up to the GitHub prerelease
`android-matrix-snapshot-2026-09-30`. The main build scripts are on `master`
and the companion PySide fork is on branch `android-cross-build-fixes` at
`https://github.com/EchterAlsFake/pyside-setup`.
