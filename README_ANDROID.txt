╔════════════════════════════════════════════════════════════════════════════╗
║                  NATProxy - Android Build Package                          ║
║                                                                            ║
║  This package contains ONLY the Android source code and build files       ║
║  Use this if you want to build the Android APK                            ║
╚════════════════════════════════════════════════════════════════════════════╝

WHAT'S INCLUDED:
✓ Flutter Dart source code (lib/)
✓ Android-specific code (android/)
✓ Go backend library (golib/)
✓ Build scripts and configuration
✓ Dependencies configuration (pubspec.yaml)
✓ Comprehensive build guide

WHAT'S NOT INCLUDED (Removed):
✗ iOS files (use iOS package instead)
✗ Desktop files (use Desktop package instead)
✗ Web files
✗ Signaling server
✗ Desktop CLI tool

═══════════════════════════════════════════════════════════════════════════════

QUICK START:
1. Read: BUILD_ANDROID_ONLY.md
2. Install prerequisites (Java 17, Go, Flutter, Android SDK)
3. Set environment variables
4. Run: ./build-android.sh arm
5. Run: flutter pub get
6. Run: flutter build apk --release
7. Find APK at: build/app/outputs/flutter-apk/app-release.apk

═══════════════════════════════════════════════════════════════════════════════

SYSTEM REQUIREMENTS:
• Java 17 (JDK)
• Go 1.25+
• Flutter (latest)
• Android SDK (API 24+)
• NDK
• 10+ GB disk space
• 4+ GB RAM

═══════════════════════════════════════════════════════════════════════════════

BUILD TIME:
• First build: 30-60 minutes
• Subsequent: 5-10 minutes

═══════════════════════════════════════════════════════════════════════════════

DOCUMENTATION:
• BUILD_ANDROID_ONLY.md - Detailed build instructions
• README.md - Original project documentation
• LICENSE - License information

═══════════════════════════════════════════════════════════════════════════════

SUPPORT:
GitHub: https://github.com/mahsanet/natproxy
Issues: https://github.com/mahsanet/natproxy/issues

═══════════════════════════════════════════════════════════════════════════════
