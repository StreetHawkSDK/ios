#!/bin/bash -x

echo "==============================================================="
echo "Sync Core phonegap module"
STREETHAWK_NATIVE_SDK=./StreetHawk/

PHONEGAP_ANALYTICS=../PhonegapAnalytics/src/ios/SDK/
PHONEGAP_LOCATIONS=../PhonegapLocations/src/ios/SDK/
PHONEGAP_BEACONS=../PhonegapBeacons/src/ios/SDK/

# delete
rm -Rf $PHONEGAP_ANALYTICS/Core/*
# core folder
cp -Ra $STREETHAWK_NATIVE_SDK/Classes/Core/ $PHONEGAP_ANALYTICS/
sed -i -e 's/\[SHLogger checkLogdbForFreshInstall\];/ /g' "$PHONEGAP_ANALYTICS/Core/Publish/SHApp.m"
sed -i -e 's/\[SHLogger checkSentApnsModeForFreshInstall\];/ /g' "$PHONEGAP_ANALYTICS/Core/Publish/SHApp.m"
sed -i -e 's/return SHDevelopmentPlatform_Native;/return SHDevelopmentPlatform_Phonegap;/g' "$PHONEGAP_ANALYTICS/Core/src/ios/SDK/Core/Publish/SHApp.m"
sed -i -e 's/NSAssert(self.logger != nil, @"Lose logline due to logger is not ready.");/ /g' "$PHONEGAP_ANALYTICS/Core/src/ios/SDK/Core/Internal/SHLogger.m"

## location folder
mkdir -p $PHONEGAP_LOCATION/Location
cp -R $STREETHAWK_NATIVE_SDK/Classes/Location/Internal/ $PHONEGAP_LOCATIONS/Location/Internal/
cp -R $STREETHAWK_NATIVE_SDK/Classes/Location/Publish/ $PHONEGAP_LOCATIONS/Location/Publish/

## resource folder
mkdir -p $PHONEGAP_LOCATION/Core/src/ios/SDK/Resource
cp -a build/outputs/Release/universal/StreetHawkCore.framework/StreetHawkCoreRes.bundle $PHONEGAP_ANALYTICS/Core/src/ios/SDK/Resource/StreetHawkCoreRes.bundle

## third-party folder
mkdir -p $PHONEGAP_ANALYTICS/Core/src/ios/SDK/ThirdParty
cp -R $STREETHAWK_NATIVE_SDK/Classes/ThirdParty/AFNetworking/ $PHONEGAP_ANALYTICS/Core/src/ios/SDK/ThirdParty/AFNetworking/

mkdir -p $PHONEGAP_ANALYTICS/ThirdParty/MBProgressHUD
cp -a $STREETHAWK_NATIVE_SDK/Classes/ThirdParty/MBProgressHUD/SHMBProgressHUD.h $PHONEGAP_ANALYTICS/ThirdParty/MBProgressHUD/SHMBProgressHUD.h
cp -a $STREETHAWK_NATIVE_SDK/Classes/ThirdParty/MBProgressHUD/SHMBProgressHUD.m $PHONEGAP_ANALYTICS/ThirdParty/MBProgressHUD/SHMBProgressHUD.m
cp -R $STREETHAWK_NATIVE_SDK/Classes/ThirdParty/Reachability/ $PHONEGAP_ANALYTICS/ThirdParty/Reachability/
cp -R $STREETHAWK_NATIVE_SDK/Classes/ThirdParty/UIDevice_Extension/ $PHONEGAP_ANALYTICS/ThirdParty/UIDevice_Extension/
#
echo "==============================================================="
echo "Sync Location phonegap module"
# delete
rm -Rf $PHONEGAP_LOCATION/*
## location files
mkdir -p $PHONEGAP_LOCATIONS/Location
mkdir -p $PHONEGAP_LOCATIONS/Location/Private
cp -a $STREETHAWK_NATIVE_SDK/Classes/Location/Private/SHLocationBridge.h $PHONEGAP_LOCATIONS/Location/Private/SHLocationBridge.h
cp -a $STREETHAWK_NATIVE_SDK/Classes/Location/Private/SHLocationBridge.m $PHONEGAP_LOCATIONS/Location/Private/SHLocationBridge.m
#
echo "==============================================================="
echo "Sync Beacon phonegap module"
# delete
rm -Rf ../../StreetHawkWrapper/Phonegap_module/Beacons/src/ios/SDK/*
# beacon files
mkdir -p $PHONEGAP_BEACONS/Beacon
mkdir -p $PHONEGAP_BEACONS/Beacon/Private
cp -a $STREETHAWK_NATIVE_SDK/Classes/Location/Private/SHBeaconBridge.h $PHONEGAP_BEACONS/Beacon/Private/SHBeaconBridge.h
cp -a $STREETHAWK_NATIVE_SDK/Classes/Location/Private/SHBeaconBridge.m $PHONEGAP_BEACONS/Beacon/Private/SHBeaconBridge.m
cp -a $STREETHAWK_NATIVE_SDK/Classes/Location/Private/SHBeaconStatus.h $PHONEGAP_BEACONS/Beacon/Private/SHBeaconStatus.h
cp -a $STREETHAWK_NATIVE_SDK/Classes/Location/Private/SHBeaconStatus.m $PHONEGAP_BEACONS/Beacon/Private/SHBeaconStatus.m

echo "==============================================================="
echo "Sync Geofence phonegap module"
# delete
rm -Rf ../../StreetHawkWrapper/Phonegap_module/Geofence/src/ios/SDK/*

# geofence files
mkdir -p $PHONEGAP_GEOFENCE/Geofence
mkdir -p $PHONEGAP_GEOFENCE/Geofence/Private
cp -a $STREETHAWK_NATIVE_SDK/Classes/Location/Private/SHGeofenceBridge.h $PHONEGAP_GEOFENCE/Geofence/Private/SHGeofenceBridge.h
cp -a $STREETHAWK_NATIVE_SDK/Classes/Location/Private/SHGeofenceBridge.m $PHONEGAP_GEOFENCE/Geofence/Private/SHGeofenceBridge.m
cp -a $STREETHAWK_NATIVE_SDK/Classes/Location/Private/SHGeofenceStatus.h $PHONEGAP_GEOFENCE/Geofence/Private/SHGeofenceStatus.h
cp -a $STREETHAWK_NATIVE_SDK/Classes/Location/Private/SHGeofenceStatus.m $PHONEGAP_GEOFENCE/Geofence/Private/SHGeofenceStatus.m

echo "==============================================================="
echo "Sync Growth phonegap module"
# delete
rm -Rf $PHONEGAP_GROWTH/Growth/src/ios/SDK/*

# growth folder
cp -R /Classes/Growth/ $PHONEGAP_GROWTH/Growth/
cp -a $STREETHAWK_NATIVE_SDK/Classes/Growth/Private/SHGrowth.m $PHONEGAP_GROWTH/Growth/Private/SHGrowth.m

echo "==============================================================="
echo "Sync Push phonegap module"
# delete
rm -Rf $PHONEGAP_PUSH/Push/src/ios/SDK/*
# notification folder
cp -R $STREETHAWK_NATIVE_SDK/Classes/Notification/ $PHONEGAP_GEOFENCE/Push/src/ios/SDK/Notification/
# third-party folder
mkdir -p ../../StreetHawkWrapper/Phonegap_module/Push/src/ios/SDK/ThirdParty
cp -R $STREETHAWK_NATIVE_SDK/Classes/ThirdParty/CBAutoScrollLabel/ $PHONEGAP_PUSH/Push/src/ios/SDK/ThirdParty/CBAutoScrollLabel/
cp -R $STREETHAWK_NATIVE_SDK/Classes/ThirdParty/Emojione/ $PHONEGAP_PUSH/Push/src/ios/SDK/ThirdParty/Emojione/

echo "==============================================================="
echo "Sync Feed phonegap module"
# delete
rm -Rf $PHONEGAP_FEED/Feed/src/ios/SDK/*
# feed folder
cp -R $PHONEGAP_FEED/Classes/Feed/ $PHONEGAP_FEED/Feed/src/ios/SDK/Feed/

echo "==============================================================="
echo "Finish sync phonegap module"
echo "==============================================================="
