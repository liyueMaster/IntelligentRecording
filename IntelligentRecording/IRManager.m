//
//  IRController.m
//  IntelligentRecording
//
//  Created by 李越 on 16/4/7.
//  Copyright © 2016年 李越. All rights reserved.
//

#import "IRManager.h"
#import "IRVideoRecorder.h"
#import "IRActsMonitor.h"

//作用时间，接收消息之后，处理的反应周期
#define EFFECT_TIME 60

//暂停阀值，统计数据小于这个值将被认为用户无操作
#define THRESHOLD_PRESS 1
#define THRESHOLD_MOVE 10

//数据采集比例，后期主要对这个值进行校准
#define SCALE_PRESS 20
#define SCALE_MOVE 200

//最大录屏速度（时间最大压缩）
#define MAX_RECORD_SPEED 30

@interface IRManager () <IRActsMonitorDelegate> {
    NSUInteger unprocessedTime;
    NSUInteger unprocessedDistance;
    NSUInteger unprocessedKey;
}

@end

@implementation IRManager

- (instancetype)init{
    self = [super init];
    if (self) {
        _type = IRSemiAutomatic;
        unprocessedTime = 0;
    }
    return self;
}

+ (instancetype)sharedManager{
    static IRManager* manager;
    if (manager == nil) {
        manager = [[IRManager alloc] init];
    }
    
    return manager;
}

/**
 *  设置监视器，自动启动监控
 *
 *  @param monitor 监视器
 */
- (void)setMonitor:(IRActsMonitor *)monitor{
    _monitor = monitor;
    
    monitor.delegate = self;
    if (monitor && !monitor.isRunning) {
        [monitor start];
    }
}

//- MARK: IRActsMonitorDelegate

- (void)monitor:(IRActsMonitor *)monitor applicationDidLaunch:(NSRunningApplication *)app{
    
    switch (_type) {
        case IRSemiAutomatic:{
            if (_recorder == nil) {
                if ([self showAlert:@"启动提醒" message:[NSString stringWithFormat:@"监测到 %@ 刚刚启动了，是否需要立即开启智能录屏？", app.localizedName]]) {
                    _recorder = [[IRVideoRecorder alloc] init];
                } else {
                    break;
                }
            }
            
            if (!_recorder.isRecording) {
                [_recorder startRecord];
            } else if (_recorder.isPaused) {
                [_recorder resumeRecord];
            }
            
            break;
        }
            
        case IRIntelligenceAll:{
            if (_recorder == nil) {
                _recorder = [[IRVideoRecorder alloc] init];
            }
            
            if (!_recorder.isRecording) {
                [_recorder startRecord];
            } else if (_recorder.isPaused) {
                [_recorder resumeRecord];
            }
            
            break;
        }
            
        case IRManual:{
            BOOL allowed = NO;
            
            if (_recorder == nil) {
                allowed = [self showAlert:@"启动提醒" message:[NSString stringWithFormat:@"监测到 %@ 刚刚启动了，是否需要立即开启录屏？", app.localizedName]];
                if (allowed) {
                    _recorder = [[IRVideoRecorder alloc] init];
                } else {
                    break;
                }
            }
            
            if (!_recorder.isRecording) {
                if (allowed || (allowed = [self showAlert:@"启动提醒" message:[NSString stringWithFormat:@"监测到 %@ 刚刚启动了，当前录屏未启动，是否立即启动录屏？", app.localizedName]])) {
                    
                    [_recorder startRecord];
                }
                
            } else if (_recorder.isPaused) {
                if (allowed || (allowed = [self showAlert:@"启动提醒" message:[NSString stringWithFormat:@"监测到 %@ 刚刚启动了，当前录屏已暂停，是否立即继续录屏？", app.localizedName]])) {
                    
                    [_recorder resumeRecord];
                }
            }
            
            break;
        }
            
        default:
            break;
    }
}

- (void)monitor:(IRActsMonitor *)monitor applicationDidTerminate:(NSRunningApplication *)app{
    switch (_type) {
        case IRSemiAutomatic:
        case IRIntelligenceAll:{
            
            if (_recorder == nil) {
                break;
            }
            
            if (_recorder.isRecording && !_recorder.isPaused) {
                [_recorder pauseRecord];
            }
            
            break;
        }
            
        case IRManual:{
            if (_recorder == nil) {
                break;
            }
            
            if (_recorder.isRecording && !_recorder.isPaused) {
                if ([self showAlert:@"暂停提醒" message:[NSString stringWithFormat:@"监测到 %@ 刚刚退出了，当前录屏未暂停，是否立即暂停录屏？", app.localizedName]]) {
                    
                    [_recorder pauseRecord];
                }
            }
            
            break;
        }
            
        default:
            break;
    }
}

- (BOOL)showAlert:(NSString *)title message:(NSString *)msg{
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:title];
    [alert setInformativeText:msg];
    [alert addButtonWithTitle:@"确认"];
    [alert addButtonWithTitle:@"取消"];
    
    __block NSModalResponse response;
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        response = [alert runModal];
    });
    
    if (response == NSAlertFirstButtonReturn) {
        return YES;
    }
    
    return NO;
}

- (void)monitor:(IRActsMonitor *)monitor unitTime:(NSUInteger)time receivedMouseMove:(NSUInteger)distance mouseClickedLeft:(NSUInteger)clickedCount1 right:(NSUInteger)clickedCount2 receivedKeyDown:(NSUInteger)keys processTrusted:(BOOL)trusted{
    unprocessedTime += time;
    
    unprocessedKey += (clickedCount1 + clickedCount2 + keys);
    unprocessedDistance += distance;
    
    if (unprocessedTime < EFFECT_TIME) {
        return;
    }
    
    if (_recorder == nil || !_recorder.isRecording) {
        return;
    }
    
    if (unprocessedKey < THRESHOLD_PRESS && unprocessedDistance < THRESHOLD_MOVE) {
        if (!_recorder.isPaused) {
            [_recorder pauseRecord];
        }
    } else {
        if (_recorder.isPaused) {
            [_recorder resumeRecord];
        }
        
        NSInteger speed = MAX_RECORD_SPEED - (unprocessedKey/SCALE_PRESS + unprocessedDistance/SCALE_MOVE);
        [_recorder setTimeLapseMultiple:(speed > 0 ? speed : 1)];
        
        NSLog(@"speed: %ld   timeScale: %ld ", speed, _recorder.timeLapseMultiple);
    }
    
    unprocessedTime = 0;
    
    unprocessedKey = 0;
    unprocessedDistance = 0;
}

// - MARK: 自我控制

- (void)stopWork{
    if (_monitor) {
        if (_monitor.isRunning) {
            [_monitor stop];
        }
        _monitor = nil;
    }
    
    if (_recorder) {
        if (_recorder.isRecording) {
            [_recorder stopRecord];
        }
        _recorder = nil;
    }
}

- (void)autoInitialize{
    _type = IRIntelligenceAll;
    
    [self setMonitor:[[IRActsMonitor alloc] init]];
}

// - MARK: 系统消息

@end
