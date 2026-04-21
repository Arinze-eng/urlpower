# NATProxy Android - Build Guide

## Overview

This package contains **ONLY** the Android build files for NATProxy. Use this if you want to build the Android APK.

---

## Prerequisites

### 1. Java Development Kit (JDK) 17

**Windows:**
```
Download: https://www.oracle.com/java/technologies/downloads/#java17
Or: choco install openjdk17
```

**macOS:**
```
brew install openjdk@17
```

**Linux (Ubuntu/Debian):**
```
sudo apt-get install openjdk-17-jdk
```

**Verify:**
```
java -version
```

### 2. Go 1.25+

**Download:** https://golang.org/dl/

**Verify:**
```
go version
```

### 3. Flutter SDK (Latest)

**Download:** https://flutter.dev/docs/get-started/install

**Install & Verify:**
```
flutter --version
flutter doctor
```

### 4. Android SDK (API 24+)

**Option A: Android Studio (Recommended)**
- Download: https://developer.android.com/studio
- Install and open
- Settings → SDK Manager
- Install: Android SDK Platform 34, Build-Tools 34.0.0

**Option B: Command Line Tools**
```bash
mkdir -p ~/Android/Sdk
# Download from: https://developer.android.com/studio#command-tools
unzip commandlinetools-*.zip
mkdir -p ~/Android/Sdk/cmdline-tools/latest
mv cmdline-tools/* ~/Android/Sdk/cmdline-tools/latest/

export ANDROID_HOME=~/Android/Sdk
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"

yes | sdkmanager --licenses
sdkmanager "platforms;android-34"
sdkmanager "build-tools;34.0.0"
sdkmanager "ndk;26.0.10792818"
```

### 5. Go Mobile

```bash
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
```

---

## Build Steps

### Step 1: Set Environment Variables

**Windows (Command Prompt):**
```cmd
set ANDROID_HOME=C:\Users\YourUsername\AppData\Local\Android\Sdk
set JAVA_HOME=C:\Program Files\Java\jdk-17
```

**Windows (PowerShell):**
```powershell
$env:ANDROID_HOME = "C:\Users\YourUsername\AppData\Local\Android\Sdk"
$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
```

**macOS/Linux:**
```bash
export ANDROID_HOME=~/Android/Sdk
export JAVA_HOME=/usr/libexec/java_home -v 17
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
```

### Step 2: Build Go Library

**Automatic (Recommended):**
```bash
./build-android.sh arm
```

**Manual:**
```bash
cd golib
go mod tidy
gomobile bind -v \
  -ldflags="-checklinkname=0" \
  -target=android/arm64,android/arm \
  -androidapi=24 \
  -o ../android/app/libs/golib.aar \
  ./
cd ..
```

**Build Options:**
- `./build-android.sh arm` → ARM64 + ARM (most devices)
- `./build-android.sh x86` → x86_64 + x86 (emulators)
- `./build-android.sh universal` → All four ABIs (largest)
- `./build-android.sh arm split` → Per-ABI APKs (smaller)

### Step 3: Get Flutter Dependencies

```bash
flutter pub get
```

### Step 4: Build APK

**Single Universal APK (Recommended):**
```bash
flutter build apk --release
```

**Split APKs (Smaller files):**
```bash
flutter build apk --release --split-per-abi
```

### Step 5: Find Your APK

**Universal APK:**
```
build/app/outputs/flutter-apk/app-release.apk
```

**Split APKs:**
```
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
build/app/outputs/flutter-apk/app-x86-release.apk
```

---

## Installation

### Method 1: ADB (Android Debug Bridge)

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Method 2: Manual Installation

1. Connect phone via USB
2. Copy APK to phone
3. Open file manager on phone
4. Tap APK file
5. Tap "Install"

### Method 3: Email/Cloud

1. Email the APK to yourself
2. Open email on phone
3. Download APK
4. Tap to install

---

## Troubleshooting

### "Could not find Android SDK"
```bash
flutter config --android-sdk /path/to/android/sdk
```

### "Could not find Java"
```bash
flutter config --jdk-dir /path/to/jdk
```

### "gomobile not found"
```bash
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
```

### Build failed
```bash
flutter clean
rm -rf build/
flutter pub get
flutter build apk --release
```

### NDK not found
```bash
sdkmanager "ndk;26.0.10792818"
```

---

## Build Time

- First build: 30-60 minutes
- Subsequent: 5-10 minutes
- Clean build: 20-40 minutes

---

## File Structure

```
natproxy-android/
├── android/                  ← Android-specific code
│   ├── app/                  ← App configuration
│   ├── gradle/               ← Gradle files
│   └── build.gradle.kts
├── golib/                    ← Go backend library
├── lib/                      ← Flutter Dart code
├── pubspec.yaml              ← Dependencies
├── build-android.sh          ← Build script
└── BUILD_ANDROID_ONLY.md     ← This file
```

---

## Success Checklist

- [ ] Java 17 installed
- [ ] Go 1.25+ installed
- [ ] Flutter installed
- [ ] Android SDK installed
- [ ] NDK installed
- [ ] Environment variables set
- [ ] Go library built
- [ ] Flutter dependencies installed
- [ ] APK built successfully
- [ ] APK installed on phone

---

## Support

- GitHub: https://github.com/mahsanet/natproxy
- Issues: https://github.com/mahsanet/natproxy/issues

---

**Happy building!** 🚀
