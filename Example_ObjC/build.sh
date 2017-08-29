#!/bin/sh -x
[ "$(whoami)" != "hawk" ] && { echo "Only hawk may run this script."; exit 1; }
echo "Build started on $(date)"
LANG=en_US.UTF-8
mkdir -p build/outputs
pod install
xcodebuild -workspace StreetHawkDemo.xcworkspace -scheme StreetHawkDemo -sdk iphoneos -configuration Release
