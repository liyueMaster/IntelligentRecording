//
//  IRVideoRecorder.m
//  IntelligentRecording
//
//  Created by 李越 on 16/3/14.
//  Copyright © 2016年 李越. All rights reserved.
//

#import "IRVideoRecorder.h"
#import "GPUImage.h"

#define MAX_DISPLAY 20

@interface IRVideoRecorder (){
    GPUImageDesktop* _inputDesktop;
    
    GPUImageCropFilter* _cropFilter;
    GPUImageGrayscaleFilter* _grayscaleFilter;
    //GPUImageTransformFilter* _transformFilter;
    
    //水印
    GPUImagePicture* _imageForBlending;
    GPUImageAlphaBlendFilter* _blendFilter;
    
    GPUImageMovieWriter* _movieWriter;
    
    NSMutableDictionary* _videoSettings;
    
    NSTimer* _timer;
}

@end

@implementation IRVideoRecorder

- (instancetype)init{
    
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _framesPerSecond = 15;
    _timeLapseMultiple = 1;
    
    _recordDisplayId = kCGDirectMainDisplay;
    _portionRect = NSZeroRect;
    //_videoSize = CGDisplayScreenSize(_recordDisplayId);
    _videoSize = NSMakeSize(CGDisplayPixelsWide(_recordDisplayId), CGDisplayPixelsHigh(_recordDisplayId));
    _autoResize = YES;
    
    _bitsPerSecond = floor(_videoSize.width * _videoSize.height / 1.5);
    
    _grayscale = NO;
    _capturesMouseClicks = NO;
    
    _recording = NO;
    _paused = NO;
    
    _recordTime = 0;
    _currentRecordTime = 0;
    _timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(timeUpdate) userInfo:nil repeats:YES];
    [_timer setFireDate:[NSDate distantFuture]];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    
    
    _saveDirectory = [NSURL fileURLWithPath:NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0]];
    //_filename = @"ir_video.mp4";
    
    return self;
}

- (instancetype)initWithVideoSettings:(NSMutableDictionary *)settings{
    self = [self init];
    
    _videoSettings = settings;
    
    return self;
}

- (void)setVideoSize:(NSSize)videoSize{
    if (videoSize.width < 24 || videoSize.height < 24) {
        NSLog(@"视频尺寸小于24将不被支持...");
        return;
    }
    
    _videoSize = videoSize;
    _bitsPerSecond = floor(_videoSize.width * _videoSize.height / 1.5);
}

- (void)setFramesPerSecond:(NSUInteger)framesPerSecond{
    if (framesPerSecond > 0) {
        _framesPerSecond = framesPerSecond;
        [_inputDesktop setFrameRate:_framesPerSecond];
    }
}

- (void)setTimeLapseMultiple:(NSUInteger)timeLapseMultiple{
    if (timeLapseMultiple > 0) {
        _timeLapseMultiple = timeLapseMultiple;
        [_inputDesktop setTimescale:timeLapseMultiple];
    }
}

- (void)setCapturesMouseClicks:(BOOL)capturesMouseClicks{
    _capturesMouseClicks = capturesMouseClicks;
    [_inputDesktop setCapturesMouseClicks:capturesMouseClicks];
}

- (NSString *)generateFilename{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    // 2016-04-20_at_16.44.49
    [formatter setDateFormat:@"yyyy-MM-dd_'at'_HH.mm.ss"];
    NSString *currentDateStr = [formatter stringFromDate:[NSDate date]];
    NSString *filename = [NSString stringWithFormat:@"%@.mp4",currentDateStr];
    
    return filename;
}

- (BOOL)prepareForRecord{
    if (_saveDirectory == nil) {
        NSLog(@"保存路径为空...");
        return NO;
    }
    
    if (_filename == nil) {
        _filename = [self generateFilename];
    }
    
    NSMutableArray<GPUImageInput>* units = [[NSMutableArray<GPUImageInput> alloc] init];
    
    _inputDesktop = [[GPUImageDesktop alloc] initWithSessionPreset:AVCaptureSessionPresetLow displayId:_recordDisplayId];
    
    if (_inputDesktop == nil) {
        NSLog(@"初始化屏幕数据源失败...");
        return NO;
    }
    
    [_inputDesktop setTimescale:_timeLapseMultiple];
    [_inputDesktop setFrameRate:_framesPerSecond];
    [_inputDesktop setCapturesMouseClicks:_capturesMouseClicks];
    //[_inputDesktop setRunBenchmark:YES];
    
    NSRect fullScreenRect = CGDisplayBounds(_recordDisplayId);  //全屏尺寸
    NSSize sourceSize = fullScreenRect.size;    //源尺寸，如果是区域录屏就是区域尺寸
    
    //如果设置了录屏区域，就使用区域录屏
    if (!NSEqualRects(_portionRect, NSZeroRect)) {
        
        NSInteger temp = (NSInteger)_portionRect.size.width%8;
        if(temp>4 && (_portionRect.size.width+(8-temp)<=fullScreenRect.size.width)){
            _portionRect.size.width += (8-temp);
        }else if(temp!=0){
            _portionRect.size.width -= temp;
        }
        //换算区域，值为0～1之间
        CGFloat cropW = _portionRect.size.width/fullScreenRect.size.width;
        CGFloat cropH = _portionRect.size.height/fullScreenRect.size.height;
        CGFloat cropX = _portionRect.origin.x/fullScreenRect.size.width;
        CGFloat cropY = 1-(_portionRect.origin.y/fullScreenRect.size.height+cropH);
        CGRect cropRegion = CGRectMake(cropX,cropY,cropW,cropH);
        _cropFilter = [[GPUImageCropFilter alloc] initWithCropRegion:cropRegion];
        
        [units addObject:_cropFilter];
        
        sourceSize = _portionRect.size;
        if (NSEqualSizes(_videoSize, fullScreenRect.size)) {
            _videoSize = sourceSize;
        }
    }
    
    if (self.isAutoResize) {
         //对视频尺寸进行修正
         NSInteger temp = (NSInteger)_videoSize.width%8;
         if(temp>4 && (_videoSize.width+(8-temp)<=sourceSize.width)){
         _videoSize.width += (8-temp);
         }else if(temp!=0){
         _videoSize.width -= temp;
         }
    }

    //错误，自由缩放视频不需要添加过滤器，只需要在Writer中设置想要的尺寸，此处如果再缩放，会导致画面再次缩放，但是视频尺寸不变，周围出现黑边
    //如果视频源的尺寸与视频尺寸不相同，就启用缩放
//    if (!NSEqualSizes(sourceSize, _videoSize)) {
//        CGFloat sx = _videoSize.width / sourceSize.width;
//        CGFloat sy = _videoSize.height / sourceSize.height;
//        CGAffineTransform affineTransform = CGAffineTransformMakeScale(sx, sy);
//        _transformFilter = [[GPUImageTransformFilter alloc] init];
//        _transformFilter.affineTransform = affineTransform;
//        
//        [units addObject:_transformFilter];
//    }
    
    //黑白
    if (self.isGrayScale) {
        _grayscaleFilter = [[GPUImageGrayscaleFilter alloc] init];
        
        [units addObject:_grayscaleFilter];
    }
    
    if (_videoSettings == nil) {
        /**
         *  AVVideoProfileLevelKey：画质
         *  AVVideoAllowFrameReorderingKey
         *  AVVideoAverageBitRateKey：视频尺寸*比率，10.1相当于AVCaptureSessionPresetHigh，数值越大，显示越精细
         *  AVVideoMaxKeyFrameIntervalKey：关键帧最大间隔，1为每个都是关键帧，数值越大压缩率越高
         *  AVVideoH264EntropyModeKey
         *  AVVideoExpectedSourceFrameRateKey
         */
        NSDictionary *videoCompressionProps
            = [NSDictionary dictionaryWithObjectsAndKeys:
               [NSNumber numberWithDouble:_bitsPerSecond],AVVideoAverageBitRateKey,
               @NO,AVVideoAllowFrameReorderingKey,
               AVVideoProfileLevelH264MainAutoLevel,AVVideoProfileLevelKey,
               @10000,AVVideoMaxKeyFrameIntervalKey,
               @0,AVVideoMaxKeyFrameIntervalDurationKey,
               AVVideoH264EntropyModeCABAC,AVVideoH264EntropyModeKey,
               [NSNumber numberWithUnsignedInteger:_framesPerSecond],AVVideoExpectedSourceFrameRateKey,
               nil ];
        
        _videoSettings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                          AVVideoCodecH264, AVVideoCodecKey,
                          [NSNumber numberWithInt:_videoSize.width], AVVideoWidthKey,
                          [NSNumber numberWithInt:_videoSize.height], AVVideoHeightKey,
                          videoCompressionProps, AVVideoCompressionPropertiesKey,
                          nil];
    } else {
        if ([_videoSettings objectForKey:AVVideoCodecKey] == nil
            || [_videoSettings objectForKey:AVVideoWidthKey] == nil
            || [_videoSettings objectForKey:AVVideoHeightKey] == nil) {
            NSLog(@"缺少关键视频参数..");
            return NO;
        }
    }
    
    NSURL* saveURL = [_saveDirectory URLByAppendingPathComponent:_filename];
    _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:saveURL size:_videoSize fileType:AVFileTypeQuickTimeMovie outputSettings:_videoSettings];
    
    [_movieWriter setFailureBlock:^(NSError *error) {
        NSLog(@"MovieWriter Error:%@",error.description);
    }];
    
    if (_movieWriter == nil) {
        NSLog(@"初始化视频写入组件失败...");
        return NO;
    }
    
    //[_movieWriter setHasAudioTrack:YES];
    //[_inputDesktop setAudioEncodingTarget:_movieWriter];
    //Audio Units
    
    //水印滤镜
    //------------------------------------------------------------------------------------------------
//    _blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
//    _blendFilter.mix = 1.0;
//    [_blendFilter forceProcessingAtSize:_videoSize];
//    [units addObject:_blendFilter];
    //-------------------------------------------------------------------------------------------
    
    [units addObject:_movieWriter];
    
    [units enumerateObjectsUsingBlock:^(id<GPUImageInput> target, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx == 0) {
            [_inputDesktop addTarget:target];
        } else {
            [units[idx-1] addTarget:units[idx]];
        }
    }];
    
    //水印图片
    //------------------------------------------------------------------------------------------------
//    NSImage* img = [NSImage imageWithSize:_videoSize flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
//        [[NSColor clearColor] set];
//        NSRectFill(dstRect);
//        
//        NSString* str = [[NSDate date] description];
//        NSFont *font = [NSFont systemFontOfSize:8];
//        NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys: font, NSFontAttributeName, [NSColor redColor],NSForegroundColorAttributeName, nil];
//        [[NSColor redColor] set];
//        [str drawAtPoint:NSMakePoint(0, 0) withAttributes:attributes];
//        
//        return YES;
//    }];
//    _imageForBlending = [[GPUImagePicture alloc] initWithImage:img smoothlyScaleOutput:YES];
//    [_imageForBlending processImage];
//    [_imageForBlending addTarget:_blendFilter];
    //-------------------------------------------------------------------------------------------
    
    return YES;
}

- (void)cleanAfterRecord{
    _inputDesktop = nil;
    
    _cropFilter = nil;
    _grayscaleFilter = nil;
    
    _movieWriter = nil;
}

- (BOOL)startRecord{
    if (_recording) {
        return YES;
    }
    
    if (![self prepareForRecord]) {
        return NO;
    }
    
    [_movieWriter startRecording];
    [_inputDesktop startCameraCapture];
    
    _recording = YES;
    _currentRecordTime = 0;
    [_timer resumeTimer];
    
    NSLog(@"录屏启动成功，%@", _filename);
    
    return YES;
}

- (NSURL *)stopRecord{
    if (!_recording) {
        return nil;
    }
    
    [_inputDesktop stopCameraCapture];
    [_movieWriter finishRecording];
    
    [self cleanAfterRecord];
    
    _recording = NO;
    _paused = NO;
    [_timer pauseTimer];
    
    NSLog(@"录屏完成，%@", _filename);
    
    return [_saveDirectory URLByAppendingPathComponent:_filename];
}

- (BOOL)pauseRecord{
    if ([_movieWriter isRecording]) {
        [_inputDesktop pauseCameraCapture];
        
        _paused = YES;
        if (_timer != nil && _timer.isValid) {
            [_timer pauseTimer];
        }
        
        return YES;
    }
    
    return NO;
}

- (BOOL)resumeRecord{
    if ([_movieWriter isRecording]) {
        [_inputDesktop resumeCameraCapture];
        
        _paused = NO;
        if (_timer != nil && _timer.isValid) {
            [_timer resumeTimer];
        }
        
        return YES;
    }
    
    return NO;
}

- (void)timeUpdate{
    _recordTime++;
    _currentRecordTime++;
}

+ (ActiveDisplayList)getMonitors{
    //kCGErrorSuccess
    uint32_t maxDisplays = MAX_DISPLAY;
    static CGDirectDisplayID activeDisplayIDs[MAX_DISPLAY];
    uint32_t displayCount;
    
    if(CGGetActiveDisplayList(maxDisplays, activeDisplayIDs, &displayCount) != kCGErrorSuccess){
        NSLog(@"获取监视器列表失败.");
        return WSMakeActiveDisplayList(0, 0);
    }
    
    return WSMakeActiveDisplayList(displayCount, activeDisplayIDs);
}

- (void)invalidateTimer{
    if (_timer != nil && _timer.isValid) {
        [_timer invalidate];
        _timer = nil;
    }
}

@end

@implementation NSTimer (Pauseable)

-(void)pauseTimer{
    if (![self isValid]) {
        return ;
    }
    
    [self setFireDate:[NSDate distantFuture]]; //如果给我一个期限，我希望是4001-01-01 00:00:00 +0000
}

-(void)resumeTimer{
    if (![self isValid]) {
        return ;
    }
    
    //[self setFireDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    [self setFireDate:[NSDate date]];
}

@end