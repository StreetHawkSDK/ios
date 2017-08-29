#!/bin/sh -x
LANG=en_US.UTF-8
mkdir -p build/outputs
pod install
xcodebuild -workspace StreetHawkDemo.xcworkspace -scheme StreetHawkDemo -sdk iphoneos -configuration Release
