//
//  ORSSerialPacketDescriptor.h
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

#import <Foundation/Foundation.h>

// Keep older versions of the compiler happy
#ifndef NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#define nullable
#define nonnullable
#define __nullable
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * Block that parses input data and returns a packet extracted from that data, or nil
 * if inputData doesn't contain a valid packet.
 */
typedef BOOL(^ORSSerialResponseEvaluator)(NSData * __nullable inputData);

/**
 *  An instance of ORSSerialPacketDescriptor is used to describe a packet format. ORSSerialPort
 *  can use these to "packetize" incoming data. Normally, bytes received by a serial port are
 *  delivered as they are received, often one or two bytes at a time. Responsibility for buffering
 *  incoming bytes, determining when a complete packet has been received, then parsing and processing
 *  the packet is left to the client of ORSSerialPort.
 *
 *  Rather than writing manual buffering and packet checking code, one or more packet descriptors
 *  can be installed on the port, and the port will call the -serialPort:didReceivePacket:matchingDescriptor:
 *  method on its delegate when a complete packet is received.
 *
 *  Note that this API is intended to be used with data that is sent by a serial device periodically,
 *  or in response to real world events, rather than in response to serial requests sent by the computer.
 *  For request/response protocols, see ORSSerialRequest, etc.
 *
 */
@interface ORSSerialPacketDescriptor : NSObject

- (instancetype)initWithUserInfo:(nullable id)userInfo
			   responseEvaluator:(ORSSerialResponseEvaluator)responseEvaluator NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithPrefix:(nullable NSData *)prefix
						suffix:(nullable NSData *)suffix
					  userInfo:(nullable id)userInfo;

- (instancetype)initWithPrefixString:(nullable NSString *)prefixString
						suffixString:(nullable NSString *)suffixString
							userInfo:(nullable id)userInfo;

- (instancetype)initWithRegularExpression:(NSRegularExpression *)regex
								 userInfo:(nullable id)userInfo;

/**
 *  Can be used to determine if a block of data is a valid packet matching the descriptor encapsulated
 *  by the receiver.
 *
 *  @param packetData Data received from a serial port.
 *
 *  @return YES if the data is a valid packet, NO otherwise.
 */
- (BOOL)dataIsValidPacket:(nullable NSData *)packetData;

@property (nonatomic, strong, readonly, nullable) NSData *prefix;
@property (nonatomic, strong, readonly, nullable) NSData *suffix;
@property (nonatomic, strong, readonly, nullable) NSRegularExpression *regularExpression;

/**
 *  Arbitrary object (e.g. NSDictionary) used to store additional data
 *  about the packet descriptor.
 */
@property (nonatomic, strong, readonly, nullable) id userInfo;

@property (nonatomic, strong, readonly) NSUUID *uuid;

@end

NS_ASSUME_NONNULL_END