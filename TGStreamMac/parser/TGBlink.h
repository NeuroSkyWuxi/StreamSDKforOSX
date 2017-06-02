//
//  TGBlink.h
//
//  Created by Tin Nguyen on 7/7/11.
//  Copyright 2011 NeuroSky. All rights reserved.
//

#import <Foundation/Foundation.h>
#pragma mark Constant definitions

#define SHIFTING_TERM 4

#define DATA_MEAN 33
#define POS_VOLT_THRESHOLD 230  /* DATA_MEAN+265*/
#define NEG_VOLT_THRESHOLD -200 /* DATA_MEAN-265*/
#define DISTANCE_THRESHOLD 120
#define INNER_DISTANCE_THRESHOLD 45

#define MAX_LEFT_RIGHT 25

#define MEAN_VARIABILITY 200
#define BLINK_LENGTH 50
#define MIN_MAX_DIFF 500
#define POORSIGNAL_THRESHOLD 51  
#define BUFFER_SIZE 512 

enum {
    NO_BLINK = 0,
    NORMAL_BLINK_UPPER = 1,
    NORMAL_BLINK_LOWER = 2,
    NORMAL_BLINK_VERIFY = 3,
    INVERTED_BLINK_LOWER = 4,
    INVERTED_BLINK_UPPER = 5,
    INVERTED_BLINK_VERIFY = 6
};
typedef NSUInteger TGBlinkState;

@interface TGBlink : NSObject {

@private

    short bufferCounter;
    short buffer[BUFFER_SIZE];
    
    TGBlinkState state;
    
    short blinkStart;
    short outerLow;
    short innerLow;
    short innerHigh;
    short outerHigh;
    short blinkEnd;
    
    short maxValue;
    short minValue;
    
    short blinkStrength;
    
    double meanVariablityThreshold;
    double average;   
}

- (int)detectBlinkWithPoorSignal:(int)poorSignalQualityValue EegValue:(int)eegValue;
@end
