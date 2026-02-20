# PySide6 on Android — Practical Guide

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

- **PySide6:** `6.10.2` (guide verified against this version)
- **Python:** `3.11.x` (preferred) or `3.10.x`

> [!WARNING]
> Ensure your application is compatible with **Python 3.10 or 3.11**. Other versions are not supported by Qt (on Android)

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
- [Legacy: Building the Wheels Yourself](#legacy-building-the-wheels-yourself)
  - [Install Qt](#install-qt)
  - [Install dependencies](#install-dependencies)
  - [Prepare `pyside-setup`](#prepare-pyside-setup)
  - [Build Qt/PySide Wheels](#build-qtpyside-wheels)
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

**Direct links for 6.10.2 (Python 3.11):**

- **PySide6**
  - [aarch64](https://download.qt.io/official_releases/QtForPython/pyside6/PySide6-6.10.2-6.10.2-cp311-cp311-android_aarch64.whl)
  - [x86_64](https://download.qt.io/official_releases/QtForPython/pyside6/PySide6-6.10.2-6.10.2-cp311-cp311-android_x86_64.whl)

- **Shiboken6**
  - [aarch64](https://download.qt.io/official_releases/QtForPython/shiboken6/shiboken6-6.10.2-6.10.2-cp311-cp311-android_aarch64.whl)
  - [x86_64](https://download.qt.io/official_releases/QtForPython/shiboken6/shiboken6-6.10.2-6.10.2-cp311-cp311-android_x86_64.whl))


If you prefer building your own wheels, see the [Legacy](#legacy-building-the-wheels-yourself) section below.
Wheels compiled by myself may also be available on the project’s GitHub Releases page, but use them **at your own risk**.

---

## Environment Setup (SDK/NDK)

To build an APK, you need both the **Android SDK** and **Android NDK**. You can install them manually, but the
Qt-provided helper is convenient.

### Install base dependencies (example: Arch Linux)
Although not strictly required, the following set is a good baseline:

```bash
sudo pacman -Syu base-devel android-tools android-udev clang jdk17-openjdk llvm openssl cmake wget git zip
```

### Fetch SDK & NDK with `pyside-setup` helper

```bash
cd ~/
git clone https://code.qt.io/pyside/pyside-setup
cd pyside-setup
git checkout 6.10.2   # dev branch can work, but is more error-prone
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
- `android.minapi`: Minimum supported API (e.g., 21+).

**Special note about `charset_normalizer` / `requests`:**  
If your project uses **`requests`** or anything that depends on `charset_normalizer`, pin:
```
charset-normalizer==2.1.1
```
to avoid architecture mismatches during packaging.

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
pyside6-android-deploy   --wheel-pyside=/path/to/PySide6-6.9.3-...-android_<arch>.whl   --wheel-shiboken=/path/to/shiboken6-6.9.3-...-android_<arch>.whl   --name=main   --ndk-path ~/.pyside6_android_deploy/android-ndk/android-ndk-r27c   --sdk-path ~/.pyside6_android_deploy/android-sdk/
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
> Use **Java 17**. While Gradle often recommends Java 11 and newer JDKs exist (e.g., 21),
> Qt’s current toolchain is aligned with **JDK 17**.

---

## Legacy: Building the Wheels Yourself

> [!NOTE]
> This path is provided for reference and is **not** maintained as frequently. It may contain rough edges. Proceed if
> you specifically need custom-builds or unsupported combinations.

### Install Qt
- Sign in at [qt.io](https://qt.io).
- Download the Qt Online Installer.
- Install both **Desktop** and **Android** components (≈ 1.3 GB download).

### Install dependencies

#### Arch Linux (recommended)

```bash
sudo pacman -Syu base-devel android-tools android-udev clang jdk17-openjdk llvm openssl cmake wget p7zip git zip
```

### Prepare `pyside-setup`

```bash
python3.11 -m venv venv
source venv/bin/activate
git clone https://code.qt.io/pyside/pyside-setup
cd pyside-setup
git checkout 6.10.1   # dev is possible, but not recommended
pip install -r requirements.txt
pip install -r tools/cross_compile_android/requirements.txt
pip install pyside6
cd
```

### Build Qt/PySide Wheels

The build helper lives at `pyside-setup/tools/cross_compile_android/main.py`.

Android architectures:
- `aarch64`
- `armv7a`
- `x86_64`
- `i686`

> [!NOTE]
> You only need to build these once; you can reuse the wheels across projects.

#### Important:
You need to make a dummy fix for armv7a to work. After you have compiled the other 3 architectues, go to:
`~/.pyside6_android_deploy/toolchain_armv7a.cmake` and remove the if statement after line 28, where it
applies the `'-mpopcnt'` as a target, because this is invalid for armv7a. I don't know why Qt has it there, because
it makes no sense, but yeah just remove it, and you are good to go.

So basically remove evrything after the `set(QT_COMPILER_FLAGS) .... -Wno-unused-command-line-argument")`
and before `set(QT_COMPILER_FLAGS_RELEASE "-O2 -pipe")`

But that don't clean cache then, because this will obviously override the toolchain. 


**Speed‑ups (optional):**
- To build for **Python 3.10**, edit `main.py` and change `PYTHON_VERSION = 3.11` to `3.10`.
- To change the NDK version from `r27c`, edit `tools/cross_compile_android/android_utilities.py`.
- To speed up CPython cloning, in `main.py` find `if not cpython_dir.exists():` and add `depth=1` to `Repo.clone_from()`.

**Template command:**

```bash
python tools/cross_compile_android/main.py --plat-name=<aarch64|armv7a|x86_64|i686> --qt-install-path=/path/to/Qt/6.10.1 --api-level 35 --auto-accept-license --clean-cache all
```

Wheels appear under `dist/` when complete. If you hit errors, try:
```
--clean-cache all
```

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
