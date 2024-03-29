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