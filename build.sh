#!/bin/sh -x
echo "Build started on $(date)"
set -e

BUILD_OUTPUTS=$(pwd)/build/outputs/
mkdir -p $BUILD_OUTPUTS
DOC_DIR=$BUILD_OUTPUTS/doc/
rm -Rf $BUILD_OUTPUTS/*

export PATH="$HOME/.fastlane/bin:$PATH"

security unlock-keychain -p $BUILD_PASSWORD "/Users/hawk/Library/Keychains/login.keychain-db"

# ------------------- build SHStatic ------------------------

pushd .

cd Example_StaticLibrary

pod install
pod update

fastlane gym --scheme StreetHawkDemo --export_method "ad-hoc" --output_directory "$BUILD_OUTPUTS" --output_name "SHStatic.ipa" --clean true

popd

# ------------------- build SHDynamic ------------------------

pushd .

cd Example_DynamicFramework

pod install
pod update

fastlane gym --scheme StreetHawkDemo --export_method "ad-hoc" --output_directory "$BUILD_OUTPUTS" --output_name "SHDynamic.ipa" --clean true

popd

# ---------------------- upload to hockeyapp ---------------------

/usr/local/bin/puck -submit=auto -download=true -notes="$(git log -1)" -notes_type=markdown -source_path=$PWD -repository_url=https://github.com/StreetHawkSDK/ios -api_token=$HOCKEYAPP_TOKEN -app_id=$HOCKEYAPP_APPID_DYNAMIC build/outputs/SHDynamic.ipa
/usr/local/bin/puck -submit=auto -download=true -notes="$(git log -1)" -notes_type=markdown -source_path=$PWD -repository_url=https://github.com/StreetHawkSDK/ios -api_token=$HOCKEYAPP_TOKEN -app_id=$HOCKEYAPP_APPID_STATIC build/outputs/SHStatic.ipa

echo "==============================================================="
echo "Generate document for StreetHawk"

/usr/local/bin/appledoc --project-name "StreetHawk" --project-company "StreetHawk" --company-id com.streethawk --ignore "StreetHawk/Classes/ThirdParty" --ignore "StreetHawk/Classes/Core/Internal" --ignore "StreetHawk/Classes/Core/Private" --ignore "StreetHawk/Classes/Crash/Internal" --ignore "StreetHawk/Classes/Crash/Private" --ignore "StreetHawk/Classes/Feed/Internal" --ignore "StreetHawk/Classes/Feed/Private" --ignore "StreetHawk/Classes/Growth/Internal" --ignore "StreetHawk/Classes/Growth/Private" --ignore "StreetHawk/Classes/Location/Internal" --ignore "StreetHawk/Classes/Location/Private" --ignore "StreetHawk/Classes/Notification/Internal" --ignore "StreetHawk/Classes/Notification/Private" --ignore .m --logformat xcode --keep-undocumented-members --no-repeat-first-par --keep-merged-sections --create-html --no-install-docset --verbose 6 --output "${DOC_DIR}" --docset-install-path "${DOC_DIR}" --exit-threshold 2 "StreetHawk/Classes"
