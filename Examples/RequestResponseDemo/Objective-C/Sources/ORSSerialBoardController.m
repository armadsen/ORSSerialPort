//
//  ORSSerialBoardController.m
//  RequestResponseDemo
//
//  Created by Andrew Madsen on 3/14/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
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

#import "ORSSerialBoardController.h"
@import ORSSerial;

static const NSTimeInterval kTimeoutDuration = 0.5;

typedef NS_ENUM(NSInteger, ORSSerialBoardRequestType) {
	ORSSerialBoardRequestTypeReadTemperature = 1,
	ORSSerialBoardRequestTypeReadLED,
	ORSSerialBoardRequestTypeSetLED,
};

@interface ORSSerialBoardController () <ORSSerialPortDelegate>

@property (nonatomic, readwrite) NSInteger temperature; // In degrees C

@property (nonatomic, strong) NSTimer *pollingTimer;

@end

@implementation ORSSerialBoardController

#pragma mark - Private

- (void)pollingTimerFired:(NSTimer *)timer
{
	[self readTemperature];
	[self readLEDState];
}

#pragma mark Sending Commands

- (void)readTemperature
{
	NSData *command = [@"$TEMP?;" dataUsingEncoding:NSASCIIStringEncoding];
	ORSSerialPacketDescriptor *responseDescriptor =
	[[ORSSerialPacketDescriptor alloc] initWithMaximumPacketLength:10
														  userInfo:nil
												 responseEvaluator:^BOOL(NSData *inputData) {
													 return [self temperatureFromResponsePacket:inputData] != nil;
												 }];
	ORSSerialRequest *request = [ORSSerialRequest requestWithDataToSend:command
															   userInfo:@(ORSSerialBoardRequestTypeReadTemperature)
														timeoutInterval:kTimeoutDuration
													 responseDescriptor:responseDescriptor];
	[self.serialPort sendRequest:request];
}

- (void)readLEDState
{
	NSData *command = [@"$LED?;" dataUsingEncoding:NSASCIIStringEncoding];
	ORSSerialPacketDescriptor *responseDescriptor =
	[[ORSSerialPacketDescriptor alloc] initWithMaximumPacketLength:10
														  userInfo:nil
												 responseEvaluator:^BOOL(NSData *inputData) {
													 return [self LEDStateFromResponsePacket:inputData] != nil;
												 }];
	ORSSerialRequest *request = [ORSSerialRequest requestWithDataToSend:command
															   userInfo:@(ORSSerialBoardRequestTypeReadLED)
														timeoutInterval:kTimeoutDuration
													 responseDescriptor:responseDescriptor];
	[self.serialPort sendRequest:request];
}

- (void)sendCommandToSetLEDToState:(BOOL)LEDState
{
	NSString *commandString = [NSString stringWithFormat:@"$LED%@;", (LEDState ? @"1" : @"0")];
	NSData *command = [commandString dataUsingEncoding:NSASCIIStringEncoding];
	ORSSerialPacketDescriptor *responseDescriptor =
	[[ORSSerialPacketDescriptor alloc] initWithMaximumPacketLength:10
														  userInfo:nil
												 responseEvaluator:^BOOL(NSData *inputData) {
													 return [self LEDStateFromResponsePacket:inputData] != nil;
												 }];
	ORSSerialRequest *request = [ORSSerialRequest requestWithDataToSend:command
															   userInfo:@(ORSSerialBoardRequestTypeSetLED)
														timeoutInterval:kTimeoutDuration
													 responseDescriptor:responseDescriptor];
	[self.serialPort sendRequest:request];
}

#pragma mark Parsing Responses

- (NSNumber *)temperatureFromResponsePacket:(NSData *)data
{
	if (![data length]) return nil;
	NSString *dataAsString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	if (![dataAsString hasPrefix:@"!TEMP"]) return nil;
	if (![dataAsString hasSuffix:@";"]) return nil;
	if ([dataAsString length] < 6) return nil;
	
	NSString *temperatureString = [dataAsString substringWithRange:NSMakeRange(5, [dataAsString length]-6)];
	return @([temperatureString integerValue]);
}

- (NSNumber *)LEDStateFromResponsePacket:(NSData *)data
{
	if (![data length]) return nil;
	NSString *dataAsString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	if (![dataAsString hasPrefix:@"!LED"]) return nil;
	if (![dataAsString hasSuffix:@";"]) return nil;
	if ([dataAsString length] < 6) return nil;
	
	NSString *LEDStateString = [dataAsString substringWithRange:NSMakeRange(4, [dataAsString length]-5)];
	return @([LEDStateString integerValue]);
}

#pragma mark - ORSSerialPortDelegate

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort
{
	self.serialPort = nil;
}

- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error
{
	NSLog(@"Serial port %@ encountered an error: %@", self.serialPort, error);
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveResponse:(NSData *)responseData toRequest:(ORSSerialRequest *)request
{
	ORSSerialBoardRequestType requestType = [request.userInfo integerValue];
	switch (requestType) {
		case ORSSerialBoardRequestTypeReadTemperature:
			self.temperature = [[self temperatureFromResponsePacket:responseData] integerValue];
			break;
			
		case ORSSerialBoardRequestTypeReadLED:
		case ORSSerialBoardRequestTypeSetLED:
			// Don't call the setter to avoid continuing to send set commands indefinitely
			[self willChangeValueForKey:@"LEDOn"];
			_LEDOn = [[self LEDStateFromResponsePacket:responseData] boolValue];
			[self didChangeValueForKey:@"LEDOn"];
			break;
			
		default:
			break;
	}
}

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort
{
	// Start polling
	self.pollingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(pollingTimerFired:) userInfo:nil repeats:YES];
	[self.pollingTimer fire]; // Do first read
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort
{
	// Stop polling
	self.pollingTimer = nil;
}

#pragma mark - Properties

- (void)setSerialPort:(ORSSerialPort *)serialPort
{
	if (serialPort != _serialPort) {
		[_serialPort close];
		_serialPort.delegate = nil;
		
		_serialPort = serialPort;
		
		_serialPort.baudRate = @57600;
		_serialPort.delegate = self;
		_serialPort.RTS = YES;
		[_serialPort open];
	}
}

- (void)setLEDOn:(BOOL)LEDOn
{
	_LEDOn = LEDOn;
	[self sendCommandToSetLEDToState:_LEDOn];
}

- (void)setPollingTimer:(NSTimer *)pollingTimer
{
	if (pollingTimer != _pollingTimer) {
		[_pollingTimer invalidate];
		_pollingTimer = pollingTimer;
	}
}

@end
