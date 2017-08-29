#!/bin/sh -x
echo "Build started on $(date)"
LANG=en_US.UTF-8
HOME=/var/lib/streethawk
mkdir -p build/outputs
mkdir -p $HOME
pod install
xcodebuild -workspace StreetHawkDemo.xcworkspace -scheme StreetHawkDemo -sdk iphoneos -configuration Release
