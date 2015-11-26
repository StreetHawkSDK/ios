/*
 * Copyright (c) StreetHawk, All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3.0 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library.
 */

#import "SHApp.h"
//header from StreetHawk
#import "SHInstallHandler.h"
#import "SHLogger.h"
#import "SHInterceptor.h"
#import "SHAppStatus.h"
#import "SHFeedbackQueue.h"
#import "SHDeepLinking.h"
#import "SHFriendlyNameObject.h"
#import "SHUtils.h"
#ifdef SH_FEATURE_CRASH
#import "SHApp+Crash.h" //for crash handler
#import "SHCrashHandler.h" //for create SHCrashHandler instance
#endif
#if defined(SH_FEATURE_LATLNG) || defined(SH_FEATURE_GEOFENCE) || defined(SH_FEATURE_IBEACON)
#import "SHApp+Location.h"
#import "SHLocationManager.h" //for create SHLocationManager instance
#endif

#define SETTING_UTC_OFFSET                  @"SETTING_UTC_OFFSET"  //key for local saved utc offset value

#define APPKEY_KEY                          @"APPKEY_KEY" //key for store "app key", next time if try to read appKey before register, read from this one.
#define INSTALL_SUID_KEY                    @"INSTALL_SUID_KEY"

#define ENTER_PAGE_HISTORY                  @"ENTER_PAGE_HISTORY"  //key for record entered page history. It's set when enter a page and cleared when send exit log except go BG.
#define ENTERBAK_PAGE_HISTORY               @"ENTERBAK_PAGE_HISTORY" //key for record entered page history as backup. It's set as backup in case ENTER_PAGE_HISTORY not set in canceled pop up.
#define EXIT_PAGE_HISTORY                   @"EXIT_PAGE_HISTORY"  //key for record send exit log history. It's set when send exit log and cleared when send enter log. This is to avoid send duplicated exit log.

#define ADS_IDENTIFIER                      @"ADS_IDENTIFIER" //user pass in advertising identifier

@interface SHViewActivity : NSObject

@property (nonatomic, strong) NSString *viewName;
@property (nonatomic, strong) NSDate *enterTime;
@property (nonatomic, strong) NSDate *exitTime;
@property (nonatomic) double duration;
@property (nonatomic) BOOL enterBg;

@end

@implementation SHViewActivity

- (id)initWithViewName:(NSString *)viewName
{
    if (self = [super init])
    {
        self.viewName = viewName;
        self.enterTime = [NSDate date];
    }
    return self;
}

- (NSString *)serializeToString
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:self.viewName forKey:@"page"];
    [dict setObject:shFormatStreetHawkDate(self.enterTime) forKey:@"enter"];
    [dict setObject:shFormatStreetHawkDate(self.exitTime) forKey:@"exit"];
    [dict setObject:@(self.duration) forKey:@"duration"];
    [dict setObject:@(self.enterBg) forKey:@"bg"];
    return NONULL(shSerializeObjToJson(dict));
}

@end

@interface SHApp ()

@property (nonatomic) BOOL isBridgeInitCalled; //Flag to let module's bridge init only call once.
@property (nonatomic) BOOL isRegisterInstallForAppCalled; //Customer Sandstone call `registerInstallForApp` many times and meet crash. It does not make sense to call it twice and later, add this flag to ignore second and later call.
@property (nonatomic) BOOL isFinishLaunchOptionCalled; //For handle Phonegap, Unity, Titanium finish launch is postpone to call again after a few seconds, at that time StreetHawk is register and ready to use. However it cause native and Xamarin enter twice. To avoid call it again add this flag.

//internal handlers
@property (nonatomic, strong) SHInstallHandler *installHandler;
@property (nonatomic, strong) SHLogger *innerLogger;

//background execution
@property (nonatomic, strong) NSOperationQueue *backgroundQueue;  //Used for background execution. Enter background or foreground must be finished in 10 seconds, to finish send install/log request begin a background task which can run 10 minutes in another thread using operation queue.
//End background task, must do this for started background task.
- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)backgroundTask;

//notifications
- (void)setupNotifications;  //Setup observer for system event, such as applicationDidFinishLaunching, Resign Active, EnterBackground, EnterForeground etc.
- (void)applicationDidFinishLaunchingNotificationHandler:(NSNotification *)notification;
- (void)applicationWillResignActiveNotificationHandler:(NSNotification *)notification;
- (void)applicationDidEnterBackgroundNotificationHandler:(NSNotification *)notification;
- (void)applicationWillEnterForegroundNotificationHandler:(NSNotification *)notification;
- (void)applicationDidBecomeActiveNotificationHandler:(NSNotification *)notification;
- (void)applicationWillTerminateNotificationHandler:(NSNotification *)notification;
- (void)applicationDidReceiveMemoryWarningNotificationHandler:(NSNotification *)notification;
- (void)appStatusChange:(NSNotification *)notification;
+ (void)delaySendLaunchOptions:(NSNotification *)notification;

//sh_utc_offset update
- (void)checkUtcOffsetUpdate;  //Check utc_offset: if not logged before or changed, log it immediately.
- (void)timeZoneChangeNotificationHandler:(NSNotification *)notification;  //Notification handler called when time zone change

//send module tags
- (void)sendModuleTags; //Send current build include what modules.

//Log enter/exit page.
@property (nonatomic, strong) SHViewActivity *currentView;
- (void)shNotifyPageEnter:(NSString *)page sendEnter:(BOOL)doEnter sendExit:(BOOL)doExit;
- (void)shNotifyPageExit:(NSString *)page clearEnterHistory:(BOOL)needClear logCompleteView:(BOOL)logComplete;

//For test purpose, check both Object-C style NSAssert and C style assert in SDK. It's hidden, not visible to public.
- (void)checkAssert;

//Auto integrate app delegate
@property (nonatomic, strong) SHInterceptor *appDelegateInterceptor; //interceptor for handling AppDelegate automatically integration.
@property (nonatomic, strong) id<UIApplicationDelegate> originalAppDelegate; //strong pointer to keep original customer's AppDelegate, otherwise after switch to interceptor it's null.

//Submit friendly names to StreetHawk server.
- (void)submitFriendlyNames;

@end

@implementation SHApp

@synthesize currentInstall = _currentInstall;

#pragma mark - life cycle

+ (void)load
{
    //Fix Phonegap, Titanium and Unity delay register issue: in these platforms App first launch, get ready (take Phonegap for example after html load, take Unity for example after main camera ready) then call [StreetHawk registerInstallForApp...]. When StreetHawk SDK prepare to use, application did finish launch is pass, causing issue such as:
    //1. Some function like check library not called;
    //2. Cannot handle remote notification in case App not launch.
    //3. Open url miss in case App not launch.
    //To fix this, before everything starts (as load function register class to runtime), register `UIApplicationDidFinishLaunchingNotification` and delay send again in 2 seconds.
    //To keep compatible with native and xamarin, a flag is added to avoid twice call.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(delaySendLaunchOptions:) name:UIApplicationDidFinishLaunchingNotification object:nil];
}

+ (void)delaySendLaunchOptions:(NSNotification *)notification
{
    double delayInSeconds = 2;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
    {
       [[NSNotificationCenter defaultCenter] postNotificationName:@"StreetHawkDelayLaunchOptionsNotification" object:notification.object userInfo:notification.userInfo];
    });
}

+ (SHApp *)sharedInstance
{
    static SHApp *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        instance = [[SHApp alloc] init];
    });
    if (!instance.isBridgeInitCalled)
    {
        instance.isBridgeInitCalled = YES;
        //add module init bridges. This is automatically for native, Phonegap, Xamarin.
        //In case cannot reflect bridge class, customer need to manually add notification observer.
        //disable warning as this selector is defined in sub-module category.
#pragma GCC diagnostic push
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Wundeclared-selector"
        Class growthBridge = NSClassFromString(@"SHGrowthBridge");
        NSLog(@"Bridge for growth: %@.", growthBridge); //cannot use SHLog as this place `isDebugMode` not configured yet. Use NSLog to make sure prints important bridge message.
        if (growthBridge)
        {
            [[NSNotificationCenter defaultCenter] addObserver:growthBridge selector:@selector(bridgeHandler:) name:SH_InitBridge_Notification object:nil];
        }
        Class notificationBridge = NSClassFromString(@"SHNotificationBridge");
        NSLog(@"Bridge for notification: %@.", notificationBridge);
        if (notificationBridge)
        {
            [[NSNotificationCenter defaultCenter] addObserver:notificationBridge selector:@selector(bridgeHandler:) name:SH_InitBridge_Notification object:nil];
        }
        Class locationBridge = NSClassFromString(@"SHLocationBridge");
        NSLog(@"Bridge for location: %@.", locationBridge);
        if (locationBridge)
        {
            [[NSNotificationCenter defaultCenter] addObserver:locationBridge selector:@selector(bridgeHandler:) name:SH_InitBridge_Notification object:nil];
        }
        Class geofenceBridge = NSClassFromString(@"SHGeofenceBridge");
        NSLog(@"Bridge for geofence: %@.", geofenceBridge);
        if (geofenceBridge)
        {
            [[NSNotificationCenter defaultCenter] addObserver:geofenceBridge selector:@selector(bridgeHandler:) name:SH_InitBridge_Notification object:nil];
        }
        Class beaconBridge = NSClassFromString(@"SHBeaconBridge");
        NSLog(@"Bridge for beacon: %@.", beaconBridge);
        if (beaconBridge)
        {
            [[NSNotificationCenter defaultCenter] addObserver:beaconBridge selector:@selector(bridgeHandler:) name:SH_InitBridge_Notification object:nil];
        }
#pragma GCC diagnostic pop
#pragma clang diagnostic pop
        //finally post notification to let bridge ready.
        [[NSNotificationCenter defaultCenter] postNotificationName:SH_InitBridge_Notification object:nil];
    }
    
    return instance;
}

- (id)init
{
    if (self = [super init])
    {
        self.isBridgeInitCalled = NO;
        self.isRegisterInstallForAppCalled = NO;
        self.isFinishLaunchOptionCalled = NO;
        //Check local SQLite database and NSUserDefaults at first time before any call. If not match next will be treat as a new install. This is only checked when launch App, not check during App running. Check Apns mode also.
        [SHLogger checkLogdbForFreshInstall];
        [SHLogger checkSentApnsModeForFreshInstall];
        //Then continue normal code.
        self.isDebugMode = NO;
#ifdef SH_FEATURE_CRASH
        self.isEnableCrashReport = YES;
#endif
        self.backgroundQueue = [[NSOperationQueue alloc] init];
        self.backgroundQueue.maxConcurrentOperationCount = 1;
        self.install_semaphore = dispatch_semaphore_create(1);  //happen in sequence
        //some handlers initialize erlier
        self.installHandler = [[SHInstallHandler alloc] init];

        self.autoIntegrateAppDelegate = YES;
        [self setupNotifications]; //move early so that Phonegap can handle remote notification in appDidFinishLaunching.
    }
    return self;
}

- (void)registerInstallForApp:(NSString *)appKey withDebugMode:(BOOL)isDebugMode
{
    if (self.isRegisterInstallForAppCalled)
    {
        return; //ignore second and later call.
    }
    self.isRegisterInstallForAppCalled = YES;
    NSString *registerAppKey = appKey; //first try this function pass in.
    if (shStrIsEmpty(registerAppKey)) //second try property StreetHawk.appKey set by code.
    {
        registerAppKey = StreetHawk.appKey;
    }
    if (shStrIsEmpty(registerAppKey)) //second try Info.plist, for Phonegap, Titanium, set APP_KEY in Info.plist.
    {
        registerAppKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"APP_KEY"];
    }
    NSAssert(!shStrIsEmpty(registerAppKey), @"Not setup App key for this register.");
    if (!shStrIsEmpty(registerAppKey))
    {
        StreetHawk.appKey = registerAppKey;
        [[NSUserDefaults standardUserDefaults] setObject:registerAppKey forKey:APPKEY_KEY];
    }
    else
    {
        SHLog(@"Warning: Please setup APP_KEY in Info.plist or pass in by parameter.");
    }
    //assign pass in parameters
    self.isDebugMode = isDebugMode;
    //initialize handlers
    self.innerLogger = [[SHLogger alloc] init];  //this creates logs db, wait till user call `registerInstallForApp` to take action. logger must before location manager, because location manager create and start to send log, for example failure, and logger must be ready.
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_LMBridge_CreateLocationManager" object:nil];
#ifdef SH_FEATURE_CRASH
    if (self.isEnableCrashReport)
    {
        self.crashHandler = [[SHCrashHandler alloc] init];
        [self.crashHandler enableCrashReporter];
    }
#endif
    //At first possible place check app/status (https://bitbucket.org/shawk/streethawk/issue/555/apps-status-should-be-called-before), note:
    //1. It does NOT stop anything, streethawkEnabled is YES by default, and all other functions work, not wait for completeHandler.
    //2. It sends /apps/status request before all other request, but cannot put init as app_key is not known yet.
    //3. Not force so that second and later launch not send request.
    [[SHAppStatus sharedInstance] sendAppStatusCheckRequest:NO completeHandler:nil];
    //do analytics for application first run/started
    if ([[NSUserDefaults standardUserDefaults] integerForKey:@"NumTimesAppUsed"] == 0)
    {
        [StreetHawk sendLogForCode:LOG_CODE_APP_LAUNCH withComment:@"App first run"];
        [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"NumTimesAppUsed"];
    }
    else
    {
        [StreetHawk sendLogForCode:LOG_CODE_APP_LAUNCH withComment:@"App started and engine initialized"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    //check time zone and register for later change
    [self checkUtcOffsetUpdate];
    //check current build include which modules and send tags.
    [self sendModuleTags];
    //setup intercept app delegate
    if (self.autoIntegrateAppDelegate)
    {
        self.appDelegateInterceptor = [[SHInterceptor alloc] init];  //strong property
        self.appDelegateInterceptor.firstResponder = self;  //weak property
        self.appDelegateInterceptor.secondResponder = [UIApplication sharedApplication].delegate;
        self.originalAppDelegate = [UIApplication sharedApplication].delegate;  //must use a strong property to keep original AppDelegate, otherwise after next set to interceptor, original AppDelegate is null and cannot do StreetHawk first then forward to original AppDelegate.
        [UIApplication sharedApplication].delegate = (id<UIApplicationDelegate>)self.appDelegateInterceptor;
    }
}

- (void)registerInstallForApp:(NSString *)appKey withDebugMode:(BOOL)isDebugMode withiTunesId:(NSString *)iTunesId
{
    StreetHawk.itunesAppId = iTunesId;
    [StreetHawk registerInstallForApp:appKey withDebugMode:isDebugMode];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.currentInstall = nil;
}

#pragma mark - properties

- (NSString *)appKey
{
    if (shStrIsEmpty(_appKey))  //not call register yet try to read from local cache
    {
        _appKey = [[NSUserDefaults standardUserDefaults] objectForKey:APPKEY_KEY];
    }
    return _appKey;
}

- (void)setDefaultStartingUrl:(NSString *)defaultUrl
{
    [SHAppStatus sharedInstance].defaultHost = defaultUrl;
}

- (NSString *)itunesAppId
{
    return [SHAppStatus sharedInstance].appstoreId;
}

- (void)setItunesAppId:(NSString *)itunesAppId
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        [SHAppStatus sharedInstance].appstoreId = itunesAppId;
    });
}

- (NSString *)clientVersion
{
    return [NSString stringWithFormat:@"%@ (%@)", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"]];
}

- (NSString *)version
{
    //Framework version is upgraded by StreetHawkCore-Info.plist and StreetHawkCoreRes-Info.plist, but the version number is not accessible by code. StreetHawkCore-Info.plist is built as binrary in main App, StreetHawkCoreRes-Info.plist may be contained in main App but not guranteed. To make sure this version work, add a method with hard-coded version number.
    //Format: X.Y.Z, make sure X and Y and Z are from >= 0  and < 1000.
    return @"1.7.4";
}

- (SHInstall *)currentInstall
{
    if (_currentInstall == nil)
    {
        NSString *savedInstallId = [[NSUserDefaults standardUserDefaults] objectForKey:INSTALL_SUID_KEY];
        if (savedInstallId != nil && savedInstallId.length > 0)
        {
            _currentInstall = [[SHInstall alloc] initWithSuid:savedInstallId];
        }
    }
    return _currentInstall;
}

- (void)setCurrentInstall:(SHInstall *)currentInstall
{
    if (_currentInstall == nil || ![_currentInstall isEqual:currentInstall])
    {
        _currentInstall = currentInstall;
        //cache install id locally
        [[NSUserDefaults standardUserDefaults] setObject:(_currentInstall!=nil) ? _currentInstall.suid : @""/*if install is invalid, need to clear local cache*/ forKey:INSTALL_SUID_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (SHDevelopmentPlatform)developmentPlatform
{
    return SHDevelopmentPlatform_Native; //hard code, when distribute change for each platform.
}

- (SHLogger *)logger
{
    return self.innerLogger;
}

#pragma mark - public functions

- (BOOL)shCustomActivityList:(NSArray *)arrayFriendlyNameObj
{
    if (!streetHawkIsEnabled())
    {
        return NO;
    }
    //clean and save a whole new one.
    NSMutableArray *arrayFriendlyNames = [NSMutableArray array];
    for (SHFriendlyNameObject *obj in arrayFriendlyNameObj)
    {
        NSAssert(obj.friendlyName != nil && obj.friendlyName.length > 0 && obj.friendlyName.length < 150 && [obj.friendlyName rangeOfString:@":"].location == NSNotFound, @"Wrong format for friendly name %@.", obj.friendlyName);
        if (!(obj.friendlyName != nil && obj.friendlyName.length > 0 && obj.friendlyName.length < 150 && [obj.friendlyName rangeOfString:@":"].location == NSNotFound))
        {
            SHLog(@"Wrong format for friendly name %@.", obj.friendlyName);
            return NO;
        }
        NSAssert(obj.vc != nil && obj.vc.length > 0, @"Wrong format for vc %@.", obj.vc);
        if (!(obj.vc != nil && obj.vc.length > 0))
        {
            SHLog(@"Wrong format for vc %@.", obj.vc);
            return NO;
        }
        //Not check vc must be subclass of UIViewController because Phonegap submit html page name as vc.
        //        Class vcClass = NSClassFromString(obj.vc);
        //        NSAssert([vcClass isSubclassOfClass:[UIViewController class]], @"vc is not a subclass of UIViewController: %@.", obj.vc);
        //        if (![vcClass isSubclassOfClass:[UIViewController class]])
        //        {
        //            SHLog(@"vc is not a subclass of UIViewController %@.", obj.vc);
        //            return NO;
        //        }
        NSMutableDictionary *dictFriendlyName = [NSMutableDictionary dictionary];
        dictFriendlyName[FRIENDLYNAME_NAME] = obj.friendlyName;
        dictFriendlyName[FRIENDLYNAME_VC] = obj.vc;
        if (obj.xib_iphone != nil && obj.xib_iphone.length > 0)
        {
            dictFriendlyName[FRIENDLYNAME_XIB_IPHONE] = obj.xib_iphone;
        }
        if (obj.xib_ipad != nil && obj.xib_ipad.length > 0)
        {
            dictFriendlyName[FRIENDLYNAME_XIB_IPAD] = obj.xib_ipad;
        }
        [arrayFriendlyNames addObject:dictFriendlyName];
    }
    [[NSUserDefaults standardUserDefaults] setObject:arrayFriendlyNames forKey:FRIENDLYNAME_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
    //Following should NOT trigger on an Apple Store version, it should ONLY happen on debug.
    if (StreetHawk.isDebugMode && shAppMode() != SHAppMode_AppStore && shAppMode() != SHAppMode_Enterprise /*Some customer always set debug mode = YES, but AppStore version should not always send friendly names*/
        && ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)/*avoid send when App wake up in background. Here cannot use Active, its status is InActive for normal launch, Background for location launch.*/)
    {
        //In debug mode, each "shCustomActivityList" do submit regardless "submit_views"; in production mode, only submit when "submit_views"=true. https://bitbucket.org/shawk/streethawk/issue/275/submit_views-is-disabled-in-api-dev
        //By doing this, SDK user won't feel inconvenient when debugging App, because friendly names submitted without any condition; final release won't submit useless request (actually final release won't submit any request, because debug mode fill that client_version).
        [self submitFriendlyNames];
    }
    return YES;
}

- (void)shFeedback:(NSArray *)arrayChoice needInputDialog:(BOOL)needInput needConfirmDialog:(BOOL)needConfirm withTitle:(NSString *)infoTitle withMessage:(NSString *)infoMessage withPushData:(PushDataForApplication *)pushData
{
    if (!streetHawkIsEnabled())
    {
        return;
    }
    [[SHFeedbackQueue shared] addFeedback:arrayChoice needInputDialog:needInput needConfirmDialog:needConfirm withTitle:infoTitle withMessage:infoMessage withPushData:pushData];
}

- (void)shSendFeedbackWithTitle:(NSString *)title withContent:(NSString *)content withHandler:(SHCallbackHandler)handler
{
    if (!streetHawkIsEnabled())
    {
        return;
    }
    [[SHFeedbackQueue shared] submitFeedbackForTitle:title withType:0/*discussed: this is not used now*/ withContent:content withPushData:nil withShowError:NO withHandler:handler];
}

- (void)shNotifyPageEnter:(NSString *)page
{
    //These checks applies to normal customer App calls. However even the check fail it only throw assert in Debug (not happen in official release), and not stop send 8108 log.
    NSAssert(page != nil && page.length > 0, @"Try to enter a page without page name.");
    //When App wake up by location service, App is in background but home vc is created and viewDidAppear called! It cause a mistake enter log sent. This is wrong because user not launch App yet. At this time send exit log for previous if has (maybe crashed on another page) and put home vc at history. Next App to FG will send enter for home vc from history.
    //Additional comments for location service:
    //a) if App in FG and restart device, not wake up App because FG uses significant location change. In this case because App not wake up it runs as normal.
    //b) if App in BG and restart device, App is wake up.
    BOOL sendEnter = ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground); //Test: manual launch state is Active, location launch is Background.
    [self shNotifyPageEnter:page sendEnter:sendEnter sendExit:YES/*for normal App calls, if history has enter first send exit log*/];
}

- (void)shNotifyPageExit:(NSString *)page
{
    //These checks applies to normal customer App calls. However even the check fail it only throw assert in Debug (not happen in official release), and not stop send 8109 log.
    NSAssert(page != nil && page.length > 0, @"Try to exit a page without page name.");
    if (page != nil && page.length > 0)
    {
        //Exit page name should match history traced enter page name.
        page = [SHFriendlyNameObject tryFriendlyName:page];  //friendly name is used in notification scenario
        NSString *enterPage = [[NSUserDefaults standardUserDefaults] objectForKey:ENTER_PAGE_HISTORY]; //ENTER_PAGE_HISTORY is setup in viewDidAppear, normally it's called but one exception is canceled pop up, which only call viewWillAppear but not call viewDidAppear.
        //https://bitbucket.org/shawk/streethawk/issue/627/testfest1-assert-exit-page
        if (enterPage == nil || enterPage.length == 0) //in canceled pop up viewWillAppear called but viewDidAppear not called, use backup enter.
        {
            enterPage = [[NSUserDefaults standardUserDefaults] objectForKey:ENTERBAK_PAGE_HISTORY];
            enterPage = [SHFriendlyNameObject tryFriendlyName:enterPage]; //viewWillAppear record class vc, try using friendly name if have. Friendly name is used in notification scenario.
            if (enterPage != nil && enterPage.length > 0)
            {
                //Add enter logline too, as it's missing due to viewDidAppear not called in this case.
                [self shNotifyPageEnter:enterPage];
            }
        }
        NSAssert([page compare:enterPage options:NSCaseInsensitiveSearch] == NSOrderedSame, @"Exit page (%@) mismatch enter page (%@).", page, enterPage);
    }
    //Send log even if check fail. If page is nil will use history, although not recommend normal App to do this.
    [self shNotifyPageExit:page clearEnterHistory:YES/*for normal App calls, after exit clear history*/ logCompleteView:YES/*normal App call, this is manual exit a view so complete.*/];
}

- (void)shRegularTask:(void (^)(UIBackgroundFetchResult))completionHandler needComplete:(BOOL)needComplete
{
    BOOL needHeartbeatLog = YES;
    NSObject *lastPostHeartbeatLogsVal = [[NSUserDefaults standardUserDefaults] objectForKey:REGULAR_HEARTBEAT_LOGTIME];
    if (lastPostHeartbeatLogsVal != nil && [lastPostHeartbeatLogsVal isKindOfClass:[NSNumber class]])
    {
        NSTimeInterval lastPostHeartbeatLogs = [(NSNumber *)lastPostHeartbeatLogsVal doubleValue];
        if ([[NSDate date] timeIntervalSinceReferenceDate] - lastPostHeartbeatLogs < 6*60*60) //heartbeat time interval is 6 hours
        {
            needHeartbeatLog = NO;
        }
    }
#if defined(SH_FEATURE_LATLNG) || defined(SH_FEATURE_GEOFENCE) || defined(SH_FEATURE_IBEACON)
    if (needHeartbeatLog)
    {
        //Meet one crash when turn off air-plan mode after one night. At this time background fetch happen, but meantime location change happen due to network recover. Try to not do background task in this case to avoid crash. https://bitbucket.org/shawk/streethawk/issue/442/crash-background-fetch-exceed-time.
        NSTimeInterval recoverTime = 0;
        NSObject *recoverTimeValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"NETWORK_RECOVER_TIME"];
        if (recoverTimeValue != nil && [recoverTimeValue isKindOfClass:[NSNumber class]])
        {
            recoverTime = [(NSNumber *)recoverTimeValue doubleValue];
        }
        if (recoverTime == 0/*If reachability says it's not connected, not do heartbeat. It may be not accurate(https://bitbucket.org/shawk/streethawk/issue/443/not-send-request-if-network-unavailable), but in bad network status it's more possible to crash, and avoid crash is first priority.*/
            || [[NSDate date] timeIntervalSinceReferenceDate] - recoverTime < 3/*not just turn off air plan mode*/)
        {
            needHeartbeatLog = NO;
        }
    }
#endif
#ifdef SH_FEATURE_LATLNG
    BOOL needLocationLog = ([SHLocationManager locationServiceEnabledForApp:NO/*must allowed location already*/] && StreetHawk.locationManager.currentGeoLocation.latitude != 0 && StreetHawk.locationManager.currentGeoLocation.longitude != 0); //log current geo location if location service is enabled and already detect location.
    if (needLocationLog)
    {
        NSObject *lastPostLocationLogsVal = [[NSUserDefaults standardUserDefaults] objectForKey:REGULAR_LOCATION_LOGTIME];
        if (lastPostLocationLogsVal != nil && [lastPostLocationLogsVal isKindOfClass:[NSNumber class]])
        {
            NSTimeInterval lastPostLocationLogs = [(NSNumber *)lastPostLocationLogsVal doubleValue];
            if ([[NSDate date] timeIntervalSinceReferenceDate] - lastPostLocationLogs < 60*60) //more location time interval is 1 hour
            {
                needLocationLog = NO;
            }
        }
    }
#else
    BOOL needLocationLog = NO;
#endif
    if (!needHeartbeatLog && !needLocationLog) //nothing to do
    {
        if (needComplete && completionHandler != nil)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(UIBackgroundFetchResultNewData);
            });
        }
    }
    else if (needHeartbeatLog && needLocationLog)  //send both
    {
#ifdef SH_FEATURE_LATLNG
        NSDictionary *dictLoc = @{@"lat": @(StreetHawk.locationManager.currentGeoLocation.latitude), @"lng": @(StreetHawk.locationManager.currentGeoLocation.longitude)};
        [StreetHawk sendLogForCode:LOG_CODE_LOCATION_MORE withComment:shSerializeObjToJson(dictLoc)];
#endif
        [StreetHawk sendLogForCode:LOG_CODE_HEARTBEAT withComment:@"Heart beat." forAssocId:0 withResult:100/*ignore*/ withHandler:^(NSObject *result, NSError *error)
         {
             if (needComplete && completionHandler != nil)
             {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     completionHandler(UIBackgroundFetchResultNewData);
                 });
             }
         }];
    }
    else if (needHeartbeatLog)  //only send heart beat
    {
        [StreetHawk sendLogForCode:LOG_CODE_HEARTBEAT withComment:@"Heart beat." forAssocId:0 withResult:100/*ignore*/ withHandler:^(NSObject *result, NSError *error)
         {
             if (needComplete && completionHandler != nil)
             {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     completionHandler(UIBackgroundFetchResultNewData);
                 });
             }
         }];
    }
    else  //only send more location
    {
#ifdef SH_FEATURE_LATLNG
        NSDictionary *dictLoc = @{@"lat": @(StreetHawk.locationManager.currentGeoLocation.latitude), @"lng": @(StreetHawk.locationManager.currentGeoLocation.longitude)};
        [StreetHawk sendLogForCode:LOG_CODE_LOCATION_MORE withComment:shSerializeObjToJson(dictLoc) forAssocId:0 withResult:100/*ignore*/ withHandler:^(NSObject *result, NSError *error)
         {
             if (needComplete && completionHandler != nil)
             {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     completionHandler(UIBackgroundFetchResultNewData);
                 });
             }
         }];
#else
        if (needComplete && completionHandler != nil)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(UIBackgroundFetchResultNewData);
            });
        }
#endif
    }
}

- (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    BOOL handledBySDK = NO;
    if (StreetHawk.developmentPlatform == SHDevelopmentPlatform_Native || StreetHawk.developmentPlatform == SHDevelopmentPlatform_Xamarin)
    {
        NSString *command = url.host;
        if (command != nil && [command compare:@"launchvc" options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            SHDeepLinking *deepLinking = [[SHDeepLinking alloc] init];
            handledBySDK = [deepLinking launchDeepLinkingVC:url.absoluteString withPushData:nil increaseGrowthClick:YES];
            if (handledBySDK)
            {
                return YES; //launchvc deeplinking is handled by StreetHawk
            }
        }
    }
    if (!handledBySDK && StreetHawk.openUrlHandler != nil)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_GrowthBridge_Increase_Notification" object:nil userInfo:@{@"url": NONULL(url.absoluteString)}]; //send Growth increase request
        StreetHawk.openUrlHandler(url);
        return YES; //open url is handled by customer code.
    }
    return NO;
}

- (void)setAdvertisingIdentifier:(NSString *)advertisingIdentifier
{
    NSString *refinedAds = NONULL(advertisingIdentifier);
    if ([refinedAds compare:StreetHawk.advertisingIdentifier] != NSOrderedSame)
    {
        [StreetHawk tagString:refinedAds forKey:@"sh_advertising_identifier"];
        [[NSUserDefaults standardUserDefaults] setObject:refinedAds forKey:ADS_IDENTIFIER];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (NSString *)advertisingIdentifier
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:ADS_IDENTIFIER];
}

#pragma mark - permission

- (BOOL)launchSystemPreferenceSettings
{
    if (&UIApplicationOpenSettingsURLString != NULL)
    {
        NSURL *appSettings = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        [[UIApplication sharedApplication] openURL:appSettings];
        return YES;
    }
    else
    {
        return NO;
    }
}

#pragma mark - application system notification handler

//Good Apple doc for App states: https://developer.apple.com/library/ios/DOCUMENTATION/iPhone/Conceptual/iPhoneOSProgrammingGuide/ManagingYourApplicationsFlow/ManagingYourApplicationsFlow.html#//apple_ref/doc/uid/TP40007072-CH4.

//Called when user manually launch a not launched App.
//Called when remote or local notification happen.
//Called when location service wake up App and put App into background.
- (void)applicationDidFinishLaunchingNotificationHandler:(NSNotification *)notification
{
    if (self.isFinishLaunchOptionCalled)
    {
        return;
    }
    self.isFinishLaunchOptionCalled = YES;
    if (!streetHawkIsEnabled())
    {
        return;
    }
    NSDictionary *launchOptions = [notification userInfo];
    SHLog(@"Application did finish launching with launchOptions: %@", launchOptions);

    BOOL isFromDelayLaunch = [notification.name isEqualToString:@"StreetHawkDelayLaunchOptionsNotification"]; //in case from delay launch options, the remote delegate happens when app launch, and at that time StreetHawk delegate not ready, it's pass and cannot handle. Handle it again here.
    //Phonegap open url system delegate happen before StreetHawk library get ready, so `sh.shDeeplinking(function(result){alert("open url: " + result)},function(){});` not trigger when App not launch. Check delay launch options, if from open url, give it second chance to trigger again.
    if (isFromDelayLaunch)
    {
        NSURL *openUrl = launchOptions[UIApplicationLaunchOptionsURLKey];
        if (openUrl != nil)
        {
            [StreetHawk openURL:openUrl sourceApplication:nil annotation:nil];
        }
    }
    
#ifdef SH_FEATURE_LATLNG
    if (launchOptions[UIApplicationLaunchOptionsLocationKey] != nil)  //happen when significate location service wake up App, the value is a number such as 1
    {
        //To fix location service after phone power off/on.
        //After phone power on, register significate location service App is wake up, and applicationDidFinishLaunching is called.
        //In this situation, it stays in background, using significant location change.
        [self.locationManager startMonitorGeoLocationStandard:NO];
    }
#endif
    
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)/*avoid send visible log when App wake up in background. Here cannot use Active, its status is InActive for normal launch, Background for location launch.*/
    {
        NSMutableDictionary *dictComment = [NSMutableDictionary dictionary];
        [dictComment setObject:@"App launch from not running." forKey:@"action"];
#ifdef SH_FEATURE_LATLNG
        if (StreetHawk.locationManager.currentGeoLocation.latitude != 0 && StreetHawk.locationManager.currentGeoLocation.longitude != 0)
        {
            [dictComment setObject:@(StreetHawk.locationManager.currentGeoLocation.latitude) forKey:@"lat"];
            [dictComment setObject:@(StreetHawk.locationManager.currentGeoLocation.longitude) forKey:@"lng"];
        }
#endif
        [StreetHawk sendLogForCode:LOG_CODE_APP_VISIBLE withComment:shSerializeObjToJson(dictComment)];
    }

    if ([[UIApplication sharedApplication] respondsToSelector:@selector(setMinimumBackgroundFetchInterval:)]) //available since 7.0
    {
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:30*60/*perform background fetch in half an hour to increase chance*/];
    }
    
    if (StreetHawk.developmentPlatform == SHDevelopmentPlatform_Native && StreetHawk.isDebugMode && shAppMode() != SHAppMode_AppStore && shAppMode() != SHAppMode_Enterprise && ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground))  //In debug mode, not live for AppStore, not in background wake up (either by location with option has location key, or by background fetch with optional is nil), check current version and StreetHawk's latest version. Print log if current not the latest version.
    {
        SHRequest *requestCheckVersion = [SHRequest requestWithPath:@"core/library/" withParams:@[@"operating_system", @"ios", @"development_platform", shDevelopmentPlatformString()]];
        requestCheckVersion.requestHandler = ^(SHRequest *request)
        {
            if (request.error == nil && request.resultCode == 0)
            {
                NSString *serverVersion = (NSString *)request.resultValue;  //it's supposed to be @"1/1.3.2" or @"1.3.2".
                NSAssert(serverVersion != nil && [serverVersion isKindOfClass:[NSString class]] && serverVersion.length >= StreetHawk.version.length, @"Fail to get server's sh_version. %@.", serverVersion);
                if (serverVersion != nil && [serverVersion isKindOfClass:[NSString class]] && serverVersion.length >= StreetHawk.version.length)
                {
                    if ([serverVersion compare:StreetHawk.version/*like 1.3.2*/ options:NSCaseInsensitiveSearch range:NSMakeRange(serverVersion.length - StreetHawk.version.length, StreetHawk.version.length)] != NSOrderedSame)
                    {
                        SHLog(@"INFO: A newer version of the StreetHawk Library is available: %@.", serverVersion);
                    }
                }
            }
        };
        [requestCheckVersion startAsynchronously];
    }
}

//Called when click home button to background App.
//Called when App is open and lock screen.
//Called when phone comes or other interruptions.
//Called when asking permission of location service.
- (void)applicationWillResignActiveNotificationHandler:(NSNotification *)notification
{
    if (!streetHawkIsEnabled())
    {
        return;
    }
    SHLog(@"Application will resignActive with info: %@.", notification.userInfo);
}

//Called when click home button to background App.
//Called when App is open and lock screen.
//Not called when phone comes or other interruptions.
//Not called when App is not launched, wake up by location service and enter background.
- (void)applicationDidEnterBackgroundNotificationHandler:(NSNotification *)notification
{
    if (!streetHawkIsEnabled())
    {
        return;
    }
    SHLog(@"Application did enter background with info: %@", notification.userInfo);
#ifdef SH_FEATURE_LATLNG
    [self.locationManager startMonitorGeoLocationStandard:NO];
#endif
    //Go to BG, send exit log.
    [StreetHawk shNotifyPageExit:nil/*for send exit log, not really go to new page*/ clearEnterHistory:NO/*keep history for go to FG send enter*/ logCompleteView:YES/*enter BG complete as bg=true*/];
    //Send install/log when enter background, begin a background task to gain 10 minutes to finish this.
    __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^
    {
        [self endBackgroundTask:backgroundTask];
    }];
    __block NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^
    {
        if (!op.isCancelled)
        {
            NSMutableDictionary *dictComment = [NSMutableDictionary dictionary];
            [dictComment setObject:@"App to BG." forKey:@"action"];
#ifdef SH_FEATURE_LATLNG
            if (StreetHawk.locationManager.currentGeoLocation.latitude != 0 && StreetHawk.locationManager.currentGeoLocation.longitude != 0)
            {
                [dictComment setObject:@(StreetHawk.locationManager.currentGeoLocation.latitude) forKey:@"lat"];
                [dictComment setObject:@(StreetHawk.locationManager.currentGeoLocation.longitude) forKey:@"lng"];
            }
#endif
            [StreetHawk sendLogForCode:LOG_CODE_APP_INVISIBLE withComment:shSerializeObjToJson(dictComment) forAssocId:0 withResult:100/*ignore*/ withHandler:^(id result, NSError *error)
            {
                //Once start not cancel the install/log request, there are 10 minutes so make sure it can finish. Call endBackgroundTask after it's done.
                [self endBackgroundTask:backgroundTask];
            }];
        }
        else
        {
            [self endBackgroundTask:backgroundTask];
        }
    }];
    [self.backgroundQueue addOperation:op];
}

//Pair with applicationDidEnterBackground
//Called when App is in background and manual click to go foreground.
//Called when App is open and screen locked, unlock the screen.
//Not called when App is not launched, manually click to open App. This is different from applicationDidBecomeActive.
//Not called when App is open and phone ends or control center dismiss, as applicationDidEnterBackground is not called wither.
//Called when App is not launched, wake up by location service and enter background (not called), later click to manual launch this is called. -- a little not pair with applicationDidEnterBackground because that is not called.
- (void)applicationWillEnterForegroundNotificationHandler:(NSNotification *)notification
{
    if (!streetHawkIsEnabled())
    {
        return;
    }
    SHLog(@"Application will enter foreground with info: %@", notification.userInfo);
    
    //Log here instead of applicationDidBecomeActive when interrupt by phone or permission dialog or control center or notification center, this is not called.
    NSMutableDictionary *dictComment = [NSMutableDictionary dictionary];
    [dictComment setObject:@"App opened from BG." forKey:@"action"];
#ifdef SH_FEATURE_LATLNG
    if (StreetHawk.locationManager.currentGeoLocation.latitude != 0 && StreetHawk.locationManager.currentGeoLocation.longitude != 0)
    {
        [dictComment setObject:@(StreetHawk.locationManager.currentGeoLocation.latitude) forKey:@"lat"];
        [dictComment setObject:@(StreetHawk.locationManager.currentGeoLocation.longitude) forKey:@"lng"];
    }
#endif
    [StreetHawk sendLogForCode:LOG_CODE_APP_VISIBLE withComment:shSerializeObjToJson(dictComment)];
    [StreetHawk shNotifyPageEnter:nil/*not know previoius page, but can get from history*/ sendEnter:YES sendExit:NO/*Not send exit for App go to FG*/];
}

//Pair with applicationWillResignActive
//Called when App is in background and manual click to go foreground.
//Called when App is open and screen locked, unlock the screen.
//Called when phone comes or other interruptions such as control center end.
//Called when App is not launched, manually click to open App. This is different from applicationWillEnterForeground.
//Called when App is not launched, wake up by location service and enter background.
//Called when dismiss asking permission of location service.
- (void)applicationDidBecomeActiveNotificationHandler:(NSNotification *)notification
{
    //check app status from background to foreground, most actually return because of "one day not call" limitation.
    [[SHAppStatus sharedInstance] sendAppStatusCheckRequest:NO completeHandler:nil];  //a chance to check if sdk was disabled, may be able to wake up again. Choose this instead of applicationWillEnterForeground because this is also called when App not launched, manually click to open.
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_SetBadge_Notification" object:nil userInfo:@{@"badge": @(0)}]; //clear badge when App open, for some user they don't like this number and would like to launch App to dismiss it.
    if (!streetHawkIsEnabled())
    {
        return;
    }
    SHLog(@"Application did become active with info: %@", notification.userInfo);
    
    //start location services in FG so we get a better lock on location
#ifdef SH_FEATURE_LATLNG
    [self.locationManager startMonitorGeoLocationStandard:!StreetHawk.reportWorkHomeLocationOnly];
#endif
    if (self.currentInstall != nil)
    {
        //each time when App go to foreground, check push message situation. user can disable App's push message when App is in background, so this is the time to check. Only do it when currentInstall!=nil, because if currentInstall==nil, next will call register install, and that will trigger registerForRemoteNotification.
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_Register_Notification" object:nil];
        if ([self checkInstallChangeForLaunch] //check whether App or device attribute change, tricky: this must be first, as it sends client upgrade logline. If move to later, self.currentInstall.appKey is always nil when fresh launch, and correct sent client version, so no chance to send the logline.
            || self.currentInstall.appKey == nil || self.currentInstall.appKey.length == 0) //check install attribute is filled, to make sure later visit currentInstall has correct value, meantime fix crash report submitted immediately after App launch
        {
            [self registerOrUpdateInstallWithHandler:nil];
        }
    }
    else
    {
        //call install register here. If previous App is offline, now open App and should refresh install. It also fixed install id not get immediately if location service denied.
        [self registerOrUpdateInstallWithHandler:nil];
    }
    //check when App is active
    [self shRegularTask:nil needComplete:NO];
    //check smart push
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_Smart_Notification" object:nil];
}

- (void)applicationWillTerminateNotificationHandler:(NSNotification *)notification
{
    if (!streetHawkIsEnabled())
    {
        return;
    }
    SHLog(@"Application will terminate with info: %@", notification.userInfo);
    //When open App it's active and use standard location service. At this time when power phone off/on, standard location service cannot wake up App.
    //By testing applicationWillTerminate is called in this situation, and it's a chance to switch to significate location service.
#ifdef SH_FEATURE_LATLNG
    [self.locationManager startMonitorGeoLocationStandard:NO];
#endif
    //Same as go to BG, send exit log.
    [StreetHawk shNotifyPageExit:nil/*for send exit log, not really go to new page*/ clearEnterHistory:NO/*keep history for go to FG send enter*/ logCompleteView:YES/*enter BG complete as bg=true*/];
}

- (void)applicationDidReceiveMemoryWarningNotificationHandler:(NSNotification *)notification
{
    if (!streetHawkIsEnabled())
    {
        return;
    }
    SHLog(@"StreetHawk Received memory warning");
}

- (void)appStatusChange:(NSNotification *)notification
{
    if ([SHAppStatus sharedInstance].allowSubmitFriendlyNames)
    {
        [self submitFriendlyNames];
    }
}

- (void)timeZoneChangeNotificationHandler:(NSNotification *)notification
{
    [self checkUtcOffsetUpdate];
}

#pragma mark - UIAppDelegate auto integration

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings  //since iOS 8.0
{
    NSMutableDictionary *dictUserInfo = [NSMutableDictionary dictionary];
    if (notificationSettings != nil)
    {
        dictUserInfo[@"notificationSettings"] = notificationSettings;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_DidRegisterUserNotification" object:nil userInfo:dictUserInfo];
    if ([self.appDelegateInterceptor.secondResponder respondsToSelector:@selector(application:didRegisterUserNotificationSettings:)])
    {
        [self.appDelegateInterceptor.secondResponder application:application didRegisterUserNotificationSettings:notificationSettings];
    }
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSMutableDictionary *dictUserInfo = [NSMutableDictionary dictionary];
    if (deviceToken != nil)
    {
        dictUserInfo[@"token"] = deviceToken;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_ReceiveToken_Notification" object:nil userInfo:dictUserInfo];
    if ([self.appDelegateInterceptor.secondResponder respondsToSelector:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)])
    {
        [self.appDelegateInterceptor.secondResponder application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    }
}

//called when notification arrives and:
//1. App in FG, directly call this.
//2. App in BG notification banner show, click the banner (not the button) and call this.
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    //Because StreetHawk take over didReceiveRemoteNotification, customer's AppDelegate may have one to call, do that first as this will call completeHandler.
    if ([self.appDelegateInterceptor.secondResponder respondsToSelector:@selector(application:didReceiveRemoteNotification:)]) //give it a chance to call
    {
        [self.appDelegateInterceptor.secondResponder application:application didReceiveRemoteNotification:userInfo];
    }
    BOOL customerAppResponse = [self.appDelegateInterceptor.secondResponder respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)];
    NSMutableDictionary *dictUserInfo = [NSMutableDictionary dictionary];
    if (userInfo != nil)
    {
        dictUserInfo[@"payload"] = userInfo;
    }
    dictUserInfo[@"fgbg"] = @(SHAppFGBG_Unknown);
    dictUserInfo[@"needComplete"] = @(!customerAppResponse);
    if (completionHandler)
    {
        dictUserInfo[@"fetchCompletionHandler"] = completionHandler;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_ReceiveRemoteNotification" object:nil userInfo:dictUserInfo];
    if (customerAppResponse)
    {
        [self.appDelegateInterceptor.secondResponder application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
    }
}

//called when notification arrives and:
//1. App in BG notification bannder show, pull down and click the button can call this.
//2. NOT called when App in FG.
//3. NOT called when click notification banner directly.
//This delegate callback not mixed with above `didReceiveRemoteNotification`.
- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())completionHandler
{
    BOOL customerAppResponse = [self.appDelegateInterceptor.secondResponder respondsToSelector:@selector(application:handleActionWithIdentifier:forRemoteNotification:completionHandler:)];
    NSMutableDictionary *dictUserInfo = [NSMutableDictionary dictionary];
    if (userInfo != nil)
    {
        dictUserInfo[@"payload"] = userInfo;
    }
    if (identifier != nil)
    {
        dictUserInfo[@"actionid"] = identifier;
    }
    dictUserInfo[@"needComplete"] = @(!customerAppResponse)/*if customer needs, not complete in StreetHawk call but let customer AppDelegate to end it*/;
    if (completionHandler)
    {
        dictUserInfo[@"completionHandler"] = completionHandler;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_HandleRemoteActionButton" object:nil userInfo:dictUserInfo];
    if (customerAppResponse)
    {
        [self.appDelegateInterceptor.secondResponder application:application handleActionWithIdentifier:identifier forRemoteNotification:userInfo completionHandler:completionHandler];
    }
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    NSMutableDictionary *dictUserInfo = [NSMutableDictionary dictionary];
    if (notification != nil)
    {
        dictUserInfo[@"notification"] = notification;
    }
    dictUserInfo[@"fgbg"] = @(SHAppFGBG_Unknown);
    dictUserInfo[@"needComplete"] = @(YES);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_ReceiveLocalNotification" object:nil userInfo:dictUserInfo];
    if ([self.appDelegateInterceptor.secondResponder respondsToSelector:@selector(application:didReceiveLocalNotification:)])
    {
        [self.appDelegateInterceptor.secondResponder application:application didReceiveLocalNotification:notification];
    }
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler
{
    BOOL customerAppResponse = [self.appDelegateInterceptor.secondResponder respondsToSelector:@selector(application:handleActionWithIdentifier:forLocalNotification:completionHandler:)];
    NSMutableDictionary *dictUserInfo = [NSMutableDictionary dictionary];
    if (notification != nil)
    {
        dictUserInfo[@"notification"] = notification;
    }
    if (identifier != nil)
    {
        dictUserInfo[@"actionid"] = identifier;
    }
    dictUserInfo[@"needComplete"] = @(!customerAppResponse)/*if customer needs, not complete in StreetHawk call but let customer AppDelegate to end it*/;
    if (completionHandler)
    {
        dictUserInfo[@"completionHandler"] = completionHandler;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SH_PushBridge_HandleLocalActionButton" object:nil userInfo:dictUserInfo];
    if (customerAppResponse)
    {
        [self.appDelegateInterceptor.secondResponder application:application handleActionWithIdentifier:identifier forLocalNotification:notification completionHandler:completionHandler];
    }
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    BOOL customerAppResponse = [self.appDelegateInterceptor.secondResponder respondsToSelector:@selector(application:performFetchWithCompletionHandler:)];
    [StreetHawk shRegularTask:completionHandler needComplete:!customerAppResponse];
    if (customerAppResponse)
    {
        [self.appDelegateInterceptor.secondResponder application:application performFetchWithCompletionHandler:completionHandler];
    }
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([self.appDelegateInterceptor.secondResponder respondsToSelector:@selector(application:openURL:sourceApplication:annotation:)])
    {
        if ([self.appDelegateInterceptor.secondResponder application:application openURL:url sourceApplication:sourceApplication annotation:annotation])
        {
            if (StreetHawk.developmentPlatform != SHDevelopmentPlatform_Phonegap) //Phonegap has openURL function implemented, but iOS plugin still implement shDeepLinking to keep consistence with Android. https://bitbucket.org/shawk/streethawk/issue/587/handle-open-url-in-phonegap.
            {
                return YES;
            }
        }
    }
    if ([self.appDelegateInterceptor.secondResponder respondsToSelector:@selector(application:handleOpenURL:)]) //try old style handle
    {
        if ([self.appDelegateInterceptor.secondResponder application:application handleOpenURL:url])
        {
            return YES;
        }
    }
    //If custom App cannot handle it, try StreetHawk's.
    return [StreetHawk openURL:url sourceApplication:sourceApplication annotation:annotation];
}

#pragma mark - private functions

- (void)setupNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunchingNotificationHandler:) name:UIApplicationDidFinishLaunchingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunchingNotificationHandler:) name:@"StreetHawkDelayLaunchOptionsNotification" object:nil]; //handle both direct send and delay send
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActiveNotificationHandler:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackgroundNotificationHandler:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForegroundNotificationHandler:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActiveNotificationHandler:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminateNotificationHandler:) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidReceiveMemoryWarningNotificationHandler:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(timeZoneChangeNotificationHandler:) name:UIApplicationSignificantTimeChangeNotification object:nil];
    //disable warning as this selector is defined in sub-module category.
#pragma GCC diagnostic push
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appStatusChange:) name:SHAppStatusChangeNotification object:nil];
#ifdef SH_FEATURE_CRASH
    self.isSendingCrashReport = NO;  //must use `self` instead of `StreetHawk` as this is called in `init`.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installUpdateSucceededForCrash:) name:SHInstallUpdateSuccessNotification object:nil];
#endif
#pragma GCC diagnostic pop
#pragma clang diagnostic pop
}

- (void)checkUtcOffsetUpdate
{
    //Not check ![SHAppStatus sharedInstance].streethawkEnabled here because: 1. it's invisible to user; 2. If this time not update, it will not happen again.
    NSInteger offset = [[NSTimeZone localTimeZone] secondsFromGMT];
    BOOL needUpdateUtcOffset = YES;
    NSObject *utcoffsetVal = [[NSUserDefaults standardUserDefaults] objectForKey:SETTING_UTC_OFFSET];
    if (utcoffsetVal != nil && [utcoffsetVal isKindOfClass:[NSNumber class]])
    {
        int utcOffsetLocal = [(NSNumber *)utcoffsetVal intValue];
        if (utcOffsetLocal == offset / 60)
        {
            needUpdateUtcOffset = NO;
        }
    }
    if (needUpdateUtcOffset)
    {
        __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^
         {
             [self endBackgroundTask:backgroundTask];
         }];
        __block NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^
        {
            if (!op.isCancelled)
            {
                [StreetHawk sendLogForCode:LOG_CODE_TIMEOFFSET withComment:[NSString stringWithFormat:@"%ld", (long)offset/60] forAssocId:0 withResult:100/*ignore*/ withHandler:^(id result, NSError *error)
                 {
                     [[NSUserDefaults standardUserDefaults] setObject:@(offset/60) forKey:SETTING_UTC_OFFSET];
                     [[NSUserDefaults standardUserDefaults] synchronize];
                     [self endBackgroundTask:backgroundTask];
                 }];
            }
            else
            {
                [self endBackgroundTask:backgroundTask];
            }
        }];
        [self.backgroundQueue addOperation:op];
    }
}

- (void)sendModuleTags
{
    if (StreetHawk.developmentPlatform == SHDevelopmentPlatform_Native || StreetHawk.developmentPlatform == SHDevelopmentPlatform_Phonegap || StreetHawk.developmentPlatform == SHDevelopmentPlatform_Xamarin) //all these can reflect bridge class.
    {
        Class growthBridge = NSClassFromString(@"SHGrowthBridge");
        NSString *growthCurrent = (growthBridge == nil) ? @"false" : @"true";
        NSString *growthSent = [[NSUserDefaults standardUserDefaults] objectForKey:@"sh_module_growth"];
        if ([growthCurrent compare:growthSent] != NSOrderedSame)
        {
            [StreetHawk tagString:growthCurrent forKey:@"sh_module_growth"];
            [[NSUserDefaults standardUserDefaults] setObject:growthCurrent forKey:@"sh_module_growth"];
        }
        Class notificationBridge = NSClassFromString(@"SHNotificationBridge");
        NSString *pushCurrent = (notificationBridge == nil) ? @"false" : @"true";
        NSString *pushSent = [[NSUserDefaults standardUserDefaults] objectForKey:@"sh_module_push"];
        if ([pushCurrent compare:pushSent] != NSOrderedSame)
        {
            [StreetHawk tagString:pushCurrent forKey:@"sh_module_push"];
            [[NSUserDefaults standardUserDefaults] setObject:pushCurrent forKey:@"sh_module_push"];
        }
        NSString *locationCurrent = nil;
#ifdef SH_FEATURE_LATLNG
        locationCurrent = @"true";
#else
        locationCurrent = @"false";
#endif
        NSString *locationSent = [[NSUserDefaults standardUserDefaults] objectForKey:@"sh_module_location"];
        if ([locationCurrent compare:locationSent] != NSOrderedSame)
        {
            [StreetHawk tagString:locationCurrent forKey:@"sh_module_location"];
            [[NSUserDefaults standardUserDefaults] setObject:locationCurrent forKey:@"sh_module_location"];
        }
        NSString *geofenceCurrent = nil;
#ifdef SH_FEATURE_GEOFENCE
        geofenceCurrent = @"true";
#else
        geofenceCurrent = @"false";
#endif
        NSString *geofenceSent = [[NSUserDefaults standardUserDefaults] objectForKey:@"sh_module_geofence"];
        if ([geofenceCurrent compare:geofenceSent] != NSOrderedSame)
        {
            [StreetHawk tagString:geofenceCurrent forKey:@"sh_module_geofence"];
            [[NSUserDefaults standardUserDefaults] setObject:geofenceCurrent forKey:@"sh_module_geofence"];
        }
        NSString *iBeaconCurrent = nil;
#ifdef SH_FEATURE_IBEACON
        iBeaconCurrent = @"true";
#else
        iBeaconCurrent = @"false";
#endif
        NSString *iBeaconSent = [[NSUserDefaults standardUserDefaults] objectForKey:@"sh_module_beacon"];
        if ([iBeaconCurrent compare:iBeaconSent] != NSOrderedSame)
        {
            [StreetHawk tagString:iBeaconCurrent forKey:@"sh_module_beacon"];
            [[NSUserDefaults standardUserDefaults] setObject:iBeaconCurrent forKey:@"sh_module_beacon"];
        }
        NSString *crashCurrent = nil;
#ifdef SH_FEATURE_CRASH
        crashCurrent = @"true";
#else
        crashCurrent = @"false";
#endif
        NSString *crashSent = [[NSUserDefaults standardUserDefaults] objectForKey:@"sh_module_crash"];
        if ([crashCurrent compare:crashSent] != NSOrderedSame)
        {
            [StreetHawk tagString:crashCurrent forKey:@"sh_module_crash"];
            [[NSUserDefaults standardUserDefaults] setObject:crashCurrent forKey:@"sh_module_crash"];
        }
        NSString *feedsCurrent = nil;
#ifdef SH_FEATURE_FEED
        feedsCurrent = @"true";
#else
        feedsCurrent = @"false";
#endif
        NSString *feedsSent = [[NSUserDefaults standardUserDefaults] objectForKey:@"sh_module_feeds"];
        if ([feedsCurrent compare:feedsSent] != NSOrderedSame)
        {
            [StreetHawk tagString:feedsCurrent forKey:@"sh_module_feeds"];
            [[NSUserDefaults standardUserDefaults] setObject:feedsCurrent forKey:@"sh_module_feeds"];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    //other cross platform will be add when implement them.
}

- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)backgroundTask
{
    [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
    backgroundTask = UIBackgroundTaskInvalid;
}

- (void)shNotifyPageEnter:(NSString *)page sendEnter:(BOOL)doEnter sendExit:(BOOL)doExit
{
    if (page == nil || page.length == 0)
    {
        NSAssert(doEnter, @"Enter without page should used for App go to FG only, with doEnter = YES");
        NSAssert(!doExit, @"Enter without page should used for App go to FG only, with doExit = NO");
        page = [[NSUserDefaults standardUserDefaults] objectForKey:ENTER_PAGE_HISTORY]; //for App go FG and log enter
    }
    if (doExit)
    {
        //First check whether need to send 8109 for exit previous page
        NSString *previousEnterPage = [[NSUserDefaults standardUserDefaults] objectForKey:ENTER_PAGE_HISTORY];
        if (previousEnterPage != nil && previousEnterPage.length > 0) //Not check it's not same as "page". For example, stay FG at homepage and App killed, enter history has homepage, exit history is empty. Next launch is homepage. So sends homepage exit first to match previous enter, and sends homepage enter again.
        {
            NSString *previousExitPage = [[NSUserDefaults standardUserDefaults] objectForKey:EXIT_PAGE_HISTORY];
            BOOL multipleBGTerminal = NO;
            //Case like this: 1)App stay in page C and BG, enter history=C, exit history=C. 2)App terminated in BG, launch again. Homepage A's viewDidAppear called, it check enter history=C so try to send exit for C but stopped by exit history=C, no exit log sent, finally set enter history=A! (this enter will called as App go to FG) 3)Sadly, App in BG and terminated again, launch again. Homepage A's viewDidAppear called, this time enter history=A, exit history=C.
            //If not add this `multipleBGTerminal` to check, it will try to send exit, but NSAssert fail due to "try to exit A" but exit history=C.
            if ([previousEnterPage compare:page options:NSCaseInsensitiveSearch] == NSOrderedSame && previousExitPage != nil && previousExitPage.length > 0)
            {
                multipleBGTerminal = YES;
            }
            if (!multipleBGTerminal)
            {
                //Has a previous record, means it enters some page before. Send it as exit and clear it.
                [self shNotifyPageExit:previousEnterPage clearEnterHistory:YES logCompleteView:NO/*App crash and launch again, this cannot count as complete duration.*/];
            }
        }
    }
    //Second if page not nil, send 8108 for enter this page
    if (page != nil && page.length > 0)
    {
        //Check whether has friendly name for this page. If match sends friendly name instead of view class name.
        page = [SHFriendlyNameObject tryFriendlyName:page]; //friendly name is used in notification scenario
        if (doEnter)
        {
            [StreetHawk sendLogForCode:LOG_CODE_VIEW_ENTER withComment:page];
            self.currentView = [[SHViewActivity alloc] initWithViewName:page];
            //Clear exit history after send enter log, next exit log can send.
            [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:EXIT_PAGE_HISTORY];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        [[NSUserDefaults standardUserDefaults] setObject:page forKey:ENTER_PAGE_HISTORY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)shNotifyPageExit:(NSString *)page clearEnterHistory:(BOOL)needClear logCompleteView:(BOOL)logComplete
{
    BOOL isEnterBg = (page == nil || page.length == 0);
    if (page == nil || page.length == 0)
    {
        NSAssert(!needClear, @"Exit without page should used for App go to BG only, with needClear = NO");
        page = [[NSUserDefaults standardUserDefaults] objectForKey:ENTER_PAGE_HISTORY]; //for App go BG and log exit
    }
    NSAssert(page != nil && page.length > 0, @"Try to really exit a page without page name. Stop now.");
    if (page != nil && page.length > 0)
    {
        page = [SHFriendlyNameObject tryFriendlyName:page]; //friendly name is used in notification scenario
        //Check whether previous send exit for this page already. If already send ignore this. It happens when:
        //1. App at page C and go to BG, send exit C.
        //2. App killed at BG, re-launch it. Home page viewDidAppear and find enter history has C. It will try to send exit C, but should be ignored.
        NSString *previousExitPage = [[NSUserDefaults standardUserDefaults] objectForKey:EXIT_PAGE_HISTORY];
        if (previousExitPage != nil && previousExitPage.length > 0)
        {
            NSAssert([previousExitPage compare:page options:NSCaseInsensitiveSearch] == NSOrderedSame, @"Try to send exit page (%@) different from history (%@).", page, previousExitPage);
            if ([previousExitPage compare:page options:NSCaseInsensitiveSearch] == NSOrderedSame)
            {
                return; //ignore duplicated exit log
            }
        }
        [StreetHawk sendLogForCode:LOG_CODE_VIEW_EXIT withComment:page];
        if (logComplete)
        {
            NSAssert(self.currentView != nil && [self.currentView.viewName isEqualToString:page], @"When complete enter (%@) different from exit (%@).", self.currentView.viewName, page);
            if (self.currentView != nil && [self.currentView.viewName isEqualToString:page])
            {
                self.currentView.exitTime = [NSDate date];
                self.currentView.duration = [self.currentView.exitTime timeIntervalSinceDate:self.currentView.enterTime];
                self.currentView.enterBg = isEnterBg;
                [StreetHawk sendLogForCode:LOG_CODE_VIEW_COMPLETE withComment:[self.currentView serializeToString]];
            }
        }
        [[NSUserDefaults standardUserDefaults] setObject:page forKey:EXIT_PAGE_HISTORY]; //remember this.
        [[NSUserDefaults standardUserDefaults] synchronize];
        if (needClear)
        {
            [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:ENTER_PAGE_HISTORY];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
}

- (void)submitFriendlyNames
{
    if (!shStrIsEmpty(StreetHawk.currentInstall.suid))
    {
        //Read friendly name from local.
        NSArray *arrayFriendlyNames = [[NSUserDefaults standardUserDefaults] objectForKey:FRIENDLYNAME_KEY];
        NSMutableArray *arrayViews = [NSMutableArray array];
        for (NSDictionary *dict in arrayFriendlyNames)
        {
            NSString *friendlyName = dict[FRIENDLYNAME_NAME];
            if (![arrayViews containsObject:friendlyName])
            {
                [arrayViews addObject:friendlyName];
            }
            else
            {
                NSLog(@"WARNING: friendly name \"%@\" redefined. Please choose different names.", friendlyName);
            }
        }
        //If has friendly name to submit, do it.
        if (arrayViews.count > 0)
        {
            NSData *data = [NSJSONSerialization dataWithJSONObject:arrayViews options:0 error:nil];
            SHRequest *request = [SHRequest requestWithPath:@"/apps/submit_views/" withVersion:SHHostVersion_V1 withParams:nil withMethod:@"POST" withHeaders:nil withBodyOrStream:data]; //get by /apps/list_views
            request.requestHandler = ^(SHRequest *request)
            {
                if (request.error != nil)
                {
                    SHLog(@"Fail to submit friendly name: %@", request.error); //submit friendly name not show error dialog to bother customer.
                }
            };
            [request startAsynchronously];
        }
    }
}

- (void)checkAssert
{
    NSAssert(NO, @"Crash intentionally: NSAssert in SDK.");
    NSAssert1(NO, @"Crash intentionally: NSAssert1 in SDK: %@.", @"param1");
    NSAssert2(NO, @"Crash intentionally: NSAssert2 in SDK, %@, %@.", @"param1", @"param2");
    NSAssert3(NO, @"Crash intentionally: NSAssert3 in SDK, %@, %@, %@.", @"param1", @"param2", @"param3");
    NSAssert4(NO, @"Crash intentionally: NSAssert4 in SDK, %@, %@, %@, %@.", @"param1", @"param2", @"param3", @"param4");
    NSAssert5(NO, @"Crash intentionally: NSAssert5 in SDK, %@, %@, %@, %@, %@.", @"param1", @"param2", @"param3", @"param4", @"param5");
    assert(NO && @"Crash intentionally: assert in SDK.");
}

@end

@interface SHApp (LoggerExt_private)

//Some key requires value has some format, check here. It returns checking result and log warning.
- (BOOL)checkTagValue:(NSObject *)value forKey:(NSString *)key;
//Key has some rule, for example no more than 30 chars. Check and return suitable key, meantime log warning.
- (NSString *)checkTagKey:(NSString *)key;

@end

@implementation SHApp (LoggerExt)

#pragma mark - public functions

- (BOOL)tagCuid:(NSString *)uniqueId
{
    return [self tagString:uniqueId forKey:@"sh_cuid"];
}

- (BOOL)tagString:(NSObject *)value forKey:(NSString *)key
{
    if (value != nil && key != nil && key.length > 0)
    {
        if ([self checkTagValue:value forKey:key])
        {
            key = [self checkTagKey:key];
            NSDictionary *dict = @{@"key": key, @"string": value};
            [self sendLogForTag:dict withCode:LOG_CODE_TAG_ADD];
            return YES;
        }
    }
    return NO;
}

- (BOOL)tagNumeric:(double)value forKey:(NSString *)key
{
    if (key != nil && key.length > 0)
    {
        if ([self checkTagValue:@(value) forKey:key])
        {
            key = [self checkTagKey:key];
            NSDictionary *dict = @{@"key": key, @"numeric": @(value)};
            [self sendLogForTag:dict withCode:LOG_CODE_TAG_ADD];
            return YES;
        }
    }
    return NO;
}

- (BOOL)tagDatetime:(NSDate *)value forKey:(NSString *)key
{
    if (value != nil && key != nil && key.length > 0)
    {
        if ([self checkTagValue:value forKey:key])
        {
            key = [self checkTagKey:key];
            NSDictionary *dict = @{@"key": key, @"datetime": value};
            [self sendLogForTag:dict withCode:LOG_CODE_TAG_ADD];
            return YES;
        }
    }
    return NO;
}

- (BOOL)removeTag:(NSString *)key
{
    if (key != nil && key.length > 0)
    {
        key = [self checkTagKey:key];
        NSDictionary *dict = @{@"key": key};
        [self sendLogForTag:dict withCode:LOG_CODE_TAG_DELETE];
        return YES;
    }
    return NO;
}

- (BOOL)incrementTag:(NSString *)key
{
    if (key != nil && key.length > 0)
    {
        key = [self checkTagKey:key];
        NSDictionary *dict = @{@"key": key, @"numeric": @1};
        [self sendLogForTag:dict withCode:LOG_CODE_TAG_INCREMENT];
        return YES;
    }
    return NO;
}

#pragma mark - private functions

- (BOOL)checkTagValue:(NSObject *)value forKey:(NSString *)key
{
    if (key != nil && key.length > 0 && [key compare:@"sh_phone" options:NSCaseInsensitiveSearch] == NSOrderedSame)
    {
        //sh_phone: The User's phone number. Number must be in E.164 format. Example: +61404257513
        BOOL isValid = [value isKindOfClass:[NSString class]] && ((NSString *)value).length > 1 && [(NSString *)value hasPrefix:@"+"];
        if (isValid)
        {
            for (int i = 1; i < ((NSString *)value).length; i ++)
            {
                unichar charNumber = [(NSString *)value characterAtIndex:i];
                if (charNumber > '9' || charNumber < '0')
                {
                    isValid = NO;
                    break;
                }
            }
        }
        if (!isValid)
        {
            NSLog(@"WARNING: Please provide a phone number in the following format: +<country code><national destination code (optional)><subscriber number>. Examples: +6140XXXXXXX (mobile number Australia), +4930XXXXXXXX (landline number Berlin/Germany), +8621XXXXXXXX (landline number Shanghai/China)");
        }
        return isValid;
    }
    return YES;
}

- (NSString *)checkTagKey:(NSString *)key
{
    if (key.length > 30)
    {
        key = [key substringToIndex:30];
        SHLog(@"WARNING: Tag key should be no more than 30 characters. Your key will be truncated as \"%@\".", key);
    }
    return key;
}

@end

@interface SHApp (InstallExt_private)//This category private interface declaration must have "private" to avoid warning: category is implementing a method which will also be implemented by its primary class

//Registers a new installation.
- (void)registerInstallWithHandler:(SHCallbackHandler)handler;

@end

@implementation SHApp (InstallExt)

#pragma mark - public functions

-(void)registerOrUpdateInstallWithHandler:(SHCallbackHandler)handler
{
    if (!streetHawkIsEnabled())
    {
        if (handler)
        {
            handler(nil, nil);
        }
        return;
    }
    handler = [handler copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^
       {
           NSAssert(![NSThread isMainThread], @"registerOrUpdateInstallWithHandler wait in main thread.");
           if (![NSThread isMainThread])
           {
               dispatch_semaphore_wait(self.install_semaphore, DISPATCH_TIME_FOREVER);
               // This is the global one stop shop for registering or updating info about the current installation to the server.  The first time the app is installed, no installation object is created, so a "nil" request is sent to the server to register a new installation. Once this is done, the installation ID is stored in user defaults and is loaded everytime the app is restarted.  After this each time, this method is called, the stored installation ID is used and only "update" requests are sent to the server (ie when APNS tokens have changed or "modes" have changed etc).
               SHCallbackHandler handlerCopy = [handler copy];
               if (self.currentInstall)  // install exists so save the params
               {
                   return [self.currentInstall saveToServer:^(NSObject *result, NSError *error)
                           {
                               if (error == nil)
                               {
                                   self.currentInstall = (SHInstall *)result;
                                   dispatch_semaphore_signal(self.install_semaphore); //make sure currentInstall is set to latest.
                                   //check client version upgrade, must do it before update local cache.
                                   NSString *sentClientVersion = [[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_ClientVersion];
                                   if (sentClientVersion != nil && sentClientVersion.length > 0 && ![sentClientVersion isEqualToString:StreetHawk.clientVersion])
                                   {
                                       [StreetHawk sendLogForCode:LOG_CODE_CLIENTUPGRADE withComment:sentClientVersion];
                                   }
                                   //save sent install parameters for later compare, because install does not have local cache, and avoid query install/details/ from server. Only save it after successfully install/update.
                                   [[NSUserDefaults standardUserDefaults] setObject:NONULL(StreetHawk.appKey) forKey:SentInstall_AppKey];
                                   [[NSUserDefaults standardUserDefaults] setObject:StreetHawk.clientVersion forKey:SentInstall_ClientVersion];
                                   [[NSUserDefaults standardUserDefaults] setObject:StreetHawk.version forKey:SentInstall_ShVersion];
                                   [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:shAppMode()] forKey:SentInstall_Mode];
                                   [[NSUserDefaults standardUserDefaults] setObject:shGetCarrierName() forKey:SentInstall_Carrier];
                                   [[NSUserDefaults standardUserDefaults] setObject:[UIDevice currentDevice].systemVersion forKey:SentInstall_OSVersion];
#ifdef SH_FEATURE_IBEACON
                                   [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:StreetHawk.locationManager.iBeaconSupportState] forKey:SentInstall_IBeacon];
#endif
                                   [[NSUserDefaults standardUserDefaults] synchronize];
                                   NSDictionary *userInfo = @{SHInstallNotification_kInstall: self.currentInstall};
                                   [[NSNotificationCenter defaultCenter] postNotificationName:SHInstallUpdateSuccessNotification object:self userInfo:userInfo];
                               }
                               else
                               {
                                   dispatch_semaphore_signal(self.install_semaphore);
                                   NSDictionary *userInfo = @{SHInstallNotification_kInstall: self.currentInstall, SHInstallNotification_kError: error};
                                   [[NSNotificationCenter defaultCenter] postNotificationName:SHInstallUpdateFailureNotification object:self userInfo:userInfo];
                               }
                               if (handlerCopy)
                               {
                                   handlerCopy(self.currentInstall, error);
                               }
                           }];
               }
               else    //install does not exist and we have no prior install id so create one
               {
                   return [self registerInstallWithHandler:^(NSObject *result, NSError *error)
                           {
                               if (error == nil)
                               {
                                   self.currentInstall = (SHInstall *)result;
                                   dispatch_semaphore_signal(self.install_semaphore); //make sure currentInstall is set to latest.
                                   //save sent install parameters for later compare, because install does not have local cache, and avoid query install/details/ from server. Only save it after successfully install/register.
                                   [[NSUserDefaults standardUserDefaults] setObject:NONULL(StreetHawk.appKey) forKey:SentInstall_AppKey];
                                   [[NSUserDefaults standardUserDefaults] setObject:StreetHawk.clientVersion forKey:SentInstall_ClientVersion];
                                   [[NSUserDefaults standardUserDefaults] setObject:StreetHawk.version forKey:SentInstall_ShVersion];
                                   [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:shAppMode()] forKey:SentInstall_Mode];
                                   [[NSUserDefaults standardUserDefaults] setObject:shGetCarrierName() forKey:SentInstall_Carrier];
                                   [[NSUserDefaults standardUserDefaults] setObject:[UIDevice currentDevice].systemVersion forKey:SentInstall_OSVersion];
#ifdef SH_FEATURE_IBEACON
                                   [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:StreetHawk.locationManager.iBeaconSupportState] forKey:SentInstall_IBeacon];
#endif
                                   [[NSUserDefaults standardUserDefaults] synchronize];
                                   NSDictionary *userInfo = @{SHInstallNotification_kInstall: self.currentInstall};
                                   [[NSNotificationCenter defaultCenter] postNotificationName:SHInstallRegistrationSuccessNotification object:self userInfo:userInfo];
                               }
                               else
                               {
                                   dispatch_semaphore_signal(self.install_semaphore);
                                   NSDictionary *userInfo = @{SHInstallNotification_kError: error};
                                   [[NSNotificationCenter defaultCenter] postNotificationName:SHInstallRegistrationFailureNotification object:self userInfo:userInfo];
                               }
                               if (handlerCopy)
                               {
                                   handlerCopy(self.currentInstall, error);
                               }
                           }];
               }
           }
       });
}

NSString *SentInstall_AppKey = @"SentInstall_AppKey";
NSString *SentInstall_ClientVersion = @"SentInstall_ClientVersion";
NSString *SentInstall_ShVersion = @"SentInstall_ShVersion";
NSString *SentInstall_Mode = @"SentInstall_Mode";
NSString *SentInstall_Carrier = @"SentInstall_Carrier";
NSString *SentInstall_OSVersion = @"SentInstall_OSVersion";
#ifdef SH_FEATURE_IBEACON
NSString *SentInstall_IBeacon = @"SentInstall_IBeacon";
#endif

-(BOOL)checkInstallChangeForLaunch
{
    NSString *sentAppKey = [[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_AppKey];
    NSString *sentClientVersion = [[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_ClientVersion];
    NSString *sentShVersion = [[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_ShVersion];
    NSString *sentCarrier = [[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_Carrier];
    NSString *sentOsVersion = [[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_OSVersion];
#ifdef SH_FEATURE_IBEACON
    SHiBeaconState sentiBeacon = [[[NSUserDefaults standardUserDefaults] objectForKey:SentInstall_IBeacon] intValue];
    SHiBeaconState currentiBeacon = StreetHawk.locationManager.iBeaconSupportState;
    return ((sentAppKey != nil && sentAppKey.length > 0 && ![sentAppKey isEqualToString:StreetHawk.appKey])
            || (sentClientVersion != nil && sentClientVersion.length > 0 && ![sentClientVersion isEqualToString:StreetHawk.clientVersion])
            || (sentShVersion != nil && sentShVersion.length > 0 && ![sentShVersion isEqualToString:StreetHawk.version])
            || (sentCarrier != nil && sentCarrier.length > 0 && ![sentCarrier isEqualToString:shGetCarrierName()])
            || (sentOsVersion != nil && sentOsVersion.length > 0 && ![sentOsVersion isEqualToString:[UIDevice currentDevice].systemVersion])
            || (sentiBeacon == SHiBeaconState_Unknown)/*sent is unknown, update install and refresh sent again*/ || (currentiBeacon != SHiBeaconState_Unknown && sentiBeacon != currentiBeacon/*current change*/));
#else
    return ((sentAppKey != nil && sentAppKey.length > 0 && ![sentAppKey isEqualToString:StreetHawk.appKey])
            || (sentClientVersion != nil && sentClientVersion.length > 0 && ![sentClientVersion isEqualToString:StreetHawk.clientVersion])
            || (sentShVersion != nil && sentShVersion.length > 0 && ![sentShVersion isEqualToString:StreetHawk.version])
            || (sentCarrier != nil && sentCarrier.length > 0 && ![sentCarrier isEqualToString:shGetCarrierName()])
            || (sentOsVersion != nil && sentOsVersion.length > 0 && ![sentOsVersion isEqualToString:[UIDevice currentDevice].systemVersion]));
#endif
}

#pragma mark - private functions

-(void)registerInstallWithHandler:(SHCallbackHandler)handler
{
    //create a fake SHInstall to get save body
    SHInstall *fakeInstall = [[SHInstall alloc] initWithSuid:@"fake_install"];
    handler = [handler copy];
    NSAssert(StreetHawk.currentInstall == nil, @"Install should not exist when call installs/register/.");
    SHRequest *request = [SHRequest requestWithPath:@"installs/register/" withVersion:SHHostVersion_V1 withParams:nil withMethod:@"POST" withHeaders:nil withBodyOrStream:[fakeInstall saveBody]];
    request.requestHandler = ^(SHRequest *registerRequest)
    {
        SHInstall *new_install = nil;
        NSError *error = registerRequest.error;
        if (registerRequest.error == nil)
        {
            NSAssert(registerRequest.resultValue != nil && [registerRequest.resultValue isKindOfClass:[NSDictionary class]], @"Register install return wrong json: %@.", registerRequest.resultValue);
            if (registerRequest.resultValue != nil && [registerRequest.resultValue isKindOfClass:[NSDictionary class]])
            {
                NSDictionary *dict = (NSDictionary *)registerRequest.resultValue;
                new_install = [[SHInstall alloc] initWithSuid:dict[@"installid"]];
                [new_install loadFromDictionary:dict];
            }
            else
            {
                error = [NSError errorWithDomain:SHErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Register install return wrong json: %@.", registerRequest.resultValue]}];
            }
        }
        if (handler)
        {
            handler(new_install, error);
        }
    };
    [request startAsynchronously];
}

@end
