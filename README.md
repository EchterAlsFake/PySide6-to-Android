# PySide6 for Android Devices
> [!NOTE]
> DISCLAIMER: This guide is unofficial and not affiliated with Qt. Please refer to the Official Documentation about the compiling process for Android.

[Taking Qt for Python to Android](https://www.qt.io/blog/taking-qt-for-python-to-android)


# Building the Qt for Python Wheels
> [!IMPORTANT]
> You can use the pre-compiled Wheels in the Repository's release. If they don't work, you need to compile them:

If you want to use the pre-compiled wheels go over [here](https://github.com/EchterAlsFake/PySide6-to-android/releases/)
And skip the guide to: [Android NDK / SDK](#android-sdk--ndk)

## Installing Qt
- Log in to your Qt account at [Qt](https://qt.io)
- Download the Qt Online Installer and execute it
- Select "Desktop" and "Android" and install Qt (Should be around ~1.3 Gigabyte downloading)

# Install dependencies
#### Arch Linux (recommended)

```
sudo pacman -Syu base-devel android-tools android-udev clang jdk17-openjdk llvm openssl cmake wget p7zip git
```

#### Ubuntu (Untested)

## Python3.10 Support
> [!NOTE]
> If you want to compile your App using Python3.10 you need to install Python3.10 with shared libraries. 
> You only need this if you want Python3.10. If you use Python3.11 you can skip this step!


```bash
wget "https://www.python.org/ftp/python/3.10.13/Python-3.10.13.tar.xz"
tar -xvf Python-3.10.13.tar.xz
cd Python-3.10.13
./configure --enable-optimizations --enable-shared # We explicitly need shared libraries!
make -j 8 # You can set this higher if you have a good CPU
sudo make altinstall # ALTINSTALL not INSTALL, otherwise will break your Linux
cd
```

> [!IMPORTANT]
> Whenever you are in a new terminal session or getting an error while trying to use Python3.10 execute this:

`export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH`

This applies the correct path for the shared libraries which we need for compiling Qt

## Android SDK / NDK
I've made a script which automatically sets up the Android SDK / NDK. Go into your home directory at /home/{your_username/

Then execute the following:

`wget -O - "https://raw.githubusercontent.com/EchterAlsFake/PySide6-to-Android/master/android_sdk_ndk_script.sh" | bash`

(You only need to execute this one time)

# Building the Qt Wheels
> [!NOTE]
> Skip this step if you are using the pre-compiled wheels from the releases

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

Quick Information: You only need to build the wheels once, and you can use them for all your projects. So this is a one time step!

The basic command for building the wheels is the following:

`python tools/cross_compile_android/main.py --plat-name=--ndk-path=$ANDROID_NDK_ROOT --qt-install-path= --sdk-path=$ANDROID_SDK_ROOT --api-level 29`

--plat-name = Here comes your Android architecture. e.g, aarch64 or armv7a
<br>--qt-install-path = Here comes your Qt installation path. e.g, "/home/$USER/Qt/6.7.0/" or "/opt/Qt/6.7.0"

Now, execute this command for all 4 Android architectures.
Your Wheels should be in the `dist` folder at the end.

If you get any errors, try to use the `--clean-cache all` argument first. 


# Building the Android APK

## PySide6 modification (Important)
We need to modify the PySide6 build script to fix some things. Don't worry it's easy.

1) Go into your virtual environment to the PySide6 folder (e.g: venv/lib/python3.11/site-packages/PySide6/scripts/)
2) Edit the `android_deploy.py` file.
3) Search for the line: `logging.info("[DEPLOY] Running buildozer deployment")`
4) Above this line write this: `input("Modify your buildozer.spec now")`

Done :)


# Building the APK
The wheels are in pyside-setup/dist/ (Or use the downloaded ones from releases)

```pyside6-android-deploy --wheel-pyside=<your .whl file for the architecture> --wheel-shiboken=<your .whl file for your architecture> --name=main --ndk-path ~/Android/Sdk/ndk/26b/ --sdk-path ~/Android/Sdk/```
   
> [!IMPORTANT]
> If you have followed the PySide6 modification listed above, you should see the line "Modify your buildozer.spec now"

Open The `buildozer.spec` file and write this line into it:

`p4a.branch = develop`

(We need to do this, because Qt worked together with Python for Android to change some stuff upstream, but it's still in the develop
branch and not in the latest stable release. This is why we need to use the develop branch.

### Other Stuff (Important)

#### pysidedeploy.spec

The `pysidedeploy.spec` file is used to define your Application name, the architecture and some other things.
The `pysidedeploy.spec` file is created when you build your first .apk. You can use this file by doing:

`pyside6-android-deploy -c pysidedeploy.spec` This makes the process easier. 

#### External Libraries
If your App needs external libraries like requests or colorama, you need to list them in the 
`requirements` line (in the buildozer.spec). Just separate them with a comma.
You can specify exact version numbers like with pip and also install from git using `git+....`

#### App Icon
If you want to use your own App Icon you can do:
<br>
`icon.filename = <path_to_your_app_icon_png>`

# Debugging / Error finding

I HIGHLY recommend to download the Android studio and run your App from the Android Studio.
Just connect your Phone or Tablet to your PC, enable USB Debugging and start your App from the Android
Studio, because this will allow you to easily profile and debug your apk. You will see all Python tracebacks, and it makes
it a lot easier to debug.

## Special Note on 'charset_normalizer'
If your project uses the 'requests' library or any other library dependent on 'charset_normalizer', ensure to specify the version `charset-normalizer==2.1.1` in your requirements.

# Storage Permissions
Kivy and Pyjnius don't work. We can't access the Java API on Android and therefore can't request Permissions at runtime.
You need to use a lower Android API to ue the legacy storage paths in /storage/emulated/0/...


# Errors:
- RuntimeError: "You are including a lot of QML files from a local venv..."

This error is related to your virtual environment. Make sure your virtual environment
is NOT inside your projects' folder. It doesn't matter where it is, but must not be in your projects'
folder. For example, if you have your main.py in a folder named my_project, then your
virtual environment can't be in this folder! 

Create a new virtual environment in a different location and delete your old one with
`rm -rf venv .venv` (or whatever you've called it)

This is more an issue from Qt and will hopefully be fixed in a later Qt release, so that
you don't need to do this anymore. I know it's confusing.

- c compiler can not create executables
<br>Solution: Jump from the bridge

- blah blash blah is for x86_64 architecture not aarch64
<br>Solution: Search online if the pip package has a verified aarch64 version. If it doesn't prepare for some months of work
building the receipes lmao


# Contributions / Issues
If you see Issues in this guide, or you have something to improve it, feel free to open PRs and Issues. I'll
respond to them and try to help you as much as possible.  (Only for Arch Linux).

Maybe someone of you can make an alternative readme for other distros. Would be nice :) 

# Support
I appreciate every star on this repo, as it shows me that my work is useful for people, and it keeps me motivated :)
