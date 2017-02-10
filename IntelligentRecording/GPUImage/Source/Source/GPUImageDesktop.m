//
//  GPUImageDesktop.m
//  GPUImageMac
//
//  Created by 李越 on 15/12/31.
//  Copyright © 2015年 Sunset Lake Software LLC. All rights reserved.
//
#import "GPUImageDesktop.h"
#import "GPUImageMovieWriter.h"
#import "GPUImageFilter.h"
#import "GPUImageColorConversion.h"

#pragma mark -
#pragma mark Private methods and instance variables

@interface GPUImageDesktop ()
{
    NSDate *startingCaptureTime;
    
    NSInteger _frameRate;
    
    dispatch_queue_t cameraProcessingQueue;
    
    GLProgram *yuvConversionProgram;
    GLint yuvConversionPositionAttribute, yuvConversionTextureCoordinateAttribute;
    GLint yuvConversionLuminanceTextureUniform, yuvConversionChrominanceTextureUniform;
    
    int imageBufferWidth, imageBufferHeight;
    
    CMTimeValue lastVideoTimeValue;
    CMTimeValue lastReallyTimeValue;
    CMTimeValue pausedTimeValue;
    
    NSInteger ignoredFramesCount;
    
    //水印
    CIContext* ciContext;
    NSDateFormatter *formatter;
    NSFont *font;
    NSDictionary* attributes;
    
    NSInteger minorVersion;
}

- (void)convertYUVToRGBOutput;

@end

@implementation GPUImageDesktop

@synthesize captureSessionPreset = _captureSessionPreset;
@synthesize captureSession = _captureSession;
@synthesize displayId = _displayId;
@synthesize runBenchmark = _runBenchmark;
@synthesize delegate = _delegate;

#pragma mark -
#pragma mark Initialization and teardown

- (id)initWithSessionPreset:(NSString *)sessionPreset displayId:(CGDirectDisplayID)displayId
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    lastVideoTimeValue = 0;
    lastReallyTimeValue = 0;
    pausedTimeValue = 0;
    _watermark = YES;
    minorVersion = [NSProcessInfo processInfo].operatingSystemVersion.minorVersion;
    
    ciContext = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @NO}];
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    font = [NSFont systemFontOfSize:24];
    attributes = [NSDictionary dictionaryWithObjectsAndKeys: font, NSFontAttributeName, [NSColor redColor],NSForegroundColorAttributeName, nil];
    
    cameraProcessingQueue = dispatch_queue_create("com.sunsetlakesoftware.GPUImage.cameraProcessingQueue", NULL);
    
    frameRenderingSemaphore = dispatch_semaphore_create(1);
    
    _frameRate = 0; // This will not set frame rate unless this value gets set to 1 or above
    _runBenchmark = NO;
    capturePaused = NO;
    outputRotation = kGPUImageNoRotation;
    //    captureAsYUV = YES;
    captureAsYUV = NO;
    
    runSynchronouslyOnVideoProcessingQueue(^{
        
        if (captureAsYUV)
        {
            [GPUImageContext useImageProcessingContext];
            //            if ([GPUImageContext deviceSupportsRedTextures])
            //            {
            //                yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVVideoRangeConversionForRGFragmentShaderString];
            //            }
            //            else
            //            {
            yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVVideoRangeConversionForLAFragmentShaderString];
            //            }
            
            if (!yuvConversionProgram.initialized)
            {
                [yuvConversionProgram addAttribute:@"position"];
                [yuvConversionProgram addAttribute:@"inputTextureCoordinate"];
                
                if (![yuvConversionProgram link])
                {
                    NSString *progLog = [yuvConversionProgram programLog];
                    NSLog(@"Program link log: %@", progLog);
                    NSString *fragLog = [yuvConversionProgram fragmentShaderLog];
                    NSLog(@"Fragment shader compile log: %@", fragLog);
                    NSString *vertLog = [yuvConversionProgram vertexShaderLog];
                    NSLog(@"Vertex shader compile log: %@", vertLog);
                    yuvConversionProgram = nil;
                    NSAssert(NO, @"Filter shader link failed");
                }
            }
            
            yuvConversionPositionAttribute = [yuvConversionProgram attributeIndex:@"position"];
            yuvConversionTextureCoordinateAttribute = [yuvConversionProgram attributeIndex:@"inputTextureCoordinate"];
            yuvConversionLuminanceTextureUniform = [yuvConversionProgram uniformIndex:@"luminanceTexture"];
            yuvConversionChrominanceTextureUniform = [yuvConversionProgram uniformIndex:@"chrominanceTexture"];
            
            [GPUImageContext setActiveShaderProgram:yuvConversionProgram];
            
            glEnableVertexAttribArray(yuvConversionPositionAttribute);
            glEnableVertexAttribArray(yuvConversionTextureCoordinateAttribute);
        }
    });
    
    // Grab the back-facing or front-facing camera
    if (displayId == 0) {
        _displayId = kCGDirectMainDisplay;
    }else{
        _displayId = displayId;
    }
    
    //加速倍数，适用于延时录屏，1表示不加速
    _timescale = 1;
    
    // Create the capture session
    _captureSession = [[AVCaptureSession alloc] init];
    
    [_captureSession beginConfiguration];
    
    // Add the video input
    videoInput = [[AVCaptureScreenInput alloc] initWithDisplayID:_displayId];
    if ([_captureSession canAddInput:videoInput])
    {
        [_captureSession addInput:videoInput];
    }
    
    // Add the video frame output
    videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoOutput setAlwaysDiscardsLateVideoFrames:NO];
    
    //    NSLog(@"Camera: %@", _inputCamera);
    //    [self printSupportedPixelFormats];
    
    //    if (captureAsYUV && [GPUImageContext deviceSupportsRedTextures])
    if (captureAsYUV && [GPUImageContext supportsFastTextureUpload])
    {
        BOOL supportsFullYUVRange = NO;
        NSArray *supportedPixelFormats = videoOutput.availableVideoCVPixelFormatTypes;
        for (NSNumber *currentPixelFormat in supportedPixelFormats)
        {
            if ([currentPixelFormat intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            {
                supportsFullYUVRange = YES;
            }
        }
        
        if (supportsFullYUVRange)
        {
            [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        }
        else
        {
            [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        }
    }
    else
    {
        // Despite returning a longer list of supported pixel formats, only RGB, RGBA, BGRA, and the YUV 4:2:2 variants seem to return cleanly
        [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        //        [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr8_yuvs] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    }
    
    [videoOutput setSampleBufferDelegate:self queue:cameraProcessingQueue];
    //    [videoOutput setSampleBufferDelegate:self queue:[GPUImageContext sharedContextQueue]];
    if ([_captureSession canAddOutput:videoOutput])
    {
        [_captureSession addOutput:videoOutput];
    }
    else
    {
        NSLog(@"Couldn't add video output");
        return nil;
    }
    
    _captureSessionPreset = sessionPreset;
    [_captureSession setSessionPreset:_captureSessionPreset];
    
    // This will let you get 60 FPS video from the 720p preset on an iPhone 4S, but only that device and that preset
    //    AVCaptureConnection *conn = [videoOutput connectionWithMediaType:AVMediaTypeVideo];
    //
    //    if (conn.supportsVideoMinFrameDuration)
    //        conn.videoMinFrameDuration = CMTimeMake(1,60);
    //    if (conn.supportsVideoMaxFrameDuration)
    //        conn.videoMaxFrameDuration = CMTimeMake(1,60);
    
    [_captureSession commitConfiguration];
    
    return self;
}

- (void)dealloc
{
    [self stopCameraCapture];
    [videoOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
    
    [self removeInputsAndOutputs];
    
    ciContext = nil;
    formatter = nil;
    font = nil;
    attributes = nil;
    frameRenderingSemaphore = 0;
    
    // ARC forbids explicit message send of 'release'; since iOS 6 even for dispatch_release() calls: stripping it out in that case is required.
    //#if ( (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0) || (!defined(__IPHONE_6_0)) )
#if __MAC_OS_X_VERSION_MAX_ALLOWED <= __MAC_10_7
    if (cameraProcessingQueue != NULL)
    {
        dispatch_release(cameraProcessingQueue);
    }
    
    if (frameRenderingSemaphore != NULL)
    {
        dispatch_release(frameRenderingSemaphore);
    }
#endif
}

- (void)removeInputsAndOutputs;
{
    [_captureSession removeInput:videoInput];
    [_captureSession removeOutput:videoOutput];
}

#pragma mark -
#pragma mark Managing targets

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation;
{
    [super addTarget:newTarget atTextureLocation:textureLocation];
    
    [newTarget setInputRotation:outputRotation atIndex:textureLocation];
}

#pragma mark -
#pragma mark Manage the camera video stream

- (void)startCameraCapture;
{
    if (![_captureSession isRunning])
    {
        startingCaptureTime = [NSDate date];
        [_captureSession startRunning];
    };
}

- (void)stopCameraCapture;
{
    if ([_captureSession isRunning])
    {
        [_captureSession stopRunning];
    }
}

- (void)pauseCameraCapture;
{
    capturePaused = YES;
}

- (void)resumeCameraCapture;
{
    capturePaused = NO;
}

- (void)setCaptureSessionPreset:(NSString *)captureSessionPreset;
{
    [_captureSession beginConfiguration];
    
    _captureSessionPreset = captureSessionPreset;
    [_captureSession setSessionPreset:_captureSessionPreset];
    
    [_captureSession commitConfiguration];
}

- (void)setFrameRate:(NSInteger)frameRate;
{
    _frameRate = frameRate;
    
    /**
    if (_frameRate > 0)
    {
        for (AVCaptureConnection *connection in videoOutput.connections)
        {
            if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)]){
                
                //connection.videoMinFrameDuration = CMTimeMake((int64_t)(_timescale<1?1:_timescale), (int32_t)_frameRate);
                
                connection.videoMinFrameDuration = CMTimeMake(1, (int32_t)_frameRate);
                
            }
        }
    }
    else
    {
        for (AVCaptureConnection *connection in videoOutput.connections)
        {
            if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
                connection.videoMinFrameDuration = kCMTimeInvalid; // This sets videoMinFrameDuration back to default
        }
    }
     
     */
    
    videoInput.minFrameDuration = CMTimeMake(1, (int32_t)_frameRate);
    //videoInput.minFrameDuration = CMTimeMake((int64_t)(_timescale<1?1:_timescale), (int32_t)_frameRate);
}

- (NSInteger)frameRate;
{
    return _frameRate;
}

- (void)setTimescale:(NSInteger)timescale{
    if (timescale > 0) {
        _timescale = timescale;
        
        //[self setFrameRate:timescale];
        ignoredFramesCount = 0;
    }
}

- (void)setCapturesMouseClicks:(BOOL)capturesMouseClicks{
    videoInput.capturesMouseClicks = capturesMouseClicks;
}

- (AVCaptureConnection *)videoCaptureConnection {
    for (AVCaptureConnection *connection in [videoOutput connections] ) {
        for ( AVCaptureInputPort *port in [connection inputPorts] ) {
            if ( [[port mediaType] isEqual:AVMediaTypeVideo] ) {
                return connection;
            }
        }
    }
    
    return nil;
}

#define INITIALFRAMESTOIGNOREFORBENCHMARK 5

- (void)updateTargetsForVideoCameraUsingCacheTextureAtWidth:(int)bufferWidth height:(int)bufferHeight time:(CMTime)currentTime;
{
    // First, update all the framebuffers in the targets
    for (id<GPUImageInput> currentTarget in targets)
    {
        if ([currentTarget enabled])
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            if (currentTarget != self.targetToIgnoreForUpdates)
            {
                [currentTarget setInputRotation:outputRotation atIndex:textureIndexOfTarget];
                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:textureIndexOfTarget];
                
                if ([currentTarget wantsMonochromeInput] && captureAsYUV)
                {
                    [currentTarget setCurrentlyReceivingMonochromeInput:YES];
                    // TODO: Replace optimization for monochrome output
                    [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
                }
                else
                {
                    [currentTarget setCurrentlyReceivingMonochromeInput:NO];
                    [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
                }
            }
            else
            {
                [currentTarget setInputRotation:outputRotation atIndex:textureIndexOfTarget];
                [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
            }
        }
    }
    
    // Then release our hold on the local framebuffer to send it back to the cache as soon as it's no longer needed
    [outputFramebuffer unlock];
    
    // Finally, trigger rendering as needed
    for (id<GPUImageInput> currentTarget in targets)
    {
        if ([currentTarget enabled])
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            if (currentTarget != self.targetToIgnoreForUpdates)
            {
                [currentTarget newFrameReadyAtTime:currentTime atIndex:textureIndexOfTarget];
            }
        }
    }
}

- (CGImageRef)createCGImageRefFromNSImage:(NSImage*)image;
{
    NSData *imageData;
    CGImageRef imageRef;
    @try {
        imageData = [image TIFFRepresentation];
        if (imageData) {
            CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
            NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
                                     (id)kCFBooleanFalse, (id)kCGImageSourceShouldCache,
                                     (id)kCFBooleanTrue, (id)kCGImageSourceShouldAllowFloat,
                                     nil];
            
            //要用这个带option的 kCGImageSourceShouldCache指出不需要系统做cache操作 默认是会做的
            imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, (__bridge CFDictionaryRef)options);
            CFRelease(imageSource);
            return imageRef;
        }else{
            return NULL;
        }
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
    
    return NULL;
}

- (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
{
    if (ignoredFramesCount++ != 0) {
        if (ignoredFramesCount >= _timescale) {
            ignoredFramesCount = 0;
        }
        
        return;
    }
    
    
    CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    if (capturePaused)
    {
        //暂停，记录实际时间，防止画面暂停，但是时间仍然在继续的情况
        lastReallyTimeValue = currentTime.value;
        return;
    }
    
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    GLsizei bufferWidth = (GLsizei)CVPixelBufferGetWidth(cameraFrame);
    GLsizei bufferHeight = (GLsizei)CVPixelBufferGetHeight(cameraFrame);
    
    //CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    //去掉时间为0的帧，出现在第一帧，为什么？
    if(currentTime.value == 0){
        return;
    }
    
    //--------------------延时录屏----------------------------------
    //每一帧的时间都单独计算，将常规录屏看作延时为1的延时录屏，统一计算
    
    CMTimeValue temp = currentTime.value;
    
    //--改变时间，延时录屏 value: x => x/a
    currentTime.value = (currentTime.value - lastReallyTimeValue) / _timescale + lastVideoTimeValue;
    
    lastReallyTimeValue = temp;
    lastVideoTimeValue = currentTime.value;
    
    //--------------------延时录屏----------------------------------
    
    
    
    //--------------------------水印文字-----------------------------
    
    //NSLog(@"%ld.%ld.%ld", [NSProcessInfo processInfo].operatingSystemVersion.majorVersion, [NSProcessInfo processInfo].operatingSystemVersion.minorVersion, [NSProcessInfo processInfo].operatingSystemVersion.patchVersion);
    if (minorVersion >= 11 && _watermark) {
        //CVPixelBufferRef pixBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(cameraFrame, 0);
        
        NSString *currentDateStr = [formatter stringFromDate:[NSDate date]];
        NSSize textSize = [currentDateStr sizeWithAttributes:attributes];
        
        NSImage* img = [NSImage imageWithSize:textSize flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
            [[NSColor redColor] set];
            [currentDateStr drawAtPoint:NSMakePoint(0, 0) withAttributes:attributes];
            return YES;
        }];
        currentDateStr = nil;
        
        CGImageRef cgImg = [self createCGImageRefFromNSImage:img];
        img = nil;
        
        CIImage* ciImage = [[CIImage alloc] initWithCGImage:cgImg];
        
        CFRelease(cgImg);
        
        [ciContext render:ciImage toCVPixelBuffer:cameraFrame /*bounds:[ciImage extent] colorSpace:CGColorSpaceCreateDeviceRGB()*/];
        
        CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
    }
    
    //----------------------------------------------------------------
    
     
    [GPUImageContext useImageProcessingContext];
    
    CVPixelBufferLockBaseAddress(cameraFrame, 0);
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(bufferWidth, bufferHeight) onlyTexture:YES];
    
    glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
    
    //        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bufferWidth, bufferHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(cameraFrame));
    
    // Using BGRA extension to pull in video frame data directly
    //    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, bytesPerRow / 3, bufferHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(cameraFrame));
    //	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bufferWidth, bufferHeight, 0, GL_YCBCR_422_APPLE, GL_UNSIGNED_SHORT_8_8_REV_APPLE, CVPixelBufferGetBaseAddress(cameraFrame));
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bufferWidth, bufferHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(cameraFrame));
    
    [self updateTargetsForVideoCameraUsingCacheTextureAtWidth:bufferWidth height:bufferHeight time:currentTime];
    
    //    for (id<GPUImageInput> currentTarget in targets)
    //    {
    //        if ([currentTarget enabled])
    //        {
    //            if (currentTarget != self.targetToIgnoreForUpdates)
    //            {
    //                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
    //                NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
    //
    //                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:textureIndexOfTarget];
    //                [currentTarget newFrameReadyAtTime:currentTime atIndex:textureIndexOfTarget];
    //            }
    //        }
    //    }
    
    CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
    
    if (_runBenchmark)
    {
        numberOfFramesCaptured++;
        if (numberOfFramesCaptured > INITIALFRAMESTOIGNOREFORBENCHMARK)
        {
            CFAbsoluteTime currentFrameTime = (CFAbsoluteTimeGetCurrent() - startTime);
            totalFrameTimeDuringCapture += currentFrameTime;
            NSLog(@"Average frame time : %f ms", [self averageFrameDurationDuringCapture]);
            NSLog(@"Current frame time : %f ms", 1000.0 * currentFrameTime);
        }
    }
}

- (void)convertYUVToRGBOutput;
{
    [GPUImageContext setActiveShaderProgram:yuvConversionProgram];
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(imageBufferWidth, imageBufferHeight) textureOptions:self.outputTextureOptions onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    static const GLfloat textureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, luminanceTexture);
    glUniform1i(yuvConversionLuminanceTextureUniform, 4);
    
    glActiveTexture(GL_TEXTURE5);
    glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
    glUniform1i(yuvConversionChrominanceTextureUniform, 5);
    
    glVertexAttribPointer(yuvConversionPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

#pragma mark -
#pragma mark Benchmarking

- (CGFloat)averageFrameDurationDuringCapture;
{
    return (totalFrameTimeDuringCapture / (CGFloat)(numberOfFramesCaptured - INITIALFRAMESTOIGNOREFORBENCHMARK)) * 1000.0;
}

#pragma mark -
#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (dispatch_semaphore_wait(frameRenderingSemaphore, DISPATCH_TIME_NOW) != 0)
    {
        return;
    }
    
    CFRetain(sampleBuffer);
    runAsynchronouslyOnVideoProcessingQueue(^{
        //Feature Detection Hook.
        if (self.delegate && [self.delegate respondsToSelector:@selector(willOutputSampleBuffer:)])
        {
            [self.delegate willOutputSampleBuffer:sampleBuffer];
        }
        
        [self processVideoSampleBuffer:sampleBuffer];
        
        CFRelease(sampleBuffer);
        dispatch_semaphore_signal(frameRenderingSemaphore);
    });
}

#pragma mark -
#pragma mark Accessors

- (void)printSupportedPixelFormats;
{
    NSArray *supportedPixelFormats = videoOutput.availableVideoCVPixelFormatTypes;
    for (NSNumber *currentPixelFormat in supportedPixelFormats)
    {
        NSString *pixelFormatName = nil;
        
        switch([currentPixelFormat intValue])
        {
            case kCVPixelFormatType_1Monochrome: pixelFormatName = @"kCVPixelFormatType_1Monochrome"; break;
            case kCVPixelFormatType_2Indexed: pixelFormatName = @"kCVPixelFormatType_2Indexed"; break;
            case kCVPixelFormatType_4Indexed: pixelFormatName = @"kCVPixelFormatType_4Indexed"; break;
            case kCVPixelFormatType_8Indexed: pixelFormatName = @"kCVPixelFormatType_8Indexed"; break;
            case kCVPixelFormatType_1IndexedGray_WhiteIsZero: pixelFormatName = @"kCVPixelFormatType_1IndexedGray_WhiteIsZero"; break;
            case kCVPixelFormatType_2IndexedGray_WhiteIsZero: pixelFormatName = @"kCVPixelFormatType_2IndexedGray_WhiteIsZero"; break;
            case kCVPixelFormatType_4IndexedGray_WhiteIsZero: pixelFormatName = @"kCVPixelFormatType_4IndexedGray_WhiteIsZero"; break;
            case kCVPixelFormatType_8IndexedGray_WhiteIsZero: pixelFormatName = @"kCVPixelFormatType_8IndexedGray_WhiteIsZero"; break;
            case kCVPixelFormatType_16BE555: pixelFormatName = @"kCVPixelFormatType_16BE555"; break;
            case kCVPixelFormatType_16LE555: pixelFormatName = @"kCVPixelFormatType_16LE555"; break;
            case kCVPixelFormatType_16LE5551: pixelFormatName = @"kCVPixelFormatType_16LE5551"; break;
            case kCVPixelFormatType_16BE565: pixelFormatName = @"kCVPixelFormatType_16BE565"; break;
            case kCVPixelFormatType_16LE565: pixelFormatName = @"kCVPixelFormatType_16LE565"; break;
            case kCVPixelFormatType_24RGB: pixelFormatName = @"kCVPixelFormatType_24RGB"; break;
            case kCVPixelFormatType_24BGR: pixelFormatName = @"kCVPixelFormatType_24BGR"; break;
            case kCVPixelFormatType_32ARGB: pixelFormatName = @"kCVPixelFormatType_32ARGB"; break;
            case kCVPixelFormatType_32BGRA: pixelFormatName = @"kCVPixelFormatType_32BGRA"; break;
            case kCVPixelFormatType_32ABGR: pixelFormatName = @"kCVPixelFormatType_32ABGR"; break;
            case kCVPixelFormatType_32RGBA: pixelFormatName = @"kCVPixelFormatType_32RGBA"; break;
            case kCVPixelFormatType_64ARGB: pixelFormatName = @"kCVPixelFormatType_64ARGB"; break;
            case kCVPixelFormatType_48RGB: pixelFormatName = @"kCVPixelFormatType_48RGB"; break;
            case kCVPixelFormatType_32AlphaGray: pixelFormatName = @"kCVPixelFormatType_32AlphaGray"; break;
            case kCVPixelFormatType_16Gray: pixelFormatName = @"kCVPixelFormatType_16Gray"; break;
            case kCVPixelFormatType_30RGB: pixelFormatName = @"kCVPixelFormatType_30RGB"; break;
            case kCVPixelFormatType_422YpCbCr8: pixelFormatName = @"kCVPixelFormatType_422YpCbCr8"; break;
            case kCVPixelFormatType_4444YpCbCrA8: pixelFormatName = @"kCVPixelFormatType_4444YpCbCrA8"; break;
            case kCVPixelFormatType_4444YpCbCrA8R: pixelFormatName = @"kCVPixelFormatType_4444YpCbCrA8R"; break;
            case kCVPixelFormatType_4444AYpCbCr8: pixelFormatName = @"kCVPixelFormatType_4444AYpCbCr8"; break;
            case kCVPixelFormatType_4444AYpCbCr16: pixelFormatName = @"kCVPixelFormatType_4444AYpCbCr16"; break;
            case kCVPixelFormatType_444YpCbCr8: pixelFormatName = @"kCVPixelFormatType_444YpCbCr8"; break;
            case kCVPixelFormatType_422YpCbCr16: pixelFormatName = @"kCVPixelFormatType_422YpCbCr16"; break;
            case kCVPixelFormatType_422YpCbCr10: pixelFormatName = @"kCVPixelFormatType_422YpCbCr10"; break;
            case kCVPixelFormatType_444YpCbCr10: pixelFormatName = @"kCVPixelFormatType_444YpCbCr10"; break;
            case kCVPixelFormatType_420YpCbCr8Planar: pixelFormatName = @"kCVPixelFormatType_420YpCbCr8Planar"; break;
            case kCVPixelFormatType_420YpCbCr8PlanarFullRange: pixelFormatName = @"kCVPixelFormatType_420YpCbCr8PlanarFullRange"; break;
            case kCVPixelFormatType_422YpCbCr_4A_8BiPlanar: pixelFormatName = @"kCVPixelFormatType_422YpCbCr_4A_8BiPlanar"; break;
            case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: pixelFormatName = @"kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange"; break;
            case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: pixelFormatName = @"kCVPixelFormatType_420YpCbCr8BiPlanarFullRange"; break;
            case kCVPixelFormatType_422YpCbCr8_yuvs: pixelFormatName = @"kCVPixelFormatType_422YpCbCr8_yuvs"; break;
            case kCVPixelFormatType_422YpCbCr8FullRange: pixelFormatName = @"kCVPixelFormatType_422YpCbCr8FullRange"; break;
            case kCVPixelFormatType_OneComponent8: pixelFormatName = @"kCVPixelFormatType_OneComponent8"; break;
            case kCVPixelFormatType_TwoComponent8: pixelFormatName = @"kCVPixelFormatType_TwoComponent8"; break;
        }
        NSLog(@"Supported pixel format: %@", pixelFormatName);
    }
}

@end
