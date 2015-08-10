//
//  ORSSerialPacketDescriptor.m
//  ORSSerialPort
//
//  Created by Andrew Madsen on 7/21/15.
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

#import "ORSSerialPacketDescriptor.h"

@interface ORSSerialPacketDescriptor ()

@property (nonatomic, copy, readonly) ORSSerialResponseEvaluator responseEvaluator;

@end

@implementation ORSSerialPacketDescriptor

- (instancetype)initWithUserInfo:(id)userInfo responseEvaluator:(ORSSerialResponseEvaluator)responseEvaluator
{
	self = [super init];
	if (self) {
		_userInfo = userInfo;
		_responseEvaluator = [responseEvaluator ?: ^BOOL(NSData *d){ return [d length] > 0; } copy];
		_uuid = [NSUUID UUID];
	}
	return self;
}

- (instancetype)initWithPrefix:(NSData *)prefix suffix:(NSData *)suffix userInfo:(id)userInfo
{
	self = [self initWithUserInfo:userInfo responseEvaluator:^BOOL(NSData *data) {
		NSRange fullRange = NSMakeRange(0, [data length]);
		NSRange prefixRange = NSMakeRange(0, 0);
		if (prefix) prefixRange = [data rangeOfData:prefix options:NSDataSearchAnchored range:fullRange];
		NSRange suffixRange = NSMakeRange([data length]-1, 0);
		if (suffix) suffixRange = [data rangeOfData:suffix options:NSDataSearchAnchored | NSDataSearchBackwards range:fullRange];
		
		return prefixRange.location != NSNotFound && suffixRange.location != NSNotFound;
	}];
	if (self) {
		_prefix = prefix;
		_suffix = suffix;
	}
	return self;
}

- (instancetype)initWithPrefixString:(nullable NSString *)prefixString
						suffixString:(nullable NSString *)suffixString
					  userInfo:(nullable id)userInfo
{
	NSData *prefixData = [prefixString dataUsingEncoding:NSUTF8StringEncoding];
	NSData *suffixData = [suffixString dataUsingEncoding:NSUTF8StringEncoding];
	return [self initWithPrefix:prefixData suffix:suffixData userInfo:userInfo];
}

- (instancetype)initWithRegularExpression:(NSRegularExpression *)regex
								 userInfo:(nullable id)userInfo
{
	self = [self initWithUserInfo:userInfo responseEvaluator:^BOOL(NSData *data) {
		NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		if (!string) return NO;
		
		return [regex numberOfMatchesInString:string options:NSMatchingAnchored range:NSMakeRange(0, [string length])] > 0;
	}];
	if (self) {
		_regularExpression = regex;
	}
	return self;
}

- (BOOL)isEqual:(id)object
{
	if (object == self) return YES;
	if (![object isKindOfClass:[ORSSerialPacketDescriptor class]]) return NO;
	return [[(ORSSerialPacketDescriptor *)object uuid] isEqual:self.uuid];
}

- (NSUInteger)hash { return [self.uuid hash]; }

- (BOOL)dataIsValidPacket:(nullable NSData *)packetData
{
	if (!self.responseEvaluator) return YES;
	return self.responseEvaluator(packetData);
}

@end
