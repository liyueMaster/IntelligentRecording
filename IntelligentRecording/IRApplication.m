//
//  IRApplication.m
//  IntelligentRecording
//
//  Created by 李越 on 16/4/25.
//  Copyright © 2016年 李越. All rights reserved.
//

#import "IRApplication.h"

#import <FMDB/FMDB.h>

#define TARGETS_DB @"TARGETS.sqlite"

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
    _bundleURL = app.bundleURL;
    _executableURL = app.executableURL;
    _icon = app.icon;
    
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

+ (NSArray<IRApplication *> *)allApplicationsInstalled:(BOOL)autoExclude{
    NSMutableArray<IRApplication *> * apps = [[NSMutableArray alloc] init];
    [[IRApplication allApplicationPaths:@"/Applications"] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (autoExclude && [obj containsString:@"/Utilities"]) {
            return;
        }
        
        IRApplication* app = [[IRApplication alloc] initWithPath:obj];
        if (app != nil) {
            [apps addObject:app];
        }
    }];
    
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
    NSArray<IRApplication *>* allApps = [IRApplication allApplications];
    
    [[IRApplication runningApplications] enumerateObjectsUsingBlock:^(IRApplication * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![allApps containsApp:obj]) {
            [obj save];
        }
    }];
    
    allApps = [IRApplication allApplications];
    
    [[IRApplication allApplicationsInstalled:YES] enumerateObjectsUsingBlock:^(IRApplication * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![allApps containsApp:obj]) {
            [obj save];
        }
    }];
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
        
        NSString* sqlCreateTable = @"CREATE TABLE IF NOT EXISTS 'targets' ( 'dbindex' integer NOT NULL PRIMARY KEY AUTOINCREMENT, 'selected' integer, 'localizedname' TEXT(200,0),  'bundleidentifier' text(200,0), 'bundleurl' text(200,0), 'executableurl' text(200,0), 'icon' BLOB ); INSERT INTO 'main'.sqlite_sequence (name, seq) VALUES ('targets', '1');";
        
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
    NSString* sql = [NSString stringWithFormat:@"INSERT INTO targets (localizedname, bundleidentifier, bundleurl, executableurl, selected, icon) VALUES ('%@', '%@', '%@', '%@', %d, ?);", self.localizedName, self.bundleIdentifier, self.bundleURL, self.executableURL, self.isSelected];
    
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

+ (NSArray<IRApplication *> *)allApplications{
    NSString* sql = @"SELECT * from targets";
    
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


