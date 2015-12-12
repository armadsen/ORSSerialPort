//
//  SerialPacketDescriptor.swift
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

/**
* Block that parses input data and returns YES if inputData consists of a valid packet, or NO
* if inputData doesn't contain a valid packet.
*/
public typealias SerialPacketEvaluator = (NSData) -> Bool

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
*  For more information about ORSSerialPort's packet descriptor API, see the ORSSerialPort Packet Parsing
*  Programming Guide at
*/
@objc(ORSSerialPacketDescriptor) public class SerialPacketDescriptor : NSObject {
	
	/**
	*  Creates an initializes an ORSSerialPacketDescriptor instance using a response evaluator block.
	*
	*  This initializer can be used to creat a packet descriptor with complex packet matching
	*  rules. For most packet formats, the initializers that take prefix and suffix, or regular expression
	*  are easier to use. However, if the packet format cannot be described using a simple prefix/suffix
	*  or regular expression, a response evaulator block containing arbitrary validation code can be
	*  provided instead.
	*
	*  @param maxPacketLength The maximum length of a valid packet. This value _must_ be correctly specified.
	*  @param userInfo          An arbitrary userInfo object.
	*  @param responseEvaluator A block used to evaluate whether received data constitutes a valid packet.
	*
	*  @return An initizliaized ORSSerialPacketDesciptor instance.
	*
	*  @see -initWithPrefix:suffix:maximumPacketLength:userInfo:
	*  @see -initWithPrefixString:suffixString:maximumPacketLength:userInfo:
	*  @see -initWithRegularExpression:maximumPacketLength:userInfo:
	*/
	public convenience init(maximumPacketLength: Int, userInfo: AnyObject?, responseEvaluator: SerialPacketEvaluator) {
		self.init(maxPacketLength: maximumPacketLength, userInfo: userInfo, responseEvaluator: responseEvaluator)
	}
	
	/**
	*	Creates an initializes an ORSSerialPacketDescriptor instance using fixed packet data.
	*
	*  This can be used to create a packet descriptor for packets which consist of a fixed sequence of data.
	*
	*  @param packetData	An NSData instance containing a fixed sequence of bytes making up a packet.
	*  @param userInfo		An arbitrary userInfo object. May be nil.
	*
	*  @return An initizliaized ORSSerialPacketDesciptor instance.
	*/
	public convenience init(packetData: NSData, userInfo: AnyObject?) {
		self.init(maxPacketLength: packetData.length, packetData: packetData, userInfo: userInfo, responseEvaluator: { $0 == packetData })
	}
	
	/**
	*  Creates an initializes an ORSSerialPacketDescriptor instance using a prefix and/or suffix.
	*
	*  If the packet format uses printable ASCII characters,
	*  -initWithPrefixString:suffixString:maximumPacketLength:userInfo: may be more suitable.
	*
	*  @note Either prefix or suffix may be nil, but not both. If the suffix is nil,
	*  packets will be considered to consist solely of prefix. If either value is nil, packets
	*  will be considred to consist soley of the the non-nil value.
	*
	*  @param prefix   An NSData instance containing a fixed packet prefix. May be nil.
	*  @param suffix   An NSData instance containing a fixed packet suffix. May be nil.
	*  @param maxPacketLength The maximum length of a valid packet. This value _must_ be correctly specified.
	*  @param userInfo An arbitrary userInfo object. May be nil.
	*
	*  @return An initizliaized ORSSerialPacketDesciptor instance.
	*
	*  @see -initWithPrefixString:suffixString:userInfo:
	*/
	public convenience init(prefix: NSData?, suffix: NSData?, maximumPacketLength: Int, userInfo: AnyObject?) {
		self.init(maxPacketLength: maximumPacketLength, prefix: prefix, suffix: suffix, userInfo: userInfo) { (data: NSData) -> Bool in
			guard data.length > 0 else { return false }
			
			if let prefix = prefix {
				if data.length < prefix.length { return false }
				if data.subdataWithRange(NSRange(location: 0, length: prefix.length)) != prefix { return false }
			}
			
			if let suffix = suffix {
				if data.length < suffix.length { return false }
				let dataSuffix = data.subdataWithRange(NSRange(location: data.length-suffix.length, length: suffix.length))
				if dataSuffix != suffix { return false }
			}
			
			return true
		}
	}
	
	/**
	*  Creates an initializes an ORSSerialPacketDescriptor instance using a prefix string and/or suffix string.
	*
	*  This method assumes that prefixString and suffixString are ASCII or UTF8 strings.
	*  If the packet format does not use printable ASCII characters, -initWithPrefix:suffix:maximumPacketLength:userInfo:
	*  may be more suitable.
	*
	*  @note Either prefixString or suffixString may be nil, but not both. If the suffix is nil,
	*  packets will be considered to consist solely of prefix. If either value is nil, packets
	*  will be considred to consist soley of the the non-nil value. If both are nil, a fatal error will occur.
	*
	*  @param prefixString A fixed packet prefix string. May be nil.
	*  @param suffixString A fixed packet suffix string. May be nil.
	*  @param maxPacketLength The maximum length of a valid packet. This value _must_ be correctly specified.
	*  @param userInfo     An arbitrary userInfo object. May be nil.
	*
	*  @return An initizliaized ORSSerialPacketDesciptor instance.
	*
	*  @see -initWithPrefix:suffix:maximumPacketLength:userInfo:
	*/
	public convenience init(prefixString: String?, suffixString: String?, maximumPacketLength: Int, userInfo: AnyObject?) {
		let prefixData = prefixString?.dataUsingEncoding(NSUTF8StringEncoding)
		let suffixData = suffixString?.dataUsingEncoding(NSUTF8StringEncoding)
		
		self.init(prefix: prefixData, suffix: suffixData, maximumPacketLength: maximumPacketLength, userInfo: userInfo)
	}
	
	/**
	*  Creates an initializes an ORSSerialPacketDescriptor instance using a regular expression.
	*
	*  A packet is considered valid as long as it contains at least one match for the provided
	*  regular expression. For this reason, the regex should match as conservatively (smallest match) as possible.
	*
	*  Packets described by descriptors created using this method are assumed to be ASCII or UTF8 strings.
	*  If your packets are not naturally represented as strings, consider using
	*  -initWithMaximumPacketLength:userInfo:responseEvaluator: instead.
	*
	*  @param regex    An NSRegularExpression instance for which valid packets are a match.
	*  @param maxPacketLength The maximum length of a valid packet. This value _must_ be correctly specified.
	*  @param userInfo An arbitrary userInfoObject. May be nil.
	*
	*  @return An initizliaized ORSSerialPacketDesciptor instance.
	*/
	public convenience init(regularExpression: NSRegularExpression, maximumPacketLength: Int, userInfo: AnyObject?) {
		
		self.init(maxPacketLength: maximumPacketLength, regularExpression: regularExpression, userInfo: userInfo) { (data: NSData) -> Bool in
			guard let string = String(data: data, encoding: NSUTF8StringEncoding) else { return false }
			let fullRange = NSRange(location: 0, length: string.utf16.count)
			return regularExpression.numberOfMatchesInString(string, options: .Anchored, range: fullRange) != 0
		}
	}
	
	private init(maxPacketLength: Int, packetData: NSData? = nil, prefix: NSData? = nil, suffix: NSData? = nil, regularExpression: NSRegularExpression? = nil, userInfo: AnyObject? = nil, responseEvaluator: SerialPacketEvaluator) {
			
			self.maximumPacketLength = maxPacketLength
			self.packetData = packetData
			self.prefix = prefix
			self.suffix = suffix
			self.regularExpression = regularExpression
			self.userInfo = userInfo
			self.responseEvaluator = responseEvaluator
			self.uuid = NSUUID()
		
			super.init()
	}
	
	/**
	*  Can be used to determine if a block of data is a valid packet matching the descriptor encapsulated
	*  by the receiver.
	*
	*  @param packetData Data received from a serial port.
	*
	*  @return YES if the data is a valid packet, NO otherwise.
	*/
	public func dataIsValidPacket(packetData: NSData?) -> Bool {
		guard let data = packetData else { return false }
		return responseEvaluator(data)
	}
	
	/**
	*  The fixed packetData for packets described by the receiver. Will be nil for packet
	*  descriptors not created using -initWithPacketData:userInfo:
	*/
	public let packetData: NSData?
	
	/**
	*  The prefix for packets described by the receiver. Will be nil for packet
	*  descriptors not created using one of the prefix/suffix initializer methods.
	*/
	public let prefix: NSData?
	
	/**
	*  The suffix for packets described by the receiver. Will be nil for packet
	*  descriptors not created using one of the prefix/suffix initializer methods.
	*/
	public let suffix: NSData?
	
	/**
	*  A regular expression matching packets described by the receiver. Will be nil
	*  for packet descriptors not created using -initWithRegularExpression:userInfo:.
	*/
	public let regularExpression: NSRegularExpression?
	
	/**
	*  The maximum lenght of a packet described by the receiver.
	*/
	public let maximumPacketLength: Int
	
	/**
	*  Arbitrary object (e.g. NSDictionary) used to store additional data
	*  about the packet descriptor.
	*/
	public let userInfo: AnyObject?
	
	/**
	*  Unique identifier for the descriptor.
	*/
	public let uuid: NSUUID
	
	override public var hashValue: Int { return uuid.hash }
	
	// Private
	
	private let responseEvaluator: SerialPacketEvaluator
}

public func ==(lhs: SerialPacketDescriptor, rhs: SerialPacketDescriptor) -> Bool {
	return lhs.uuid == rhs.uuid
}
