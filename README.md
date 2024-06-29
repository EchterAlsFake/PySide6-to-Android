# PySide6 for Android Devices
> [!NOTE]
> DISCLAIMER: This guide is unofficial and not affiliated with Qt. Please refer to the Official Documentation about the compiling process for Android.

[Taking Qt for Python to Android](https://www.qt.io/blog/taking-qt-for-python-to-android)

> [!WARNING]
> My own compiled Android application has some serious UI issues (when scrolling, and crashes). I don't know where this comes from.
> If you experience this too, don't worry, I am actively searching for a solution, and you aren't alone.

# Building the Qt for Python Wheels
> [!IMPORTANT]
> You can use the pre-compiled Wheels in the Repository's release. If they don't work, you need to compile them
> You will however still need to set up your Android SDK / NDK, so that it works for buildozer.

### Current Release: 6.7.1
- Python3.11: [Qt 6.7.1](https://github.com/EchterAlsFake/PySide6-to-Android/releases/tag/6.7.1_3.11)


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
> You only need this if you want Python3.10

# PySide-Setup
Explanation:

This is the source directory of PySide6. Just execute the bash stuff below. It will install the needed stuff. Execute this one time
and REMEMBER where you've cloned this to, as we need this later :)

```bash
python -m venv venv # Needed, trust me...
source venv/bin/activate
git clone https://code.qt.io/pyside/pyside-setup
cd pyside-setup
git checkout 6.7.2
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
> If you want to use a different NDK version than r26b, go into `tools/cross_compile_android/android_utilities.py` and 
> change the value in the NDK version to your preferred one (at the top of the script)

Quick Information: You only need to build the wheels once, and you can use them for all your projects. So this is a one time step!

The basic command for building the wheels is the following:

`python tools/cross_compile_android/main.py --plat-name= --qt-install-path= --api-level 34 --verbose`

> [!IMPORTANT]
> DO NOT REMOVE THE `--verbose` flag! The installer redirects all output from the SDK / NDK installation to the logs.
> Android will prompt you to accept the license, and you need to type `y` and proceed. If you don't use the --verbose line, 
> you simply won't see this and the script is stuck forever!

--plat-name = Here comes your Android architecture. e.g, aarch64 or armv7a
<br>--qt-install-path = Here comes your Qt installation path. e.g, "/home/$USER/Qt/6.7.2/" or "/opt/Qt/6.7.2"
<br>--api-level = Here comes your target android API level. I recommend 34.
Now, execute this command for all 4 Android architectures.
Your Wheels should be in the `dist` folder at the end.

If you get any errors, try to use the `--clean-cache all` argument first.

# Building the Android APK

## PySide6 modification (Important)
> [!IMPORTANT] 
> If your project depends on external libraries other than PySide6, you need to do the following steps:

1) Go into your virtual environment to the PySide6 folder (e.g: venv/lib/python3.11/site-packages/PySide6/scripts/)
2) Edit the `android_deploy.py` file.
3) Search for the line: `logging.info("[DEPLOY] Running buildozer deployment")`
4) Above this line write this: `input("Modify your buildozer.spec now")`

Done :)

Explanation:

Later, when buildozer builds your .apk the `buildozer.spec` file will be created. It defines a lot of things, and also
which external libraries are used. Unfortunately the pyside6-android-deploy script doesn't let you edit this file, which
is the reason why we need to make an input statement, so that you can write your external libraries in their, before it
gets processed.  (Sidenote: it took me 6 months to figure this out :skull:)

# Building the APK
The wheels are in pyside-setup/dist/ (Or use the downloaded ones from releases)
```pyside6-android-deploy --wheel-pyside=<your .whl file for the architecture> --wheel-shiboken=<your .whl file for your architecture> --name=main --ndk-path ~/.pyside6_android_deploy/android-ndk/android-ndk-r26b --sdk-path ~/.pyside6_android_deploy/android-sdk/```

> [!NOTE]
> If you've changed your NDK version, you of course need to adapt the path to your NDK version.

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
Don't worry, this issue most of the time comes because you are using a too high API level. Just go into the path, where it
says the C compiler wouldn't be able to create executables and then look inside this directory. You'll find files ending like
`androidclang33-` (or something like that). The highest number which is there is the highest number you can select.

- blah blash blah is for x86_64 architecture not aarch64
<br>Solution: Search online if the pip package has a verified aarch64 version. If it doesn't prepare for some months of work
building the receipes lmao

> [!IMPORTANT]
> I AGAIN want to remind you of using the Java version 17! Java 11 is supported by Gradle and even recommended, but not
> supported by Qt, and version 21 is supported by Qt, but not by the currently used Gradle version. This may change in the
> future and I will update it accordingly.

# Contributions / Issues
If you see Issues in this guide, or you have something to improve it, feel free to open PRs and Issues. I'll
respond to them and try to help you as much as possible.  (Only for Arch Linux).

Maybe someone of you can make an alternative readme for other distros. Would be nice :) 

# Support
I appreciate every star on this repo, as it shows me that my work is useful for people, and it keeps me motivated :)
