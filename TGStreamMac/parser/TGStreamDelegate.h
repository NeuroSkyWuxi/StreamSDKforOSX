/**
 @file TGStreamDelegate.h
 @discussion TGStreamDelegate header in CommunicationSDK
 @author Angelo Wang
 @version 0.7.0  3/2/15 Creation
 @copyright   Copyright (c) 2015 com.neurosky. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import "TGStreamEnum.h"

/**
 @protocol TGStreamDelegate
 @abstract TGStreamDelegate Protocol
 @discussion output data & class status
 */

@protocol TGStreamDelegate <NSObject>

/**
 @method onDataReceived
 @discussion When data received, this function will be called.
 @param datatype  type of data
 @param data  data value
 @param obj  return a obj such EEGPower instance
 @return void
 */
-(void)onDataReceived:(NSInteger)datatype data:(int)data obj:(NSObject *)obj;


@optional

-(void)onStatesChanged:(ConnectionStates)connectionState;

-(void)onChecksumFail:(Byte *)payload length:(NSUInteger)length checksum:(NSInteger)checksum;

-(void)onRecordFail:(RecrodError)flag;

-(void)eegBlink:(int)blinkValue;

@end
