
> [!IMPORTANT]
> Update: I got Qt 6.7.0 working with Android. I will now do some additional tests and make sure everything runs smooth.
> After it I am going to update this guide. Please be patient.  
> DO NOT USE THE GUIDE NOW, IT DOESN'T WORK!

# PySide6 to Android

## Please Note
This guide outlines a method to use PySide6 for Android development. It is important to remember that this process might differ depending on your system setup. Success is not guaranteed, as I have not tested this with QML, though it should theoretically work.

# Table of Contents

- [Requirements](#requirements)
- [Basic Knowledge](#basic-knowledge--understanding)
- [Qt requirements](#qt-requirements)
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
- Qt Version: 6.6.3 (In the Qt unified installer check the options for "Android" and "Desktop" Development
- Python 3.11 (Or Python3.10) with OpenSSL


## Basic Knowledge / Understanding
What we are doing here is to build PySide6 and Shiboken6 for the different Android architectures.
Basically, Qt relies on C / C++ code, which is why we need to build it in this exceptional way.
There are multiple Android architectures:

- aarch64
- i686
- x86_64
- armv7a

We are going to build it for every architecture and your users then need to install the .apk for their architecture.
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
   git checkout 6.7.0
   pip install -r requirements.txt
   pip install –r tools/cross_compile_android/requirements.txt
   pip install PySide6
   cd
   ```
2. Install additional development tools and Android-specific packages:
   ```
   sudo pacman -Syu base-devel android-tools android-udev clang jdk17-openjdk llvm openssl cmake
   ```

# PySide6 modification (Important)

We need to modify the PySide6 build script to fix some things. Don't worry it's easy.

1) Go into your virtual environment to the PySide6 folder (e.g: venv/lib/python3.11/site-packages/PySide6/scripts/)
2) Edit the `android_deploy.py` file.
3) Search for the line: `logging.info("[DEPLOY] Running buildozer deployment")`
4) Above this line write this: `input("Modify your buildozer.spec now")`

Done :)

### Android SDK and NDK
3. Automate the SDK and NDK setup by creating and executing a bash script.
   <br>Just paste this into your terminal and wait

I know that the Qt build tool also has an option to automatically download the NDK, BUT this won't work for buildozer later.
Just use this script and you won't have errors.

```bash
#!/bin/bash

# Set the location where you want to install the SDK and NDK
ANDROID_SDK_ROOT="${HOME}/Android/Sdk"
ANDROID_NDK_ROOT="${ANDROID_SDK_ROOT}/ndk/26b" # Simplified for corrected structure

# Create directories
mkdir -p "${ANDROID_SDK_ROOT}"
mkdir -p "${ANDROID_NDK_ROOT}"

# Download and unzip Android SDK command line tools
CMDLINE_TOOLS_VERSION="11076708_latest" # Ensure this matches the latest version
SDK_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}.zip"
wget "${SDK_TOOLS_URL}" -O "${ANDROID_SDK_ROOT}/cmdline-tools.zip"
unzip -d "${ANDROID_SDK_ROOT}/cmdline-tools-temp" "${ANDROID_SDK_ROOT}/cmdline-tools.zip"
rm "${ANDROID_SDK_ROOT}/cmdline-tools.zip"

# Properly setup cmdline-tools directory according to the latest structure required by SDK Manager
mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools/latest"
mv "${ANDROID_SDK_ROOT}/cmdline-tools-temp/cmdline-tools/"* "${ANDROID_SDK_ROOT}/cmdline-tools/latest"
# Fix for the non-empty temporary directory issue
rm -rf "${ANDROID_SDK_ROOT}/cmdline-tools-temp"

# Download and extract Android NDK
NDK_VERSION="r26b" # Corrected NDK version
NDK_URL="https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip"
wget "${NDK_URL}" -O "${ANDROID_NDK_ROOT}/ndk.zip"
unzip -d "${ANDROID_NDK_ROOT}" "${ANDROID_NDK_ROOT}/ndk.zip"
rm "${ANDROID_NDK_ROOT}/ndk.zip"
# Move the content up and remove the versioned directory
mv "${ANDROID_NDK_ROOT}/android-ndk-${NDK_VERSION}"/* "${ANDROID_NDK_ROOT}/"
rm -rf "${ANDROID_NDK_ROOT}/android-ndk-${NDK_VERSION}"

# Update ANDROID_NDK_ROOT to point directly to the NDK directory
ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT}/" # Already correctly set

# Set environment variables
export ANDROID_SDK_ROOT
export ANDROID_NDK_ROOT
export PATH="${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_NDK_ROOT}"

# Optional: Add environment variables to your .bashrc or .bash_profile
echo "export ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT}" >> ~/.bashrc
echo "export ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT}" >> ~/.bashrc
echo "export PATH=\${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_NDK_ROOT}" >> ~/.bashrc

# Initialize sdkmanager and accept licenses
yes | ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager --licenses

# Install SDK packages required by Qt for Android development
# Note: Specify exact versions or latest available
${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager "platforms;android-29" "build-tools;29.0.3" "platform-tools"

echo "Android SDK and NDK installation completed."
cd
```
   The script will handle the downloading, unzipping, and setting of environment variables for the SDK and NDK.

## Building the Qt wheels
> [!IMPORTANT]
> Your app must be named "main.py" this is a requirement from Python for Android
> Your PySide and Shiboken version needs to match the Qt version you used for compiling.

Execute the following commands in the PySide-setup folder:
   ```
   python tools/cross_compile_android/main.py --plat-name=aarch64 --ndk-path=$ANDROID_NDK_ROOT --qt-install-path=/home/$USER/Qt/6.6.1 --sdk-path=$ANDROID_SDK_ROOT --api-level 29
   ```
   Now if this did run successfully, you should have the .whl files for every architecture in the "dist" folder.
   You can now ALWAYS reuse them for all your projects. You don't need to build them again.



# Building the APK
   The wheels are in pyside-setup/dist/
    
   ```pyside6-android-deploy --wheel-pyside=<your .whl file for the architecture> --wheel-shiboken=<your .whl file for your architecture> --name=main --ndk-path ~/Android/Sdk/ndk/26b/ --sdk-path ~/Android/Sdk/```
   
> [!IMPORTANT]
> If you have followed the PySide6 modification listed above, you should see the line "Modify your buildozer.spec now"

Open The `buildozer.spec` file and write this line into it:

`p4a.branch = develop`

If you don't do this, it won't work!

   <br>After successful execution, you will find the APK in your test folder.

## Including External Libraries
Incorporating external libraries requires modification to the `android_deploy.py` script in the PySide6 scripts folder. Go into your venv folder and navigate to the PySide6/scripts path.
Find the android_deploy.py script and modify it. Search for the `# run buildozer` comment and place an input("Put libraries into requirements") before it. When you now run the pyside6-android-deploy
 script, wait until you see your created input statement. Then go into the buildozer.spec file and search for the line `requirements`. Now you can append your external libraries with a comma

# Pysidedeploy.spec

After your first successful run, you can always use the `-c` flag when using `pyside6-android-deploy`. With that, you can specify an
existing `pysidedeploy.spec` script. Have a look at it, because there you can change the title of your application, version
number and a lot of other stuff.

# App Icons

When you enter your requirements as described above, go into the buildozer.spec file and add the following line:

icon.filename = <path_to_your_app_icon_png>

# Debugging / Error finding

I HIGHLY recommend to download the Android studio and run your App from Android Studio.
Just connect your Phone or Tablet to your PC, enable USB Debugging and start your App from the Android
Studio, because this will allow you to easily profile and debug your apk. You will see all Python tracebacks, and it makes
it much easier to debug.


## Special Note on 'charset_normalizer'
If your project uses the 'requests' library or any other library dependent on 'charset_normalizer', ensure to specify the version `charset-normalizer==2.1.1` in your requirements.

# Storage Permissions

Kivy and Pyjnius don't work. We can't access the Java API on Android and therefore can't request Permissions at runtime.
You need to use a lower Android API to ue the legacy storage paths in /storage/emulated/0/...


# Errors:

- RuntimeError: "You are including a lot of QML files from a local venv..."

This eror is related to your virtual environment. Make sure your virtual environment
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
