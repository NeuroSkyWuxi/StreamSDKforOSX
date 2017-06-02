//
//  FileLogMacro.m
//  MotionSwTestApp
//
//  Created by peterwang on 3/18/15.
//  Copyright (c) 2015 peter. All rights reserved.
//

#import "TGSFileLogMacro.h"
#import "utility.h"

@implementation TGSFileLogMacro

void _Log( NSString *file, int lineNumber, NSString *funcName, NSString *message)
{

    dispatch_async(logQueue, ^{
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:sdkLogPath];
        NSString *logMessage = [NSString stringWithFormat:@"%@|%@| %d| %@| %@\n",[utility convertDate2String:[NSDate date]],file,lineNumber,funcName,message];
        
        [handle truncateFileAtOffset:[handle seekToEndOfFile]];
        [handle writeData:[logMessage dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
        NSLog(@"log file");
        
        //- ForMWM1.6 version
        //NSLog(@"sdk log path%@",sdkLogPath);
    });
    
}

@end
