#!/bin/sh -x
echo "Build started on $(date)"
set -e

BUILD_OUTPUTS=$(pwd)/build/outputs/
mkdir -p $BUILD_OUTPUTS
rm -Rf $BUILD_OUTPUTS/*

# ------------------- build SHStatic ------------------------

pushd .

cd Example_StaticLibrary

fastlane gym --scheme StreetHawkDemo --export_method "ad-hoc" --output_directory "$BUILD_OUTPUTS" --output_name "SHStatic.ipa" --clean true

popd

# ------------------- build SHDynamic ------------------------

pushd .

cd Example_DynamicFramework

fastlane gym --scheme StreetHawkDemo --export_method "ad-hoc" --output_directory "$BUILD_OUTPUTS" --output_name "SHDynamic.ipa" --clean true

popd

# ---------------------- upload to hockeyapp ---------------------

/usr/local/bin/puck -submit=auto -download=true -notes="$(git log -1)" -notes_type=markdown -source_path=$PWD -repository_url=https://github.com/StreetHawkSDK/ios -api_token=$HOCKEYAPP_TOKEN -app_id=$HOCKEYAPP_APPID_DYNAMIC build/outputs/SHDynamic.ipa
/usr/local/bin/puck -submit=auto -download=true -notes="$(git log -1)" -notes_type=markdown -source_path=$PWD -repository_url=https://github.com/StreetHawkSDK/ios -api_token=$HOCKEYAPP_TOKEN -app_id=$HOCKEYAPP_APPID_STATIC build/outputs/SHStatic.ipa
