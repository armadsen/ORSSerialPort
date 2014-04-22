//
//  ORSSerialRequest.m
//  CameraRemote
//
//  Created by Andrew Madsen on 4/21/14.
//  Copyright (c) 2014 Ryan Darton. All rights reserved.
//

#import "ORSSerialRequest.h"

@interface ORSSerialRequest ()

@property (nonatomic, strong, readwrite) NSData *dataToSend;
@property (nonatomic, strong, readwrite) id userInfo;
@property (nonatomic, strong) ORSSerialRequestResponseEvaluator responseEvaluator;
@property (nonatomic, strong, readwrite) NSString *UUIDString;

@end

@implementation ORSSerialRequest

+ (instancetype)requestWithDataToSend:(NSData *)dataToSend
							 userInfo:(id)userInfo
					responseEvaluator:(ORSSerialRequestResponseEvaluator)responseEvaluator;
{
	return [[self alloc] initWithDataToSend:dataToSend userInfo:userInfo responseEvaluator:responseEvaluator];
}

- (instancetype)initWithDataToSend:(NSData *)dataToSend
						  userInfo:(id)userInfo
				 responseEvaluator:(ORSSerialRequestResponseEvaluator)responseEvaluator;
{
	self = [super init];
	if (self) {
		_dataToSend = dataToSend;
		_userInfo = userInfo;
		_responseEvaluator = responseEvaluator;
		CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
		_UUIDString = CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuid));
		CFRelease(uuid);
	}
	return self;
}

- (BOOL)dataIsValidResponse:(NSData *)responseData
{
	if (!self.responseEvaluator) return [responseData length] > 0;
	
	return self.responseEvaluator(responseData);
}

@end
