//
//  thinkGear.m
//  blueToothMac
//
//  Created by peterwang on 7/23/15.
//  Copyright (c) 2015 NeuroSky. All rights reserved.
//

#import "TGStreamForMac.h"
#import "TGSIParser.h"
#import "TGSNormalParser.h"

#import "ORSSerialPort.h"
#import "ORSSerialPortManager.h"
#import "ORSSerialRequest.h"

@interface TGStreamForMac()<ORSSerialPortDelegate>
@end

static NSString *const sdkVersion                                 =@"1.8";
//static NSString *const mindWaveMobilePortName       =@"/dev/tty.MindWaveMobile-DevA";
static NSString *mindWaveMobilePortName       =@"/dev/tty.MindWaveMobile-SerialPo";

NSString  * const     TGSSDKLogPrefix    = @"Stream SDK MAC-- ";
BOOL                  TGSenableLogsFlag  = false;

dispatch_queue_t     logQueue;
NSString            *sdkLogPath;

@implementation TGStreamForMac{
    
    TGSIParser      *normalParser;
    ConnectionStates ConnectionState;

    //file stream
    NSInputStream   *inputStream;
    dispatch_queue_t thinkGearQueue;
    dispatch_queue_t tTGOpenPortQueue;
    
    BOOL             endOfStream;
    
    //record raw data
    NSString                *ped2Path;
    NSFileManager           *ped2FM;
    NSFileHandle            *ped2DataHandle;
    BOOL                    startRecordBTFlag;

    //ORSSerialPort
    ORSSerialPort                  *kORSSerialPort;
    //bluetooth stream Flag
    BOOL isPortOpened;
    
    ORSSerialRequest *orSSRequest;
}

#pragma mark - lifeCycle and shared Instance

static const NSTimeInterval kTimeoutDuration = 5;

+ (TGStreamForMac *)sharedInstance{
    
    static TGStreamForMac *TGStreamMacSingleton=nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        TGStreamMacSingleton = [[self alloc] init];
    });
    
    return TGStreamMacSingleton;
}

+ (TGStreamForMac *)sharedInstance:(NSString *)portPath{
    
    static TGStreamForMac *TGStreamMacSingleton=nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        TGStreamMacSingleton = [[self alloc] init];
        //reset the device port name
        if (portPath) {
            mindWaveMobilePortName = [NSString stringWithString:portPath];
        }
    });
    
    return TGStreamMacSingleton;
}

-(instancetype) init{
    
    if (self = [super init]) {
        
        thinkGearQueue = dispatch_queue_create("com.neurosky.thinkGearQueue", DISPATCH_QUEUE_SERIAL);
        tTGOpenPortQueue = dispatch_queue_create("com.neurosky.tTGOpenPortQueue", DISPATCH_QUEUE_SERIAL);

        NSLog(@"-- init normalParser --");
        //stream init
        normalParser=[[TGSNormalParser alloc] init];
        normalParser.delegate=self;
     
        ped2FM=[NSFileManager defaultManager];
        ped2Path=nil;
        
        //log funtion setup
        [self logSetup];

        //bluetooth flag init
        isPortOpened = NO;
        
        [NSTimer scheduledTimerWithTimeInterval:2.0
                                         target:self
                                       selector:@selector(checkBaudCount)
                                       userInfo:nil
                                        repeats:YES];
    }
    
    return self;
}

-(void)fireSerialPort
{
    // fire listen Port
    dispatch_async(tTGOpenPortQueue, ^{
        @try{
            if (!kORSSerialPort){
                kORSSerialPort=[ORSSerialPort serialPortWithPath:mindWaveMobilePortName];
                kORSSerialPort.delegate=self;
            }
            [kORSSerialPort open];
            if(TGSenableLogsFlag) NSLog(@"%@ is %@", mindWaveMobilePortName, kORSSerialPort.isOpen ? @"open" : @"close");
        }@catch (NSException *exception) {
            NSLog(@"Error: %@",exception);
        } @finally {
        }
    });
}

-(void) checkBaudCount
{
    //  NSLog(@"diff: %d",baundCount-baundOld);
    baundCount = baundOld;
}

-(void)frozenSerialPort
{
    // fire listen Port
    dispatch_async(tTGOpenPortQueue, ^{
        @try{
            [kORSSerialPort close];
        }
        @catch (NSException *exception) {
            NSLog(@"Error: %@",exception);
        } @finally {
            
        }
    });
}

-(void)dealloc{
    [self stopStream];
}

#pragma mark - serialPort delegate

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveResponse:(NSData *)responseData toRequest:(ORSSerialRequest *)request;
{
    NSLog(@"%s-%@", __func__, responseData);
}

static int baundOld = 0;
static int baundCount = 0;

#pragma mark -- serialPort: didReceiveData: --
- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data;{
    if (isPortOpened)
    {
        baundCount ++;
        [normalParser parse:data];
        
        if(startRecordBTFlag && ped2DataHandle)
        {
            @try
            {
                [ped2DataHandle seekToEndOfFile];
                [ped2DataHandle writeData:data];
                [ped2DataHandle synchronizeFile];
            }
            @catch (NSException *exception)
            {
                if ([_delegate respondsToSelector:@selector(onRecordFail:)])
                {
                    [_delegate onRecordFail:RECORD_ERROR_RECORD_WRITE_FILE_FAILED];
                }
            }
        }
    }
}

- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error{
    isPortOpened=NO;
   NSLog(@"%s Error: %@", __func__ , error);
}

- (void)serialPort:(ORSSerialPort *)serialPort requestDidTimeout:(ORSSerialRequest *)request;
{
    if ([orSSRequest isEqual:request]) {
         NSLog(@"%s", __func__);
    }
}

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort;{
     NSLog(@"serialPortWasOpened");
    isPortOpened=YES;
    
    NSLog(@"%@ : %@", kORSSerialPort, kORSSerialPort.baudRate);
    if ([self.delegate respondsToSelector:@selector(onStatesChanged:)]){
        [self.delegate onStatesChanged:STATE_CONNECTED];
    }else
    {
        NSLog(@"NO DELEGATE METHOD: onStatesChanged:");
    }
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort;{
     NSLog(@"serialPortWasClosed");
    if (isPortOpened) {
        if ([self.delegate respondsToSelector:@selector(onStatesChanged:)]){
            [self.delegate onStatesChanged:STATE_DISCONNECTED];
        }
        if (startRecordBTFlag && ped2DataHandle)
        {
            NSLog(@"serialPortConnectionInterrupt stop record");
            startRecordBTFlag=NO;
            [self setConnectionState:STATE_RECORDING_END];
        }
        
        isPortOpened=NO;
    }
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort;{
    NSLog(@"serialPortWasRemovedFromSystem");
}

#pragma mark - public method
- (NSString *) getVerison;{
    return sdkVersion;
}

- (void)enableLog:(BOOL)enabled;{
    
    TGSenableLogsFlag=enabled;
}

-(void) initStreamWithFile:(NSString *)filePath{
    
    if([[NSFileManager defaultManager] fileExistsAtPath:filePath])
    {
        
        inputStream = [[NSInputStream alloc] initWithFileAtPath:filePath];
        [self streamParser];
    }else
    {
        [self setConnectionState:STATE_FAILED];
    }
}

#pragma mark -- startStream --
- (void)startStream
{
    if (!isPortOpened){
        [self fireSerialPort];
    }
}

- (void)stopStream
{
    if(isPortOpened)
    {
        [self frozenSerialPort];
    }

    //stop file stream
    if (!endOfStream) {
        endOfStream=true;
    }
    
    if (startRecordBTFlag && ped2DataHandle)
    {
        startRecordBTFlag=NO;
        [self setConnectionState:STATE_RECORDING_END];
    }
    
    [self setConnectionState:STATE_STOPPED];
}

- (void)setRecordStreamFilePath{
    
    NSDateFormatter *dateFormatter =[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    
    NSString  *ped2FileName = [NSString stringWithFormat: @"%@-RawPackageRecording.txt",[dateFormatter stringFromDate:[NSDate date]]];
    
    NSArray *pathArray = NSSearchPathForDirectoriesInDomains( NSDocumentDirectory,NSUserDomainMask, YES);
    NSString *pathRecord = [pathArray objectAtIndex:0];
    
    ped2Path = [pathRecord stringByAppendingPathComponent:@"TSG_log"];
    
    BOOL didCreate = [[NSFileManager defaultManager] createDirectoryAtPath:ped2Path withIntermediateDirectories:YES attributes:nil error:nil];
    
    if (didCreate)
    {
        ped2Path = [ped2Path stringByAppendingPathComponent:ped2FileName];
        
        if (TGSenableLogsFlag) NSLog(@"%@ ped2path:%@ ",TGSSDKLogPrefix,ped2Path);

        if ([ped2FM fileExistsAtPath:ped2Path] == false)
        {
            BOOL fileDidCreate=[ped2FM createFileAtPath:ped2Path contents:nil attributes:nil];
            if (!fileDidCreate)
            {
                if ([_delegate respondsToSelector:@selector(onRecordFail:)])
                {
                    [_delegate onRecordFail:RECORD_ERROR_FILE_PATH_NOT_READY];
                }
                if (TGSenableLogsFlag) NSLog(@"%@ fail to create file path:%@ ",TGSSDKLogPrefix,ped2Path);
            }
            else
            {
                if (TGSenableLogsFlag) NSLog(@"%@ success to create file path:%@ ",TGSSDKLogPrefix,ped2Path);
                NSLog(@"%@ success to create file path:%@ ",TGSSDKLogPrefix,ped2Path);
            }
        }
    }else
    {
        if ([_delegate respondsToSelector:@selector(onRecordFail:)]) {
            [_delegate onRecordFail:RECORD_ERROR_FILE_PATH_NOT_READY];
        }
        
        if (TGSenableLogsFlag) NSLog(@"%@ fail to create file path:%@ ",TGSSDKLogPrefix,ped2Path);
        NSLog(@"%@ fail to create file path:%@ ",TGSSDKLogPrefix,ped2Path);
    }
}

-(void)setRecordStreamFilePath:(NSString *)filePath{
    if ( !filePath || [@"" isEqualToString:filePath])
    {
        if ([_delegate respondsToSelector:@selector(onRecordFail:)])
        {
            [_delegate onRecordFail:RECORD_ERROR_FILE_PATH_NOT_READY];
        }
        
        if (TGSenableLogsFlag) NSLog(@"%@ file path set is not correct:%@ ",TGSSDKLogPrefix,ped2Path);
        NSLog(@"%@ file path set is not correct:%@ ",TGSSDKLogPrefix,ped2Path);
        return;
    }
    
    ped2Path = filePath;
    
    if ([ped2FM fileExistsAtPath:ped2Path] == false)
    {
        if (![ped2FM createFileAtPath:ped2Path contents:nil attributes:nil])
        {
            if ([_delegate respondsToSelector:@selector(onRecordFail:)])
            {
                [_delegate onRecordFail:RECORD_ERROR_FILE_PATH_NOT_READY];
            }
            
            if (TGSenableLogsFlag) NSLog(@"%@ fail to create file path:%@ ",TGSSDKLogPrefix,ped2Path);
            NSLog(@"%@ fail to create file path:%@ ",TGSSDKLogPrefix,ped2Path);
            return;
        }
        else{
            if (TGSenableLogsFlag) NSLog(@"%@ success to create file path:%@ ",TGSSDKLogPrefix,ped2Path);
            NSLog(@"%@ success to create file path:%@ ",TGSSDKLogPrefix,ped2Path);
            
        }
    }
}

-(void)startRecordRawData{
    if(startRecordBTFlag)
    {
        if (TGSenableLogsFlag)  NSLog(@"%@ start record raw data already started",TGSSDKLogPrefix);
        NSLog(@"%@ start record raw data already started",TGSSDKLogPrefix);
        
        
        if ([_delegate respondsToSelector:@selector(onRecordFail:)]){
            
            [_delegate onRecordFail:RECORD_ERROR_RECORD_IS_ALREADY_WORKING];
        }
        
        return;
    }
    
    ped2DataHandle = [NSFileHandle fileHandleForWritingAtPath:ped2Path];
    NSLog(@"ped2Path %@",ped2Path);
    
    if (!ped2DataHandle)
    {
        if ([_delegate respondsToSelector:@selector(onRecordFail:)]){
            
            [_delegate onRecordFail:RECORD_ERROR_RECORD_OPEN_FILE_FAILED];
        }
        NSLog(@"ped2DataHandle is nil");
        return;
    }
    
    startRecordBTFlag = true;
    
    [self setConnectionState:STATE_RECORDING_START];
}

-(void)stopRecordRawData{
    if(!startRecordBTFlag){
        if (TGSenableLogsFlag)  NSLog(@"%@ start record raw data not started yet",TGSSDKLogPrefix);
        NSLog(@"%@ start record raw data not started yet",TGSSDKLogPrefix);
        return;
    }
    
    startRecordBTFlag = false;
    
    @try {
        if (TGSenableLogsFlag)  NSLog(@"%@ close file",TGSSDKLogPrefix);
        NSLog(@"%@ close file",TGSSDKLogPrefix);
        [ped2DataHandle closeFile];
    }
    @catch (NSException *exception) {
        
        if (TGSenableLogsFlag)  NSLog(@"%@ close file fail",TGSSDKLogPrefix);
        NSLog(@"%@ close file fail",TGSSDKLogPrefix);

        if ([_delegate respondsToSelector:@selector(onRecordFail:)]) {
            [_delegate onRecordFail:RECORD_ERROR_RECORD_WRITE_FILE_FAILED];
        }else
        {
            NSLog(@"NO DELETE METHOD: onRecordFail:");
        }
    }
    
    if (ped2DataHandle)
    {
        ped2DataHandle = nil;
    }
    
    [self setConnectionState:STATE_RECORDING_END];
}

#pragma mark - private method
-(void)setConnectionState:(ConnectionStates)connectionStates{
    ConnectionState = connectionStates;
    if ([self.delegate respondsToSelector:@selector(onStatesChanged:)])
    {
        [[self delegate] onStatesChanged:ConnectionState];
    }
}

-(void)logSetup{
    
    logQueue = dispatch_queue_create("com.neurosky.logQueue", DISPATCH_QUEUE_SERIAL);
    
    //creat log path
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    sdkLogPath = [documentsDirectory stringByAppendingPathComponent:@"logfile.txt"];
    
    [ped2FM createFileAtPath:sdkLogPath contents:nil attributes:nil];
    
    NSLog(@"sdkLogPath:%@",sdkLogPath);
    
}

-(void)streamParser{
    dispatch_async(thinkGearQueue, ^{
        NSInteger           maxLength = 128;
        uint8_t                readBuffer[maxLength];
        NSMutableData *readData;
        endOfStream       = false;
        
        [inputStream open];
        
        [self setConnectionState:STATE_WORKING];
        
        while (!endOfStream)
        {
            
            NSInteger bytesRead = [inputStream read:readBuffer maxLength:maxLength];
            
            if (bytesRead)
            {
                                
                if (!readData) {
                    readData = [[NSMutableData alloc] init];
                }
                [readData appendBytes:(void *)readBuffer length:bytesRead];
                
                [normalParser parse:readData];
                
                if(startRecordBTFlag && ped2DataHandle){
                    
                    @try {
                        
                        [ped2DataHandle seekToEndOfFile];
                        [ped2DataHandle writeData:readData];
                        [ped2DataHandle synchronizeFile];
                        
                    }
                    @catch (NSException *exception) {
                        
                        if ([_delegate respondsToSelector:@selector(onRecordFail:)]) {
                            [_delegate onRecordFail:RECORD_ERROR_RECORD_WRITE_FILE_FAILED];
                        }
                    }
                }
                
                NSRange range = NSMakeRange(0, bytesRead);
                [readData replaceBytesInRange:range withBytes:NULL length:0];
                
            }else{
                endOfStream = true;
                [self setConnectionState:STATE_COMPLETE];
            }
            
            usleep(30000);
            
        }
        
        [inputStream close];
        
        if (startRecordBTFlag && ped2DataHandle)
        {
            startRecordBTFlag=NO;
            [self setConnectionState:STATE_RECORDING_END];
        }
        
    });
}

#pragma mark - TGstream Mac delegate

-(void) onDataReceived:(NSInteger)datatype data:(int)data obj:(NSObject *)obj {
    
    if ([self.delegate respondsToSelector:@selector(onDataReceived:data:obj:)])
    {
        [[self delegate] onDataReceived:datatype data:data obj:obj];
    }
}

-(void) onChecksumFail:(Byte *)payload length:(NSUInteger)length checksum:(NSInteger)checksum{

    if ([self.delegate respondsToSelector:@selector(onChecksumFail:length:checksum:)])
    {
        [[self delegate] onChecksumFail:payload length:length checksum:checksum];
    }
}

static  int numberCount = 0;
-(void)sendCommand:(SendCMDType)cmdType
{
    NSLog(@"%s",__func__);
 
    if(cmdType == SendCMDTypeNone)
        return;
 
    // the mind wave port name
    if (![mindWaveMobilePortName isEqualToString:@"/tty.MindWaveMobile-SerialPo"]) {
        NSLog(@"%@ can't support the commands.", mindWaveMobilePortName);
        return;
    }
    
    ORSSerialPacketDescriptor *responseDescriptor =
    [[ORSSerialPacketDescriptor alloc] initWithMaximumPacketLength:20
                                                          userInfo:nil
                                                 responseEvaluator:^BOOL(NSData *inputData) {
                                                     // return [self LEDStateFromResponsePacket:inputData] != nil;
                                                    return false;
                                                 }];
    
    orSSRequest = [ORSSerialRequest requestWithDataToSend:[self lowSendHandShake:cmdType]
                                                               userInfo:@(cmdType)
                                                        timeoutInterval:kTimeoutDuration
                                                     responseDescriptor:nil];
    
    [kORSSerialPort sendRequest:orSSRequest];
}

-(NSData *)lowSendHandShake: (SendCMDType) cmd
{
    // 20 byte handshake
    unsigned char handshake[6]; // initialized to zero
    for (int i=0; i<6; i++) handshake[i] = 0;
    
    handshake[0] = 0xAA;
    handshake[1] = 0xAA;
    handshake[2] = 0x02;

    switch (cmd) {
        case SendCMDTypeReadBaud:
            handshake[3] = 0xBA;
            handshake[4] = 0x03;
            handshake[5] = 0x42;
            break;
        case SendCMDTypeChangeBaudTo_576000:
            handshake[3] = 0xBA;
            handshake[4] = 0x01;
            handshake[5] = 0x44;
            break;
        case SendCMDTypeChangeBaudTo_1152000:
            handshake[3] = 0xBA;
            handshake[4] = 0x02;
            handshake[5] = 0x43;
            break;
            
        case SendCMDTypeReadNotch:
            handshake[3] = 0xBC;
            handshake[4] = 0x03;
            handshake[5] = 0x40;
            break;
        case SendCMDTypeChangeNotchTo_50:
            handshake[3] = 0xBC;
            handshake[4] = 0x01;
            handshake[5] = 0x42;
            break;
        case SendCMDTypeChangeNotchTo_60:
            handshake[3] = 0xBC;
            handshake[4] = 0x02;
            handshake[5] = 0x41;
            break;
       
    default:
        break;
    }
    
    // NOTE: now sending all 20 bytes
    NSData *handshakeData = [[NSData alloc] initWithBytes:handshake length:6];
    
    return handshakeData;
}




@end
