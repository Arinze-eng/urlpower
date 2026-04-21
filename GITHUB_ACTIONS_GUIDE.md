# GitHub Actions Build Guide for NATProxy Android

This guide provides a comprehensive overview of how to compile the NATProxy Android application using GitHub Actions, eliminating the need for a local Flutter SDK installation. By leveraging GitHub's CI/CD infrastructure, you can automate the entire build process in the cloud.

## Setup and Implementation

To begin the automated build process, you must first create a new repository on GitHub. Once the repository is established, you should upload the contents of the `natproxy-android` folder. The critical component for this automation is the workflow file located at `.github/workflows/android_build.yml`. This file must be present in your repository's root directory for GitHub to recognize and execute the build steps.

The build process is designed to be highly accessible. It will trigger automatically upon every push to the `main` branch, ensuring that your APK is always up to date with the latest code changes. Alternatively, you can initiate a build manually by navigating to the **Actions** tab in your GitHub repository, selecting the **Android APK Build** workflow, and clicking the **Run workflow** button.

## Automated Workflow Steps

The GitHub Actions environment is pre-configured with the necessary tools to compile both the Go-based backend and the Flutter-based frontend. The table below outlines the primary steps executed during the build process:

| Step | Description |
| :--- | :--- |
| **Environment Setup** | Configures Java 17 (Temurin), Go 1.21.x, and the stable Flutter SDK. |
| **SDK Installation** | Installs Android SDK Platform 34, Build-Tools 34.0.0, and NDK 26. |
| **Go Mobile Init** | Installs and initializes the `gomobile` tool for cross-compilation. |
| **Library Compilation** | Executes `./build-android.sh arm` to generate the `golib.aar` library. |
| **APK Generation** | Runs `flutter build apk --release` to produce the final application package. |

## Retrieving the Compiled APK

After the workflow completes successfully, the resulting APK will be available for download directly from the GitHub interface. You can find it by navigating to the **Actions** tab and selecting the most recent successful run. At the bottom of the run summary page, you will find a section titled **Artifacts**, where you can download the `app-release-apk` file.

If you encounter any issues during the build, the **Actions** tab provides detailed logs for each step of the process. Most failures are typically related to missing files or incorrect paths. Ensure that all source code from the original zip file has been correctly pushed to your repository. For projects requiring sensitive information like API keys, it is recommended to use **GitHub Secrets** to securely inject these values into the build environment.
