//
//  ORSSerialPort_Tests.m
//  ORSSerialPort Tests
//
//  Created by Andrew Madsen on 8/1/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <ORSSerial/ORSSerial.h>

@interface ORSSerialPort_Tests : XCTestCase <ORSSerialPortDelegate>

@property (nonatomic, strong) ORSSerialPort *serialPort;

// Expectations
@property (nonatomic, strong) XCTestExpectation *serialPortOpenExpectation;
@property (nonatomic, strong) XCTestExpectation *serialPortCloseExpectation;

@property (nonatomic, copy) void (^blockToRunAfterOpening)(void);

@end

@implementation ORSSerialPort_Tests

#pragma mark - Setup/Teardown

static ORSSerialPort *sharedSerialPort = nil;

// We need tests to run in a well-defined order, so we return our own, correctly ordered array of NSInvocations
// here. Since we must manually add test methods here, this will assert if any test methods are not in the ordered
// array.
+ (NSArray *)testInvocations
{
	NSArray *selectorStrings = @[
								 @"testPortNotNil",
								 @"testOpeningPort",
								 @"testSendingWithEcho",
								 @"testSettingRTS",
								 @"testClearingRTS",
								 @"testSettingDTR",
								 @"testClearingDTR",
								 @"testReadingCTSChange1",
								 @"testReadingDSRChange1",
								 @"testReadingCTSChange2",
								 @"testReadingDSRChange2",
								 @"testReadingDCDChange1",
								 @"testReadingDCDChange2",
								 @"testSendingGoodbye",
								 @"testClosingPort"
								 ];
	
	NSMutableArray *result = [NSMutableArray array];
	for (NSString *selectorString in selectorStrings) {
		SEL selector = NSSelectorFromString(selectorString);
		NSMethodSignature *methodSignature = [self instanceMethodSignatureForSelector:selector];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
		invocation.selector = selector;
		[result addObject:invocation];
	}
	
	
	NSMutableSet *superSet = [NSMutableSet set];
	for (NSInvocation *invocation in [super testInvocations]) { [superSet addObject:NSStringFromSelector(invocation.selector)]; }
	for (NSInvocation *invocation in result) { [superSet removeObject:NSStringFromSelector(invocation.selector)]; }
	NSAssert(superSet.count == 0, @"Test methods are not being returned from +testInvocations: %@", superSet);
	
	return result;
}

+ (void)setUp
{
	ORSSerialPortManager *manager = [ORSSerialPortManager sharedSerialPortManager];
	NSPredicate *notBluetooth = [NSPredicate predicateWithFormat:@"!(name contains[cd] %@)", @"bluetooth"];
	NSArray *usablePorts = [manager.availablePorts filteredArrayUsingPredicate:notBluetooth];
	if ([usablePorts count] > 0) {
		//		sharedSerialPort = usablePorts[0]; // Let testbed app take the first port
		sharedSerialPort = [ORSSerialPort serialPortWithPath:@"/dev/cu.USA19H1442P1.1"];
		sharedSerialPort.baudRate = @57600;
	}
}

+ (void)tearDown
{
	[sharedSerialPort sendData:[@"Goodbye!" dataUsingEncoding:NSASCIIStringEncoding]];
	[sharedSerialPort close];
	sharedSerialPort = nil;
}

- (void)setUp
{
	self.serialPort = sharedSerialPort;
}

#pragma mark - Test Cases

#pragma mark Open/Close

- (void)testPortNotNil
{
	XCTAssertNotNil(self.serialPort, @"self.serialPort is nil");
}

- (void)testOpeningPort
{
	XCTAssertFalse(self.serialPort.isOpen, @"Serial port was already open");
	self.serialPortOpenExpectation = [self expectationWithDescription:@"Serial port open expectation"];
	[self.serialPort open];
	[self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
		if (error) {
			NSLog(@"Expectations not fulfilled.");
		}
	}];
}

- (void)testClosingPort
{
	XCTAssertTrue(self.serialPort.isOpen, @"Serial port was already closed");
	self.serialPortCloseExpectation = [self expectationWithDescription:@"Serial port close expectation"];
	[self.serialPort close];
	[self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
		if (error) {
			NSLog(@"Expectations not fulfilled.");
			return;
		}
	}];
}

#pragma mark Basic Send/Receive

- (void)testSendingWithEcho
{
	XCTestExpectation *expectation = [self expectationWithDescription:@"ACK expectation"];
	NSData *ackData = [NSData dataWithBytes:&(char){0x06} length:1];
	ORSSerialPacketDescriptor *ack = [[ORSSerialPacketDescriptor alloc] initWithPacketData:ackData userInfo:nil];
	ORSSerialRequest *request = [ORSSerialRequest requestWithDataToSend:[@"Hello?" dataUsingEncoding:NSASCIIStringEncoding]
															   userInfo:expectation
														timeoutInterval:1.0
													 responseDescriptor:ack];
	
	[self openPortIfNeededThen:^{
		[self.serialPort sendRequest:request];
	}];
	
	[self waitForExpectationsWithTimeout:0.25 handler:^(NSError *error) {
		if (error) { NSLog(@"Expectations not fulfilled."); }
	}];
}

- (void)testSendingGoodbye
{
	XCTestExpectation *expectation = [self expectationWithDescription:@"ACK expectation"];
	NSData *ackData = [NSData dataWithBytes:&(char){0x06} length:1];
	ORSSerialPacketDescriptor *ack = [[ORSSerialPacketDescriptor alloc] initWithPacketData:ackData userInfo:nil];
	ORSSerialRequest *request = [ORSSerialRequest requestWithDataToSend:[@"Goodbye!" dataUsingEncoding:NSASCIIStringEncoding]
															   userInfo:expectation
														timeoutInterval:1.0
													 responseDescriptor:ack];
	
	[self openPortIfNeededThen:^{
		[self.serialPort sendRequest:request];
	}];
	
	[self waitForExpectationsWithTimeout:0.25 handler:^(NSError *error) {
		if (error) { NSLog(@"Expectations not fulfilled."); }
	}];
}

#pragma mark Hardware Pins

- (void)testSettingRTS
{
	self.serialPort.RTS = NO; // Clear pin to start with
	
	[NSThread sleepForTimeInterval:0.1];
	
	self.serialPort.RTS = YES;
	
	[NSThread sleepForTimeInterval:0.1];
	
	NSData *ctsStateReadCommand = [@"CTS?" dataUsingEncoding:NSASCIIStringEncoding];
	ORSSerialPacketDescriptor *ackDescriptor = [[ORSSerialPacketDescriptor alloc] initWithPrefixString:@"CTS1;"
																						  suffixString:nil
																				   maximumPacketLength:5
																							  userInfo:nil];
	XCTestExpectation *expectation = [self expectationWithDescription:@"RTS set ack expectation"];
	ORSSerialRequest *ctsStateRequest = [ORSSerialRequest requestWithDataToSend:ctsStateReadCommand
																	   userInfo:expectation
																timeoutInterval:0.1
															 responseDescriptor:ackDescriptor];
	
	[self openPortIfNeededThen:^{
		[self.serialPort sendRequest:ctsStateRequest];
	}];
	
	[self waitForExpectationsWithTimeout:0.2 handler:^(NSError *error) {
		if (error) { NSLog(@"Expectations not fulfilled."); }
	}];
}

- (void)testClearingRTS
{
	self.serialPort.RTS = YES; // Set pin to start with
	
	[NSThread sleepForTimeInterval:0.1];
	
	self.serialPort.RTS = NO;
	
	[NSThread sleepForTimeInterval:0.1];
	
	NSData *ctsStateReadCommand = [@"CTS?" dataUsingEncoding:NSASCIIStringEncoding];
	ORSSerialPacketDescriptor *ackDescriptor = [[ORSSerialPacketDescriptor alloc] initWithPrefixString:@"CTS0;"
																						  suffixString:nil
																				   maximumPacketLength:5
																							  userInfo:nil];
	XCTestExpectation *expectation = [self expectationWithDescription:@"RTS clear ack expectation"];
	ORSSerialRequest *ctsStateRequest = [ORSSerialRequest requestWithDataToSend:ctsStateReadCommand
																	   userInfo:expectation
																timeoutInterval:0.1
															 responseDescriptor:ackDescriptor];
	
	[self openPortIfNeededThen:^{
		[self.serialPort sendRequest:ctsStateRequest];
	}];
	
	[self waitForExpectationsWithTimeout:0.2 handler:^(NSError *error) {
		if (error) { NSLog(@"Expectations not fulfilled."); }
	}];
}

- (void)testSettingDTR
{
	self.serialPort.DTR = NO; // Clear pin to start with
	
	[NSThread sleepForTimeInterval:0.1];
	
	self.serialPort.DTR = YES;
	
	[NSThread sleepForTimeInterval:0.1];
	
	NSData *ctsStateReadCommand = [@"DSR?" dataUsingEncoding:NSASCIIStringEncoding];
	ORSSerialPacketDescriptor *ackDescriptor = [[ORSSerialPacketDescriptor alloc] initWithPrefixString:@"DSR1;"
																						  suffixString:nil
																				   maximumPacketLength:5
																							  userInfo:nil];
	XCTestExpectation *expectation = [self expectationWithDescription:@"DTR set ack expectation"];
	ORSSerialRequest *ctsStateRequest = [ORSSerialRequest requestWithDataToSend:ctsStateReadCommand
																	   userInfo:expectation
																timeoutInterval:0.1
															 responseDescriptor:ackDescriptor];
	
	[self openPortIfNeededThen:^{
		[self.serialPort sendRequest:ctsStateRequest];
	}];
	
	[self waitForExpectationsWithTimeout:0.2 handler:^(NSError *error) {
		if (error) { NSLog(@"Expectations not fulfilled."); }
	}];
}

- (void)testClearingDTR
{
	self.serialPort.DTR = YES; // Set pin to start with
	
	[NSThread sleepForTimeInterval:0.1];
	
	self.serialPort.DTR = NO;
	
	[NSThread sleepForTimeInterval:0.1];
	
	NSData *ctsStateReadCommand = [@"DSR?" dataUsingEncoding:NSASCIIStringEncoding];
	ORSSerialPacketDescriptor *ackDescriptor = [[ORSSerialPacketDescriptor alloc] initWithPrefixString:@"DSR0;"
																						  suffixString:nil
																				   maximumPacketLength:5
																							  userInfo:nil];
	XCTestExpectation *expectation = [self expectationWithDescription:@"DTR clear ack expectation"];
	ORSSerialRequest *ctsStateRequest = [ORSSerialRequest requestWithDataToSend:ctsStateReadCommand
																	   userInfo:expectation
																timeoutInterval:0.1
															 responseDescriptor:ackDescriptor];
	
	[self openPortIfNeededThen:^{
		[self.serialPort sendRequest:ctsStateRequest];
	}];
	
	[self waitForExpectationsWithTimeout:0.2 handler:^(NSError *error) {
		if (error) { NSLog(@"Expectations not fulfilled."); }
	}];
}

- (void)testReadingCTSChange1
{
	BOOL initialState = self.serialPort.CTS;
	NSString *commandString = initialState ? @"RTS0;" : @"RTS1;";
	NSData *command = [commandString dataUsingEncoding:NSASCIIStringEncoding];
	[self keyValueObservingExpectationForObject:self.serialPort keyPath:@"CTS" expectedValue:@(!initialState)];
	[self.serialPort sendData:command];
	[self waitForExpectationsWithTimeout:0.2 handler:^(NSError *error) {
		if (error) { NSLog(@"Expectations not fulfilled."); }
	}];
}

- (void)testReadingCTSChange2
{
	BOOL initialState = self.serialPort.CTS;
	NSString *commandString = initialState ? @"RTS0;" : @"RTS1;";
	NSData *command = [commandString dataUsingEncoding:NSASCIIStringEncoding];
	[self keyValueObservingExpectationForObject:self.serialPort keyPath:@"CTS" expectedValue:@(!initialState)];
	[self.serialPort sendData:command];
	[self waitForExpectationsWithTimeout:0.2 handler:^(NSError *error) {
		if (error) { NSLog(@"Expectations not fulfilled."); }
	}];
}

- (void)testReadingDSRChange1
{
	BOOL initialState = self.serialPort.DSR;
	NSString *commandString = initialState ? @"DTR0;" : @"DTR1;";
	NSData *command = [commandString dataUsingEncoding:NSASCIIStringEncoding];
	[self keyValueObservingExpectationForObject:self.serialPort keyPath:@"DSR" expectedValue:@(!initialState)];
	[self.serialPort sendData:command];
	[self waitForExpectationsWithTimeout:0.2 handler:^(NSError *error) {
		if (error) { NSLog(@"Expectations not fulfilled."); }
	}];
}

- (void)testReadingDSRChange2
{
	BOOL initialState = self.serialPort.DSR;
	NSString *commandString = initialState ? @"DTR0;" : @"DTR1;";
	NSData *command = [commandString dataUsingEncoding:NSASCIIStringEncoding];
	[self keyValueObservingExpectationForObject:self.serialPort keyPath:@"DSR" expectedValue:@(!initialState)];
	[self.serialPort sendData:command];
	[self waitForExpectationsWithTimeout:0.2 handler:^(NSError *error) {
		if (error) { NSLog(@"Expectations not fulfilled."); }
	}];
}

- (void)testReadingDCDChange1
{
	BOOL initialState = self.serialPort.DCD;
	NSString *commandString = initialState ? @"DTR0;" : @"DTR1;";
	NSData *command = [commandString dataUsingEncoding:NSASCIIStringEncoding];
	[self keyValueObservingExpectationForObject:self.serialPort keyPath:@"DCD" expectedValue:@(!initialState)];
	[self.serialPort sendData:command];
	[self waitForExpectationsWithTimeout:0.2 handler:^(NSError *error) {
		if (error) { NSLog(@"Expectations not fulfilled."); }
	}];
}

- (void)testReadingDCDChange2
{
	BOOL initialState = self.serialPort.DCD;
	NSString *commandString = initialState ? @"DTR0;" : @"DTR1;";
	NSData *command = [commandString dataUsingEncoding:NSASCIIStringEncoding];
	[self keyValueObservingExpectationForObject:self.serialPort keyPath:@"DCD" expectedValue:@(!initialState)];
	[self.serialPort sendData:command];
	[self waitForExpectationsWithTimeout:0.2 handler:^(NSError *error) {
		if (error) { NSLog(@"Expectations not fulfilled."); }
	}];
}

#pragma mark - Private

- (void)openPortIfNeededThen:(void (^)(void))block
{
	block = block ?: ^{};
	if (self.serialPort.isOpen) return block();
	
	self.blockToRunAfterOpening = block;
	[self.serialPort open];
}

#pragma mark - ORSSerialPortDelegate

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort
{
	self.serialPort = nil;
}

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort
{
	[self.serialPortOpenExpectation fulfill];
	
	if (self.blockToRunAfterOpening) self.blockToRunAfterOpening();
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort
{
	[self.serialPortCloseExpectation fulfill];
}

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveResponse:(NSData *)responseData toRequest:(ORSSerialRequest *)request
{
	if ([request.userInfo isKindOfClass:[XCTestExpectation class]]) {
		[request.userInfo fulfill];
	}
}

#pragma mark - Properties

- (void)setSerialPort:(ORSSerialPort *)serialPort
{
	if (serialPort != _serialPort) {
		_serialPort.delegate = nil;
		_serialPort = serialPort;
		_serialPort.delegate = self;
	}
}

@end
