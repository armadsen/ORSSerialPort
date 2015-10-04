//
//  ORSSerialPacketDescriptor_Tests.m
//  ORSSerialPort
//
//  Created by Andrew Madsen on 8/1/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <ORSSerial/ORSSerial.h>

#define ORSTStringToData_(x) [x dataUsingEncoding:NSASCIIStringEncoding]

@interface ORSSerialPort (Private)

- (void)receiveData:(NSData *)data;

@end

@interface ORSSerialPacketDescriptor_Tests : XCTestCase <ORSSerialPortDelegate>

@property (nonatomic, strong) ORSSerialPort *port;

@end

@implementation ORSSerialPacketDescriptor_Tests

- (void)setUp
{
	[super setUp];
	self.port = [[ORSSerialPort alloc] initWithDevice:-1];
	self.port.delegate = self;
}

- (void)tearDown
{
	[super tearDown];
	self.port.delegate = nil;
	self.port = nil;
}

#pragma mark - Test Cases

- (void)testPrefixSuffix
{
	NSData *prefix = [@"!" dataUsingEncoding:NSASCIIStringEncoding];
	NSData *suffix = [@";" dataUsingEncoding:NSASCIIStringEncoding];
	ORSSerialPacketDescriptor *descriptor = [[ORSSerialPacketDescriptor alloc] initWithPrefix:prefix
																					   suffix:suffix
											 maximumPacketLength:5
																					 userInfo:nil];
	XCTAssertNotNil(descriptor, @"Creating packet descriptor with prefix and suffix failed.");
	XCTAssertEqualObjects(descriptor.prefix, prefix, @"Desriptor prefix property incorrect.");
	XCTAssertEqualObjects(descriptor.suffix, suffix, @"Desriptor suffix property incorrect.");
	
	XCTAssertTrue([descriptor dataIsValidPacket:ORSTStringToData_(@"!foo;")], @"Valid packet rejected by descriptor.");
	XCTAssertTrue([descriptor dataIsValidPacket:ORSTStringToData_(@"!;")], @"Valid packet rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"!foo")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"foo;")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"foo")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"x!foo;")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"!foo;x")], @"Invalid packet not rejected by descriptor.");
}

- (void)testPrefixSuffixStrings
{
	ORSSerialPacketDescriptor *descriptor = [[ORSSerialPacketDescriptor alloc] initWithPrefixString:@"!"
																					   suffixString:@";"
																				maximumPacketLength:5
																						   userInfo:nil];
	XCTAssertNotNil(descriptor, @"Creating packet descriptor with prefix and suffix failed.");
	XCTAssertEqualObjects(descriptor.prefix, [@"!" dataUsingEncoding:NSASCIIStringEncoding], @"Desriptor prefix property incorrect.");
	XCTAssertEqualObjects(descriptor.suffix, [@";" dataUsingEncoding:NSASCIIStringEncoding], @"Desriptor suffix property incorrect.");
	
	XCTAssertTrue([descriptor dataIsValidPacket:ORSTStringToData_(@"!foo;")], @"Valid packet rejected by descriptor.");
	XCTAssertTrue([descriptor dataIsValidPacket:ORSTStringToData_(@"!;")], @"Valid packet rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"!foo")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"foo;")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"foo")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"x!foo;")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"!foo;x")], @"Invalid packet not rejected by descriptor.");
}

- (void)testMissingPrefix
{
	XCTestExpectation *expectation = [self expectationWithDescription:@"Missing suffix packet parsing expectation."];
	NSDictionary *userInfo = @{[@";" dataUsingEncoding:NSASCIIStringEncoding] : expectation};
	NSData *suffix = [@";" dataUsingEncoding:NSASCIIStringEncoding];
	ORSSerialPacketDescriptor *descriptor = [[ORSSerialPacketDescriptor alloc] initWithPrefix:nil
																					   suffix:suffix
																		  maximumPacketLength:5
																					 userInfo:userInfo];
	XCTAssertNotNil(descriptor, @"Creating packet descriptor with prefix and suffix failed.");
	XCTAssertEqualObjects(descriptor.suffix, suffix, @"Desriptor suffix property incorrect.");
	XCTAssertNil(descriptor.prefix, @"Desriptor prefix property incorrect.");
	
	XCTAssertTrue([descriptor dataIsValidPacket:ORSTStringToData_(@"!foo;")], @"Valid packet rejected by descriptor.");
	XCTAssertTrue([descriptor dataIsValidPacket:ORSTStringToData_(@"foobar;")], @"Valid packet rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"!foo")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"foo")], @"Invalid packet not rejected by descriptor.");
	
	[self.port startListeningForPacketsMatchingDescriptor:descriptor];
	
	NSData *buffer = [@"foobar;" dataUsingEncoding:NSASCIIStringEncoding];
	[self.port receiveData:buffer];
	
	[self waitForExpectationsWithTimeout:0.5 handler:^(NSError *error) {
		if (error) {
			NSLog(@"expectation %@ failed: %@", expectation, error);
		}
	}];
}

- (void)testMissingSuffix
{
	XCTestExpectation *expectation = [self expectationWithDescription:@"Missing suffix packet parsing expectation."];
	NSDictionary *userInfo = @{[@"!" dataUsingEncoding:NSASCIIStringEncoding] : expectation};
	NSData *prefix = [@"!" dataUsingEncoding:NSASCIIStringEncoding];
	ORSSerialPacketDescriptor *descriptor = [[ORSSerialPacketDescriptor alloc] initWithPrefix:prefix
																					   suffix:nil
																		  maximumPacketLength:5
																					 userInfo:userInfo];
	XCTAssertNotNil(descriptor, @"Creating packet descriptor with prefix and suffix failed.");
	XCTAssertEqualObjects(descriptor.prefix, prefix, @"Desriptor prefix property incorrect.");
	XCTAssertNil(descriptor.suffix, @"Desriptor suffix property incorrect.");
	
	XCTAssertTrue([descriptor dataIsValidPacket:ORSTStringToData_(@"!foo;")], @"Valid packet rejected by descriptor.");
	XCTAssertTrue([descriptor dataIsValidPacket:ORSTStringToData_(@"!foobar")], @"Valid packet rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"foo;")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"foo")], @"Invalid packet not rejected by descriptor.");
	
	[self.port startListeningForPacketsMatchingDescriptor:descriptor];
	
	NSData *buffer = [@"!foobar" dataUsingEncoding:NSASCIIStringEncoding];
	[self.port receiveData:buffer];
	
	[self waitForExpectationsWithTimeout:0.5 handler:^(NSError *error) {
		if (error) {
			NSLog(@"expectation %@ failed: %@", expectation, error);
		}
	}];
}

- (void)testRegex
{
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^!.+;$" options:0 error:NULL];
	ORSSerialPacketDescriptor *descriptor = [[ORSSerialPacketDescriptor alloc] initWithRegularExpression:regex
																					 maximumPacketLength:5
																								userInfo:nil];
	XCTAssertNotNil(descriptor, @"Creating packet descriptor with regular expression failed.");
	XCTAssertEqualObjects(descriptor.regularExpression, regex, @"Descriptor regex property incorrect.");
	
	XCTAssertTrue([descriptor dataIsValidPacket:ORSTStringToData_(@"!foo;")], @"Valid packet rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"!;")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"!foo")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"foo;")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"foo")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"x!foo;")], @"Invalid packet not rejected by descriptor.");
	XCTAssertFalse([descriptor dataIsValidPacket:ORSTStringToData_(@"!foo;x")], @"Invalid packet not rejected by descriptor.");
}

- (void)testParsingWithLeadingBadData
{
	XCTestExpectation *expectation = [self expectationWithDescription:@"Leading bad data packet parsing expectation"];
	NSDictionary *userInfo = @{[@"!bar;" dataUsingEncoding:NSASCIIStringEncoding]: expectation};
	ORSSerialPacketDescriptor *descriptor = [self defaultPacketDescriptorWithUserInfo:userInfo];
	[self.port startListeningForPacketsMatchingDescriptor:descriptor];
	
	NSData *buffer = [@"!fo!bar;" dataUsingEncoding:NSASCIIStringEncoding];
	[self.port receiveData:buffer];
	
	[self waitForExpectationsWithTimeout:0.5 handler:^(NSError *error) {
		if (error) {
			NSLog(@"expectation %@ failed: %@", expectation, error);
		}
	}];
}

- (void)testParsingMultipleDifferentPackets
{
	XCTestExpectation *expectation1 = [self expectationWithDescription:@"Multiple packets type 1 parsing expectation"];
	XCTestExpectation *expectation2 = [self expectationWithDescription:@"Multiple packets type 2 parsing expectation"];
	
	NSDictionary *userInfo1 = @{[@"!foo;" dataUsingEncoding:NSASCIIStringEncoding]: expectation1};
	NSDictionary *userInfo2 = @{[@"$bar;" dataUsingEncoding:NSASCIIStringEncoding]: expectation2};
	ORSSerialPacketDescriptor *descriptor1 = [self defaultPacketDescriptorWithUserInfo:userInfo1];
	ORSSerialPacketDescriptor *descriptor2 = [[ORSSerialPacketDescriptor alloc] initWithPrefix:[@"$" dataUsingEncoding:NSASCIIStringEncoding]
																						suffix:[@";" dataUsingEncoding:NSASCIIStringEncoding]
																		   maximumPacketLength:5
																					  userInfo:userInfo2];
	[self.port startListeningForPacketsMatchingDescriptor:descriptor1];
	[self.port startListeningForPacketsMatchingDescriptor:descriptor2];
	
	[self.port receiveData:[@"$bar" dataUsingEncoding:NSASCIIStringEncoding]];
	[self.port receiveData:[@";!foo;" dataUsingEncoding:NSASCIIStringEncoding]];
	
	[self waitForExpectationsWithTimeout:0.5 handler:^(NSError *error) {
		if (error) {
			NSLog(@"expectations failed: %@", error);
		}
	}];
}

- (void)testParsingMultipleSimilarPackets
{
	XCTestExpectation *expectation1 = [self expectationWithDescription:@"Multiple packets parsing expectation 1"];
	XCTestExpectation *expectation2 = [self expectationWithDescription:@"Multiple packets parsing expectation 2"];
	NSDictionary *userInfo1 = @{[@"!foo;" dataUsingEncoding:NSASCIIStringEncoding]: expectation1};
	NSDictionary *userInfo2 = @{[@"!bar;" dataUsingEncoding:NSASCIIStringEncoding]: expectation2};
	ORSSerialPacketDescriptor *descriptor1 = [self defaultPacketDescriptorWithUserInfo:userInfo1];
	ORSSerialPacketDescriptor *descriptor2 = [self defaultPacketDescriptorWithUserInfo:userInfo2];
	
	[self.port startListeningForPacketsMatchingDescriptor:descriptor1];
	[self.port startListeningForPacketsMatchingDescriptor:descriptor2];
	
	[self.port receiveData:[@"!ba" dataUsingEncoding:NSASCIIStringEncoding]];
	[self.port receiveData:[@"r;!fo" dataUsingEncoding:NSASCIIStringEncoding]];
	[self.port receiveData:[@"o;!ba" dataUsingEncoding:NSASCIIStringEncoding]];
	
	[self waitForExpectationsWithTimeout:0.5 handler:^(NSError *error) {
		if (error) {
			NSLog(@"expectations failed: %@", error);
		}
	}];
}

- (void)testMultipleIncomingPacketsInASingleReceive
{
	XCTestExpectation *expectation1 = [self expectationWithDescription:@"Multiple packets single receive parsing expectation 1"];
	XCTestExpectation *expectation2 = [self expectationWithDescription:@"Multiple packets single receive parsing expectation 2"];
	NSDictionary *userInfo1 = @{[@"!foo;" dataUsingEncoding:NSASCIIStringEncoding]: expectation1};
	NSDictionary *userInfo2 = @{[@"!bar;" dataUsingEncoding:NSASCIIStringEncoding]: expectation2};
	ORSSerialPacketDescriptor *descriptor1 = [self defaultPacketDescriptorWithUserInfo:userInfo1];
	ORSSerialPacketDescriptor *descriptor2 = [self defaultPacketDescriptorWithUserInfo:userInfo2];
	
	[self.port startListeningForPacketsMatchingDescriptor:descriptor1];
	[self.port startListeningForPacketsMatchingDescriptor:descriptor2];
	
	[self.port receiveData:[@"!foo;!bar;" dataUsingEncoding:NSASCIIStringEncoding]];
	
	[self waitForExpectationsWithTimeout:0.5 handler:^(NSError *error) {
		if (error) {
			NSLog(@"expectations failed: %@", error);
		}
	}];
}

- (void)testParsingNestedPackets
{
	XCTestExpectation *expectation1 = [self expectationWithDescription:@"Nested packets parsing expectation 1"];
	XCTestExpectation *expectation2 = [self expectationWithDescription:@"Nested packets parsing expectation 2"];
	NSDictionary *userInfo1 = @{[@"!foo$bar%;" dataUsingEncoding:NSASCIIStringEncoding]: expectation1};
	NSDictionary *userInfo2 = @{[@"$bar%" dataUsingEncoding:NSASCIIStringEncoding]: expectation2};
	ORSSerialPacketDescriptor *descriptor1 = [self defaultPacketDescriptorWithUserInfo:userInfo1];
	ORSSerialPacketDescriptor *descriptor2 = [[ORSSerialPacketDescriptor alloc] initWithPrefix:[@"$" dataUsingEncoding:NSASCIIStringEncoding]
																						suffix:[@"%" dataUsingEncoding:NSASCIIStringEncoding]
																		   maximumPacketLength:5
																					  userInfo:userInfo2];
	[self.port startListeningForPacketsMatchingDescriptor:descriptor1];
	[self.port startListeningForPacketsMatchingDescriptor:descriptor2];
	
	[self.port receiveData:[@"!foo" dataUsingEncoding:NSASCIIStringEncoding]];
	[self.port receiveData:[@"$bar" dataUsingEncoding:NSASCIIStringEncoding]];
	[self.port receiveData:[@"%;" dataUsingEncoding:NSASCIIStringEncoding]];
	
	[self waitForExpectationsWithTimeout:0.5 handler:^(NSError *error) {
		if (error) {
			NSLog(@"expectations failed: %@", error);
		}
	}];
}

- (void)testPacketDescriptorsPropertyAdd
{
	XCTAssertNotNil(self.port.packetDescriptors, @"-[ORSSerialPort packetDescriptors] returned nil.");
	XCTAssert([self.port.packetDescriptors count] == 0, @"-[ORSSerialPort packetDescriptors] returned non-empty array with no descriptors added.");
	
	ORSSerialPacketDescriptor *descriptor = [self defaultPacketDescriptorWithUserInfo:nil];
	[self keyValueObservingExpectationForObject:self.port keyPath:@"packetDescriptors" expectedValue:@[descriptor]];
	[self.port startListeningForPacketsMatchingDescriptor:descriptor];
	
	[self waitForExpectationsWithTimeout:0.1 handler:^(NSError *error) {
		if (error) {
			NSLog(@"expectations failed: %@", error);
		}
	}];
}

- (void)testPacketDescriptorsPropertyRemove
{
	ORSSerialPacketDescriptor *descriptor = [self defaultPacketDescriptorWithUserInfo:nil];
	[self.port startListeningForPacketsMatchingDescriptor:descriptor];
	XCTAssertEqualObjects(@[descriptor], self.port.packetDescriptors, @"-packetDescriptors did not return expected result.");
	
	[self keyValueObservingExpectationForObject:self.port keyPath:@"packetDescriptors" expectedValue:@[]];
	[self.port stopListeningForPacketsMatchingDescriptor:descriptor];
	
	[self waitForExpectationsWithTimeout:0.1 handler:^(NSError *error) {
		if (error) {
			NSLog(@"expectations failed: %@", error);
		}
	}];
}

#pragma mark - Performance

- (void)testPerformanceWithMultipleInstalledDescriptors
{
	[self measureMetrics:@[XCTPerformanceMetric_WallClockTime] automaticallyStartMeasuring:YES forBlock:^{
		XCTestExpectation *expectation1 = [self expectationWithDescription:@"Multiple packets type 1 parsing expectation"];
		
		NSDictionary *userInfo1 = @{[@"!foo;" dataUsingEncoding:NSASCIIStringEncoding]: expectation1};
		ORSSerialPacketDescriptor *descriptor1 = [self defaultPacketDescriptorWithUserInfo:userInfo1];
		ORSSerialPacketDescriptor *descriptor2 = [[ORSSerialPacketDescriptor alloc] initWithPrefix:[@"$ba" dataUsingEncoding:NSASCIIStringEncoding]
																							suffix:[@";" dataUsingEncoding:NSASCIIStringEncoding]
																			   maximumPacketLength:5
																						  userInfo:nil];
		
		[self.port startListeningForPacketsMatchingDescriptor:descriptor1];
		[self.port startListeningForPacketsMatchingDescriptor:descriptor2];
		
		for (NSUInteger i=0; i<320; i++) {
			[self.port receiveData:[@"$bar" dataUsingEncoding:NSASCIIStringEncoding]];
			[self.port receiveData:[@";" dataUsingEncoding:NSASCIIStringEncoding]];
		}
		[self.port receiveData:[@"!foo;" dataUsingEncoding:NSASCIIStringEncoding]];
		
		[self waitForExpectationsWithTimeout:100 handler:^(NSError *error) {
			if (error) {
				NSLog(@"expectations failed: %@", error);
			}
			
			[self.port stopListeningForPacketsMatchingDescriptor:descriptor1];
			[self.port stopListeningForPacketsMatchingDescriptor:descriptor2];
		}];
		
	}];
	
}

#pragma mark - Utilties

- (ORSSerialPacketDescriptor *)defaultPacketDescriptorWithUserInfo:(id)userInfo
{
	NSData *prefix = [@"!" dataUsingEncoding:NSASCIIStringEncoding];
	NSData *suffix = [@";" dataUsingEncoding:NSASCIIStringEncoding];
	return [[ORSSerialPacketDescriptor alloc] initWithPrefix:prefix suffix:suffix maximumPacketLength:20 userInfo:userInfo];
}

#pragma mark - ORSSerialPortDelegate

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort {}

- (void)serialPort:(ORSSerialPort *)serialPort didReceivePacket:(NSData *)packetData matchingDescriptor:(ORSSerialPacketDescriptor *)descriptor
{
	NSDictionary *userInfo = (NSDictionary *)descriptor.userInfo;
	XCTestExpectation *expectation = userInfo[packetData];
	[expectation fulfill];
}

@end
