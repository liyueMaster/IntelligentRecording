//
//  IRApplication.m
//  IntelligentRecording
//
//  Created by 李越 on 16/4/25.
//  Copyright © 2016年 李越. All rights reserved.
//

#import "IRApplication.h"

#import <FMDB/FMDB.h>

#define TARGETS_DB @"IRApplication.sqlite"

#define PreInstalledAppIdentifiers [NSArray arrayWithObjects:@"com.apple.appstore"/*App Store*/, @"com.apple.Automator"/*Automator*/, @"com.apple.calculator"/*计算器*/, @"com.apple.iCal"/*日历*/, @"com.apple.Chess"/*国际象棋*/, @"com.apple.AddressBook"/*通讯录*/, @"com.apple.dashboardlauncher"/*Dashboard*/, @"com.apple.Dictionary"/*词典*/, @"com.apple.DVDPlayer"/*DVD 播放程序*/, @"com.apple.FaceTime"/*FaceTime*/, @"com.apple.FontBook"/*字体册*/, @"com.apple.gamecenter"/*Game Center*/, @"com.apple.Image_Capture"/*图像捕捉*/, @"com.apple.iTunes"/*iTunes*/, @"com.apple.iWork.Keynote"/*Keynote*/, @"com.apple.launchpad.launcher"/*Launchpad*/, @"com.apple.mail"/*邮件*/, @"com.apple.Maps"/*地图*/, @"com.apple.iChat"/*信息*/, @"com.apple.exposelauncher"/*Mission Control*/, @"com.apple.Notes"/*备忘录*/, @"com.apple.iWork.Numbers"/*Numbers*/, @"com.apple.iWork.Pages"/*Pages*/, @"com.apple.PhotoBooth"/*Photo Booth*/, @"com.apple.Photos"/*照片*/, @"com.apple.Preview"/*预览*/, @"com.apple.QuickTimePlayerX"/*QuickTime Player*/, @"com.apple.reminders"/*提醒事项*/, @"com.apple.Safari"/*Safari*/, @"com.apple.Stickies"/*便笺*/, @"com.apple.systempreferences"/*系统偏好设置*/, @"com.apple.TextEdit"/*文本编辑*/, @"com.apple.backup.launcher"/*Time Machine*/, @"com.apple.ActivityMonitor"/*活动监视器*/, @"com.apple.airport.airportutility"/*AirPort 实用工具*/, @"com.apple.audio.AudioMIDISetup"/*音频 MIDI 设置*/, @"com.apple.BluetoothFileExchange"/*蓝牙文件交换*/, @"com.apple.bootcampassistant"/*Boot Camp 助理*/, @"com.apple.ColorSyncUtility"/*ColorSync 实用工具*/, @"com.apple.Console"/*控制台*/, @"com.apple.DigitalColorMeter"/*数码测色计*/, @"com.apple.Disk-Utility"/*磁盘工具*/, @"com.apple.Grab"/*抓图*/, @"com.apple.grapher"/*Grapher*/, @"com.apple.keychainaccess"/*钥匙串访问*/, @"com.apple.MigrateAssistant"/*迁移助理*/, @"com.apple.ScriptEditor2"/*脚本编辑器*/, @"com.apple.SystemProfiler"/*系统信息*/, @"com.apple.Terminal"/*终端*/, @"com.apple.VoiceOverUtility"/*VoiceOver 实用工具*/, @"com.apple.ScriptEditor.id.桌面图标"/*桌面图标*/, @"com.apple.iTunesHelper"/*iTunes Helper*/, nil]

#define CoreServicesAppIdentifiers [NSArray arrayWithObjects:@"com.apple.print.add"/*AddPrinter*/, @"com.apple.AddressBook.UrlForwarder"/*AddressBookUrlForwarder*/, @"com.apple.AirPlayUIAgent"/*AirPlayUIAgent*/, @"com.apple.AirPortBaseStationAgent"/*AirPort 基站代理*/, @"com.apple.appstore.AppDownloadLauncher"/*AppDownloadLauncher*/, @"com.apple.AppleFileServer"/*AppleFileServer*/, @"com.apple.AppleGraphicsWarning"/*AppleGraphicsWarning*/, @"com.apple.AppleScriptUtility"/*AppleScript 实用工具*/, @"com.apple.archiveutility"/*归档实用工具*/, @"com.apple.DirectoryUtility"/*目录实用工具*/, @"com.apple.appleseed.FeedbackAssistant"/*反馈助理*/, @"com.apple.NetworkUtility"/*网络实用工具*/, @"com.apple.RAIDUtility"/*RAID 实用工具*/, @"com.apple.ScreenSharing"/*屏幕共享*/, @"com.apple.SystemImageUtility"/*System Image Utility*/, @"com.apple.wifi.diagnostics"/*无线诊断*/, @"com.apple.AutomatorRunner"/*Automator Runner*/, @"com.apple.AVB-Audio-Configuration"/*AVB Audio Configuration*/, @"com.apple.TMHelperAgent"/*TMHelperAgent*/, @"com.apple.BluetoothSetupAssistant"/*蓝牙设置助理*/, @"com.apple.BluetoothUIServer"/*BluetoothUIServer*/, @"com.apple.CalendarFileHandler"/*日历/提醒事项*/, @"com.apple.CaptiveNetworkAssistant"/*Captive Network Assistant*/, @"com.apple.CertificateAssistant"/*证书助理*/, @"com.apple.cloudphotosd"/*cloudphotosd*/, @"com.apple.CoreLocationAgent"/*CoreLocationAgent*/, @"com.apple.coreservices.uiagent"/*CoreServicesUIAgent*/, @"com.apple.databaseevents"/*数据库事件*/, @"com.apple.DiscHelper"/*DiscHelper*/, @"com.apple.DiskImageMounter"/*DiskImageMounter*/, @"com.apple.dock"/*Dock*/, @"com.apple.EscrowSecurityAlert"/*EscrowSecurityAlert*/, @"com.apple.ExpansionSlotUtility"/*扩充槽实用工具*/, @"com.apple.FileSyncUI"/*文件同步*/, @"com.apple.FileSyncAgent"/*FileSyncAgent*/, @"com.apple.finder"/*Finder*/, @"com.apple.FirmwareUpdateHelper"/*FirmwareUpdateHelper*/, @"com.apple.FolderActionsSetup"/*文件夹操作设置*/, @"com.apple.FolderActionsDispatcher"/*FolderActionsDispatcher*/, @"com.apple.helpviewer"/*帮助显示程序*/, @"com.apple.imageevents"/*图像事件*/, @"com.apple.dt.CommandLineTools.installondemand"/*Install Command Line Developer Tools*/, @"com.apple.PackageKit.Install-in-Progress"/*Install in Progress*/, @"com.apple.Installer-Progress"/*Installer Progress*/, @"com.apple.installer"/*安装器*/, @"com.apple.JarLauncher"/*Jar Launcher*/, @"com.apple.JavaWebStart"/*Java Web Start*/, @"com.apple.FileSystemUIAgent"/*FileSystemUIAgent*/, @"com.apple.KeyboardSetupAssistant"/*KeyboardSetupAssistant*/, @"com.security.apple.Keychain-Circle-Notification"/*Keychain Circle Notification*/, @"com.apple.Language-Chooser"/*Language Chooser*/, @"com.apple.locationmenu"/*Location Menu*/, @"com.apple.loginwindow"/*loginwindow*/, @"com.apple.ManagedClient"/*ManagedClient*/, @"com.apple.MemorySlotUtility"/*内存插槽实用工具*/, @"com.apple.TISwitcher"/*TISwitcher*/, @"com.apple.MRT"/*MRT*/, @"com.apple.NetAuthAgent"/*NetAuthAgent*/, @"com.apple.NetworkDiagnostics"/*网络诊断*/, @"com.apple.NetworkSetupAssistant"/*网络设置助理*/, @"com.apple.notificationcenterui"/*通知中心*/, @"com.apple.OBEXAgent"/*OBEXAgent*/, @"com.apple.ODSAgent"/*ODSAgent*/, @"com.apple.Pass-Viewer"/*Pass Viewer*/, @"com.apple.PhotoLibraryMigrationUtility"/*Photo Library Migration Utility*/, @"com.apple.PowerChime"/*PowerChime*/, @"com.apple.ProblemReporter"/*Problem Reporter*/, @"com.apple.rcd"/*rcd*/, @"com.apple.pluginIM.pluginIMRegistrator"/*RegisterPluginIM*/, @"com.apple.LockScreen"/*LockScreen*/, @"com.apple.VNCGuestRequest"/*共享屏幕请求*/, @"com.apple.VNCDragHelper"/*SSDragHelper*/, @"com.apple.RemoteDesktopAgent"/*ARDAgent*/, @"com.apple.SSAssistanceCursor"/*SSAssistanceCursor*/, @"com.apple.ssinvitationagent"/*SSInvitationAgent*/, @"com.apple.ReportPanic"/*ReportPanic*/, @"com.apple.ScriptMonitor"/*ScriptMonitor*/, @"com.apple.SecurityFixer"/*SecurityFixer*/, @"com.apple.SetupAssistant"/*设置助理*/, @"com.apple.CloudKit.ShareBear"/*ShareBear*/, @"com.apple.SocialPushAgent"/*SocialPushAgent*/, @"com.apple.SoftwareUpdate"/*软件更新*/, @"com.apple.Spotlight"/*Spotlight*/, @"com.apple.stocks"/*Stocks*/, @"com.apple.systemevents"/*系统事件*/, @"com.apple.systemuiserver"/*SystemUIServer*/, @"com.apple.ThermalTrap"/*ThermalTrap*/, @"com.apple.Ticket-Viewer"/*票据显示程序*/, @"com.apple.UniversalAccessControl"/*UniversalAccessControl*/, @"com.apple.UnmountAssistantAgent"/*UnmountAssistantAgent*/, @"com.apple.UserNotificationCenter"/*UserNotificationCenter*/, @"com.apple.VoiceOver"/*VoiceOver*/, @"com.apple.weather"/*Weather*/, @"com.apple.wifi.WiFiAgent"/*WiFiAgent*/, @"com.apple.ZoomWindow.app"/*ZoomWindow*/, @"com.apple.dock.extra"/*com.apple.dock.extra*/, @"com.apple.lateragent"/*LaterAgent*/, @"com.apple.WebKit.Networking"/*Safari Networking*/, @"com.apple.nbagent"/*nbagent*/, @"com.apple.ViewBridgeAuxiliary"/*ViewBridgeAuxiliary*/, @"com.apple.storeuid"/*storeuid*/, nil]

@implementation IRApplication

- (instancetype)initWithRunningApp:(NSRunningApplication *)app {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    
    _dbIndex = -1;
    _selected = NO;
    _localizedName = app.localizedName;
    _bundleIdentifier = app.bundleIdentifier;
    
    if (_bundleIdentifier == nil) {
        return nil;
    }
    
    _bundleURL = app.bundleURL;
    _executableURL = app.executableURL;
    
    __block NSInteger appCount = 0;
    [[_executableURL pathComponents] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj hasSuffix:@".app"]) {
            if (++appCount > 1) {
                *stop = YES;
            }
        }
    }];
    if (appCount > 1) {
        return nil;
    }
    
    _icon = app.icon;
    [_icon removeRepresentationsExceptBiggest];
    
    _system = [PreInstalledAppIdentifiers containsObject:_bundleIdentifier] || [CoreServicesAppIdentifiers containsObject:_bundleIdentifier];
    
    return self;
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    
    _dbIndex = -1;
    _selected = NO;
    
    NSBundle *bundle = [NSBundle bundleWithPath:path];
    if (bundle == nil || bundle.bundleIdentifier == nil) {
        return nil;
    }
    NSString *localizedName = bundle.localizedInfoDictionary[@"CFBundleName"];
    _localizedName = localizedName ? localizedName : bundle.infoDictionary[@"CFBundleName"];
    _bundleIdentifier = bundle.bundleIdentifier;
    _bundleURL = bundle.bundleURL;
    _executableURL = bundle.executableURL;
    
    _icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
    [_icon removeRepresentationsExceptBiggest];
    
    _system = [PreInstalledAppIdentifiers containsObject:_bundleIdentifier] || [CoreServicesAppIdentifiers containsObject:_bundleIdentifier];
    
//    NSLog(@"%@ 总共 %ld 个", _localizedName, [_icon.representations count]);
//    for (NSImageRep *rep in _icon.representations) {
//        NSLog(@"%ld,%ld  Size %f", rep.pixelsWide, rep.pixelsHigh, rep.size.width);
//    }
    
    return self;
}

+ (NSArray<IRApplication *> *)runningApplications{
    NSMutableArray<IRApplication *> * runningApps = [[NSMutableArray alloc] init];
    
    [[IRActsMonitor getRunningApplications] enumerateObjectsUsingBlock:^(NSRunningApplication * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        //NSLog(@"应用：%@, ID：%@", obj.localizedName, obj.bundleIdentifier);
        
        IRApplication* app = [[IRApplication alloc] initWithRunningApp:obj];
        if (app != nil) {
            [runningApps addObject:app];
        }
    }];
    
    return runningApps;
}

+ (NSArray<IRApplication *> *)allApplicationsInstalled{
    
//    NSMutableString* str = [[NSMutableString alloc] init];
    
    NSMutableArray<IRApplication *> * apps = [[NSMutableArray alloc] init];
    [[IRApplication allApplicationPaths:@"/Applications"] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
//        NSBundle *bundle = [NSBundle bundleWithPath:obj];
//        NSString *localizedName = bundle.localizedInfoDictionary[@"CFBundleName"];
//        localizedName = localizedName ? localizedName : bundle.infoDictionary[@"CFBundleName"];
//        
//        if ([bundle.bundleIdentifier hasPrefix:@"com.apple"]) {
//            [str appendString:[NSString stringWithFormat:@"@\"%@\"/*%@*/, ", bundle.bundleIdentifier, localizedName]];
//        }
        
        IRApplication* app = [[IRApplication alloc] initWithPath:obj];
        if (app != nil) {
            [apps addObject:app];
        }
    }];
    
    [[IRApplication allApplicationPaths:@"/System/Library/CoreServices"] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
//        NSBundle *bundle = [NSBundle bundleWithPath:obj];
//        NSString *localizedName = bundle.localizedInfoDictionary[@"CFBundleName"];
//        localizedName = localizedName ? localizedName : bundle.infoDictionary[@"CFBundleName"];
//
//        [str appendString:[NSString stringWithFormat:@"@\"%@\"/*%@*/, ", bundle.bundleIdentifier, localizedName]];
        
        IRApplication* app = [[IRApplication alloc] initWithPath:obj];
        if (app != nil) {
            [apps addObject:app];
        }
    }];
    
//    NSLog(@"%@", str);
    
    return apps;
}

+ (NSArray<NSString *> *)allApplicationPaths:(NSString *)path{
    NSMutableArray<NSString *> * appPaths = [[NSMutableArray alloc] init];
    
    // 1. 判断文件还是目录
    NSFileManager * fileManger = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExist = [fileManger fileExistsAtPath:path isDirectory:&isDir];
    if (isExist) {
        // 2. 判断是不是目录
        if (isDir) {
            
            //3. 判断是不是应用程序
            BOOL isApp = [path hasSuffix:@".app"];
            if (isApp) {
                //NSLog(@"%@", path);
                [appPaths addObject:path];
            } else {
                NSArray * dirArray = [fileManger contentsOfDirectoryAtPath:path error:nil];
                NSString * subPath = nil;
                for (NSString * str in dirArray) {
                    subPath  = [path stringByAppendingPathComponent:str];
                    BOOL issubDir = NO;
                    [fileManger fileExistsAtPath:subPath isDirectory:&issubDir];
                    [appPaths addObjectsFromArray:[IRApplication allApplicationPaths:subPath]];
                }
            }
        }
    }
    
    return appPaths;
}

+ (void)updateApplicationListToLast{
    NSArray<IRApplication *>* allApps = [IRApplication allApplications:YES];
    
    [[IRApplication runningApplications] enumerateObjectsUsingBlock:^(IRApplication * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![allApps containsApp:obj]) {
            [obj save];
        }
    }];
    
    allApps = [IRApplication allApplications:YES];
    
    [[IRApplication allApplicationsInstalled] enumerateObjectsUsingBlock:^(IRApplication * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![allApps containsApp:obj]) {
            [obj save];
        }
    }];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:IRApplicationListDidUpdate object:nil];
}

- (instancetype)initWithResultSet:(FMResultSet *)rs{
    self = [super init];
    if (self == nil) {
        return nil;
    }
    
    _dbIndex = [rs intForColumn:@"dbindex"];
    _selected = [rs boolForColumn:@"selected"];
    _localizedName = [rs stringForColumn:@"localizedname"];
    _bundleIdentifier = [rs stringForColumn:@"bundleidentifier"];
    _bundleURL = [NSURL URLWithString:[rs stringForColumn:@"bundleurl"]];
    _executableURL = [NSURL URLWithString:[rs stringForColumn:@"executableurl"]];
    _icon = [[NSImage alloc] initWithData:[rs dataForColumn:@"icon"]];
    _system = [rs boolForColumn:@"system"];
    
    return self;
}

+ (FMDatabaseQueue *)sharedDatabaseQueue{
    
    static FMDatabaseQueue* dbq;
    
    if (dbq == nil) {
        NSString* dbFilePath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"com.IntelligentRecording"];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:dbFilePath]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dbFilePath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        dbq = [FMDatabaseQueue databaseQueueWithPath:[dbFilePath stringByAppendingPathComponent:TARGETS_DB]];
        
        NSString* sqlCreateTable = @"CREATE TABLE IF NOT EXISTS 'targets' ( 'dbindex' integer NOT NULL PRIMARY KEY AUTOINCREMENT, 'selected' integer, 'localizedname' TEXT(200,0),  'bundleidentifier' text(200,0), 'bundleurl' text(200,0), 'executableurl' text(200,0), 'icon' BLOB , 'system' integer); INSERT INTO 'main'.sqlite_sequence (name, seq) VALUES ('targets', '1');";
        
        [dbq inTransaction:^(FMDatabase *db, BOOL *rollback) {
            *rollback = ![db executeUpdate:sqlCreateTable];
            
            if (*rollback) {
                NSLog(@"初始化本地数据库失败，组件可能崩溃...\n%@", db.lastError);
            }
        }];
        
    }
    
    return dbq;
}

- (BOOL)save{
    NSString* sql = [NSString stringWithFormat:@"INSERT INTO targets (localizedname, bundleidentifier, bundleurl, executableurl, selected, system, icon) VALUES ('%@', '%@', '%@', '%@', %d, %d, ?);", self.localizedName, self.bundleIdentifier, self.bundleURL, self.executableURL, self.isSelected, self.isSystem];
    
    __block BOOL flag = NO;
    
    [[IRApplication sharedDatabaseQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        flag = [db executeUpdate:sql, self.icon.TIFFRepresentation];
        
        *rollback = !flag;
        
        if (*rollback) {
            NSLog(@"保存错误...\n%@", db.lastError);
        }
    }];
    
    return flag;
}

- (BOOL)remove{
    NSString* sql = [NSString stringWithFormat:@"DELETE FROM targets WHERE bundleidentifier = '%@' ;", self.bundleIdentifier];
    
    __block BOOL flag = NO;
    
    [[IRApplication sharedDatabaseQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        flag = [db executeUpdate:sql, self.icon];
        
        *rollback = !flag;
        
        if (*rollback) {
            NSLog(@"删除错误...\n%@", db.lastError);
        }
    }];
    
    return flag;
}

- (instancetype)exist{
    NSString* sql = [NSString stringWithFormat:@"SELECT * from targets WHERE bundleidentifier = '%@' ;", self.bundleIdentifier];
    
    __block IRApplication* app = nil;
    
    [[IRApplication sharedDatabaseQueue] inDatabase:^(FMDatabase *db) {
        FMResultSet* rs = [db executeQuery:sql];
        if ([rs next]) {
            app = [[IRApplication alloc] initWithResultSet:rs];
        }
        [rs close];
    }];
    
    return app;
}

- (BOOL)appDidUpdateState{
    NSString* sql = [NSString stringWithFormat:@"UPDATE targets SET selected=%d WHERE bundleidentifier = '%@';", self.isSelected, self.bundleIdentifier];
    
    __block BOOL flag = NO;
    
    [[IRApplication sharedDatabaseQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        flag = [db executeUpdate:sql, self.icon];
        
        *rollback = !flag;
        
        if (*rollback) {
            NSLog(@"修改错误...\n%@", db.lastError);
        }
    }];
    
    return flag;
}

+ (NSArray<IRApplication *> *)allApplications:(BOOL)containSystemApp{
    NSString* sql = @"SELECT * from targets WHERE system=0";
    if (containSystemApp) {
        sql = @"SELECT * from targets";
    }
    
    __block NSMutableArray<IRApplication *> * apps = [[NSMutableArray alloc] init];
    
    [[IRApplication sharedDatabaseQueue] inDatabase:^(FMDatabase *db) {
        FMResultSet* rs = [db executeQuery:sql];
        while ([rs next]) {
            IRApplication* app = [[IRApplication alloc] initWithResultSet:rs];
            
            [apps addObject:app];
        }
        [rs close];
    }];
    
    return apps;
}

+ (NSArray<IRApplication *> *)allSelectedApplications{
    NSString* sql = @"SELECT * FROM targets WHERE selected=1";
    
    __block NSMutableArray<IRApplication *> * apps = [[NSMutableArray alloc] init];
    
    [[IRApplication sharedDatabaseQueue] inDatabase:^(FMDatabase *db) {
        FMResultSet* rs = [db executeQuery:sql];
        while ([rs next]) {
            IRApplication* app = [[IRApplication alloc] initWithResultSet:rs];
            
            [apps addObject:app];
        }
        [rs close];
    }];
    
    return apps;
}

- (void)dealloc{
    [[IRApplication sharedDatabaseQueue] close];
}

@end


@implementation NSArray (IR)

- (BOOL)containsApp:(IRApplication *)app{
    for (IRApplication* obj in self) {
        if ([obj.bundleIdentifier isEqualToString:app.bundleIdentifier]) {
            return true;
        }
    }
    
    return false;
}

@end

@implementation NSImage (Icon)

- (void)removeRepresentationsExceptBiggest{
    NSArray<NSImageRep *> *reps = self.representations;
    NSImageRep* biggestRep = reps[0];
    for (NSImageRep* rep in reps) {
        if (biggestRep.size.width < rep.size.width) {
            [self removeRepresentation:biggestRep];
            biggestRep = rep;
        } else {
            [self removeRepresentation:rep];
        }
    }
}

@end


