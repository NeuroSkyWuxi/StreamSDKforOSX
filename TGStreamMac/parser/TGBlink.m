//
//  TGBlink.m
//
//  Created by Tin Nguyen on 7/7/11.
//  Copyright 2011 NeuroSky. All rights reserved.
//

#import "TGBlink.h"

@implementation TGBlink

- (id)init {
    state = NO_BLINK;
    blinkStart = -1;
    outerLow   = -1;
    innerLow   = -1;
    innerHigh  = -1;
    outerHigh  = -1;
    blinkEnd   = -1;
    
    return self;
}

- (int)detectBlinkWithPoorSignal:(int)poorSignalQualityValue EegValue:(int)eegValue {
    if (poorSignalQualityValue < POORSIGNAL_THRESHOLD) {   /*if poorSignal is less than 51, continue with algorithm*/
        
        short i;
        
        /* TODO: make this more efficient */
        /* update the buffer with the latest eegValue */
        for (i = 0; i < BUFFER_SIZE - 1; i++) {
            buffer[i] = buffer[i + 1];
        }
        buffer[BUFFER_SIZE - 1] = (short)eegValue;
        
        /* Counting the number of points in the buffer to make sure you have 512*/
        if (bufferCounter < 512) {
            bufferCounter++;
        }
        
        if ( bufferCounter > (BUFFER_SIZE - 1) ) {   /* if the buffer is full (it has BUFFER_SIZE number of points)*/
            
            switch (state) {
                case NO_BLINK:
                    
                    if (eegValue > POS_VOLT_THRESHOLD) {
                        blinkStart = -1;
                        innerLow   = -1;
                        innerHigh  = -1;
                        outerHigh  = -1;
                        blinkEnd   = -1;
                        
                        outerLow = BUFFER_SIZE - 1;
                        maxValue = eegValue;
                        state    = NORMAL_BLINK_UPPER;
                    }
                    
                    if (eegValue < NEG_VOLT_THRESHOLD) {
                        blinkStart = -1;
                        innerLow   = -1;
                        innerHigh  = -1;
                        outerHigh  = -1;
                        blinkEnd   = -1;
                        
                        outerLow = BUFFER_SIZE - 1;
                        minValue = eegValue;
                        state    = INVERTED_BLINK_LOWER;
                    }
                    
                    break;
                    
                case NORMAL_BLINK_UPPER:
                    /* Monitors the DISTANCE_THRESHOLD*/
                    if (((BUFFER_SIZE - 1) - outerLow) > DISTANCE_THRESHOLD || outerLow < 1) {
                        state = NO_BLINK;
                    }
                    
                    outerLow--;		//decrement the index of outerlow to account for shifting of the buffer
                    
                    //Monitors the innerLow value.
                    if (eegValue <= POS_VOLT_THRESHOLD && buffer[BUFFER_SIZE - 2] > POS_VOLT_THRESHOLD) {	//if the current value is less than POS_VOLT_THRESH and the previous value is greater than POS_VOLT_THRESH
                        innerLow = BUFFER_SIZE - 2;		//then innerLow is defined to be the previous value
                    }
                    else {
                        innerLow--;
                    }
                    
                    //Monitors the maximum value
                    if (eegValue > maxValue) maxValue = eegValue;
                    
                    //When it hits the negative threshold, set that to be the innerHigh and set the state to NORMAL_BLINK_LOWER.
                    if (eegValue < NEG_VOLT_THRESHOLD) {	//if we are below the NEG_VOLT_THRESH 
                        innerHigh = BUFFER_SIZE - 1;	//innerHigh is the current value
                        minValue = eegValue;
                        
                        //Verify the INNER_DISTANCE_THRESHOLD
                        if ((innerHigh - innerLow) < INNER_DISTANCE_THRESHOLD) {	//if the distance btwn innerHigh and innerLow isn't too long
                            state = NORMAL_BLINK_LOWER;
                        }
                        else {		//otherwise the distance btwn innerHigh and innerLow is too much and it wasn't actually a blink
                            state = NO_BLINK;
                        }
                    }
                    
                    break;
                    
                case INVERTED_BLINK_LOWER:
                    /* Monitors the DISTANCE_THRESHOLD*/
                    if (((BUFFER_SIZE - 1) - outerLow) > DISTANCE_THRESHOLD || outerLow < 1) {
                        state = NO_BLINK;
                        return 0;
                    }
                    
                    outerLow--;
                    
                    //Monitors the innerLow value.
                    if (eegValue >= NEG_VOLT_THRESHOLD && buffer[BUFFER_SIZE - 2] < NEG_VOLT_THRESHOLD) {
                        innerLow = BUFFER_SIZE - 2;
                    }
                    else {
                        innerLow--;
                    }
                    
                    //Monitors the minimum value
                    if (eegValue < minValue) minValue = eegValue;
                    
                    //When it hits the positive threshold, set that to be innerHigh and set the state to INVERTED_BLINK_UPPER.
                    if (eegValue > POS_VOLT_THRESHOLD) {
                        innerHigh = BUFFER_SIZE - 1;
                        maxValue = eegValue;
                        
                        //Verify the INNER_DISTANCE_THRESHOLD
                        if (innerHigh - innerLow < INNER_DISTANCE_THRESHOLD) {
                            state = INVERTED_BLINK_UPPER;
                        }
                        else {
                            state = NO_BLINK;
                        }
                    }
                    
                    break;
                    
                case NORMAL_BLINK_LOWER:
                    outerLow--;
                    innerLow--;
                    innerHigh--;
                    
                    /* Monitors the outerHigh value*/
                    if (eegValue >= NEG_VOLT_THRESHOLD && buffer[BUFFER_SIZE - 2] < NEG_VOLT_THRESHOLD)	/* if the current value is greater than NEG_VOLT_THRESH and the previous value is less than NEG_VOLT_THRESH*/
                    {
                        outerHigh = BUFFER_SIZE - 2;		/* then the previous value is defined to be outerHigh*/
                        state = NORMAL_BLINK_VERIFY;
                    }
                    else {
                        outerHigh--;
                    }
                    
                    /* Monitors the minimum value*/
                    if (eegValue < minValue) minValue = eegValue;
                    
                    /* Monitors the DISTANCE_THRESHOLD*/
                    if (((BUFFER_SIZE - 1) - outerLow) > DISTANCE_THRESHOLD) {   /* if the distance from the current point to outerLow is greater than DIST_THRESH*/
                        outerHigh = BUFFER_SIZE - 1;
                        state = NORMAL_BLINK_VERIFY;
                    }
                    
                    break;
                    
                case INVERTED_BLINK_UPPER:
                    outerLow--;
                    innerLow--;
                    innerHigh--;
                    
                    //Monitors the outerHigh value.
                    if ((eegValue <= POS_VOLT_THRESHOLD) && (buffer[BUFFER_SIZE - 2] > POS_VOLT_THRESHOLD))	{	//if the current value is less than POS_VOLT_THRESH and the previous value is greater than POS_VOLT_THRESH
                    
                        outerHigh = BUFFER_SIZE - 2;			//then the previous value is defined as outerHigh
                        state = INVERTED_BLINK_VERIFY;
                    }
                    else {
                        outerHigh--;
                    }
                    
                    //Monitors the maximum value
                    if (eegValue > maxValue) maxValue = eegValue;
                    
                    //Monitors the DISTANCE_THRESHOLD
                    if (((BUFFER_SIZE - 1) - outerLow) > DISTANCE_THRESHOLD) {
                        outerHigh = BUFFER_SIZE - 1;
                        state = INVERTED_BLINK_VERIFY;
                    }
                    break;
                    
                case NORMAL_BLINK_VERIFY:
                    outerLow--;
                    innerLow--;
                    innerHigh--;
                    
                    if (eegValue < NEG_VOLT_THRESHOLD) { //if the current value is less than NEG_VOLT_THRES
                        state = NORMAL_BLINK_LOWER;
                    }
                    else {
                        outerHigh--;
                    }
                    
                    //Set the endBlink to when it hits the mean or it hits MAX_LEFT_RIGHT.
                    if (((BUFFER_SIZE - 1) - outerHigh > MAX_LEFT_RIGHT) || (eegValue > DATA_MEAN)) {
                        blinkEnd = BUFFER_SIZE - 1;
                    }
                    
                    //Checks if the value is back at the DATA_MEAN
                    if (blinkEnd > 0) {
                        //Verifies the Blink
                        //Sets the blinkStart to when it hits the mean or it hits MAX_LEFT_RIGHT.
                        for (i = 0; i < MAX_LEFT_RIGHT; i++) {
                            
                            blinkStart = (short)(outerLow - i);
                            
                            if (buffer[outerLow - i] < DATA_MEAN) {
                                break;
                            }
                        }
                        
                        //Verify the MIN_MAX_DIFF
                        blinkStrength = (short)(maxValue - minValue);
                        if (blinkStrength < MIN_MAX_DIFF) {
                            state = NO_BLINK;
                            return 0;
                        }
                        
                        //Verify the MEAN_VARIABILITY
                        meanVariablityThreshold = blinkStrength / 993 * MEAN_VARIABILITY;
                        average = 0;
                        for (i = blinkStart; i < blinkEnd + 1; i++) {
                            average += buffer[i];
                        }
                        average /= (blinkEnd - blinkStart + 1);
                        /*take abs value of average*/
                        if (average < 0) {
                            average = average * -1;
                        }
                        
                        if (average > MEAN_VARIABILITY)
                        {
                            state = NO_BLINK;
                            return 0;
                        }
                        
                        //Verify the BLINK_LENGTH
                        if (blinkEnd - blinkStart < BLINK_LENGTH)
                        {
                            state = NO_BLINK;
                            return 0;
                        }
                        
                        //verify that blinkStart is between POS_VOLT_THRESHOLD and NEG_VOLT_THRESHOLD
                        if ((buffer[blinkStart] > POS_VOLT_THRESHOLD) || (buffer[blinkStart] < NEG_VOLT_THRESHOLD))
                        {
                            state = NO_BLINK;
                            return 0;
                        }
                        
                        //verify that blinkEnd is between POS_VOLT_THRESHOLD and NEG_VOLT_THRESHOLD
                        if ((buffer[blinkEnd] > POS_VOLT_THRESHOLD) || (buffer[blinkEnd] < NEG_VOLT_THRESHOLD))
                        {
                            state = NO_BLINK;
                            return 0;
                        }
                        
                        state = NO_BLINK;
                        return (Byte)(blinkStrength >> SHIFTING_TERM);
                    }
                    
                    break;
                    
                case INVERTED_BLINK_VERIFY:
                    outerLow--;
                    innerLow--;
                    innerHigh--;
                    
                    if (eegValue > POS_VOLT_THRESHOLD) {
                        state = INVERTED_BLINK_UPPER;
                    }
                    else {
                        outerHigh--;
                    }
                    
                    //Set the endBlink to when it hits the mean or it hits MAX_LEFT_RIGHT.
                    if (((BUFFER_SIZE - 1) - outerHigh > MAX_LEFT_RIGHT) || (eegValue < DATA_MEAN)) {
                        blinkEnd = BUFFER_SIZE - 1;
                    }
                    
                    //Checks if the value is back at the DATA_MEAN
                    if (blinkEnd > 0) {
                        //Verifies the Blink
                        //Sets the blinkStart to when it hits the mean or it hits MAX_LEFT_RIGHT.
                        for (i = 0; i < MAX_LEFT_RIGHT; i++) {
                            blinkStart = (short)(outerLow - i);
                            
                            if (buffer[outerLow - i] > DATA_MEAN) {
                                break;
                            }
                        }
                        
                        //Verify the MIN_MAX_DIFF
                        blinkStrength = (short)(maxValue - minValue);
                        if (blinkStrength < MIN_MAX_DIFF) {
                            state = NO_BLINK;
                            return 0;
                        }
                        
                        //Verify the MEAN_VARIABILITY
                        meanVariablityThreshold = blinkStrength / 993 * MEAN_VARIABILITY;
                        average = 0;
                        for (i = blinkStart; i < blinkEnd + 1; i++) {
                            average += buffer[i];
                        }
                        average /= (blinkEnd - blinkStart + 1);
                        /*take abs value of average*/
                        if (average < 0) {
                            average = average * -1;
                        }
                        
                        if (average > MEAN_VARIABILITY) {
                            state = NO_BLINK;
                            return 0;
                        }
                        
                        //Verify the BLINK_LENGTH
                        if (blinkEnd - blinkStart < BLINK_LENGTH) {
                            state = NO_BLINK;
                            return 0;
                        }
                        
                        //verify that blinkStart is between POS_VOLT_THRESHOLD and NEG_VOLT_THRESHOLD
                        if ((buffer[blinkStart] > POS_VOLT_THRESHOLD) || (buffer[blinkStart] < NEG_VOLT_THRESHOLD)) {
                            state = NO_BLINK;
                            return 0;
                        }
                        
                        //verify that blinkEnd is between POS_VOLT_THRESHOLD and NEG_VOLT_THRESHOLD
                        if ((buffer[blinkEnd] > POS_VOLT_THRESHOLD) || (buffer[blinkEnd] < NEG_VOLT_THRESHOLD)) {
                            state = NO_BLINK;
                            return 0;
                        }
                        
                        state = NO_BLINK;
                        return (Byte)(blinkStrength >> SHIFTING_TERM);
                    }
                    
                    break;
                    
                default:
                    state = NO_BLINK;
                    
                    break;
            }
        }
    }
    else {	/* poorsignal is greater than 51 and do not evaluate the algorithm */

        bufferCounter = 0;
        outerLow = -1;
        innerLow = -1;
        innerHigh = -1;
        outerHigh = -1;
        
        state = NO_BLINK;
    }
    return 0;
}

@end
