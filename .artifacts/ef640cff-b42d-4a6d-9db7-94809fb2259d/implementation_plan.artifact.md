# Implementation Plan - Build Environment Recovery (Disk Space)

The build is failing due to insufficient disk space on the **C: drive** (only 0.89 GB free). We will clean up generated build artifacts and move the Gradle home to the **D: drive** (808 GB free) to ensure a successful release build.

## Build Environment Report

| Item | Location |
| :--- | :--- |
| **Gradle Cache** | `C:\Users\harsh\.gradle\caches` |
| **Java Temp** | `C:\Users\harsh\AppData\Local\Temp` |
| **Flutter Build** | `C:\Users\harsh\AndroidStudioProjects\krishibhandar\build` |
| **Android Build** | `C:\Users\harsh\AndroidStudioProjects\krishibhandar\android\build` |
| **TEMP / TMP** | `C:\Users\harsh\AppData\Local\Temp` |
| **USERPROFILE** | `C:\Users\harsh` |

### Disk Space Status

- **C: Drive**: 0.89 GB Free (CRITICAL)
- **D: Drive**: 808.06 GB Free (RECOMENDED)

## Proposed Actions

### 1. Cleanup
- Delete generated `build/` folders in the project and the `android/` module.
- Delete Gradle `caches`, `daemon`, and `workers` in `C:\Users\harsh\.gradle`.

### 2. Environment Configuration
- Set `GRADLE_USER_HOME` to `D:\.gradle` to utilize the massive free space on the D: drive.

### 3. Build Execution
- Run `fvm flutter clean`
- Run `fvm flutter pub get`
- Run `fvm flutter build appbundle --release`

## Verification Plan

### Manual Verification
- Monitor the build logs to ensure `:app:mergeReleaseNativeLibs` completes without "out of space" errors.
- Confirm the creation of the App Bundle in the build output directory.
