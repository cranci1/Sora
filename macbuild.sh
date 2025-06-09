#!/bin/bash

set -e

cd "$(dirname "$0")"

WORKING_LOCATION="$(pwd)"
APPLICATION_NAME=Sulfur

if [ ! -d "build" ]; then
    mkdir build
fi

cd build

xcodebuild -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
    -scheme "$APPLICATION_NAME" \
    -configuration Release \
    -derivedDataPath "$WORKING_LOCATION/build/DerivedDataApp-x86_64" \
    -destination 'platform=macOS,arch=x86_64,variant=Mac Catalyst' \
    clean build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"

xcodebuild -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
    -scheme "$APPLICATION_NAME" \
    -configuration Release \
    -derivedDataPath "$WORKING_LOCATION/build/DerivedDataApp-arm64" \
    -destination 'platform=macOS,arch=arm64,variant=Mac Catalyst' \
    clean build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"

DD_APP_PATH_X86_64="$WORKING_LOCATION/build/DerivedDataApp-x86_64/Build/Products/Release-maccatalyst/$APPLICATION_NAME.app"
DD_APP_PATH_ARM64="$WORKING_LOCATION/build/DerivedDataApp-arm64/Build/Products/Release-maccatalyst/$APPLICATION_NAME.app"
TARGET_APP="$WORKING_LOCATION/build/$APPLICATION_NAME.app"

rm -rf "$TARGET_APP"
cp -r "$DD_APP_PATH_ARM64" "$TARGET_APP"

lipo -create \
    "$DD_APP_PATH_X86_64/Contents/MacOS/$APPLICATION_NAME" \
    "$DD_APP_PATH_ARM64/Contents/MacOS/$APPLICATION_NAME" \
    -output "$TARGET_APP/Contents/MacOS/$APPLICATION_NAME"

codesign --remove "$TARGET_APP"
if [ -e "$TARGET_APP/_CodeSignature" ]; then
    rm -rf "$TARGET_APP/_CodeSignature"
fi

echo "Universal Mac Catalyst build completed: $TARGET_APP"
lipo -archs "$TARGET_APP/Contents/MacOS/$APPLICATION_NAME"
