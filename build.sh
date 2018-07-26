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
fastlane beta HOCKEYAPP_TOKEN:$HOCKEYAPP_TOKEN
popd

# ------------------- build SHDynamic ------------------------

pushd .

cd Example_DynamicFramework

pod install
fastlane beta HOCKEYAPP_TOKEN:$HOCKEYAPP_TOKEN

popd

echo "==============================================================="
echo "Generate document for StreetHawk"

/usr/local/bin/appledoc --project-name "StreetHawk" --project-company "StreetHawk" --company-id com.streethawk --ignore "StreetHawk/Classes/ThirdParty" --ignore "StreetHawk/Classes/Core/Internal" --ignore "StreetHawk/Classes/Core/Private" --ignore "StreetHawk/Classes/Crash/Internal" --ignore "StreetHawk/Classes/Crash/Private" --ignore "StreetHawk/Classes/Feed/Internal" --ignore "StreetHawk/Classes/Feed/Private" --ignore "StreetHawk/Classes/Growth/Internal" --ignore "StreetHawk/Classes/Growth/Private" --ignore "StreetHawk/Classes/Location/Internal" --ignore "StreetHawk/Classes/Location/Private" --ignore "StreetHawk/Classes/Notification/Internal" --ignore "StreetHawk/Classes/Notification/Private" --ignore .m --logformat xcode --keep-undocumented-members --no-repeat-first-par --keep-merged-sections --create-html --no-install-docset --verbose 6 --output "${DOC_DIR}" --docset-install-path "${DOC_DIR}" --exit-threshold 3 "StreetHawk/Classes"
