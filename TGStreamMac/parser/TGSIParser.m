//
//  IParser.m
//  CommunicationSDK
//
//  Created by Angelo on 2/27/15.
//  Copyright (c) 2015 com.neurosky. All rights reserved.
//

#import "TGSIParser.h"

@implementation TGSIParser

-(instancetype) init{
    if ([super init]) {
        return self;
    }
    else{
        return nil;
    }
}

-(void)parse:(NSData *)dataByte
{

}

-(void) onDataReceived:(NSInteger)datatype data:(int)data obj:(NSObject *)obj{
    
}

@end
