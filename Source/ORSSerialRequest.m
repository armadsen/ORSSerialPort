//
//  ORSSerialRequest.h
//  ORSSerialPort
//
//  Created by Andrew Madsen on 4/21/14.
//  Copyright (c) 2014 Andrew Madsen. All rights reserved.
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
