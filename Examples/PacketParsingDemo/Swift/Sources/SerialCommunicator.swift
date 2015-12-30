//
//  SerialCommunicator.swift
//  PacketParsingDemo
//
//  Created by Andrew Madsen on 8/10/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

import Cocoa
import ORSSerial

class SerialCommunicator: NSObject, SerialPortDelegate {
	
	deinit {
		self.serialPort = nil
	}
	
	// MARK - SerialPortDelegate
	
	func serialPortWasRemovedFromSystem(serialPort: SerialPort) {
		self.serialPort = nil
	}
	
	func serialPort(serialPort: SerialPort, didEncounterError error: NSError) {
		print("Serial port \(serialPort) encountered an error: \(error)")
	}
	
	func serialPortWasOpened(serialPort: SerialPort) {
		let descriptor = SerialPacketDescriptor(prefixString: "!pos", suffixString: ";", maximumPacketLength: 8, userInfo: nil)
		serialPort.startListeningForPacketsMatchingDescriptor(descriptor)
	}
	
	func serialPort(serialPort: SerialPort, didReceivePacket packetData: NSData, matchingDescriptor descriptor: SerialPacketDescriptor) {
		if let dataAsString = NSString(data: packetData, encoding: NSASCIIStringEncoding) {
			let valueString = dataAsString.substringWithRange(NSRange(location: 4, length: dataAsString.length-5))
			self.sliderPosition = Int(valueString)!
		}
	}
	
	// MARK: - Properties
	
	dynamic private(set) var sliderPosition: Int = 0
	
	dynamic var serialPort: SerialPort? {
		willSet {
			if let port = serialPort {
				port.close()
				port.delegate = nil
			}
		}
		didSet {
			if let port = serialPort {
				port.baudRate = 57600
				port.delegate = self
				port.open()
			}
		}
	}
}
