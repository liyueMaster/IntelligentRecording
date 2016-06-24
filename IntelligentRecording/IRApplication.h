//
//  IRApplication.h
//  IntelligentRecording
//
//  Created by 李越 on 16/4/25.
//  Copyright © 2016年 李越. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IRApplication : NSObject

@property (nullable, readonly, copy) NSString *localizedName;

@property (nullable, readonly, copy) NSString *bundleIdentifier;

@property (nullable, readonly, copy) NSURL *bundleURL;

@property (nullable, readonly, copy) NSURL *executableURL;

@property (nullable, readonly, strong) NSImage *icon;

- (instancetype __nullable)initWithRunningApp:(NSRunningApplication * __nonnull)app;

- (instancetype __nullable)initWithPath:(NSString * __nonnull)path;

@property (readonly) NSInteger dbIndex;

@property (readonly, getter=isSystem) BOOL system;

@property (getter=isSelected) BOOL selected;

+ (NSArray<IRApplication *> * __nonnull)runningApplications;

+ (NSArray<IRApplication *> * __nonnull)allApplicationsInstalled;

//自动完善数据库
+ (void)updateApplicationListToLast;

@end

@class FMResultSet;

@interface IRApplication (SQLite)

- (BOOL)save;

- (BOOL)remove;

- (BOOL)appDidUpdateState;

+ (NSArray<IRApplication *> * __nonnull)allApplications:(BOOL)containSystemApp;

+ (NSArray<IRApplication *> * __nonnull)allSelectedApplications;

- (instancetype __nullable)exist;

- (instancetype __nullable)initWithResultSet:(FMResultSet * __nonnull)rs;

@end

@interface NSArray<ObjectType> (IR)

- (BOOL)containsApp:(IRApplication * _Nonnull)app;

@end

@interface NSImage (Icon)

/**
 *  图片包含多种大小格式，保留最大的值
 *
 */
- (void)removeRepresentationsExceptBiggest;

@end