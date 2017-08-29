#!/bin/sh -x
pod install
xcodebuild -workspace StreetHawkDemo.xcworkspace -scheme StreetHawkDemo -sdk iphoneos -configuration Release
