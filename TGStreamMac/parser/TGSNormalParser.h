//
//  Parser.h
//  CommunicationSDK
//
//  Created by Angelo on 2/28/15.
//  Copyright (c) 2015 com.neurosky. All rights reserved.
//

/*-
 @header Parser.h
 @abstract Default Parser Class in CommunicationSDK
 @author Angelo Wang
 @version 1.00  2/28/15 Creation
 */

#import "TGSIParser.h"
#import "TGStreamDelegate.h"

extern NSString  * const     TGSSDKLogPrefix;
extern BOOL                      TGSenableLogsFlag;

@interface TGSNormalParser : TGSIParser

- (instancetype)init;

- (void)parse:(NSData *)dataByte;


@end
