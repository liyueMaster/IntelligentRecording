//
//  IRVideoRecorder.h
//  IntelligentRecording
//
//  Created by 李越 on 16/3/14.
//  Copyright © 2016年 李越. All rights reserved.
//

#import <Foundation/Foundation.h>

struct ActiveDisplayList {
    uint32_t count;
    CGDirectDisplayID* activeDisplayIDs;
};
typedef struct ActiveDisplayList ActiveDisplayList;

NS_INLINE ActiveDisplayList WSMakeActiveDisplayList(uint32_t count, CGDirectDisplayID* activeDisplayIDs) {
    ActiveDisplayList list;
    list.count = count;
    list.activeDisplayIDs = activeDisplayIDs;
    return list;
}

/**
 *  智能录屏组件--录屏模块，不仅支持自定义帧率、比特率、视频尺寸
 *  等常见视频参数；
 *  在此基础上，更增加了延时录制、区域录制、以及录屏监视器选择
 *  等高级功能。
 *  视频保存路径默认 Documents 目录，可自定义；
 *  文件名默认 yyyy-MM-dd_'at'_HH.mm.ss.mp4，可自定义。
 *  注意：当同名文件存在时，组件不会覆盖原文件，录屏不成功。
 *
 */
@interface IRVideoRecorder : NSObject

/**
 *  每秒传输帧数，默认值 15
 */
@property (nonatomic) NSUInteger framesPerSecond;

/**
 *  每秒传送位数；
 *  注意：在设置此属性之后，如果再次设置其他属性，此属性可能恢复默认值，具体请参照其他属性描述。
 *  默认值为 _videoSize.width * _videoSize.height / 2
 */
@property (nonatomic) NSUInteger bitsPerSecond;

/**
 *  视频尺寸，默认与监视器显示尺寸相同，设置此属性之后，bitsPerSecond将恢复默认。注意：部分尺寸可能不支持，建议视频宽度为8的整数倍。
 */
@property (nonatomic) NSSize videoSize;

/**
 *  自动修复视频尺寸，开启之后，如果当前设置的视频尺寸不支持，系统将自动调整到临近的支持尺寸。默认开启
 */
@property (nonatomic, getter=isAutoResize) BOOL autoResize;

/**
 *  延时录制倍数，1为不延时，默认值不延时；延时倍数越大，录制的视频越短；
 *  如设置 timeLapseMultiple = 20，则录制20分钟将得到1分钟时长的视频
 *  请不要频繁设置此参数，以保证录屏的稳定性
 */
@property (nonatomic) NSUInteger timeLapseMultiple;

/**
 *  当仅需要录制部分区域时，使用此方法，设置录屏区域；
 *  默认值 NSZeroRect,全屏录制；使用分辨率进行该参数设置
 */
@property (nonatomic) NSRect portionRect;

/**
 *  录屏监视器ID，默认为主屏幕 kCGDirectMainDisplay
 */
@property (nonatomic) CGDirectDisplayID recordDisplayId;

/**
 *  黑白录制，默认 NO
 */
@property (nonatomic, getter=isGrayScale) BOOL grayscale;

/**
 *  录制鼠标点击, 默认 NO
 */
@property (nonatomic) BOOL capturesMouseClicks;

/**
 *  视频文件的路径
 */
@property (nonatomic) NSURL* saveDirectory;

/**
 *  视频文件名
 */
@property (nonatomic,copy) NSString* filename;

/**
 *  录屏时间
 */
@property (nonatomic, readonly) NSTimeInterval recordTime;
@property (nonatomic, readonly) NSTimeInterval currentRecordTime;

@property (nonatomic, readonly, getter=isRecording) BOOL recording;

@property (nonatomic, readonly, getter=isPaused) BOOL paused;

/**
 *  初始化录屏组件，并且指定写入的视频参数；若要使用默认视频参数，请使用 - (instancetype)init 定义；必须参数AVVideoCodecKey、AVVideoWidthKey、AVVideoHeightKey
 *
 *  @param settings 视频参数
 *
 *  @return 初始化的录屏对象
 */
- (instancetype)initWithVideoSettings:(NSMutableDictionary *)settings;

/**
 *  开始录屏
 *
 *  @return 成功返回 YES，反之 NO
 */
- (BOOL)startRecord;

/**
 *  停止录屏
 *
 *  @return 返回 录屏文件全路径
 */
- (NSURL *)stopRecord;


/**
 *  暂停录屏;
 *  如果当前已经是暂停状态则返回 YES，
 *  如果当前录屏未启动或者已经停止则返回 NO
 *
 *  @return 成功返回 YES，反之 NO
 */
- (BOOL)pauseRecord;

/**
 *  继续录屏;
 *  如果当前正在录屏且未进入暂停状态则返回 YES，
 *  如果当前录屏未启动或者已经停止则返回 NO
 *
 *  @return 成功返回 YES，反之 NO
 */
- (BOOL)resumeRecord;

/**
 *  获取所有监视器ID，不包含镜像
 *
 *  @return CGDirectDisplayID数组
 */
+ (ActiveDisplayList)getMonitors;

/**
 *  用于销毁定时器
 *  由于定时器会retain当前对象，所以外部调用这个方法来销毁定时器，
 *  否则会造成逻辑内存泄露，一直占用内存
 */
- (void)invalidateTimer;

@end

@interface NSTimer (Pauseable)

-(void)pauseTimer;
-(void)resumeTimer;

@end