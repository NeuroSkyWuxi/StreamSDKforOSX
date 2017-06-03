//
//  FileLogMacro.h
//  MotionSwTestApp
//
//  Created by peterwang on 3/18/15.
//  Copyright (c) 2015 peter. All rights reserved.
//

#import <Foundation/Foundation.h>

extern dispatch_queue_t  logQueue;
extern NSString                *sdkLogPath;


@interface TGSFileLogMacro : NSObject

void _Log(NSString *file, int lineNumber, NSString *funcName, NSString *message);

@end
