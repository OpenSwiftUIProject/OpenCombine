#!/usr/bin/env bash
#
# Cross-compiles the tests with the Swift SDK for Android and runs them on an
# Android device or emulator through adb.

set -euo pipefail

usage() {
    cat <<EOF
Usage: bash utils/android_test.sh [build [FLAGS...] | run [FILTER...]]

  build  Build the tests with the Swift SDK for Android and stage the test
         runner with the Swift runtime libraries. FLAGS go to 'swift build'.
  run    Push the staged tests to the connected device or emulator and run
         them there. FILTER goes to XCTest, e.g. OpenCombineTests.JustTests.

Without a command, builds and then runs the tests.

Requirements: a swift.org toolchain with the matching Swift SDK for Android
installed, the Android NDK, and for 'run' adb with a device on API 28+.

Environment:
  ANDROID_ARCH              x86_64 or aarch64 (default: the connected device's
                            ABI for 'run', the host architecture for 'build')
  ANDROID_API_LEVEL         API level of the target triple (default: 28)
  ANDROID_NDK_HOME          NDK to link into the Swift SDK if not linked yet
  SWIFT_ANDROID_SDK_BUNDLE  Path to the Swift SDK for Android artifact bundle
                            (default: the one matching the host toolchain)
  ANDROID_SERIAL            Device to use when several are connected
EOF
}

readonly api_level=${ANDROID_API_LEVEL:-28}
readonly test_dir=OpenCombineTests
readonly remote_parent=/data/local/tmp
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly repo_root

log() { printf '** %s\n' "$*" >&2; }
fatal() { printf '** error: %s\n' "$*" >&2; exit 1; }

host_arch() {
    case "$(uname -m)" in
        x86_64 | amd64) echo x86_64 ;;
        arm64 | aarch64) echo aarch64 ;;
        *) fatal "unsupported host architecture $(uname -m), set ANDROID_ARCH" ;;
    esac
}

device_arch() {
    local abi
    command -v adb > /dev/null || fatal "adb not found in PATH"
    abi=$(adb shell getprop ro.product.cpu.abi | tr -d '\r') ||
        fatal "no Android device or emulator available"
    case "$abi" in
        x86_64) echo x86_64 ;;
        arm64-v8a) echo aarch64 ;;
        *) fatal "unsupported device ABI $abi" ;;
    esac
}

stage_dir() {
    echo "$repo_root/.build/android-test/$1-unknown-linux-android$api_level/$test_dir"
}

# The Swift SDK for Android must match the host toolchain exactly, so look for
# the bundle named after the toolchain tag, e.g. swift-6.3.3-RELEASE_android.
find_sdk_bundle() {
    if [ -n "${SWIFT_ANDROID_SDK_BUNDLE:-}" ]; then
        echo "$SWIFT_ANDROID_SDK_BUNDLE"
        return
    fi
    local tag dir
    tag=$(swift --version 2> /dev/null | sed -n 's/.*(\(swift-[^)]*\)).*/\1/p' | head -n 1)
    [ -n "$tag" ] ||
        fatal "cannot determine the host toolchain version, use a swift.org toolchain"
    for dir in \
        ${XDG_CONFIG_HOME:+"$XDG_CONFIG_HOME/swiftpm/swift-sdks"} \
        "$HOME/.swiftpm/swift-sdks" \
        "$HOME/.config/swiftpm/swift-sdks" \
        "$HOME/Library/org.swift.swiftpm/swift-sdks"; do
        if [ -d "$dir/${tag}_android.artifactbundle" ]; then
            echo "$dir/${tag}_android.artifactbundle"
            return
        fi
    done
    fatal "Swift SDK for Android matching $tag is not installed, see" \
        "https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html"
}

build() {
    local arch=$1
    shift
    local triple="$arch-unknown-linux-android$api_level"
    local bundle sdk bin_path stage runners

    bundle=$(find_sdk_bundle)
    sdk="$bundle/swift-android"
    if [ ! -d "$sdk/ndk-sysroot" ]; then
        [ -n "${ANDROID_NDK_HOME:-}" ] ||
            fatal "set ANDROID_NDK_HOME to link the Android NDK into $bundle"
        log "Linking the Android NDK at $ANDROID_NDK_HOME"
        "$sdk/scripts/setup-android-sdk.sh"
    fi

    log "Building tests for $triple"
    cd "$repo_root"
    swift build --build-tests --swift-sdk "$triple" "$@"
    bin_path=$(swift build --build-tests --swift-sdk "$triple" "$@" --show-bin-path)

    stage=$(stage_dir "$arch")
    log "Staging tests in $stage"
    rm -rf "$stage"
    mkdir -p "$stage"
    shopt -s nullglob
    runners=("$bin_path"/*.xctest "$bin_path"/*-test-runner)
    [ ${#runners[@]} -gt 0 ] || fatal "no test runner found in $bin_path"
    cp "${runners[@]}" "$bin_path"/*.so "$stage"
    shopt -u nullglob
    cp "$sdk/swift-resources/usr/lib/swift-$arch/android/"*.so "$stage"
    cp "$sdk/ndk-sysroot/usr/lib/$arch-linux-android/libc++_shared.so" "$stage"
}

run() {
    local arch=$1
    shift
    local remote_dir="$remote_parent/$test_dir"
    local stage runners runner arg filters=""

    stage=$(stage_dir "$arch")
    [ -d "$stage" ] || fatal "no tests staged in $stage, run the build command first"
    shopt -s nullglob
    runners=("$stage"/*-test-runner "$stage"/*.xctest)
    shopt -u nullglob
    [ ${#runners[@]} -gt 0 ] || fatal "no test runner found in $stage"
    runner=$(basename "${runners[0]}")

    # Quote the filters for the device shell.
    for arg in "$@"; do
        filters+=" '${arg//\'/\'\\\'\'}'"
    done

    log "Pushing tests to $remote_dir"
    adb shell rm -rf "$remote_dir"
    adb push "$stage" "$remote_parent"

    log "Running $runner"
    adb shell "cd $remote_dir && LD_LIBRARY_PATH=$remote_dir ./$runner$filters"
}

command=${1:-all}
if [ $# -gt 0 ]; then
    shift
fi

case "$command" in
    build)
        arch=${ANDROID_ARCH:-$(host_arch)}
        build "$arch" "$@"
        ;;
    run)
        arch=${ANDROID_ARCH:-$(device_arch)}
        run "$arch" "$@"
        ;;
    all)
        [ $# -eq 0 ] || fatal "pass flags or filters to the build or run command"
        arch=${ANDROID_ARCH:-$(device_arch)}
        build "$arch"
        run "$arch"
        ;;
    -h | --help)
        usage
        ;;
    *)
        usage >&2
        exit 64
        ;;
esac
