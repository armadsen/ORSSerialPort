//
//  SerialBoardController.swift
//  RequestResponseDemo
//
//  Created by Andrew Madsen on 3/14/15.
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

import Cocoa
import ORSSerial

let kTimeoutDuration = 0.5

class SerialBoardController: NSObject, ORSSerialPortDelegate {
	
	enum SerialBoardRequestType: Int {
		case ReadTemperature = 1
		case ReadLED
		case SetLED
	}
	
	// MARK: - Private
	
	func pollingTimerFired(timer: NSTimer) {
		self.readTemperature()
		self.readLEDState()
	}
	
	// MARK: Sending Commands
	private func readTemperature() {
		guard let serialPort = syncSerialPort else { return }
		let command = "$TEMP?;".dataUsingEncoding(NSASCIIStringEncoding)!
		let responseDescriptor = ORSSerialPacketDescriptor(prefixString: "!TEMP", suffixString: ";", maximumPacketLength: 10, userInfo: nil)
		let request = ORSSerialRequest(dataToSend: command,
			userInfo: SerialBoardRequestType.ReadTemperature.rawValue,
			timeoutInterval: 0.5,
			responseDescriptor: responseDescriptor)
		do {
			let response = try serialPort.sendRequestToPort(request)
			self.temperature = self.temperatureFromResponsePacket(response)!
		} catch let error {
			print("Error with request \(request): \(error)")
		}
	}
	
	private func readLEDState() {
		guard let serialPort = syncSerialPort else { return }
		let command = "$LED?;".dataUsingEncoding(NSASCIIStringEncoding)!
		let responseDescriptor = ORSSerialPacketDescriptor(prefixString: "!LED", suffixString: ";", maximumPacketLength: 10, userInfo: nil)
		let request = ORSSerialRequest(dataToSend: command,
			userInfo: SerialBoardRequestType.ReadLED.rawValue,
			timeoutInterval: kTimeoutDuration,
			responseDescriptor: responseDescriptor)
		do {
			let response = try serialPort.sendRequestToPort(request)
			self.internalLEDOn = self.LEDStateFromResponsePacket(response)!
		} catch let error {
			print("Error with request \(request): \(error)")
		}
	}
	
	private func sendCommandToSetLEDToState(state: Bool) {
		guard let serialPort = syncSerialPort else { return }
		let commandString = NSString(format: "$LED%@;", (state ? "1" : "0"))
		let command = commandString.dataUsingEncoding(NSASCIIStringEncoding)!
		let responseDescriptor = ORSSerialPacketDescriptor(prefixString: "!LED", suffixString: ";", maximumPacketLength: 10, userInfo: nil)
		let request = ORSSerialRequest(dataToSend: command,
			userInfo: SerialBoardRequestType.SetLED.rawValue,
			timeoutInterval: kTimeoutDuration,
			responseDescriptor: responseDescriptor)
		do {
			let response = try serialPort.sendRequestToPort(request)
			self.internalLEDOn = self.LEDStateFromResponsePacket(response)!
		} catch let error {
			print("Error with request \(request): \(error)")
		}
	}
	
	// MARK: Parsing Responses
	
	private func temperatureFromResponsePacket(data: NSData) -> Int? {
		let dataAsString = NSString(data: data, encoding: NSASCIIStringEncoding)!
		if dataAsString.length < 6 || !dataAsString.hasPrefix("!TEMP") || !dataAsString.hasSuffix(";") {
			return nil
		}
		
		let temperatureString = dataAsString.substringWithRange(NSRange(location: 5, length: dataAsString.length-6))
		return Int(temperatureString)
	}
	
	private func LEDStateFromResponsePacket(data: NSData) -> Bool? {
		let dataAsString = NSString(data: data, encoding: NSASCIIStringEncoding)!
		if dataAsString.length < 6 || !dataAsString.hasPrefix("!LED") || !dataAsString.hasSuffix(";") {
			return nil
		}
		
		let LEDStateString = dataAsString.substringWithRange(NSRange(location: 4, length: dataAsString.length-5))
		return Int(LEDStateString)! != 0
	}
	
	// MARK: - ORSSerialPortDelegate
	
	func serialPortWasRemovedFromSystem(serialPort: ORSSerialPort) {
		self.serialPort = nil
	}
	
	func serialPortWasOpened(serialPort: ORSSerialPort) {
		dispatch_async(dispatch_get_main_queue()) { () -> Void in
			self.pollingTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "pollingTimerFired:", userInfo: nil, repeats: true)
			self.pollingTimer!.fire()
			self.syncSerialPort = SynchronousSerialPort(port: serialPort)
		}
	}
	
	func serialPortWasClosed(serialPort: ORSSerialPort) {
		self.pollingTimer = nil
	}
	
	// MARK: - Properties
	
	private var syncSerialPort: SynchronousSerialPort?
	
	private(set) internal var serialPort: ORSSerialPort? {
		willSet {
			if let port = serialPort {
				port.close()
				port.delegate = nil
				syncSerialPort = nil
			}
		}
		didSet {
			if let port = serialPort {
				port.baudRate = 57600
				port.delegate = self
				port.RTS = true
				port.open()
			}
		}
	}
	
	dynamic private(set) internal var temperature: Int = 0
	
	dynamic private var internalLEDOn = false
	
	class func keyPathsForValuesAffectingLEDOn() -> NSSet { return NSSet(object: "internalLEDOn") }
	dynamic var LEDOn: Bool {
		get {
			return self.internalLEDOn
		}
		set(newValue) {
			self.internalLEDOn = newValue
			self.sendCommandToSetLEDToState(newValue)
		}
	}
	
	private var pollingTimer: NSTimer? {
		willSet {
			if let timer = pollingTimer {
				timer.invalidate()
			}
		}
	}
}
