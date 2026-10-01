# PySide6 on Android — Practical Guide

> [!CAUTION]
> Because of the next exams in school and my focus shifting entirely to my other projects, I am heavily
using AI to maintain this project. Everything you see is tested by a human!

If you have a problem with that, make your own :) 

> [!NOTE]
> This guide is **unofficial** and not affiliated with Qt. For authoritative details on the Android toolchain and the
> overall process, see the official documentation and blog posts:
> - [Taking Qt for Python to Android](https://www.qt.io/blog/taking-qt-for-python-to-android)
> - [Qt for Python v6.8 announcement](https://www.qt.io/blog/qt-for-python-release-6.8)

> [!IMPORTANT]
> Building and shipping **PySide6** apps to Android is non‑trivial. Read this guide **end‑to‑end** before you start—
> the pitfalls are real, and many of them are captured here so you don’t have to rediscover them. 🙂

---

## Supported Versions

- **Qt / PySide6:** `6.11.2`
- **Official Android wheels:** Python `3.11`, AArch64 and x86_64
- **Experimental source builds from the companion fork:** Python `3.10`–`3.14` on AArch64

> [!WARNING]
> Python versions other than the official 3.11 require a source build. Wheels are not substitutes
> for testing the complete Python runtime and application packaging on a real
> Android device.

---

## Table of Contents

- [Overview](#overview)
- [Get Prebuilt Android Wheels](#get-prebuilt-android-wheels)
- [Environment Setup (SDK/NDK)](#environment-setup-sdkndk)
- [Build the APK](#build-the-apk)
  - [Configure `buildozer.spec`](#configure-buildozerspec)
  - [Optional: Pause `pyside6-android-deploy` to tweak config](#optional-pause-pyside6-android-deploy-to-tweak-config)
  - [Run the final build](#run-the-final-build)
  - [Install & Debug on Device](#install--debug-on-device)
- [Common Errors & Fixes](#common-errors--fixes)
- [Debugging Strategy (Highly Recommended)](#debugging-strategy-highly-recommended)
- [Building Qt and the Wheels Yourself](#building-qt-and-the-wheels-yourself)
- [Contributing](#contributing)
- [Support](#support)

---

## Overview
Android devices typically use one of four CPU architectures: `armv7`, `aarch64`, `x86_64`, `i686`.  
To maximize compatibility, you’ll often want to build for multiple architectures. The official
`pyside6-android-deploy` tool orchestrates most of the process.

---

## Get Prebuilt Android Wheels
Since Qt 6.8, **official Android wheels** are published and are the **recommended** route.
You’ll save hours of compilation time and avoid a lot of complexity.

- Public archive: `https://download.qt.io/official_releases/QtForPython/`

> [!NOTE]
> As of now, official Android wheels are available for **`aarch64`** and **`x86_64`**.

**Direct links for 6.11.2 (Python 3.11):**

- **PySide6**
  - [aarch64](https://download.qt.io/official_releases/QtForPython/pyside6/pyside6-6.11.2-6.11.2-cp311-cp311-android_aarch64.whl)
  - [x86_64](https://download.qt.io/official_releases/QtForPython/pyside6/pyside6-6.11.2-6.11.2-cp311-cp311-android_x86_64.whl)

- **Shiboken6**
  - [aarch64](https://download.qt.io/official_releases/QtForPython/shiboken6/shiboken6-6.11.2-6.11.2-cp311-cp311-android_aarch64.whl)
  - [x86_64](https://download.qt.io/official_releases/QtForPython/shiboken6/shiboken6-6.11.2-6.11.2-cp311-cp311-android_x86_64.whl)


If you prefer building your own wheels, see [Building Qt and the Wheels Yourself](#building-qt-and-the-wheels-yourself).
Wheels compiled by myself may also be available on the project’s GitHub Releases page, but use them **at your own risk**.

---

## Environment Setup (SDK/NDK)

To build an APK, you need both the **Android SDK** and **Android NDK**. You can install them manually, but the
Qt-provided helper is convenient.

### Install base dependencies (example: Arch Linux)
Although not strictly required, the following set is a good baseline:

```bash
sudo pacman -Syu base-devel android-tools android-udev clang jdk21-openjdk llvm openssl cmake wget git zip
```

### Fetch SDK & NDK with `pyside-setup` helper

```bash
cd ~/
git clone https://github.com/EchterAlsFake/pyside-setup-android
cd pyside-setup-android
git checkout android-cross-build-fixes
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install -r tools/cross_compile_android/requirements.txt
python tools/cross_compile_android/main.py --download-only --auto-accept-license
```

> [!IMPORTANT]
> If you prefer to review licenses manually, omit `--auto-accept-license` and add `--verbose` so the license text is shown.

After running the script, the tools are placed at:

- **Android SDK:** `~/.pyside6_android_deploy/android-sdk/`
- **Android NDK:** `~/.pyside6_android_deploy/android-ndk/android-ndk-r27c/`

---

## Build the APK

### Configure `buildozer.spec`

> [!NOTE]
> `buildozer` (using **Python‑for‑Android** under the hood) handles packaging. Its `buildozer.spec` file
> controls app metadata, permissions, dependencies, orientation, and more.

Key options you’ll likely touch:

- `requirements`: Comma‑separated list of Python dependencies your app needs.
- `icon.filename`: App icon file (`.png` or `.jpg`). See Android’s
  [Adaptive Icons](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive).
- `title`: App display name.
- `version`: App version (e.g., `1.1`).
- `android.permissions`: Requested Android permissions. See
  [Manifest.permission](https://developer.android.com/reference/android/Manifest.permission).
- `package.name`: Output package name.
- `package.domain`: Reverse‑DNS app identifier (unique in the Android ecosystem).
- `orientation`: `portrait` or `landscape`.
- `android.api`: Target API level (use current stable / highest you can).
- `android.minapi`: Minimum supported API. Qt 6.11 requires API 28 or newer;
  your other native libraries may require a higher value.

Every dependency containing native code needs an Android wheel for the same
ABI, or a compatible python-for-android recipe. Pure-Python packages can
usually be packaged directly. Avoid carrying old desktop-specific pins into a
new build unless the current resolver output proves they are still necessary.

### Optional: Pause `pyside6-android-deploy` to tweak config

By default, `pyside6-android-deploy` immediately starts the build and doesn’t give you a chance to edit
`buildozer.spec`. You can add a simple pause:

1. Activate your virtualenv and locate the PySide6 scripts folder (e.g. `venv/lib/python3.11/site-packages/PySide6/scripts/`).
2. Open `android_deploy.py`.
3. Find the line:
   ```python
   logging.info("[DEPLOY] Running buildozer deployment")
   ```
4. Insert this line **above** it:
   ```python
   input("Modify your buildozer.spec now and press Enter to continue...")
   ```

Now the build will pause so you can edit `buildozer.spec` before it proceeds.

### Run the final build

> [!IMPORTANT]
> Name your entry script **`main.py`**.

From your project’s source directory, run:

```bash
pyside6-android-deploy \
    --wheel-pyside=/path/to/PySide6-6.11.2-...-android_<arch>.whl \
    --wheel-shiboken=/path/to/shiboken6-6.11.2-...-android_<arch>.whl \
    --name=main \
    --ndk-path ~/.pyside6_android_deploy/android-ndk/android-ndk-r27c \
    --sdk-path ~/.pyside6_android_deploy/android-sdk/
```

**Arguments explained**

- `--wheel-pyside`: The PySide6 Android wheel you downloaded (per architecture).
- `--wheel-shiboken`: The matching Shiboken6 Android wheel.
- `--name`: Your application name (entry point is `main.py`).
- `--ndk-path`: Path to your Android NDK.
- `--sdk-path`: Path to your Android SDK.

If everything goes well, you’ll end up with an **`.apk`** for the specified architecture.

### Install & Debug on Device

Using **ADB** is the most reliable way to install and debug quickly:

1. Enable Developer Options (tap “Build number” multiple times).
2. Enable **USB debugging** (or **Wireless debugging** if applicable).
3. Install platform tools:
   - **Arch Linux:** `sudo pacman -S android-tools`
   - **Ubuntu/Debian:** `sudo apt install android-tools-adb android-tools-fastboot`
   - **Windows/macOS:** Install [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools).

4. Verify device connection:
   ```bash
   adb devices
   ```
   Confirm the authorization dialog on your device, then run `adb devices` again.

Alternatively, you can also use Android Studio to install and run your application.
Android studio will provide you automatically with detailed logging.

**Core commands**

```bash
# Install your build
adb install /path/to/your.apk

# Stream logs (replace with your final package name)
adb logcat --regex "com.example.yourapp"
```

Once installed, the app appears in your launcher. In **App info**, you’ll typically see something like:

```
Version 2.1.6
com.example.yourapp
```

The first line is the human‑readable app version; the second line is your package ID. Use `adb logcat` while
launching the app to capture crashes and diagnostics.

> [!NOTE]
> Steps may vary slightly by device/Android version. If you get stuck, search on Google, Stack Overflow, or XDA.

---

## Common Errors & Fixes

- **RuntimeError — “You are including a lot of QML files from a local venv…”**  
  Ensure your **virtual environment is _not_ inside your project folder**. Create it elsewhere and delete the old one:
  ```bash
  rm -rf venv .venv
  ```
  (This appears to be a Qt quirk and may improve in future releases.)

- **“C compiler cannot create executables”**  
  Often caused by targeting too high an API level for the available toolchains. Inspect the toolchain directory indicated
  in the error and check the highest available `androidclangXX-` version; use a matching or lower API level.

- **“… is for x86_64 architecture, not aarch64” (or similar)**  
  Verify that each third‑party wheel you depend on has an Android build for your target architecture. If not, you may need
  to provide/build a recipe (expect significant effort).

- **`DeadObjectException` (e.g., “Couldn't insert … into …”)**  
  This is a generic failure that can have many causes—often trying to access a resource that doesn’t exist or is
  inaccessible. Check file paths, storage permissions, and logging calls. If you see this, jump to the
  [Debugging Strategy](#debugging-strategy-highly-recommended).

- **`ModuleNotFoundError: No module named <your_module>`**  
  Some libraries pull in additional dependencies you must list explicitly under `requirements`. For example, using `httpx`
  may require `httpx`, `httpcore`, `idna`, `certifi`, `h11`, and `sniffio`. Inspect dependency trees and include all
  required packages.

---

## Debugging Strategy (Highly Recommended)

> [!IMPORTANT]
> Expect the **first run to crash** while you sort out packaging details. Proactive logging helps you pinpoint the issue fast.

Add a minimal HTTP logger that works without external dependencies:

```python
import http.client
import json

def send_error_log(message: str):
    url = "<your_pc_ip>:8000"  # e.g. 192.168.1.23:8000
    endpoint = "/error-log/"
    data = json.dumps({"message": message})
    headers = {"Content-type": "application/json"}
    conn = http.client.HTTPConnection(url)
    conn.request("POST", endpoint, data, headers)
```

Sprinkle `send_error_log("reached step X")` through critical code paths to find the exact crash point.

**Simple receiver (FastAPI):**

```python
from fastapi import FastAPI
from pydantic import BaseModel

class ErrorLog(BaseModel):
    message: str

app = FastAPI()

@app.post("/error-log/")
def receive_error_log(error_log: ErrorLog):
    print(f"Received error: {error_log.message}")
    return {"detail": "Error log received"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

Run this on your computer or another device on the same network:
```
pip install fastapi pydantic uvicorn
```

> [!IMPORTANT]
> Use **JDK 21 or newer** with Qt 6.11. Older JDK 17 instructions apply to
> earlier Qt releases and fail the current toolchain requirement.

---

## Building Qt and the Wheels Yourself

The old workflow required editing `PYTHON_VERSION`, hand-fixing an ARM
toolchain after generation, and repeatedly deleting a shared cache. Those
workarounds are replaced by the companion
[`pyside-setup-android`](https://github.com/EchterAlsFake/pyside-setup-android)
fork.

See the complete [Qt 6.11 source-build guide](SOURCE_BUILD_6.11.md). It covers:

- building the exact same Qt version for the Linux host and Android;
- the extra host generators required by Quick3D, SCXML, RemoteObjects,
  CanvasPainter, and Lottie;
- the SDK 36 versus native API 35 split;
- separate, versioned CPython caches for 3.10 through 3.14;
- the corrected ARM compiler flags and dynamically derived Python SOABI;
- known OpenSSL and optional CPython-module limitations.

The [Android runtime helper](RUNTIME_BUILD.md) automates target builds of
OpenSSL, libffi, bzip2, xz, SQLite, and CPython, with optional installation of
Arch Linux host build packages. It can also invoke the companion fork to build
the corresponding PySide6 wheels.

The source-build path has produced and statically validated AArch64 and armv7
wheels for Python 3.10 through 3.14.
Use `scripts/rebuild-android-matrix.sh` to build the remaining combinations.
The artifacts have not yet been run in an APK; device and emulator testing
remains necessary.
The completed wheels and Android Python runtimes are backed up in the
[Qt 6.11.2 Android matrix prerelease](https://github.com/EchterAlsFake/PySide6-to-Android/releases/tag/android-matrix-snapshot-2026-09-30).

---

## Contributing
Spotted inaccuracies or have improvements? Please open an issue or PR. Contributions for other distributions (besides
Arch) are especially welcome.

## Support
If this guide helped you, a ⭐ on the repository is appreciated—it helps others discover it and keeps the project healthy.

## Donations
Compiling your application is very easy since Qt 6.8, however, if I was able to
save you some time with this guide, you can donate me money through:

- [PayPal](https://paypal.me/EchterAlsFake)
- [Ko-Fi](https://ko-fi.com/echteralsfake)

**Thank you very much <3**
