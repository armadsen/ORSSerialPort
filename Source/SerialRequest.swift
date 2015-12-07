//
//  SerialRequest.swift
//  ORSSerialPort
//
//  Created by Andrew Madsen on 12/7/15.
//  Copyright © 2015 Open Reel Software. All rights reserved.
//

import Foundation

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
@objc(ORSSerialRequest) public class SerialRequest : NSObject {
	
	/**
	*  Initializes an ORSSerialRequest instance.
	*
	*  @param dataToSend			The data to be sent on the serial port.
	*  @param userInfo				An arbitrary userInfo object.
	*  @param timeout				The maximum amount of time in seconds to wait for a response. Pass -1.0 to wait indefinitely.
	*  @param responseDescriptor	A packet descriptor used to evaluate whether received data constitutes a valid response to the request.
	*  May be nil. If responseDescriptor is nil, the request is assumed not to require a response, and the next request in the queue will
	*  be sent immediately.
	*
	*  @return An initialized ORSSerialRequest instance.
	*/
	public required init(dataToSend: NSData, userInfo: AnyObject?, timeoutInterval: NSTimeInterval, responseDescriptor: SerialPacketDescriptor?) {
		self.dataToSend = dataToSend
		self.userInfo = userInfo
		self.timeoutInterval = timeoutInterval
		self.responseDescriptor = responseDescriptor
		self.UUIDString = NSUUID().UUIDString
		
		super.init()
	}
	
	/**
	*  Data to be sent on the serial port when the receiver is sent.
	*/
	public let dataToSend: NSData
	
	/**
	*  Arbitrary object (e.g. NSDictionary) used to store additional data
	*  about the request.
	*/
	public let userInfo: AnyObject?
	
	/**
	*  The maximum amount of time to wait for a response before timing out.
	*  Negative values indicate that serial port will wait forever for a response
	*  without timing out.
	*/
	public let timeoutInterval: NSTimeInterval
	
	/**
	*  The descriptor describing the receiver's expected response.
	*/
	public let responseDescriptor: SerialPacketDescriptor?
	
	/**
	*  Unique identifier for the request.
	*/
	public let UUIDString: String
}

// Deprecated methods
extension SerialRequest {
	/**
	*  @deprecated Use -initWithDataToSend:userInfo:timeoutInterval:responseDescriptor: instead.
	*
	*  Creates and initializes an ORSSerialRequest instance.
	*
	*  @param dataToSend			The data to be sent on the serial port.
	*  @param userInfo				An arbitrary userInfo object.
	*  @param timeout				The maximum amount of time in seconds to wait for a response. Pass -1.0 to wait indefinitely.
	*  @param responseDescriptor	A packet descriptor used to evaluate whether received data constitutes a valid response to the request.
	*  May be nil. If responseDescriptor is nil, the request is assumed not to require a response, and the next request in the queue will
	*  be sent immediately.
	*
	*  @return An initialized ORSSerialRequest instance.
	*/
	@available(OSX, deprecated=3.0) public class func requestWithDataToSend(data: NSData, userInfo: AnyObject?, timeoutInterval: NSTimeInterval, responseDescriptor: SerialPacketDescriptor?) -> SerialRequest {
		return self.init(dataToSend: data, userInfo: userInfo, timeoutInterval: timeoutInterval, responseDescriptor: responseDescriptor)
	}
}