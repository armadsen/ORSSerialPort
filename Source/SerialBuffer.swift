//
//  SerialBuffer.swift
//  ORSSerialPort
//
//  Created by Andrew Madsen on 12/7/15.
//	Copyright (c) 2011-2015 Andrew R. Madsen (andrew@openreelsoftware.com)
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
