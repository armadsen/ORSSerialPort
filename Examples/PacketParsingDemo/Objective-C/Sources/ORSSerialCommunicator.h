//
//  ORSSerialCommunicator.h
//  PacketParsingDemo
//
//  Created by Andrew Madsen on 8/10/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ORSSerialPort;;

@interface ORSSerialCommunicator : NSObject

@property (nonatomic, strong) ORSSerialPort *serialPort;

@property (nonatomic, readonly) NSInteger sliderPosition;

@end
