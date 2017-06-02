//
//  thinkGear.h
//  blueToothMac
//
//  Created by peterwang on 7/23/15.
//  Copyright (c) 2015 NeuroSky. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOBluetooth/IOBluetooth.h>

#import "TGStreamDelegate.h"

typedef NS_ENUM(NSUInteger, SendCMDType) {
    SendCMDTypeNone = 0,
    SendCMDTypeReadBaud,
    SendCMDTypeChangeBaudTo_576000,
    SendCMDTypeChangeBaudTo_1152000,
    SendCMDTypeReadNotch,
    SendCMDTypeChangeNotchTo_50,
    SendCMDTypeChangeNotchTo_60
};

@interface TGStreamForMac : NSObject<TGStreamDelegate,NSStreamDelegate>

@property (unsafe_unretained)   id<TGStreamDelegate> delegate;

// default portPath is "/dev/tty.MindWaveMobile-SerialPo".
+ (TGStreamForMac *) sharedInstance;

//init with port path
+ (TGStreamForMac *) sharedInstance:(NSString *)portPath;

- (NSString *) getVerison;

- (void) startStream;
- (void) stopStream;

- (void) initStreamWithFile:(NSString *)filePath;

- (void) setRecordStreamFilePath;
- (void) setRecordStreamFilePath:(NSString *)filePath;

- (void) startRecordRawData;
- (void) stopRecordRawData;

-(void)sendCommand:(SendCMDType)cmdType;

- (void) enableLog:(BOOL)enabled;

@end
