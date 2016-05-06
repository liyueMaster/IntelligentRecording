//
//  IRActsMonitor.h
//  IntelligentRecording
//
//  Created by 李越 on 16/3/21.
//  Copyright © 2016年 李越. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol IRActsMonitorDelegate;

@interface IRActsMonitor : NSObject

@property (nonatomic, weak) id<IRActsMonitorDelegate> delegate;

@property (nonatomic) BOOL processTrusted;    //是否信任

/**
 *  监视器通过代理反馈数据的单位时间（频率），单位秒，默认30s
 */
@property (nonatomic) NSInteger unitTime;

@property (nonatomic, getter=isRunning) BOOL running;

/**
 *  标识当前是否有监控的目标程序正在运行，由组件进行维护，逻辑准确
 */
@property (nonatomic, readonly, getter=isAnyoneRunning) BOOL anyoneRunning;

/**
 *  启动监视器
 *
 *  @return 成功返回 YES
 */
- (BOOL)start;

/**
 *  停止监视器
 *
 *  @return 成功返回 YES
 */
- (BOOL)stop;

/**
 *  是否有正在运行的监控目标，使用数据库进行匹配，物理保证准确
 *
 *  @return 当且仅当所有的目标程序都处于退出状态，才返回 NO，否则返回 YES
 */
- (BOOL)isAnyoneTargetAppRunning;

/**
 *  获取已安装应用列表
 *
 *  @return 已安装应用列表
 */
+ (NSArray<NSApplication *> *)getInstalledApplications;

/**
 *  获取当前正在运行的程序列表
 *
 *  @return 正在运行的程序列表
 */
+ (NSArray<NSRunningApplication *> *)getRunningApplications;

/**
 *  尝试获取控制权限
 */
- (void)toMakeProcessTrusted;

@end

@protocol IRActsMonitorDelegate <NSObject>

@optional


/**
 *  反馈当前计数周期内，用户的操作情况
 *
 *  @param monitor       当前监视器
 *  @param time          单位时间
 *  @param distance      鼠标移动距离
 *  @param clickedCount1 鼠标左键点击次数
 *  @param clickedCount2 鼠标右键点击次数
 *  @param keys          键盘点击次数
 *  @param trusted       是否获取控制权限
 */
- (void)monitor:(IRActsMonitor *)monitor unitTime:(NSUInteger)time receivedMouseMove:(NSUInteger)distance mouseClickedLeft:(NSUInteger)clickedCount1 right:(NSUInteger)clickedCount2 receivedKeyDown:(NSUInteger)keys processTrusted:(BOOL)trusted;

/**
 *  当前监视器监视列表中的应用启动时，调用此方法
 *
 *  @param monitor 当前监视器
 *  @param app     启动应用
 */
- (void)monitor:(IRActsMonitor *)monitor applicationDidLaunch:(NSRunningApplication *)app;

/**
 *  当前监视器监视列表中的应用退出时，调用此方法
 *
 *  @param monitor 当前监视器
 *  @param app     退出的应用
 */
- (void)monitor:(IRActsMonitor *)monitor applicationDidTerminate:(NSRunningApplication *)app;

@end