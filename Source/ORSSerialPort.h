//
//  ORSSerialPort.h
//  ORSSerialPort
//
//  Created by Andrew R. Madsen on 08/6/11.
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
#import <IOKit/IOTypes.h>
#import <termios.h>

//#define LOG_SERIAL_PORT_ERRORS 

enum {
	ORSSerialPortParityNone = 0,
	ORSSerialPortParityOdd,
	ORSSerialPortParityEven
}; typedef NSUInteger ORSSerialPortParity;

@class ORSSerialPort;

@protocol ORSSerialPortDelegate 

@required
- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data;
- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort;

@optional
- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error;
- (void)serialPortWasOpened:(ORSSerialPort *)serialPort;
- (void)serialPortWasClosed:(ORSSerialPort *)serialPort;

@end

@interface ORSSerialPort : NSObject

+ (ORSSerialPort *)serialPortWithPath:(NSString *)devicePath;
+ (ORSSerialPort *)serialPortWithDevice:(io_object_t)device;

- (id)initWithPath:(NSString *)devicePath;
- (id)initWithDevice:(io_object_t)device;

- (void)open;
- (BOOL)close;
- (void)cleanup;
- (BOOL)sendData:(NSData *)data;

@property (nonatomic, unsafe_unretained) id<ORSSerialPortDelegate> delegate;

// Port settings
@property (readonly, getter = isOpen) BOOL open;
@property (copy, readonly) NSString *path;
@property (readonly) io_object_t IOKitDevice;
@property (copy, readonly) NSString *name;
@property (nonatomic, copy) NSNumber *baudRate;
@property (nonatomic) NSUInteger numberOfStopBits;
@property (nonatomic) BOOL shouldEchoReceivedData;
@property (nonatomic) ORSSerialPortParity parity;
@property (nonatomic) BOOL usesRTSCTSFlowControl;
@property (nonatomic) BOOL usesDTRDSRFlowControl;
@property (nonatomic) BOOL usesDCDOutputFlowControl;

// Port pins
@property (nonatomic) BOOL RTS;
@property (nonatomic) BOOL DTR;
@property (nonatomic, readonly) BOOL CTS;
@property (nonatomic, readonly) BOOL DSR;
@property (nonatomic, readonly) BOOL DCD;

@end
