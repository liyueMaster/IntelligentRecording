//
//  IRActsMonitor.m
//  IntelligentRecording
//
//  Created by 李越 on 16/3/21.
//  Copyright © 2016年 李越. All rights reserved.
//

#import "IRActsMonitor.h"
#import <ApplicationServices/ApplicationServices.h>
#import "IRApplication.h"

@interface IRActsMonitor () {
    NSUInteger _distance;    //鼠标移动距离
    
    NSUInteger _distanceBU; //before unit
    
    NSUInteger _leftClickedCount;
    NSUInteger _rightClickedCount;
    
    NSUInteger _leftClickedCountBU; //before unit
    NSUInteger _rightClickedCountBU;    //before unit
    
    NSUInteger _keyDownCount;
    
    NSUInteger _keyDownCountBU; //before unit
    
    NSTimer* _timer;
    
    id globalMonitor;
    id localMonitor;
}

@property (nonatomic,readonly) NSString* filepathForTargets;

@end

#define TARGETS_FILE @"TARGETS_FILE"

@implementation IRActsMonitor

- (instancetype)init{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _processTrusted = [self checkProcessTrusted];
    
    _distance = 0;
    _leftClickedCount = 0;
    _rightClickedCount = 0;
    _keyDownCount = 0;
    
    _distanceBU = 0;
    _leftClickedCountBU = 0;
    _rightClickedCountBU = 0;
    _keyDownCountBU = 0;
    
    _running = NO;
    _unitTime = 30;
    
    _anyoneRunning = [self isAnyoneTargetAppRunning];
    
    /*
    _filepathForTargets = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"com.IntelligentRecording"] stringByAppendingPathComponent:TARGETS_FILE];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:_filepathForTargets]) {
        _targetBundleIdentifiers = [NSMutableArray arrayWithContentsOfFile:_filepathForTargets];
    }
     */
    
    //全局事件
    globalMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSLeftMouseDownMask | NSRightMouseDownMask | NSOtherMouseDownMask | NSMouseMovedMask | NSLeftMouseDraggedMask | NSRightMouseDraggedMask | NSOtherMouseDragged | NSScrollWheelMask | NSKeyDownMask | NSFlagsChangedMask handler:^(NSEvent * _Nonnull event) {
        [self getEvent:event];
    }];
    
    //本地事件，当此程序获得焦点时，将不能接收到全局事件，只能接收到本地事件
    localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSLeftMouseDownMask | NSRightMouseDownMask | NSMouseMovedMask | NSLeftMouseDraggedMask | NSRightMouseDraggedMask | NSKeyDownMask | NSFlagsChangedMask handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        [self getEvent:event];
        return event;
    }];
    
    /*
    CFRunLoopRef theRL = CFRunLoopGetCurrent();
    CFMachPortRef keyUpEventTap = CGEventTapCreate(kCGAnnotatedSessionEventTap, kCGHeadInsertEventTap ,kCGEventTapOptionListenOnly,CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventFlagsChanged),&myCallBack,NULL);
    CFRunLoopSourceRef keyUpRunLoopSourceRef = CFMachPortCreateRunLoopSource(NULL, keyUpEventTap, 0);
    CFRelease(keyUpEventTap);
    CFRunLoopAddSource(theRL, keyUpRunLoopSourceRef, kCFRunLoopDefaultMode);
    CFRelease(keyUpRunLoopSourceRef);
    */
     
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(getApplicationDidLaunch:) name:NSWorkspaceDidLaunchApplicationNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(getApplicationDidTerminate:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
    
    //监听其他通知，后期控制监测更加准确
    [[NSWorkspace sharedWorkspace].notificationCenter addObserver:self selector:@selector(getApplicationStateChange:) name:NSWorkspaceDidHideApplicationNotification object:nil];
    [[NSWorkspace sharedWorkspace].notificationCenter addObserver:self selector:@selector(getApplicationStateChange:) name:NSWorkspaceDidUnhideApplicationNotification object:nil];
    [[NSWorkspace sharedWorkspace].notificationCenter addObserver:self selector:@selector(getApplicationStateChange:) name:NSWorkspaceDidActivateApplicationNotification object:nil];
    [[NSWorkspace sharedWorkspace].notificationCenter addObserver:self selector:@selector(getApplicationStateChange:) name:NSWorkspaceDidDeactivateApplicationNotification object:nil];
    
    return self;
}

/**
 *  检测到全局或者本地鼠标键盘事件的处理
 *
 *  @param event 事件
 */
- (void)getEvent:(NSEvent* _Nonnull)event{
    if (!_running) {
        return;
    }
    
    switch (event.type) {
        case NSLeftMouseDown:
            _leftClickedCount++;
            break;
            
        case NSRightMouseDown:
            _rightClickedCount++;
            break;
            
        case NSMouseMoved:
        case NSOtherMouseDragged:
        case NSLeftMouseDragged:
        case NSRightMouseDragged:{
            NSInteger delta = (NSInteger)sqrt(event.deltaX*event.deltaX + event.deltaY*event.deltaY);
            _distance += delta;
            break;
        }
            
        case NSScrollWheel:
        case NSOtherMouseDown:
        case NSKeyDown:
        case NSFlagsChanged:
            _keyDownCount++;
            break;
            
        default:
            break;
    }
}

/*
CGEventRef myCallBack(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo)
{
    
    UniCharCount actualStringLength = 0;
    UniChar inputString[128];
    CGEventKeyboardGetUnicodeString(event, 128, &actualStringLength, inputString);
    NSString* inputedString = [[NSString alloc] initWithBytes:(const void*)inputString length:actualStringLength encoding:NSUTF8StringEncoding];
    
    CGEventFlags flag = CGEventGetFlags(event);
    NSLog(@"inputed string:%@, flags:%lld", inputedString, flag);
    return event;
}
*/

- (BOOL)checkProcessTrusted{
    
    if (AXIsProcessTrustedWithOptions != NULL) {
        // 10.9 and later
        const void * keys[] = { kAXTrustedCheckOptionPrompt };
        const void * values[] = { kCFBooleanTrue };
        
        CFDictionaryRef options = CFDictionaryCreate(
                                                     kCFAllocatorDefault,
                                                     keys,
                                                     values,
                                                     sizeof(keys) / sizeof(*keys),
                                                     &kCFCopyStringDictionaryKeyCallBacks,
                                                     &kCFTypeDictionaryValueCallBacks);
        
        return AXIsProcessTrustedWithOptions(options);
    }
    
    // OS X 10.8 and older
    return AXAPIEnabled();
}

- (void)toMakeProcessTrusted{
    if (!_processTrusted) {
        
        NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
        NSString *currentVersion = [NSString stringWithFormat:@"%ld.%ld.%ld", version.majorVersion, version.minorVersion, version.patchVersion];
        NSLog(@"请允许程序控制您的计算机，并重新启动程序，以便获得更详尽的数据...\n当前系统：%@", currentVersion);
        
        if ([currentVersion compare:@"10.9" options:NSNumericSearch] == NSOrderedAscending) {
            AXError error = AXMakeProcessTrusted((__bridge CFStringRef _Nonnull)([NSBundle mainBundle].executablePath));
            if (error) {
                NSLog(@"获取权限失败，错误代码：%d", error);
            } else {
                NSLog(@"恭喜你，成功获取控制权限...");
            }
        } else {
            NSString *urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
        }
        
//        NSRunningApplication* app = [NSRunningApplication currentApplication];
//        
//        AXError error = AXMakeProcessTrusted((__bridge CFStringRef _Nonnull)(app.executableURL.path));
//        
//        if (error == kAXErrorSuccess) {
//            NSLog(@"获取控制权限成功，请重新启动应用...");
//        } else {
//            NSLog(@"%d", (int)error);
//        }
        
    }
}

- (void)updatePerUnit{
    //计算当前计数周期内的净增长
    NSUInteger distance = _distance - _distanceBU;
    NSUInteger leftCC = _leftClickedCount - _leftClickedCountBU;
    NSUInteger rightCC = _rightClickedCount - _rightClickedCountBU;
    NSUInteger keyDC = _keyDownCount - _keyDownCountBU;
    
    //记录更新，准备下一个计数周期
    _distanceBU = _distance;
    _leftClickedCountBU = _leftClickedCount;
    _rightClickedCountBU = _rightClickedCount;
    _keyDownCountBU = _keyDownCount;
    
    if ([self.delegate respondsToSelector:@selector(monitor:unitTime:receivedMouseMove:mouseClickedLeft:right:receivedKeyDown:processTrusted:)]) {
        [self.delegate monitor:self unitTime:_unitTime receivedMouseMove:distance mouseClickedLeft:leftCC right:rightCC receivedKeyDown:keyDC processTrusted:_processTrusted];
    }
}

- (void)getApplicationDidLaunch:(NSNotification *)not{
    /**
     *  the keys of notification userInfo dictionary
     *
     *  NSApplicationBundleIdentifier = "com.apple.systempreferences";
     *  NSApplicationName = "\U7cfb\U7edf\U504f\U597d\U8bbe\U7f6e";
     *  NSApplicationPath = "/Applications/System Preferences.app";
     *  NSApplicationProcessIdentifier = 998;
     *  NSApplicationProcessSerialNumberHigh = 0;
     *  NSApplicationProcessSerialNumberLow = 368730;
     *  NSWorkspaceApplicationKey = "<NSRunningApplication: 0x600000100ab0 (com.apple.systempreferences - 998)>";
     */
    
    NSRunningApplication* runnningApp = [not.userInfo objectForKey:@"NSWorkspaceApplicationKey"];
    
    if ([self isAppSelected:runnningApp]) {
        
        _anyoneRunning = YES;
        
        if (_running && [self.delegate respondsToSelector:@selector(monitor:applicationDidLaunch:)]) {
            [self.delegate monitor:self applicationDidLaunch:runnningApp];
        }
    }
}

- (void)getApplicationDidTerminate:(NSNotification *)not{
    
    NSRunningApplication* runnningApp = [not.userInfo objectForKey:@"NSWorkspaceApplicationKey"];
    
    if ([self isAppSelected:runnningApp]) {
        
        _anyoneRunning = [self isAnyoneTargetAppRunning];
        
        if (_running && [self.delegate respondsToSelector:@selector(monitor:applicationDidTerminate:)]) {
            [self.delegate monitor:self applicationDidTerminate:runnningApp];
        }
    }
}

- (void)getApplicationStateChange:(NSNotification *)not {
    NSRunningApplication* runnningApp = [not.userInfo objectForKey:@"NSWorkspaceApplicationKey"];
    NSLog(@"%@ %@", runnningApp.localizedName, not.name);
    NSLog(@"userInfo:\n%@", not.userInfo);
    NSLog(@"object:%@", not.object);
}

- (BOOL)start{
    _timer = [NSTimer timerWithTimeInterval:_unitTime target:self selector:@selector(updatePerUnit) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    
    _running = (_timer && _timer.isValid);
    
    return _running;
}

- (BOOL)stop{
    if (_timer.isValid) {
        [_timer invalidate];
    }
    _timer = nil;
    
    _running = (_timer && _timer.isValid);
    
    return _running;
}

/**
 *  是否有正在运行的监控目标，使用数据库进行匹配，物理保证准确
 *
 *  @return 当且仅当所有的目标程序都处于退出状态，才返回 NO，否则返回 YES
 */
- (BOOL)isAnyoneTargetAppRunning{
    __block BOOL hasAnyone = NO;
    
    NSArray<IRApplication *>* selectedApps = [IRApplication allSelectedApplications];
    
    [[IRApplication runningApplications] enumerateObjectsUsingBlock:^(IRApplication * _Nullable obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([selectedApps containsApp:obj]) {
            hasAnyone = YES;
            *stop = YES;
        }
    }];
    
    return hasAnyone;
}

- (void)setUnitTime:(NSInteger)unitTime{
    if (unitTime < 1) {
        return;
    }
    _unitTime = unitTime;
    
    if (_timer != nil) {
        if (_timer.isValid) {
            [_timer invalidate];
        }
        _timer = nil;
    }
    
    if (_running && _timer == nil) {
        _timer = [NSTimer timerWithTimeInterval:_unitTime target:self selector:@selector(updatePerUnit) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    }
}

+ (NSArray<NSApplication *> *)getInstalledApplications{

#warning miss implementation for + (NSArray<NSApplication *> *)getInstalledApplications
    NSAssert(NO, @"等待实现的方法...");
    
    return nil;
}

/**
 *  判断给定的 NSRunningApplication 是否在被用户指定
 *
 *  @param app 给定的 app
 *
 *  @return 存在返回 YES，反之 NO
 */
- (BOOL)isAppSelected:(NSRunningApplication *)app{
    IRApplication* iapp = [[IRApplication alloc] initWithRunningApp:app];
    
    if (iapp == nil) {
        return NO;
    }
    
    iapp = [iapp exist];
    
    return iapp != nil && iapp.isSelected;
}

+ (NSArray<NSRunningApplication *> *)getRunningApplications{
    return [[NSWorkspace sharedWorkspace] runningApplications];
}

- (void)dealloc{
    if (_timer.isValid) {
        [_timer invalidate];
    }
    
    [NSEvent removeMonitor:globalMonitor];
    [NSEvent removeMonitor:localMonitor];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

@end