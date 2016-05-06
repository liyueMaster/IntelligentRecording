//
//  IRController.h
//  IntelligentRecording
//
//  Created by 李越 on 16/4/7.
//  Copyright © 2016年 李越. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    IRSemiAutomatic = 0,    //仅在录屏组件已经初始化时，自动控制
    IRIntelligenceAll,  //自动创建录屏组件，并自动控制
    IRManual,   //每次操作都询问用户
} IRIntelligentType;

@class IRVideoRecorder,IRActsMonitor;

/**
 *  监听程序的启动退出进行录屏启动暂停控制；统计用户的输入情况进行录屏速度的控制，必要时暂停或继续
 */
@interface IRManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic) IRVideoRecorder* recorder;

/**
 *  设置之后，自动启动
 */
@property (nonatomic) IRActsMonitor* monitor;

@property (nonatomic) IRIntelligentType type;   //默认IRSemiAutomatic，半自动

/**
 *  智能控制只执行启动、暂停、继续操作，而不进行停止操作，停止需要单独控制
 */
- (void)stopWork;

/**
 *  自动初始化组件，采用全智能模式，后续无需任何操作
 */
- (void)autoInitialize;

@end
