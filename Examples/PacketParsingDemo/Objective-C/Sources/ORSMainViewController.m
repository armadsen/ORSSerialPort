//
//  ORSMainViewController.m
//  PacketParsingDemo
//
//  Created by Andrew Madsen on 8/10/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import "ORSMainViewController.h"
@import ORSSerial;
#import "ORSSerialCommunicator.h"

@interface ORSMainViewController ()

@end

@implementation ORSMainViewController

#pragma mark - Properties

- (ORSSerialPortManager *)serialPortManager { return [ORSSerialPortManager sharedSerialPortManager]; }

@synthesize serialCommunicator = _serialCommunicator;
- (ORSSerialCommunicator *)serialCommunicator
{
	if (!_serialCommunicator) { _serialCommunicator = [[ORSSerialCommunicator alloc] init]; }
	return _serialCommunicator;
}

@end
