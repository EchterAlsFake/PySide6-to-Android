
# PySide6 to Android

## Please Note
This guide outlines a method to use PySide6 for Android development. It is important to remember that this process might differ depending on your system setup. Success is not guaranteed, as I have not tested this with QML, though it should theoretically work.

## Requirements
- Operating System: Arch Linux
- Qt Version: 6.6.1 (suitable for both Desktop and Android development)
- Java Development Kit: OpenJDK 17 (not version 21)
- Python: Version 3.10 compiled with shared libraries

## Installation Guide

### Qt Requirements
1. Set up a Python virtual environment and activate it:
   ```
   python -m venv venv
   source venv/bin/activate
   ```
2. Install necessary packages using pacman and download Qt prerequisites:
   ```
   python -m venv venv
   source venv/bin/activate
   sudo pacman -S p7zip
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
3. Install additional development tools and Android-specific packages:
   ```
   sudo pacman -Syu base-devel android-tools android-udev clang jdk17-openjdk llvm openssl cmake
   ```

### Python 3.10
4. Download and compile Python 3.10:
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

5. Set the library path:
   ```
   export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
   ```

### Android SDK and NDK
6. Automate the SDK and NDK setup by creating and executing a bash script.
   <br>Just paste this into your terminal and wait:
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

## Building Your First App
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

2. Execute the following commands in the PySide-setup folder:
   ```
   python tools/cross_compile_android/main.py --plat-name=aarch64 --ndk-path=$ANDROID_NDK_ROOT --qt-install-path=/home/$USER/Qt/6.6.1 --sdk-path=$ANDROID_SDK_ROOT --api-level 29
   ```
   This command prepares your environment for Android development.


3. Build the APK:
    <br>You'll find the wheels in the pyside-setup/dist/ folder.
    ```
   pyside6-android-deploy --wheel-pyside=/home/$USER/pyside-setup/dist/PySide6-6.6.1-6.6.1-cp37-abi3-android_aarch64.whl --wheel-shiboken=/home/$USER/pyside-setup/dist/shiboken6-6.6.1-6.6.1-cp37-abi3-android_aarch64.whl --name=main --ndk-path ~/Android/Sdk/ndk/25c/ --sdk-path ~/Android/Sdk/
   ```
   After successful execution, you will find the APK in your test folder.

## Including External Libraries
Incorporating external libraries requires modification to the `android_deploy.py` script in the PySide6 scripts folder. Go into your venv folder and navigate to the PySide6/scripts path.
Find the android_deploy.py script and modify it. Search for the `# run buildozer` comment and place an input("Put libraries into requirements") before it. When you now run the pyside6-android-deploy
script wait until you see your created input statement. Then go into the buildozer.spec file and search for the line `requirements`. Now you can append your external libraries with a comma

# Pysidedeploy.spec

After your first successful run, you can use the `-c` flag when using `pyside6-android-deploy`. With that, you can specify an
existing `pysidedeploy.spec` script. Have a look at it, because there you can change the title of your application, version
number and a lot of other stuff.


## Special Note on 'charset_normalizer'
If your project uses the 'requests' library or any other library dependent on 'charset_normalizer', ensure to specify the version `charset-normalizer==2.1.1` in your requirements.

## Debugging and Error finding

We can't use Android Studio for debugging, which makes it hard. Your app will often just crash without telling you why.
Use this script as a server on your PC.  `pip install uvicorn fastapi pydantic`

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

Include this function into your main application:
It doesn't need any dependencies, so it should run out of the box.
```python
import http.client
import json

def send_error_log(message):
    url = "<your_pc's_ip:8000"
    endpoint = "/error-log/"
    data = json.dumps({"message": message})
    headers = {"Content-type": "application/json"}

    conn = http.client.HTTPConnection(url)

    try:
        conn.request("POST", endpoint, data, headers)
        response = conn.getresponse()

        if response.status == 200:
            print("Error log sent successfully")
        else:
            print(f"Failed to send error log: Status {response.status}, Reason: {response.reason}")

        conn.close()
    except Exception as e:
        print(f"Request failed: {e}")
```

Now you can work with try and except in your main application and send errors to your PC, phone or whatever.

# Storage Permissions

Kivy and Pyjnius don't work. We can't access the Java API on Android and therefore can't request Permissions.
If you want to use the file system you must use `QFileDialog`. Use the `getExistingDirectory` method to prompt
the user on selecting an output path. Android will then automatically ask the user to create a new folder for your
application. Android will then give this folder the needed permissions for your App. It's a bit weird, but works.

Would look like this:

```
file_dialog = QFileDialog()
self.directory = file_dialog.getExistingDirectory() # Will open a directory prompt
```


# Contributions / Issues

If you see Issues in this guide or you have something to improve it, feel free to open PRs and Issues. I'll
respond to them and try to help you as much as possible.  (Only for Arch Linux).

Maybe someone of you can make an alternative readme for other distros. Would be nice :) 

# Support

Please spread this guide across forums, Qt blogs and give this repository a star. I don't want to be arrogant, but I am
the first one who created such a comprehensive guide.
