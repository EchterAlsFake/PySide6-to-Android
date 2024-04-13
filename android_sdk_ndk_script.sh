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