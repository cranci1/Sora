#!/bin/bash

set -e

cd "$(dirname "$0")"

WORKING_LOCATION="$(pwd)"
APPLICATION_NAME=Sulfur

# Create build directory if it doesn't exist
if [ ! -d "build" ]; then
    mkdir build
fi

cd build

# Attempt to recover the project by using the backup
if [ -f "$WORKING_LOCATION/Sulfur.xcodeproj/project.pbxproj.bak" ]; then
    echo "Restoring project file from backup..."
    cp "$WORKING_LOCATION/Sulfur.xcodeproj/project.pbxproj.bak" "$WORKING_LOCATION/Sulfur.xcodeproj/project.pbxproj"
fi

# Try to build for iOS simulator
echo "Building for iOS simulator..."
xcrun simctl list devices

echo "Attempting to build the iOS app..."
# Use xcarchive to build the project - this is more reliable for damaged project files
xcodebuild clean archive -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
    -scheme "$APPLICATION_NAME" \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -archivePath "$WORKING_LOCATION/build/Sulfur.xcarchive" \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED="NO"

echo "Build completed. Check the output for any errors."
echo "Archive can be found at: $WORKING_LOCATION/build/Sulfur.xcarchive" 