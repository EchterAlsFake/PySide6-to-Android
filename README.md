# PySide6 to Android


Hello, today I compiled my first PySide6 App (without QML) to Android (13).
<br>The Process is insanely complicated, but today you'll learn how to do it.


PLEASE NOTE!

Every system is different, I can't give you a 100% guarantee!


# Requirements:

- Arch Linux
- Qt 6.6.1 (Desktop and Android development)
- OpenJDK 17 (Not 21)
- Python 3.10 compiled with shared libraries

# Installing requirements:

> Qt Requirements:

```
python -m venv venv
source venv/bin/activate
wget https://download.qt.io/development_releases/prebuilt/libclang/libclang-release_140-based-linux-Rhel8.2-gcc9.2-x86_64.7z
7z x libclang-release_140-based-linux-Rhel8.2-gcc9.2-x86_64.7z
export LLVM_INSTALL_DIR=$PWD/libclang
git clone https://code.qt.io/pyside/pyside-setup
cd pyside-setup
git checkout 6.6.1 # This is different from Qt Documentation
pip install -r requirements.txt
pip install –r tools/cross_compile_android/requirements.txt
pip install pyside6
```

```
sudo pacman -Syu base-devel android-tools android-udev clang jdk17-openjdk llvm openssl
```

> Now Download the source code for Python 3.10.13 from Python.org
<br> Extract the sources and go into the directory

```
./configure --enable-optimizations --enable-shared
make -j 8
sudo make altinstall # ALTINSTALL not INSTALL, otherwise will break your Arch Linux
```

`export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
`

# Android SDK / NDK

> Paste this into a script and execute it as bash:

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

echo "Android SDK and NDK installation completed."
echo "Paths added to .bashrc. Please restart your terminal or source your .bashrc file."


```

> Okay now we need to do something weird:

> Your Android SDK should be in your home directory. In my case it's this path:
/home/asuna/Android/Sdk/


Go to this path: `Android/Sdk/cmdline-tools/cmdline-tools/`
<br>Now to: `cp -r * ../../`

I don't know why and how I figured this out, but it's needed.

Now go in this path: `Android/Sdk/cmdline-tools/cmdline-tools/bin`
<br>And execute this: `sdkmanager "platforms;android-29"`

### If you got this point, the setup is done: Congratulations

# Getting the wheels

> Create a test folder somewhere
> Put a file main.py in there
> Paste the following content in there:

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


# Compiling


> And now we execute the two magic commands, which cost me 2 months.




## First Command:
-- plat: Your platform. Most modern Android devices have `aarch64`

`python tools/cross_compile_android/main.py --plat-name=aarch64 --ndk-path=$ANDROID_NDK_ROOT --qt-install-path=/opt/Qt/6.6.1 --sdk-path=$ANDROID_SDK_ROOT`


# If this command executed fine, you have already 50%

### Second Command (Building the apk)


--name : The name of your main.py file. In EVERY case this should be main. Always name your
main python file main. This is a requirement from python-for-android!

--wheel : Your compiled PySidd6 wheel. Should be in pyside-setup/dist/....
Make sure it has something like 

Also do the same for shiboken wheel!

### IMPORTANT

The wheels must have something with qt.6.6.1 in the name! EVERYTHING AND WITH THAT I MEAN
EVERYTHING ELSE WILL NOT WORK!!!!!!!!!!!!!!!!!!!!


EXECUTE THIS COMMAND FROM YOUR TEST  FOLDER WHERE YOUR main.py FILE IS!

`pyside6-android-deploy --wheel-pyside=/home/asuna/pyside-setup/dist/PySide6-6.6.1-6.6.1-cp37-abi3-android_aarch64.whl --wheel-shiboken=/home/asuna/pyside-setup/dist/shiboken6-6.6.1-6.6.1-cp37-abi3-android_aarch64.whl --name=main --ndk-path /home/asuna/Android/Sdk/ndk/25c/ --sdk-path /home/asuna/Android/Sdk/`


# Now you should have your apk in your test folder.















