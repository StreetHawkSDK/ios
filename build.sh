#!/bin/sh -x
set -e

# delete /build/outputs folder
rm -Rf ./build/outputs/*
pushd .

# ------------------- build SHStatic ------------------------

cd Example_StaticLibrary

# install third-party pods
pod install

# clean project
xcodebuild clean -workspace StreetHawkDemo.xcworkspace -scheme StreetHawkDemo -sdk iphoneos -configuration Release

# archive app
xcodebuild archive -workspace StreetHawkDemo.xcworkspace -scheme StreetHawkDemo -archivePath ../build/outputs/SHStatic.xcarchive

# export ipa
xcodebuild -exportArchive -archivePath ../build/outputs/SHStatic.xcarchive -exportPath ../build/outputs/ -exportOptionsPlist ../build/ExportPlist.plist
mv ../build/outputs/StreetHawkDemo.ipa ../build/outputs/SHStatic.ipa

# ------------------- build SHDynamic ------------------------

cd ..
cd Example_DynamicFramework

# install third-party pods
pod install

# clean project
xcodebuild clean -workspace StreetHawkDemo.xcworkspace -scheme StreetHawkDemo -sdk iphoneos -configuration Release

# archive app
xcodebuild archive -workspace StreetHawkDemo.xcworkspace -scheme StreetHawkDemo -archivePath ../build/outputs/SHDynamic.xcarchive

# export ipa
xcodebuild -exportArchive -archivePath ../build/outputs/SHDynamic.xcarchive -exportPath ../build/outputs/ -exportOptionsPlist ../build/ExportPlist.plist
mv ../build/outputs/StreetHawkDemo.ipa ../build/outputs/SHDynamic.ipa

popd

