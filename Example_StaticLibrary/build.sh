#!/bin/sh -x

# install third-party pods
pod install

# delete /build/outputs folder
rm -Rf ./build/outputs/*

# clean project
xcodebuild clean -workspace StreetHawkDemo.xcworkspace -scheme StreetHawkDemo -sdk iphoneos -configuration Release

# archive app
xcodebuild archive -workspace StreetHawkDemo.xcworkspace -scheme StreetHawkDemo -archivePath ./build/outputs/SHStatic.xcarchive

# export ipa
xcodebuild -exportArchive -archivePath ./build/outputs/SHStatic.xcarchive -exportPath ./build/outputs/SHStatic.ipa -exportOptionsPlist ./build/ExportPlist.plist

