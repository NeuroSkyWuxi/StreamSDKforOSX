//
//  EEGPower.m
//  CommunicationSDK
//
//  Created by Angelo on 2/28/15.
//  Copyright (c) 2015 com.neurosky. All rights reserved.
//

#import "TGSEEGPower.h"

static const int EEGPower_LENGTH = 24;
static const int EEGPower_RESUlT_LENGTH = EEGPower_LENGTH / 3;

@implementation TGSEEGPower
{
    bool isValidate;
    int    result[EEGPower_RESUlT_LENGTH];
}

- (instancetype)initWithBytes:(Byte *)arr st:(int)start len:(int)length
{
    self = [super init];
    
    if((length == EEGPower_LENGTH) && (start + length <= 256))
    {
        isValidate = true;
        
    }else
    {
        isValidate = false;
        return self;
        
    }
    
    if (self)
    {
        for(int i = 0; i<EEGPower_RESUlT_LENGTH; i++ )
        {
            result[i] = [self getEEGPowerValue:arr[start + i*3 +0] mOByte:arr[start + i*3 + 1] lOByte:arr[start + i*3 +2]];
        }
        
        _delta = result[0];
        _theta = result[1];
        _lowAlpha = result[2];
        _highAlpha = result[3];
        _lowBeta = result[4];
        _highBeta = result[5];
        _lowGamma = result[6];
        _middleGamma = result[7];
    }
    
    return self;
}


-(bool)isValidate
{
    return isValidate;
}

-(int)getEEGPowerValue:(Byte)highOrderByte mOByte:(Byte)middleOrderByte lOByte:(Byte)lowOrderByte
{
    int value = (highOrderByte << 16 | middleOrderByte << 8 | lowOrderByte) & 0xFFFFFF;
    return value;
}

@end
