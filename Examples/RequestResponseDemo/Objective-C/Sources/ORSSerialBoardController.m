//
//  ORSSerialBoardController.m
//  RequestResponseDemo
//
//  Created by Andrew Madsen on 3/14/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import "ORSSerialBoardController.h"
@import ORSSerial;

static const NSTimeInterval kTimeoutDuration = 0.5;

typedef NS_ENUM(NSInteger, ORSSerialBoardRequestType) {
	ORSSerialBoardRequestTypeReadTemperature = 1,
	ORSSerialBoardRequestTypeSetLED,
	ORSSerialBoardRequestTypeReadLED,
};

@interface ORSSerialBoardController () <ORSSerialPortDelegate>

@property (nonatomic, readwrite) NSInteger temperature; // In degrees C

@property (nonatomic, strong) NSTimer *pollingTimer;

@end

@implementation ORSSerialBoardController

#pragma mark - Private

- (void)readTemperature
{
	NSData *command = [@"$TEMP?;" dataUsingEncoding:NSASCIIStringEncoding];
	ORSSerialRequest *request =
	[ORSSerialRequest requestWithDataToSend:command
								   userInfo:@(ORSSerialBoardRequestTypeReadTemperature)
							timeoutInterval:kTimeoutDuration
						  responseEvaluator:^BOOL(NSData *data) {
							  return [self temperatureFromResponsePacket:data] != nil;
        }];
	[self.serialPort sendRequest:request];
}

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

- (void)pollingTimerFired:(NSTimer *)timer
{
	[self readTemperature];
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
		default:
			break;
	}
}

- (void)serialPort:(ORSSerialPort *)serialPort requestDidTimeout:(ORSSerialRequest *)request
{
	NSLog(@"Request %@ timed out.", request);
}

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort
{
	// Start polling
	self.pollingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(pollingTimerFired:) userInfo:nil repeats:YES];
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
		[_serialPort open];
	}
}

- (void)setPollingTimer:(NSTimer *)pollingTimer
{
	if (pollingTimer != _pollingTimer) {
		[_pollingTimer invalidate];
		_pollingTimer = pollingTimer;
	}
}

@end
