
# PySide6 to Android

## Please Note
This guide outlines a method to use PySide6 for Android development. It is important to remember that this process might differ depending on your system setup. Success is not guaranteed, as I have not tested this with QML, though it should theoretically work.

# Table of Contents

- [Requirements](#requirements)
- [Basic Knowledge](#basic-knowledge--understanding)
- [Qt requirements](#qt-requirements)
- [Python 3.10](#python-310)
- [Android SDK / NDK](#android-sdk-and-ndk)
- [Building Qt wheels](#building-the-qt-wheels)
- [Building the APK](#building-the-apk)
- [App Icons](#app-icons)
- [Debugging](#debugging--error-finding)
- [IMPORTANT](#special-note-on-charset_normalizer)
- [Storage Permissions](#storage-permissions)
- [Errors](#errors)
- [Contributions](#contributions--issues)
- [Support](#support)

## Requirements
- Operating System: Arch Linux
- Qt Version: 6.6.1 (In the Qt unified installer check the options for "Android" and "Desktop" Development

## Basic Knowledge / Understanding

What we are doing here is to build PySide6 and Shiboken6 for the different Android architectures.
Basically Qt relies on some C code which is why we need to build it in this very special way. You can't just
specify PySide6 in the buildozers requirements and expect everything to work. This is why we are doing all this here.
At the end of compiling you will have two .whl files for PySide6 and Shiboken6. For every architecture two pieces.

There are multiple Android architectures:

- aarch64
- i686
- x86_64
- armv7a

What you want to build first is aarch64 af this is where most devices run.

Information: I did NOT successfully build any other than aarch64 and I wasn't able to fix errors. Hopefully this process will be fixed in the future.

### Qt Requirements


1. Install necessary packages using pacman and download Qt prerequisites:
   ```
   python -m venv venv
   source venv/bin/activate
   sudo pacman -S p7zip wget
   wget https://download.qt.io/development_releases/prebuilt/libclang/libclang-release_140-based-linux-Rhel8.2-gcc9.2-x86_64.7z
   7z x libclang-release_140-based-linux-Rhel8.2-gcc9.2-x86_64.7z
   export LLVM_INSTALL_DIR=$PWD/libclang
   git clone https://code.qt.io/pyside/pyside-setup
   cd pyside-setup
   git checkout 6.6.1 # This is different from Qt Documentation
   pip install -r requirements.txt
   pip install –r tools/cross_compile_android/requirements.txt
   pip install pyside6
   cd
   ```
2. Install additional development tools and Android-specific packages:
   ```
   sudo pacman -Syu base-devel android-tools android-udev clang jdk17-openjdk llvm openssl cmake
   ```

### Python 3.10

> Python3.10 is only needed to build the Qt wheels for PySide6 and Shiboken6.
> Python3.10 is NOT needed to deploy the Android app itself

3. Download and compile Python 3.10:
   ```
   wget "https://www.python.org/ftp/python/3.10.13/Python-3.10.13.tar.xz"
   tar -xvf Python-3.10.13.tar.xz
   cd Python-3.10.13
   ./configure --enable-optimizations --enable-shared
   make -j 8
   sudo make altinstall # ALTINSTALL not INSTALL, otherwise will break your Arch Linux
   cd
   ```
   Note: Use 'altinstall' to avoid breaking Arch Linux.

4. Set the library path:
   ```
   export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
   ```

### Android SDK and NDK
5. Automate the SDK and NDK setup by creating and executing a bash script.
   <br>Just paste this into your terminal and wait

I know that the Qt build tool also has an option to automatically download the NDK, BUT this won't work for buildozer later.
Just use this script and you won't have errors.

   ```bash
   #!/bin/bash

   # Set the location where you want to install the SDK and NDK
   ANDROID_SDK_ROOT="${HOME}/Android/Sdk"
   ANDROID_NDK_ROOT="${ANDROID_SDK_ROOT}/ndk/25c"
   
   # Create directories
   mkdir -p "${ANDROID_SDK_ROOT}"
   mkdir -p "${ANDROID_NDK_ROOT}"
   
   # Download and unzip Android SDK command line tools
   # Check for the latest version link at https://developer.android.com/studio
   SDK_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-8092744_latest.zip"
   wget -q "${SDK_TOOLS_URL}" -O "${ANDROID_SDK_ROOT}/cmdline-tools.zip"
   unzip -q -d "${ANDROID_SDK_ROOT}/cmdline-tools" "${ANDROID_SDK_ROOT}/cmdline-tools.zip"
   rm "${ANDROID_SDK_ROOT}/cmdline-tools.zip"
   
   # Download and extract Android NDK
   NDK_URL="https://dl.google.com/android/repository/android-ndk-r25c-linux.zip"
   wget -q "${NDK_URL}" -O "${ANDROID_SDK_ROOT}/ndk-r25c.zip"
   unzip -q -d "${ANDROID_SDK_ROOT}" "${ANDROID_SDK_ROOT}/ndk-r25c.zip"
   rm "${ANDROID_SDK_ROOT}/ndk-r25c.zip"
   mv "${ANDROID_SDK_ROOT}/android-ndk-r25c" "${ANDROID_NDK_ROOT}"
   
   # Set environment variables
   export ANDROID_SDK_ROOT
   export ANDROID_NDK_ROOT
   export PATH="${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_NDK_ROOT}"
   
   # Optional: Add environment variables to your .bashrc or .bash_profile
   echo "export ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT}" >> ~/.bashrc
   echo "export ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT}" >> ~/.bashrc
   echo "export PATH=\${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_NDK_ROOT}" >> ~/.bashrc
   cd ~/Android/Sdk/ndk/25c/android-ndk-r25c/
   cp -r * ../
   cd ~/Android/Sdk
   mkdir tools
   cd ~/Android/Sdk/cmdline-tools/cmdline-tools/
   cp -r * ../../tools/
   cd ~/Android/Sdk/cmdline-tools/cmdline-tools/bin/
   ./sdkmanager "platforms;android-29"
   
   
   echo "Android SDK and NDK installation completed."
   cd
   ```
   The script will handle the downloading, unzipping, and setting of environment variables for the SDK and NDK.

## Building the Qt wheels
1. Create a test folder and place a `main.py` file in it with the following content:
   ```py
   from PySide6.QtWidgets import QApplication, QLabel
   
   def main():
       app = QApplication([])
       label = QLabel("Hello World")
       label.show()
       app.exec()
   
   if __name__ == "__main__":
       main()
   ```

Your app must be named "main.py" this is a requirement from Python for Android

2. Execute the following commands in the PySide-setup folder:
   ```
   python tools/cross_compile_android/main.py --plat-name=aarch64 --ndk-path=$ANDROID_NDK_ROOT --qt-install-path=/home/$USER/Qt/6.6.1 --sdk-path=$ANDROID_SDK_ROOT --api-level 29
   ```
   Now if this did run successfully you should have the .whl files for aarch64 in the "dist" folder.
   You can now ALWAYS reuse them for all your projects. You don't need to build them again.

# Building the APK
   The wheels are in pyside-setup/dist/
    
   ```pyside6-android-deploy --wheel-pyside=/home/$USER/pyside-setup/dist/PySide6-6.6.1-6.6.1-cp37-abi3-android_aarch64.whl --wheel-shiboken=/home/$USER/pyside-setup/dist/shiboken6-6.6.1-6.6.1-cp37-abi3-android_aarch64.whl --name=main --ndk-path ~/Android/Sdk/ndk/25c/ --sdk-path ~/Android/Sdk/```
   <br>After successful execution, you will find the APK in your test folder.

## Including External Libraries
Incorporating external libraries requires modification to the `android_deploy.py` script in the PySide6 scripts folder. Go into your venv folder and navigate to the PySide6/scripts path.
Find the android_deploy.py script and modify it. Search for the `# run buildozer` comment and place an input("Put libraries into requirements") before it. When you now run the pyside6-android-deploy
script wait until you see your created input statement. Then go into the buildozer.spec file and search for the line `requirements`. Now you can append your external libraries with a comma

# Pysidedeploy.spec

After your first successful run, you can always use the `-c` flag when using `pyside6-android-deploy`. With that, you can specify an
existing `pysidedeploy.spec` script. Have a look at it, because there you can change the title of your application, version
number and a lot of other stuff.

# App Icons

When you would enter your requirements as described above, go into the buildozer.spec file and add the following line:

icon.filename = <path_to_your_app_icon_png>

# Debugging / Error finding

I HIGHLY recommend to download the Android studio and run your App from Android Studio.
Just connect your Phone or Tablet to your PC, enable USB Debugging and start your App from the Android
Studio, because this will allow you to easily profile and debug your apk. You will see all Python tracebacks and it makes
it much easier to debug.


## Special Note on 'charset_normalizer'
If your project uses the 'requests' library or any other library dependent on 'charset_normalizer', ensure to specify the version `charset-normalizer==2.1.1` in your requirements.

# Storage Permissions

Kivy and Pyjnius don't work. We can't access the Java API on Android and therefore can't request Permissions at runtime.
You need to use a lower Android API to ue the legacy storage paths in /storage/emulated/0/...


# Errors:

- RuntimeError: "You are including a lot of QML files from a local venv..."

This eror is related to your virtual environment. Make sure your virtual environment
is NOT inside your projects folder. It doesn't matter where it is, but must not be in your projects
folder. For example, if you have your main.py in a folder named my_project then your
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

If you see Issues in this guide or you have something to improve it, feel free to open PRs and Issues. I'll
respond to them and try to help you as much as possible.  (Only for Arch Linux).

Maybe someone of you can make an alternative readme for other distros. Would be nice :) 

# Support
I appreciate every star on this repo, as it shows me that my work is useful for people, and it keeps me motivated :)