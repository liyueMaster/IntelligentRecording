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

- (instancetype)initWithRunningApp:(NSRunningApplication *)app{
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


