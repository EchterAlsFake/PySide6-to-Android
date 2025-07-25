# PySide6 for Android Devices
> [!NOTE]
> DISCLAIMER: This guide is unofficial and not affiliated with Qt. Please refer to the Official Documentation about the compiling process for Android.

[Taking Qt for Python to Android](https://www.qt.io/blog/taking-qt-for-python-to-android)
<br>[Qt for Python v6.8](https://www.qt.io/blog/qt-for-python-release-6.8)

> [!IMPORTANT]
> Compiling PySide6 to Android is a very hard topic. To take yourself away from some pain, read the `WHOLE` guide
> in all of its details, because I already went through a lot of pain and took some notes for you :) 


## **This Guide is up to date with version:**

`PySide6 == 6.9.1`

## Table of contents
- [General](#a-general-explanation)
- [Downloading the Android wheels](#downloading-the-android-wheels)
- [Setup](#setup)
- [Building the Android APK](#building-the-android-apk)
  - [PySide6 modification](#pyside6-modification)
  - [The final build process](#the-final-build-process)
  - [Installation of your App](#installation-best-practices)
- [Errors and solutions](#errors-and-potential-solutions)
  - RuntimeError
  - C-Compiler can not create executables
  - python package architecture mismatch
  - DeadObjectException
  - Module not found error
- [DEBUGGING ::: IMPORTANT ::: ](#debugging)
- [Building the Wheels (LEGACY)](#legacy-building-the-wheels)
  - [Install dependencies](#install-dependencies)
  - [PySide-Setup](#pyside-setup)
  - [Building the wheels](#building-the-qt-wheels)


> [!WARNING]
> Before proceeding, make sure your app is compatible with either `Python3.10.x` or `Python3.11.x`

# A general explanation
Android devices can have one of the four architectures: `armv7`, `aarch64`, `x86_64`, `i686`.
You should compile your application for all four of these. This involves using the official `pyside6-android-deploy`
tool, which will automatically set everything up. 

## Downloading the Android wheels

Since Qt Version `6.8` Qt published their own Android wheels, which you need for building. I **STRONGLY**
recommend you to download them, instead of compiling your own. 

However, if you want to compile them by yourself, you can skip to the [LEGACY](#legacy-building-the-wheels) part.

Here's the link to their public archive: `https://download.qt.io/official_releases/QtForPython/`

And here are the links for every release:
> [!NOTE]
> Only the `aarch64` and `x86_64` versions are available at the moment.

I also compile my own wheels, which you can download in the [GitHub releases](https://github.com/EchterAlsFake/PySide6-to-Android/releases/tag/6.8.0_3.11), although
there's no guarantee for them to work!

- [PySide6 - aarch64](https://download.qt.io/official_releases/QtForPython/pyside6/PySide6-6.9.1-6.9.1-cp311-cp311-android_aarch64.whl)
- ~~[PySide6 - armv7]()~~
- ~~[PySide6 - i686]()~~
- [PySide6 - x86_64](https://download.qt.io/official_releases/QtForPython/pyside6/PySide6-6.9.1-6.9.1-cp311-cp311-android_x86_64.whl)

- [Shiboken - aarch64](https://download.qt.io/official_releases/QtForPython/shiboken6/shiboken6-6.9.1-6.9.1-cp311-cp311-android_aarch64.whl)
- ~~[Shiboken - armv7]()~~
- ~~[Shiboken - i686]()~~
- [Shiboken - x86_64](https://download.qt.io/official_releases/QtForPython/shiboken6/shiboken6-6.9.1-6.9.1-cp311-cp311-android_x86_64.whl)

# Setup
When building the .apk you need the Android SDK and NDK. You can install them manually and skip this 
section, but to make your life a little bit easier, I recommend using Qt's own tool for that purpose.

**Dependencies:**

Although you do not need all of them, I recommend installing them:

```bash
sudo pacman -Syu base-devel android-tools android-udev clang jdk17-openjdk llvm openssl cmake wget git zip
```


```bash
cd ~/
git clone https://code.qt.io/pyside/pyside-setup
cd pyside-setup 
git checkout 6.9.1 # You can also use dev branch, but could cause errors
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install -r tools/cross_compile_android/requirements.txt
python tools/cross_compile_android/main.py --download-only --auto-accept-license
```

> [!IMPORTANT]
> Make sure to use `auto-accept-license` flag to automatically accept the license. If you don't want to do this, and you want
> to manually view the license, you need to set the `--verbose` flag, otherwise the License Agreement won't be shown to you.


After you are finished with it, your Android SDK and NDK are in the following directories:

Android SDK: `~/.pyside6_android_deploy/android-sdk/`
<br>Android NDK:   `~/.pyside6_android_deploy/android-ndk/android-ndk-r27c/`

# Building the Android APK

# The `buildozer.spec` file
> [!NOTE]
> Although you do not need this for a base PySide6 application, I still recommend you to 
> read through the following part, because it contains very important things for your Android App.

Buildozer is the tool, which generates the .apk file using P4A (Python for Android) as backend.
The buildozer.spec file is a configuration file, which is generated on Buildozer's first run.
It's used to configure the behavior of your application. For example, whether your App should
run in portrait or landscape mode and other things. Here's a list of the most important options:

- `requirements`: The list of all python packages used in your app See [Buildozer.spec](#the-buildozerspec-file)
- `icon.filename`: The Icon of your App as a .png or .jpg. Please have a look at Google's [Adaptive Icons](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive?hl=de)
- `title`: Your App name
- `version`: The version of your application e.g, 1.1
- `android.permissions:` All permissions your App needs. Have a look at [Android Permissions](https://developer.android.com/reference/android/Manifest.permission.html)
- `package.name`: The name of your package, which is the output of buildozer
- `package.domain`: The unique identifier of your app inside the Android app system
- `orientation`:  The orientation of your app: `portrait` ->: `||` or `landscape` ->: `===`
- `android.api`: The target Android API (usually you want to go for the highest here)
- `android.minapi` The minimum supported Android API (probably something like 21)

#### Special Note on `charset_normalizer` and `requests`:
If your project uses the 'requests' library or any other library dependent on 'charset_normalizer', ensure to specify 
the version `charset-normalizer==2.1.1` in your requirements, otherwise there will be an architecture
mismatch.


### PySide6 modification
Unfortunately the `pyside6-android-deploy` script starts the build proces immediately, without giving
you the option to manually review the buildozer.spec file, which is the reason why we need to do
a little modification, but don't worry it's easy:

1) Go into your virtual environment to the PySide6 folder (e.g.: venv/lib/python3.11/site-packages/PySide6/scripts/)
2) Edit the `android_deploy.py` file.
3) Search for the line: `logging.info("[DEPLOY] Running buildozer deployment")`
4) Above this line write this: `input("Modify your buildozer.spec now")`


When you start building the apk with `pyside6-android-deploy` the build process will stop at some point,
and then you can make adjustments to the `buildozer.spec` file. After you are done, press enter, and it will 
go on using your own options in the requirements.

# The final build process
> [!IMPORTANT]
> Make sure your script is named `main.py`

Go into your source directory and type the following:

`pyside6-android-deploy --wheel-pyside=<your .whl file for the architecture> --wheel-shiboken=<your .whl file for your architecture> --name=main --ndk-path ~/.pyside6_android_deploy/android-ndk/android-ndk-r26b --sdk-path ~/.pyside6_android_deploy/android-sdk/`

#### Explanation:
- --wheel-pyside= Here comes your PySide6 wheel, which you've downloaded or compiled
- --wheel-shiboken= Here comes your Shiboken wheel, which you've downloaded or compiled
- --name= The name of your application
- --ndk-path= The path to your Android NDK (See [Setup](#setup))
- --sdk-path= The path to your Android SDK (See [Setup](#setup))


The script will start configuring buildozer and buildozer will start the build process. 
In the end, you will have a .apk file for the specified Android architecture.

### Installation (Best practices)
I generally recommend you to use ADB / Fastboot to install and debug your Android application.
Once you understand how it works, it makes your life a lot easier...

1. Go into your system information and tap a few times on your build number
2. Go (or search) into the developer settings
3. Enable USB-Debugging (Or Debugging over W-Lan, but this is a little bit advanced)
4. Install the android tools on your system:
    - On Arch Linux: `sudo pacman -S android-tools`
    - On Ubuntu: `sudo apt install android-tools-adb android-tools-fastboot`
    - On Windows: `Imagine using Windows lol`

5. Type: `adb devices`
6. On your device, there should be a popup asking for your permission. Click on confirm.
7. Type: `adb devices` once again and confirm, that you see your device there.

The two magical commands

Install your apk: `adb install <path_to_apk_file>`
<br>Debug your app: `adb logcat --regex "<package.domain>`

After your apk was installed, you will see it in your system apps. Click on your app, 
scroll down, and at the very last line it should say something like:

```
Version 2.1.6
com.digibites.accubattery
```

The first line is your App version, and the second line is your package domain.
<br>After executing the logcat command, you can start your App and you should see a lot
of debug messages. In case your app crashes, you can see what went wrong, although the crash
report isn't always very helpful...

> [!NOTE]
> These instructions are based on my Pixel 7 Pro running Android 14. The steps for you might
> be different, but in general they are all very similar on all Android devices. If you are 
> stuck somewhere, XDA, Google and StackOverflow are your best friends :D



# Errors and (potential) solutions:
- RuntimeError: "You are including a lot of QML files from a local venv..."
This error is related to your virtual environment. Make sure your virtual environment
is NOT inside your projects' folder. It doesn't matter where it is, but must not be in your projects'
folder. For example, if you have your main.py in a folder named my_project, then your
virtual environment can't be in this folder! 
<br>
Create a new virtual environment in a different location and delete your old one with
`rm -rf venv .venv` (or whatever you've called it)
<br>
This is more an issue from Qt and will hopefully be fixed in a later Qt release, so that
you don't need to do this anymore. I know it's confusing.

- c compiler can not create executables
Don't worry, this issue most of the time comes because you are using a too high API level. Just go into the path, where it
says the C compiler wouldn't be able to create executables and then look inside this directory. You'll find files ending like
`androidclang33-` (or something like that). The highest number which is there is the highest number you can select.

- blah blash blah is for x86_64 architecture not aarch64
<br>Solution: Search online if the pip package has a verified aarch64 version. If it doesn't prepare for some months of work
building the recipes lmao

- DeadObjectException (Couldn't insert ... into...) 
If you see this, you can make yourself some coffee, turn on UK-Drill and try to find the error the next
few months :) This error can be literally anything, but most of the time it's because you are trying to access
a resource that doesn't exist. In my case it was a `logging.debug` function which made the whole application
crash, because I couldn't access the `log.log` file for some reason. So, if you see the DeadObjectException I recommend
you `STRONGLY` to go to [Debugging](#debugging) to find and fix the issue.

  
- No module named <your_module>
Sometimes it's not enough to just specify the module name. For example, if you want to use
`httpx` you also need to list `httpx`, `httpcore`,`idna`, `certifi`, `h11`, `sniffio` in the 
requirements, until it works.

Whenever you get such an error, I recommend you to look into the module and its dependencies and include all
the dependencies and the dependencies of the dependencies. It will be some trial and error, but
once you have got it working, it will be clear.



# DEBUGGING

> [!IMPORTANT]
> THIS SECTION IS VERY IMPORTANT

Your App **WILL CRASH** on its first run (except if you are a god), so what you do is:

Write this into your Python application:

```python
import http.client
import json

def send_error_log(message):
    url = "<your_pc's_ip>:8000" # Don't forget to place the IP of the device your server runs on
    endpoint = "/error-log/"
    data = json.dumps({"message": message})
    headers = {"Content-type": "application/json"}

    conn = http.client.HTTPConnection(url)

    conn.request("POST", endpoint, data, headers)
```

This function does not need any dependencies, and will 100% work no matter what's wrong with your App. You place
it on top of your function, and then you always use the `send_error_log()` call with your message.
For example, you have different functions in your app, and it crashes you log every new line in your Python application
until you can see where it exactly crashed. I know it's a lot of pain, but this is your only option to find the error!

**Server Code**

```python
from fastapi import FastAPI, HTTPException
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

Run this on your PC or Phone, and it will receive the error logs from your Android Application
<br>Requirements: `pip install pydantic fastapi uvicorn`

> [!IMPORTANT]
> I AGAIN want to remind you of using Java version 17! Java 11 is supported by Gradle and even recommended, but not
> supported by Qt, and version 21 is supported by Qt, but not by the currently used Gradle version. This may change in the
> future and I will update it accordingly.

# Contributions / Issues
If you see Issues in this guide, or you have something to improve it, feel free to open PRs and Issues. I'll
respond to them and try to help you as much as possible.  (Only for Arch Linux).

Maybe someone of you can make an alternative readme for other distros. Would be nice :) 

# Support
I appreciate every star on this repo, as it shows me that my work is useful for people, and it keeps me motivated :)


# Legacy (Building the wheels)

> [!NOTE]
> Please note that this won't be maintained as often and that the following part is NOT perfect
> and may contain some issues. This is made to get you into the right direction, but shouldn't be 
> seen as a perfect tutorial or guide!


## Installing Qt
- Log in to your Qt account at [Qt](https://qt.io)
- Download the Qt Online Installer and execute it
- Select "Desktop" and "Android" and install Qt (Should be around ~1.3 Gigabyte downloading)

# Install dependencies
#### Arch Linux (recommended)

```
sudo pacman -Syu base-devel android-tools android-udev clang jdk17-openjdk llvm openssl cmake wget p7zip git zip
```

## Python3.10 Support
> [!NOTE]
> If you want to compile your App using Python3.10 you need to install Python3.10 with shared libraries. 
> You only need this if you want Python3.10

# PySide-Setup
Explanation:

This is the source directory of PySide6. Just execute the bash stuff below. It will install the needed stuff. Execute this one time
and REMEMBER where you've cloned this to, as we need this later :)


```bash
python -m venv venv # Needed, trust me...
source venv/bin/activate
git clone https://code.qt.io/pyside/pyside-setup
wget https://download.qt.io/development_releases/prebuilt/libclang/libclang-release_140-based-linux-Rhel8.2-gcc9.2-x86_64.7z
7z x libclang-release_140-based-linux-Rhel8.2-gcc9.2-x86_64.7z
export LLVM_INSTALL_DIR=$PWD/libclang

if [ -n "$ZSH_VERSION" ]; then
    echo "export LLVM_INSTALL_DIR=$PWD/libclang" >> ~/.zshrc
elif [ -n "$BASH_VERSION" ]; then
    echo "export LLVM_INSTALL_DIR=$PWD/libclang" >> ~/.bashrc
fi

cd pyside-setup
git checkout 6.9.1 # You can also use dev branch, but I wouldn't recommend, because it can cause issues
pip install -r requirements.txt
pip install -r tools/cross_compile_android/requirements.txt
pip install pyside6
cd
```

# Building the Qt Wheels
Explanation:

We are going inside the `pyside-setup` folder which you've cloned. This folder is the source code of PySide6. The tool for 
compiling the wheels is located in `tools/cross_compile_android/main.py`. 

There are 4 Android architectures:
- aarch64
- armv7a
- x86_64
- i686

You want to build your Application for all of these architectures, so that your App runs on any Android Device including the oldest
phone from 11 years ago and a new Android Tablet from 2024 :)

> [!NOTE]
> If you want to use Python3.10 instead of Python3.11 modify the main.py script. You'll find a line saying: "PYTHON_VERSION = 3.11". Change this to 3.10.
> (It's line 21)

> [!NOTE]
> If you want to use a different NDK version than r27c, go into `tools/cross_compile_android/android_utilities.py` and 
> change the value in the NDK version to your preferred one (at the top of the script)

Quick Information: You only need to build the wheels once, and you can use them for all your projects. So this is a one time step!

The basic command for building the wheels is the following:

`python tools/cross_compile_android/main.py --plat-name= --qt-install-path= --api-level 35 --auto-accept-license`

> [!NOTE]
> If you want to save some time when cloning the Cpython repository, modify the main.py script. Search for: `if not cpython_dir.exists():`
> Under it, you see the Repo.clone_from() call. Add the following argument to it: `depth=1`

This will only clone the latest commits and branch from the Python repository, otherwise you'll clone a lot of unnecessary
data.

--plat-name = Here comes your Android architecture. e.g, aarch64 or armv7a
<br>--qt-install-path = Here comes your Qt installation path. e.g, "/home/$USER/Qt/6.9.1" or "/opt/Qt/6.9.1"
<br>--api-level = Here comes your target android API level. I recommend 35.
Now, execute this command for all 4 Android architectures.
Your Wheels should be in the `dist` folder at the end.

If you get any errors, try to use the `--clean-cache all` argument first.
