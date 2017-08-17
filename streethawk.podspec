Pod::Spec.new do |s|
  s.name                = "streethawk"
  s.header_dir          = "StreetHawkCore"
  s.version             = "1.9.1-beta2"
  s.summary             = "Mobile Engagement Automation: Geofences campaign, Engage in right time via push message, Segment app user, analyse campaign performance."
  s.description         = <<-DESC
                            Streethawkis mobile engagement automation for your smartphone and tablet app user.

                            Engage users in right time using push message, segment your application users, create geofences and beacon regions to trigger location based campaign, analyse results and measure campaign performance.

                            Streethawk supports iOS and Android devices. Chek out Getting started section for integrating Streethawk into your iOS and Android application or check out detailed document at Streethawk Documents.
                            DESC
  s.homepage            = "http://www.streethawk.com"
  s.screenshots         = [ ]
  s.license             = 'LGPL'
  s.author              = { 'Christine' => 'christine@streethawk.com', 'Supporter' => 'support@streethawk.com' }
  s.documentation_url   = 'http://streethawksdk.github.io/ios/'

  s.source              = { :git => 'https://github.com/StreetHawkSDK/ios.git', :tag => s.version.to_s, :submodules => true }
  s.platform            = :ios, '8.0'
  s.requires_arc        = true
  
  s.xcconfig            = { 'OTHER_LDFLAGS' => '$(inherited) -lObjC', 
                            'OTHER_CFLAGS' => '$(inherited) -DNS_BLOCK_ASSERTIONS=1 -DNDEBUG'
                          }  
  
  s.subspec 'Core' do |sp|
    sp.source_files        = 'StreetHawk/Classes/Core/**/*.{h,m}', 'StreetHawk/Classes/ThirdParty/AFNetworking/*.{h,m}'
    sp.public_header_files = 'StreetHawk/Classes/Core/Publish/*.h'
    sp.exclude_files       = 'StreetHawk/Classes/Core/Private/SHPresentDialog.m', 'StreetHawk/Classes/Core/Private/SHCoverWindow.m'
    sp.resource_bundles    = {'streethawk' => ['StreetHawk/Assets/**/*']}
    sp.frameworks          = 'CoreTelephony', 'Foundation', 'CoreGraphics', 'UIKit', 'CoreSpotlight'
    sp.libraries           = 'sqlite3'    
    sp.dependency            'MBProgressHUD'
    sp.dependency            'Masonry'
    sp.dependency            'WebViewJavascriptBridge'
  end
  
  s.subspec 'Growth' do |sp|
    sp.xcconfig               = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SH_FEATURE_GROWTH' }
    sp.source_files           = 'StreetHawk/Classes/Growth/**/*.{h,m}'
    sp.public_header_files    = 'StreetHawk/Classes/Growth/Publish/*.h'
    sp.dependency               'streethawk/Core'
  end
  
  s.subspec 'Push' do |sp|
    sp.xcconfig               = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SH_FEATURE_NOTIFICATION' }
    sp.source_files           = 'StreetHawk/Classes/Notification/**/*.{h,m}'
    sp.public_header_files    = 'StreetHawk/Classes/Notification/Publish/*.h'
    sp.dependency               'streethawk/Core'
    sp.dependency               'AutoScrollLabel'
  end
  
  s.subspec 'Locations' do |sp|
    sp.xcconfig               = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SH_FEATURE_LATLNG' }
    sp.source_files           = 'StreetHawk/Classes/Location/**/*.{h,m}'
    sp.public_header_files    = 'StreetHawk/Classes/Location/Publish/*.h'
    sp.exclude_files          = 'StreetHawk/Classes/Location/Private/SHBeaconBridge.{h,m}', 'StreetHawk/Classes/Location/Private/SHBeaconStatus.{h,m}', 'StreetHawk/Classes/Location/Private/SHGeofenceBridge.{h,m}', 'StreetHawk/Classes/Location/Private/SHGeofenceStatus.{h,m}'
    sp.frameworks             = 'CoreLocation'
    sp.dependency               'streethawk/Core'
    sp.dependency               'Reachability'
  end
  
  s.subspec 'Geofence' do |sp|
    sp.xcconfig               = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SH_FEATURE_GEOFENCE' }
    sp.source_files           = 'StreetHawk/Classes/Location/**/*.{h,m}'
    sp.public_header_files    = 'StreetHawk/Classes/Location/Publish/*.h'
    sp.exclude_files          = 'StreetHawk/Classes/Location/Private/SHBeaconBridge.{h,m}', 'StreetHawk/Classes/Location/Private/SHBeaconStatus.{h,m}', 'StreetHawk/Classes/Location/Private/SHLocationBridge.{h,m}'
    sp.frameworks             = 'CoreLocation'
    sp.dependency               'streethawk/Core'
    sp.dependency               'Reachability'
  end
  
  s.subspec 'Beacons' do |sp|
    sp.xcconfig               = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SH_FEATURE_IBEACON' }
    sp.source_files           = 'StreetHawk/Classes/Location/**/*.{h,m}'
    sp.public_header_files    = 'StreetHawk/Classes/Location/Publish/*.h'
    sp.exclude_files          = 'StreetHawk/Classes/Location/Private/SHLocationBridge.{h,m}', 'StreetHawk/Classes/Location/Private/SHGeofenceBridge.{h,m}', 'StreetHawk/Classes/Location/Private/SHGeofenceStatus.{h,m}'
    sp.frameworks             = 'CoreLocation'
    sp.dependency               'streethawk/Core'
    sp.dependency               'Reachability'
  end
  
  s.subspec 'Crash' do |sp|
    sp.xcconfig               = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SH_FEATURE_CRASH' }
    sp.source_files           = 'StreetHawk/Classes/Crash/**/*.{h,m}'
    sp.public_header_files    = 'StreetHawk/Classes/Crash/Publish/*.h'
    sp.frameworks             = 'CoreLocation'
    sp.dependency               'streethawk/Core'    
    sp.vendored_frameworks    = 'StreetHawk/Vendor/CrashReporter.framework'
  end
  
  s.subspec 'Feed' do |sp|
    sp.xcconfig               = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) SH_FEATURE_FEED' }
    sp.source_files           = 'StreetHawk/Classes/Feed/**/*.{h,m}'
    sp.public_header_files    = 'StreetHawk/Classes/Feed/Publish/*.h'
    sp.dependency               'streethawk/Core'
  end
  
end
