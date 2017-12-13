#!/bin/sh -x
echo "Build started on $(date)"
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
xcodebuild archive -workspace StreetHawkDemo.xcworkspace -scheme StreetHawkDemo -archivePath ../build/outputs/SHStatic.xcarchive -allowProvisioningUpdates

# ------------------- build SHDynamic ------------------------

cd ..
cd Example_DynamicFramework

# install third-party pods
pod install

# clean project
xcodebuild clean -workspace StreetHawkDemo.xcworkspace -scheme StreetHawkDemo -sdk iphoneos -configuration Release

# archive app
xcodebuild archive -workspace StreetHawkDemo.xcworkspace -scheme StreetHawkDemo -archivePath ../build/outputs/SHDynamic.xcarchive -allowProvisioningUpdates

popd

# ---------------------- upload to hockeyapp ---------------------

/usr/local/bin/puck -submit=auto -download=true -notes="$(git log -1)" -notes_type=markdown -source_path=$PWD -repository_url=https://github.com/StreetHawkSDK/ios -api_token=$HOCKEYAPP_TOKEN -app_id=$HOCKEYAPP_APPID_DYNAMIC build/outputs/SHDynamic.xcarchive
/usr/local/bin/puck -submit=auto -download=true -notes="$(git log -1)" -notes_type=markdown -source_path=$PWD -repository_url=https://github.com/StreetHawkSDK/ios -api_token=$HOCKEYAPP_TOKEN -app_id=$HOCKEYAPP_APPID_STATIC build/outputs/SHStatic.xcarchive
