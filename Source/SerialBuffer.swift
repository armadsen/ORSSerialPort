//
//  SerialBuffer.swift
//  ORSSerialPort
//
//  Created by Andrew Madsen on 12/7/15.
//  Copyright © 2015 Open Reel Software. All rights reserved.
//

import Foundation

/* This shouldn't stay public, but I can't figure out how to use it in ObjC otherwise. */
@objc(ORSSerialBuffer) public class SerialBuffer : NSObject {
	
	required public init(maximumLength: Int) {
		self.maximumLength = maximumLength

		super.init()
	}
	
	public func appendData(data: NSData) {
		self.willChangeValueForKey("internalBuffer")
		internalBuffer.appendData(data)
		if internalBuffer.length > maximumLength {
			let rangeToDelete = NSRange(location: 0, length: internalBuffer.length - maximumLength)
			internalBuffer.replaceBytesInRange(rangeToDelete, withBytes: nil, length: 0)
		}
	}
	
	public func clearBuffer() {
		internalBuffer.setData(NSData())
	}
	
	private let internalBuffer = NSMutableData()
	class func keyPathsForValuesAffectingData() -> Set<String> { return ["internalData"] }
	public var data: NSData { return internalBuffer }
	public let maximumLength: Int
}
