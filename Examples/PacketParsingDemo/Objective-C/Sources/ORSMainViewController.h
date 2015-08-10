//
//  ORSMainViewController.h
//  PacketParsingDemo
//
//  Created by Andrew Madsen on 8/10/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ORSSerialPortManager;
@class ORSSerialCommunicator;

@interface ORSMainViewController : NSViewController

@property (nonatomic, readonly) ORSSerialPortManager *serialPortManager;

@property (nonatomic, readonly) ORSSerialCommunicator *serialCommunicator;

@end
