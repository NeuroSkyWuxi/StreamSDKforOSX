//
//  IParser.h
//  CommunicationSDK
//
//  Created by Angelo on 2/27/15.
//  Copyright (c) 2015 com.neurosky. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TGStreamDelegate.h"

//parser state
typedef NS_ENUM(NSUInteger,PARSER_STATE){
    
    PARSER_STATE_SYNC = 1,
    
    PARSER_STATE_SYNC_CHECK = 2,
    
    PARSER_STATE_PAYLOAD_LENGTH = 3,
    
    PARSER_STATE_PAYLOAD = 4,
    
    PARSER_STATE_CHKSUM = 5
};




@interface TGSIParser : NSObject<TGStreamDelegate>
{
    NSInteger    parserStatus;
    NSUInteger payloadLength;
    NSInteger    payloadBytesReceived;
    NSInteger    payloadSum;
    NSInteger    checksum;
    
    Byte *payload;
    Byte *buffer;
    Byte chrisbuffer;
        
}

@property (nonatomic,unsafe_unretained) id<TGStreamDelegate> delegate;

-(void)parse:(NSData *)dataByte;

@end
