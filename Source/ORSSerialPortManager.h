//
//  ORSSerialPortManager.h
//  ORSSerialPort
//
//  Created by Andrew R. Madsen on 08/7/11.
//	Copyright (c) 2011-2012 Andrew R. Madsen (andrew@openreelsoftware.com)
//	
//	Permission is hereby granted, free of charge, to any person obtaining a
//	copy of this software and associated documentation files (the
//	"Software"), to deal in the Software without restriction, including
//	without limitation the rights to use, copy, modify, merge, publish,
//	distribute, sublicense, and/or sell copies of the Software, and to
//	permit persons to whom the Software is furnished to do so, subject to
//	the following conditions:
//	
//	The above copyright notice and this permission notice shall be included
//	in all copies or substantial portions of the Software.
//	
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import <Foundation/Foundation.h>
// Posted when a serial port is connected to the system
extern NSString * const ORSSerialPortsWereConnectedNotification;
// Posted when a serial port is disconnected from the system
extern NSString * const ORSSerialPortsWereDisconnectedNotification;

// Key for connected port in ORSSerialPortWasConnectedNotification userInfo dictionary
extern NSString * const ORSConnectedSerialPortsKey;
// Key for disconnected port in ORSSerialPortWasDisconnectedNotification userInfo dictionary
extern NSString * const ORSDisconnectedSerialPortsKey;

@interface ORSSerialPortManager : NSObject

+ (ORSSerialPortManager *)sharedSerialPortManager;

@property (nonatomic, copy, readonly) NSArray *availablePorts;

@end
