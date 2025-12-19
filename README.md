# Flutter APPLICATION final project

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

### Step 1: Clone repo all source code from github
git clone https://github.com/KhangBuiNam/Flutter_CK_APP.git

### Step 2: Extract the Project Files 
Unzip it using WinRAR or any extraction tool to a desired directory on your computer.

### Step 3: Open the Project and Install Dependencies
Open the terminal inside VS Code (or Android Studio) and Run the following commands:
bash:
flutter doctor
flutter pub get

### Step 4: Run the Application
open the file main.dart. Start debugging by clicking Run > Start Debugging in VS Code (or using Android Studio). Select one of the following platform: Android Emulator, Physical Android device, Chrome / Web browser (if no emulator is available)

### Step 5: Build APK File for Android
After verifying that the application works correctly, you can generate the APK file.
flutter build apk –release
or:
flutter build apk

### Step 6: Install APK on Android Device
Navigate to the following directory:
build\app\outputs\flutter-apk\app-release.apk
Locate the file: app-release.apk
Transfer the APK to your Android device via: USB cable, File sharing, Cloud storage. Next install the APK and test the application on your mobile device.

### ATTENTION!!! 
If Step 3 fails (for example, dependency or environment-related errors occur), please do the following:
Move the project folder to a directory that you normally use for running Flutter projects. This ensures that the project is compatible with your existing Flutter environment and system configuration.
After moving the project, reopen it in VS Code or Android Studio, then rerun the commands in Step 3:
flutter doctor
flutter pub get
This should resolve most environment (env) compatibility issues.
