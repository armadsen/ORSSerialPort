//
//  ORSSerialRequest.h
//  ORSSerialPort
//
//  Created by Andrew Madsen on 4/21/14.
//  Copyright (c) 2014 Andrew Madsen. All rights reserved.
//

#import <Foundation/Foundation.h>

// Keep older versions of the compiler happy
#ifndef NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#define nullable
#define nonnullable
#define __nullable
#endif

typedef BOOL(^ORSSerialRequestResponseEvaluator)(NSData * __nullable inputData);

NS_ASSUME_NONNULL_BEGIN

/**
 *  An ORSSerialRequest encapsulates a generic "request" command sent via the serial
 *  port. 
 *  
 *  An ORSSerialRequest includes data to be sent out via the serial port.
 *  It also can contain a block which is used to evaluate received
 *  data to determine if/when a valid response to the request has been received from
 *  the device on the other end of the port. Arbitrary information can be
 *  associated with the ORSSerialRequest via its userInfo property.
 */
@interface ORSSerialRequest : NSObject

/**
 *  Creates and initializes an ORSSerialRequest instance.
 *
 *  @param dataToSend        The data to be sent on the serial port.
 *  @param userInfo          An arbitrary userInfo object.
 *  @param timeout			 The maximum amount of time in seconds to wait for a response. Pass -1.0 to wait indefinitely.
 *  @param responseEvaluator A block used to evaluate whether received data constitutes a valid response to the request.
 *  May be nil. If responseEvaluator is nil, the request is assumed not to require a response, and the next request in the queue will
 *  be sent immediately.
 *
 *  @return An initialized ORSSerialRequest instance.
 */
+ (instancetype)requestWithDataToSend:(NSData *)dataToSend
							 userInfo:(nullable id)userInfo
					  timeoutInterval:(NSTimeInterval)timeout
					responseEvaluator:(nullable ORSSerialRequestResponseEvaluator)responseEvaluator;

/**
 *  Initializes an ORSSerialRequest instance.
 *
 *  @param dataToSend        The data to be sent on the serial port.
 *  @param userInfo          An arbitrary userInfo object.
 *  @param timeout			 The maximum amount of time in seconds to wait for a response. Pass -1.0 to wait indefinitely.
 *  @param responseEvaluator A block used to evaluate whether received data constitutes a valid response to the request. 
 *  May be nil. If responseEvaluator is nil, the request is assumed not to require a response, and the next request in the queue will
 *  be sent immediately.
 *
 *  @return An initialized ORSSerialRequest instance.
 */
- (instancetype)initWithDataToSend:(NSData *)dataToSend
						  userInfo:(nullable id)userInfo
				   timeoutInterval:(NSTimeInterval)timeout
				 responseEvaluator:(nullable ORSSerialRequestResponseEvaluator)responseEvaluator;

/**
 *  Can be used to determine if a block of data is a valid response to the request encapsulated
 *  by the receiver. If the receiver doesn't have a response data evaulator block, this method
 *  always returns YES.
 *
 *  @param responseData Data received from a serial port.
 *
 *  @return YES if the data is a valid response, NO otherwise.
 */
- (BOOL)dataIsValidResponse:(nullable NSData *)responseData;

/**
 *  Data to be sent on the serial port when the receiver is sent.
 */
@property (nonatomic, strong, readonly) NSData *dataToSend;

/**
 *  Arbitrary object (e.g. NSDictionary) used to store additional data
 *  about the request.
 */
@property (nonatomic, strong, readonly, nullable) id userInfo;

/**
 *  The maximum amount of time to wait for a response before timing out.
 *  Negative values indicate that serial port will wait forever for a response
 *  without timing out.
 */
@property (nonatomic, readonly) NSTimeInterval timeoutInterval;

/**
 *  Unique identifier for the request.
 */
@property (nonatomic, strong, readonly) NSString *UUIDString;

@end

NS_ASSUME_NONNULL_END