//
//  ORSSerialRequest.h
//  ORSSerialPort
//
//  Created by Andrew Madsen on 4/21/14.
//  Copyright (c) 2014 Andrew Madsen. All rights reserved.
//

#import "ORSSerialRequest.h"
#import "ORSSerialPacketDescriptor.h"

@interface ORSSerialRequest ()

@property (nonatomic, strong, readwrite) NSData *dataToSend;
@property (nonatomic, strong, readwrite) id userInfo;
@property (nonatomic, readwrite) NSTimeInterval timeoutInterval;
@property (nonatomic, strong) ORSSerialPacketDescriptor *responseDescriptor;
@property (nonatomic, strong, readwrite) NSString *UUIDString;

@end

@implementation ORSSerialRequest

+(instancetype)requestWithDataToSend:(NSData *)dataToSend
							userInfo:(id)userInfo
					 timeoutInterval:(NSTimeInterval)timeout
				  responseDescriptor:(ORSSerialPacketDescriptor *)responseDescriptor
{
	return [[self alloc] initWithDataToSend:dataToSend userInfo:userInfo timeoutInterval:timeout responseDescriptor:responseDescriptor];
}

+ (instancetype)requestWithDataToSend:(NSData *)dataToSend
							 userInfo:(id)userInfo
					  timeoutInterval:(NSTimeInterval)timeout
					responseEvaluator:(ORSSerialResponseEvaluator)responseEvaluator;
{
	return [[self alloc] initWithDataToSend:dataToSend userInfo:userInfo timeoutInterval:timeout responseEvaluator:responseEvaluator];
}

- (instancetype)initWithDataToSend:(NSData *)dataToSend
									userInfo:(id)userInfo
							 timeoutInterval:(NSTimeInterval)timeout
						  responseDescriptor:(ORSSerialPacketDescriptor *)responseDescriptor
{
	self = [super init];
	if (self) {
		_dataToSend = dataToSend;
		_userInfo = userInfo;
		_timeoutInterval = timeout;
		_responseDescriptor = responseDescriptor;
		CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
		_UUIDString = CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuid));
		CFRelease(uuid);
	}
	return self;
}

- (instancetype)initWithDataToSend:(NSData *)dataToSend
						  userInfo:(id)userInfo
				   timeoutInterval:(NSTimeInterval)timeout
				 responseEvaluator:(ORSSerialResponseEvaluator)responseEvaluator;
{
	ORSSerialPacketDescriptor *descriptor = [[ORSSerialPacketDescriptor alloc] initWithUserInfo:nil responseEvaluator:responseEvaluator];
	return [self initWithDataToSend:dataToSend userInfo:userInfo timeoutInterval:timeout responseDescriptor:descriptor];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ data: %@ userInfo: %@ timeout interval: %f", [super description], self.dataToSend, self.userInfo, self.timeoutInterval];
}

- (BOOL)dataIsValidResponse:(NSData *)responseData
{
	if (!self.responseDescriptor) return YES;
	
	return [self.responseDescriptor dataIsValidPacket:responseData];
}

@end
