//
//  utility.m
//  PelicanForiOS
//
//  Created by peterwang on 5/27/15.
//  Copyright (c) 2015 NeuroSky. All rights reserved.
//

#import "utility.h"

@implementation utility

+(NSString *)convertDate2String:(NSDate *)date
{
    
    NSDateFormatter * formatter = [[NSDateFormatter alloc]init];
    [formatter              setDateFormat:@"yyyy-MM-dd HH-mm-ss.SSS"];
    NSString               *dateString = [formatter stringFromDate:date];
    
    NSArray *array         =[dateString componentsSeparatedByString:@" "];
    NSString *stringNow=[NSString stringWithFormat:@"%@-%@",[array objectAtIndex:0],[array objectAtIndex:1]];
    return      stringNow;
    
}

@end
