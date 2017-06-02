//
//  Parser.m
//  CommunicationSDK
//
//  Created by Angelo on 2/28/15.
//  Copyright (c) 2015 com.neurosky. All rights reserved.
//

#import "TGSNormalParser.h"
#import "TGStreamEnum.h"
#import "TGSEEGPower.h"

#import "TGBlink.h"


typedef NS_ENUM(NSUInteger, PARSER_CODE){

    PARSER_CODE_POOR_SIGNAL = 2,
    PARSER_CODE_HEARTRATE = 3,
    PARSER_CODE_ATTENTION = 4,
    PARSER_CODE_MEDITATION = 5,
    PARSER_CODE_RAW = 0x80,
    PARSER_CODE_EEGPOWER = 0x83,
    PARSER_CODE_DEBUG_ONE = 132,
    PARSER_CODE_DEBUG_TWO = 133,
    PARSER_CODE_CMD_BAUD = 0xBA, // for Baud Value
    PARSER_CODE_CMD_NOTCH = 0xBC // for Notch Filter
    
};


// static and const variable
static const  NSInteger RAW_DATA_BYTE_LENGTH = 2;

static const  NSInteger EEG_DEBUG_ONE_BYTE_LENGTH = 5;
static const  NSInteger EEG_DEBUG_TWO_BYTE_LENGTH = 3;

static const  NSInteger PARSER_SYNC_BYTE = 170;
static const  NSInteger PARSER_EXCODE_BYTE = 85;

static const  NSInteger MULTI_BYTE_CODE_THRESHOLD = 127;


static int globalSignal;

@implementation TGSNormalParser
{
    TGBlink *blink;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        payload = (Byte*)malloc(256);
        parserStatus = PARSER_STATE_SYNC;
        
        //angelo: output blink value if exists! 160711
        blink = [[TGBlink alloc] init];
        NSLog(@"init blink ...");
    }
    return self;
}

-(void)parse:(NSData *)dataByte
{

    int length = 0;
    //-NSLog(@"dataByte: %@", dataByte);
    
    buffer = (Byte *)[dataByte bytes];
    length = (int)[dataByte length];
    
    for(int i = 0; i < length; i ++){
        chrisbuffer = buffer[i];
        
        switch (parserStatus)
        {
            case PARSER_STATE_SYNC:
                if (TGSenableLogsFlag)  NSLog(@"%@ parse state  PARSER_STATE_SYNC",TGSSDKLogPrefix);
           //     NSLog(@"%@ parse state  PARSER_STATE_SYNC",TGSSDKLogPrefix);
                
                if ((chrisbuffer & 0xFF) != PARSER_SYNC_BYTE)
                    break;
                parserStatus = PARSER_STATE_SYNC_CHECK;
                break;
                
            case PARSER_STATE_SYNC_CHECK:
                if (TGSenableLogsFlag)  NSLog(@"%@ parse state  PARSER_STATE_SYNC_CHECK",TGSSDKLogPrefix);
           //     NSLog(@"%@ parse state  PARSER_STATE_SYNC_CHECK",TGSSDKLogPrefix);

                if ((chrisbuffer & 0xFF) == PARSER_SYNC_BYTE)
                    parserStatus = PARSER_STATE_PAYLOAD_LENGTH;
                else {
                    parserStatus = PARSER_STATE_SYNC;
                }
                break;
                
            case PARSER_STATE_PAYLOAD_LENGTH:
                if (TGSenableLogsFlag)  NSLog(@"%@ parse state  PARSER_STATE_PAYLOAD_LENGTH",TGSSDKLogPrefix);
         //      NSLog(@"%@ parse state  PARSER_STATE_PAYLOAD_LENGTH",TGSSDKLogPrefix);
                
                payloadLength = (chrisbuffer & 0xFF);
                payloadBytesReceived = 0;
                payloadSum = 0;
                parserStatus = PARSER_STATE_PAYLOAD;
                break;
                
            case PARSER_STATE_PAYLOAD:
                if (TGSenableLogsFlag)  NSLog(@"%@ parse state  PARSER_STATE_PAYLOAD",TGSSDKLogPrefix);
     //          NSLog(@"%@ parse state  PARSER_STATE_PAYLOAD_LENGTH",TGSSDKLogPrefix);

                payload[(payloadBytesReceived++)] = chrisbuffer;
                payloadSum += (chrisbuffer & 0xFF);
                if (payloadBytesReceived < payloadLength){
                    break;
                }
//                NSLog(@"->->->->payload");
//                for(int ai=0;ai< payloadLength; ai++)
//                {
//                     NSLog(@"%02x", payload[ai]);
//                }
//                 NSLog(@"<-<-<-<-payload");
                parserStatus = PARSER_STATE_CHKSUM;
                break;
                
            case PARSER_STATE_CHKSUM:
                if (TGSenableLogsFlag)  NSLog(@"%@ parse state  PARSER_STATE_CHKSUM",TGSSDKLogPrefix);
                //NSLog(@"%@ parse state  PARSER_STATE_CHKSUM",TGSSDKLogPrefix);

                checksum = (chrisbuffer & 0xFF);
                parserStatus = PARSER_STATE_SYNC;
                if (checksum != ((payloadSum ^ 0xFFFFFFFF) & 0xFF)) {
                    
                    if ([self.delegate respondsToSelector:@selector(onChecksumFail:length:checksum:)])
                    {
                        [[self delegate] onChecksumFail:payload length:payloadLength checksum:checksum];
                    }
                }
                else
                {
                   //- NSLog(@"checksum %02lx -  payloadSum %02lx", (long)checksum, (long)payloadSum);
                    [self parsePacketPayload];
                }
                break;
        }
    }
}

-(void) parsePacketPayload
{

    int i = 0;
    int extendedCodeLevel = 0;
    int code = 0;
    int valueBytesLength = 0;
    
    int signal = 0;
    int heartrate = 0;
    int attention = 0;
    int meditation =0;
    int rawWaveData = 0;
    //cmd value
    int cmdValue = 0;
    
    TGSEEGPower  *pEEG = nil;
    
    while (i < payloadLength) {
        extendedCodeLevel++;
        
        while (payload[i] == PARSER_EXCODE_BYTE) {
            i++;
        }
        
        code = payload[(i++)] & 0xFF;
        
       //- NSLog(@"code:%02x valueLength:%d payload[%d]: %02hhx", code, valueBytesLength, i-1, payload[i-1]);
        
        if (code > MULTI_BYTE_CODE_THRESHOLD)
        {
            if (code == PARSER_CODE_CMD_NOTCH || code == PARSER_CODE_CMD_BAUD)
            {
                valueBytesLength = 1;
            }else
            {
                valueBytesLength = payload[(i++)] & 0xFF;
            }
        } else {
            valueBytesLength = 1;
        }
        
        if (code == PARSER_CODE_RAW)// RAW DATA
        {
          if (TGSenableLogsFlag)  NSLog(@"%@ parsePacketPayload  PARSER_CODE_RAW",TGSSDKLogPrefix);
            //NSLog(@"%@ parsePacketPayload  PARSER_CODE_RAW",TGSSDKLogPrefix);

            if ((valueBytesLength == RAW_DATA_BYTE_LENGTH) && (true)) {
                Byte highOrderByte = payload[i];
                Byte lowOrderByte = payload[(i + 1)];
                
                rawWaveData =  [self getRawWaveValue:highOrderByte lOrderByte:lowOrderByte];
                
                if (rawWaveData > 32768)
                    rawWaveData -= 65536;
                
                if ([self.delegate respondsToSelector:@selector(onDataReceived:data:obj:)]){
                    [[self delegate] onDataReceived:BodyDataType_CODE_RAW data:rawWaveData obj:nil];
                }else
                {
                    NSLog(@"no delegate: onDataReceived:data:obj:");
                }
                
                [self checkBlink:rawWaveData];
                
            }
            i += valueBytesLength;
        }
        else
        {
            switch (code)
            {
                case PARSER_CODE_POOR_SIGNAL:
                    if (TGSenableLogsFlag)  NSLog(@"%@ parsePacketPayload  PARSER_CODE_POOR_SIGNAL",TGSSDKLogPrefix);
                    //////NSLog(@"%@ parsePacketPayload  PARSER_CODE_POOR_SIGNAL",TGSSDKLogPrefix);

                    signal = payload[i] & 0xFF;
                    i += valueBytesLength;
 
                    globalSignal = signal;
                    if ([self.delegate respondsToSelector:@selector(onDataReceived:data:obj:)])
                    {
                        [[self delegate] onDataReceived:BodyDataType_CODE_POOR_SIGNAL data:signal obj:nil];
                    }
                    
                    break;
                    
                case PARSER_CODE_HEARTRATE:
                 if (TGSenableLogsFlag)  NSLog(@"%@ parsePacketPayload  PARSER_CODE_HEARTRATE",TGSSDKLogPrefix);
                    //NSLog(@"%@ parsePacketPayload  PARSER_CODE_HEARTRATE",TGSSDKLogPrefix);

                    heartrate = payload[i] & 0xFF;
                    i += valueBytesLength;
                    if ([self.delegate respondsToSelector:@selector(onDataReceived:data:obj:)])
                    {
                        [[self delegate] onDataReceived:BodyDataType_CODE_HEARTRATE data:heartrate obj:nil ];
                    }
                    
                    break;
                    
                case PARSER_CODE_DEBUG_ONE:
                    if (valueBytesLength == EEG_DEBUG_ONE_BYTE_LENGTH) {
                        i += valueBytesLength;
                    }
                    break;
                    
                case PARSER_CODE_DEBUG_TWO:
                    if (valueBytesLength == EEG_DEBUG_TWO_BYTE_LENGTH) {
                        i += valueBytesLength;
                    }
                    break;
                    
                case PARSER_CODE_EEGPOWER:
                    if (TGSenableLogsFlag)  NSLog(@"%@ parsePacketPayload  PARSER_CODE_EEGPOWER",TGSSDKLogPrefix);
                    //NSLog(@"%@ parsePacketPayload  PARSER_CODE_EEGPOWER",TGSSDKLogPrefix);
                    pEEG = [[TGSEEGPower alloc] initWithBytes:payload st:i len:valueBytesLength];
                    if([pEEG isValidate])
                    {
                        if ([self.delegate respondsToSelector:@selector(onDataReceived:data:obj:)])
                        {
                            [[self delegate] onDataReceived:MindDataType_CODE_EEGPOWER data:0 obj:pEEG ];
                        }
                    }else
                    {
                        
                    }
                    i += valueBytesLength;
                    break;
                    
                case PARSER_CODE_ATTENTION:
                    if (TGSenableLogsFlag)  NSLog(@"%@ parsePacketPayload  PARSER_CODE_ATTENTION",TGSSDKLogPrefix);
                    //NSLog(@"%@ parsePacketPayload  PARSER_CODE_ATTENTION",TGSSDKLogPrefix);

                    attention = payload[i] & 0xFF;
                    i += valueBytesLength;
                    if ([self.delegate respondsToSelector:@selector(onDataReceived:data:obj:)])
                    {
                        [[self delegate] onDataReceived:MindDataType_CODE_ATTENTION data:attention obj:nil];
                    }
                    break;
                    
                case PARSER_CODE_MEDITATION:
                    if (TGSenableLogsFlag)  NSLog(@"%@ parsePacketPayload  PARSER_CODE_MEDITATION",TGSSDKLogPrefix);
                   //NSLog(@"%@ parsePacketPayload  PARSER_CODE_MEDITATION",TGSSDKLogPrefix);

                    meditation = payload[i] & 0xFF;
                    i += valueBytesLength;
                    if ([self.delegate respondsToSelector:@selector(onDataReceived:data:obj:)])
                    {
                        [[self delegate] onDataReceived:MindDataType_CODE_MEDITATION data:meditation obj:nil];
                    }
                    break;
                    
                case PARSER_CODE_CMD_BAUD:
                case PARSER_CODE_CMD_NOTCH:
                    // code value(0xBA/0xBC) and its value
                    cmdValue = payload[i] & 0xFF;
                    i += valueBytesLength;
                    if ([self.delegate respondsToSelector:@selector(onDataReceived:data:obj:)])
                    {
                        [[self delegate] onDataReceived:code data:cmdValue obj:nil];
                    }
                    
                    break;
                default:
                    i += valueBytesLength;
                    break;
            }
        }
        
    }
    parserStatus = PARSER_STATE_SYNC;
}

-(void)checkBlink:(int)eegVal
{
    //NSLog(@"globalSignal:%d",globalSignal);
    int blinkValue = [blink detectBlinkWithPoorSignal:globalSignal EegValue:eegVal];
    // NSLog(@"blinkValue:%d - eegSample:%d", blinkValue, eegSample);
    // check one
    if (blinkValue > 0)
    {
        if ([self.delegate respondsToSelector:@selector(eegBlink:)]){
            [[self delegate] eegBlink:blinkValue];
        }
    }
}


-(int)getRawWaveValue:(Byte)highOrderByte lOrderByte:(Byte)lowOrderByte
{
    int hi = ((int)highOrderByte) & 0xFF;
    int lo = ((int)lowOrderByte) & 0xFF;
    return( (hi<<8) | lo );
}

@end