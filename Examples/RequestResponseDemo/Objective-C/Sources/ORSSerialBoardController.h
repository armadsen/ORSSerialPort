//
//  ORSSerialBoardController.h
//  RequestResponseDemo
//
//  Created by Andrew Madsen on 3/14/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

@import Foundation;

@class ORSSerialPort;

@interface ORSSerialBoardController : NSObject

@property (nonatomic, strong) ORSSerialPort *serialPort;

@property (nonatomic, readonly) NSInteger temperature; // In degrees C

@end
