//
//  SerialCommunicator.swift
//  PacketParsingDemo
//
//  Created by Andrew Madsen on 8/10/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

import Cocoa
import ORSSerial

class SerialCommunicator: NSObject, ORSSerialPortDelegate {
	
	deinit {
		self.serialPort = nil
	}
	
	// MARK - ORSSerialPortDelegate
	
	func serialPortWasRemovedFromSystem(serialPort: ORSSerialPort) {
		self.serialPort = nil
	}
	
	func serialPort(serialPort: ORSSerialPort, didEncounterError error: NSError) {
		print("Serial port \(serialPort) encountered an error: \(error)")
	}
	
	func serialPortWasOpened(serialPort: ORSSerialPort) {
		let descriptor = ORSSerialPacketDescriptor(prefixString: "!pos", suffixString: ";", maximumPacketLength: 8, userInfo: nil)
		serialPort.startListeningForPacketsMatchingDescriptor(descriptor)
	}
	
	func serialPort(serialPort: ORSSerialPort, didReceivePacket packetData: NSData, matchingDescriptor descriptor: ORSSerialPacketDescriptor) {
		if let dataAsString = NSString(data: packetData, encoding: NSASCIIStringEncoding) {
			let valueString = dataAsString.substringWithRange(NSRange(location: 4, length: dataAsString.length-5))
			self.sliderPosition = Int(valueString)!
		}
	}
	
	// MARK: - Properties
	
	dynamic private(set) var sliderPosition: Int = 0
	
	dynamic var serialPort: ORSSerialPort? {
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
