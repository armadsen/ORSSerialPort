//
//  ORSSerialRequest.h
//  ORSSerialPort
//
//  Created by Andrew Madsen on 4/21/14.
//  Copyright (c) 2014 Andrew Madsen. All rights reserved.
//

#import "ORSSerialRequest.h"

@interface ORSSerialRequest ()

@property (nonatomic, strong, readwrite) NSData *dataToSend;
@property (nonatomic, strong, readwrite) id userInfo;
@property (nonatomic, readwrite) NSTimeInterval timeoutInterval;
@property (nonatomic, strong) ORSSerialRequestResponseEvaluator responseEvaluator;
@property (nonatomic, strong, readwrite) NSString *UUIDString;

@end

@implementation ORSSerialRequest

+ (instancetype)requestWithDataToSend:(NSData *)dataToSend
							 userInfo:(id)userInfo
					  timeoutInterval:(NSTimeInterval)timeout
					responseEvaluator:(ORSSerialRequestResponseEvaluator)responseEvaluator;
{
	return [[self alloc] initWithDataToSend:dataToSend
								   userInfo:userInfo
							timeoutInterval:timeout
						  responseEvaluator:responseEvaluator];
}

- (instancetype)initWithDataToSend:(NSData *)dataToSend
						  userInfo:(id)userInfo
				   timeoutInterval:(NSTimeInterval)timeout
				 responseEvaluator:(ORSSerialRequestResponseEvaluator)responseEvaluator;
{
	self = [super init];
	if (self) {
		_dataToSend = dataToSend;
		_userInfo = userInfo;
		_timeoutInterval = timeout;
		_responseEvaluator = responseEvaluator;
		CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
		_UUIDString = CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuid));
		CFRelease(uuid);
	}
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ data: %@ userInfo: %@ timeout interval: %f", [super description], self.dataToSend, self.userInfo, self.timeoutInterval];
}

- (BOOL)dataIsValidResponse:(NSData *)responseData
{
	if (!self.responseEvaluator) return YES;
	
	return self.responseEvaluator(responseData);
}

@end
