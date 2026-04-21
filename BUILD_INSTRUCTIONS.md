# NATProxy Android APK - Complete Build Guide

## Overview

This package contains the complete source code for NATProxy, a P2P Internet Sharing application for Android. Follow this guide to compile it into an APK for your Android device.

---

## Prerequisites

Before you start, install the following tools on your computer:

### 1. **Java Development Kit (JDK) 17**

**Windows:**
- Download from: https://www.oracle.com/java/technologies/downloads/#java17
- Or use: `choco install openjdk17` (if using Chocolatey)

**macOS:**
- `brew install openjdk@17`

**Linux (Ubuntu/Debian):**
- `sudo apt-get install openjdk-17-jdk`

**Linux (Fedora/RHEL):**
- `sudo dnf install java-17-openjdk-devel`

**Verify installation:**
```bash
java -version
```

### 2. **Go Programming Language (1.25+)**

**Download from:** https://golang.org/dl/

**Verify installation:**
```bash
go version
```

### 3. **Flutter SDK (Latest)**

**Download from:** https://flutter.dev/docs/get-started/install

**Installation steps:**
```bash
# Extract Flutter (replace path as needed)
unzip flutter_linux_3.41.7-stable.tar.xz
# or on macOS:
unzip flutter_macos_arm64_3.41.7-stable.zip

# Add Flutter to PATH
export PATH="$PATH:$(pwd)/flutter/bin"

# Verify installation
flutter doctor
```

**Verify installation:**
```bash
flutter --version
```

### 4. **Android SDK**

**Option A: Install Android Studio (Recommended)**
- Download from: https://developer.android.com/studio
- Install and open Android Studio
- Go to: Settings → SDK Manager
- Install:
  - Android SDK Platform 34 (or latest)
  - Android SDK Build-Tools 34.0.0
  - Android Emulator (optional)

**Option B: Install Command Line Tools Only**
```bash
# Create SDK directory
mkdir -p ~/Android/Sdk

# Download command-line tools from:
# https://developer.android.com/studio#command-tools

# Extract and set up
unzip commandlinetools-*.zip
mkdir -p ~/Android/Sdk/cmdline-tools/latest
mv cmdline-tools/* ~/Android/Sdk/cmdline-tools/latest/

# Set ANDROID_HOME
export ANDROID_HOME=~/Android/Sdk
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"

# Accept licenses
yes | sdkmanager --licenses

# Install required packages
sdkmanager "platforms;android-34"
sdkmanager "build-tools;34.0.0"
sdkmanager "ndk;26.0.10792818"
```

**Verify installation:**
```bash
flutter doctor
```

### 5. **Go Mobile (for building Go library)**

```bash
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
```

---

## Step-by-Step Build Instructions

### Step 1: Navigate to Project Directory

```bash
cd natproxy-build-package
```

### Step 2: Set Environment Variables

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

### Step 3: Build the Go Library

This step compiles the Go backend library needed for the app.

**Option A: Automatic (Recommended)**
```bash
./build-android.sh arm
```

**Option B: Manual**
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

**Build variants:**
- `./build-android.sh arm` - ARM64 + ARM (most devices)
- `./build-android.sh x86` - x86_64 + x86 (emulators)
- `./build-android.sh universal` - All four ABIs (largest)
- `./build-android.sh arm split` - Per-ABI APKs (smaller downloads)

### Step 4: Get Flutter Dependencies

```bash
flutter pub get
```

### Step 5: Build the APK

**Option A: Single Universal APK (Recommended)**
```bash
flutter build apk --release
```

**Option B: Split APKs (Smaller files)
```bash
flutter build apk --release --split-per-abi
```

**Output location:**
- Universal APK: `build/app/outputs/flutter-apk/app-release.apk`
- Split APKs: `build/app/outputs/flutter-apk/app-*.apk`

### Step 6: Verify the Build

```bash
ls -lh build/app/outputs/flutter-apk/
```

You should see:
- `app-release.apk` (if universal build)
- Or `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, etc. (if split)

---

## Troubleshooting

### Error: "Could not find Android SDK"

**Solution:**
```bash
flutter config --android-sdk /path/to/android/sdk
```

### Error: "Could not find Java"

**Solution:**
```bash
flutter config --jdk-dir /path/to/jdk
```

### Error: "gomobile not found"

**Solution:**
```bash
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
```

### Error: "Build failed: Android Gradle plugin"

**Solution:**
```bash
# Clean build
flutter clean
rm -rf build/

# Try again
flutter pub get
flutter build apk --release
```

### Error: "NDK not found"

**Solution:**
```bash
sdkmanager "ndk;26.0.10792818"
```

### Build is very slow

**Solution:**
- This is normal for the first build (30-60 minutes)
- Subsequent builds are faster (5-10 minutes)
- Ensure you have at least 10 GB free disk space
- Close other applications to free up RAM

---

## Installation on Android Device

### Step 1: Transfer APK to Phone

**Option A: USB Cable**
```bash
adb connect <phone-ip>  # or connect via USB
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Option B: Manual Transfer**
1. Connect phone to computer via USB
2. Copy APK to phone's Downloads folder
3. Disconnect

### Step 2: Enable Unknown Sources (if needed)

1. Open Settings on your phone
2. Go to: Security (or Apps & notifications)
3. Find: "Unknown Sources" or "Install unknown apps"
4. Toggle it ON

### Step 3: Install APK

1. Open Files/File Manager app
2. Navigate to Downloads folder
3. Tap the APK file
4. Tap "Install"
5. Wait for installation to complete

### Step 4: Launch App

1. Find NATProxy in your app drawer
2. Tap to open
3. Grant necessary permissions (VPN, etc.)
4. Start using!

---

## Build Customization

### Change App Name

Edit `android/app/build.gradle`:
```gradle
applicationId "com.example.natproxy"
```

### Change App Icon

Replace images in:
- `android/app/src/main/res/mipmap-*/ic_launcher.png`

### Change Version Number

Edit `pubspec.yaml`:
```yaml
version: 1.0.0+1
```

### Customize Configuration

Edit `.env` file:
```bash
cp .env.example .env
# Edit .env with your settings
dart scripts/apply_env.dart
```

---

## Advanced Options

### Build for Specific Architecture

```bash
# ARM64 only
flutter build apk --release --target-platform android-arm64

# ARM32 only
flutter build apk --release --target-platform android-arm

# x86_64 only
flutter build apk --release --target-platform android-x86_64

# x86 only
flutter build apk --release --target-platform android-x86
```

### Build with Debug Info

```bash
flutter build apk --debug
```

### Build with Custom Signing

```bash
flutter build apk --release \
  --release-generic-apk \
  --keystore-path=/path/to/keystore.jks \
  --keystore-password=password \
  --key-alias=alias \
  --key-password=keypassword
```

---

## File Structure

```
natproxy-build-package/
├── lib/                    # Flutter Dart code
├── android/                # Android-specific code
├── ios/                    # iOS code (for reference)
├── golib/                  # Go backend library
├── natproxy-cli/           # Desktop CLI tool
├── signaling-server/       # Signaling server code
├── pubspec.yaml            # Flutter dependencies
├── build-android.sh        # Build script
├── README.md               # Original documentation
└── BUILD_INSTRUCTIONS.md   # This file
```

---

## Support & Documentation

- **GitHub Repository:** https://github.com/mahsanet/natproxy
- **Issues:** https://github.com/mahsanet/natproxy/issues
- **Flutter Docs:** https://flutter.dev/docs
- **Android Docs:** https://developer.android.com/docs

---

## Build Time Estimates

| Build Type | Time | Notes |
| :--- | :---: | :--- |
| First build | 30-60 min | Downloads dependencies, compiles Go lib |
| Subsequent builds | 5-10 min | Incremental compilation |
| Clean build | 20-40 min | Full recompilation |
| Split APKs | 40-70 min | Builds multiple APKs |

---

## System Requirements

| Component | Minimum | Recommended |
| :--- | :---: | :---: |
| **Disk Space** | 10 GB | 20 GB |
| **RAM** | 4 GB | 8 GB |
| **CPU** | Dual-core | Quad-core+ |
| **Java** | 17 | 17+ |
| **Go** | 1.25 | Latest |
| **Flutter** | Latest | Latest |
| **Android SDK** | API 24 | API 34+ |

---

## Success Checklist

- [ ] Java 17 installed and verified
- [ ] Go 1.25+ installed and verified
- [ ] Flutter installed and verified
- [ ] Android SDK installed
- [ ] NDK installed
- [ ] Environment variables set
- [ ] Go library built successfully
- [ ] Flutter dependencies installed
- [ ] APK built successfully
- [ ] APK transferred to phone
- [ ] APK installed on phone
- [ ] App launches successfully

---

## Next Steps

Once you have successfully built and installed the APK:

1. **Launch the app** on your Android device
2. **Grant permissions** when prompted (VPN, storage, etc.)
3. **Choose mode:**
   - **Server:** Share your internet with others
   - **Client:** Use someone else's internet
4. **Generate or enter connection code**
5. **Start sharing!**

---

## Troubleshooting Checklist

If you encounter issues:

1. ✅ Run `flutter doctor` to check your environment
2. ✅ Ensure all prerequisites are installed
3. ✅ Check that environment variables are set correctly
4. ✅ Try `flutter clean && flutter pub get`
5. ✅ Check GitHub issues for similar problems
6. ✅ Review error messages carefully
7. ✅ Try building again after restarting your computer

---

## Questions?

Visit the GitHub repository for more information:
https://github.com/mahsanet/natproxy

Good luck with your build! 🚀
