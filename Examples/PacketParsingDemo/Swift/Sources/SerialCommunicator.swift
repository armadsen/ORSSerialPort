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
	
	func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
		self.serialPort = nil
	}
	
	func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
		print("Serial port \(serialPort) encountered an error: \(error)")
	}
	
	func serialPortWasOpened(_ serialPort: ORSSerialPort) {
		let descriptor = ORSSerialPacketDescriptor(prefixString: "!pos", suffixString: ";", maximumPacketLength: 8, userInfo: nil)
		serialPort.startListeningForPackets(matching: descriptor)
	}
	
	func serialPort(_ serialPort: ORSSerialPort, didReceivePacket packetData: Data, matching descriptor: ORSSerialPacketDescriptor) {
		if let dataAsString = NSString(data: packetData, encoding: String.Encoding.ascii.rawValue) {
			let valueString = dataAsString.substring(with: NSRange(location: 4, length: dataAsString.length-5))
			self.sliderPosition = Int(valueString)!
		}
	}
	
	// MARK: - Properties
	
	dynamic fileprivate(set) var sliderPosition: Int = 0
	
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
				port.rts = true
				port.delegate = self
				port.open()
			}
		}
	}
}
