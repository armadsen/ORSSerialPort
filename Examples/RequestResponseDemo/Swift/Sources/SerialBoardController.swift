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
		case readTemperature = 1
		case readLED
		case setLED
	}
	
	// MARK: - Private
	
	func pollingTimerFired(_ timer: Timer) {
		self.readTemperature()
		self.readLEDState()
	}
	
	// MARK: Sending Commands
	fileprivate func readTemperature() {
		let command = "$TEMP?;".data(using: String.Encoding.ascii)!
		let responseDescriptor = ORSSerialPacketDescriptor(prefixString: "!TEMP", suffixString: ";", maximumPacketLength: 10, userInfo: nil)
		let request = ORSSerialRequest(dataToSend: command,
			userInfo: SerialBoardRequestType.readTemperature.rawValue,
			timeoutInterval: 0.5,
			responseDescriptor: responseDescriptor)
		self.serialPort?.send(request)
	}
	
	fileprivate func readLEDState() {
		let command = "$LED?;".data(using: String.Encoding.ascii)!
		let responseDescriptor = ORSSerialPacketDescriptor(prefixString: "!LED", suffixString: ";", maximumPacketLength: 10, userInfo: nil)
		let request = ORSSerialRequest(dataToSend: command,
			userInfo: SerialBoardRequestType.readLED.rawValue,
			timeoutInterval: kTimeoutDuration,
			responseDescriptor: responseDescriptor)
		self.serialPort?.send(request)
	}
	
	fileprivate func sendCommandToSetLEDToState(_ state: Bool) {
		let commandString = NSString(format: "$LED%@;", (state ? "1" : "0"))
		let command = commandString.data(using: String.Encoding.ascii.rawValue)!
		let responseDescriptor = ORSSerialPacketDescriptor(prefixString: "!LED", suffixString: ";", maximumPacketLength: 10, userInfo: nil)
		let request = ORSSerialRequest(dataToSend: command,
			userInfo: SerialBoardRequestType.setLED.rawValue,
			timeoutInterval: kTimeoutDuration,
			responseDescriptor: responseDescriptor)
		self.serialPort?.send(request)
	}
	
	// MARK: Parsing Responses
	
	fileprivate func temperatureFromResponsePacket(_ data: Data) -> Int? {
		let dataAsString = NSString(data: data, encoding: String.Encoding.ascii.rawValue)!
		if dataAsString.length < 6 || !dataAsString.hasPrefix("!TEMP") || !dataAsString.hasSuffix(";") {
			return nil
		}
		
		let temperatureString = dataAsString.substring(with: NSRange(location: 5, length: dataAsString.length-6))
		return Int(temperatureString)
	}
	
	fileprivate func LEDStateFromResponsePacket(_ data: Data) -> Bool? {
		let dataAsString = NSString(data: data, encoding: String.Encoding.ascii.rawValue)!
		if dataAsString.length < 6 || !dataAsString.hasPrefix("!LED") || !dataAsString.hasSuffix(";") {
			return nil
		}
		
		let LEDStateString = dataAsString.substring(with: NSRange(location: 4, length: dataAsString.length-5))
		return Int(LEDStateString)! != 0
	}
	
	// MARK: - ORSSerialPortDelegate
	
	func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
		self.serialPort = nil
	}
	
	func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
		print("Serial port \(serialPort) encountered an error: \(error)")
	}
	
	func serialPort(_ serialPort: ORSSerialPort, didReceiveResponse responseData: Data, to request: ORSSerialRequest) {
		let requestType = SerialBoardRequestType(rawValue: request.userInfo as! Int)!
		switch requestType {
		case .readTemperature:
			self.temperature = self.temperatureFromResponsePacket(responseData)!
		case .readLED, .setLED:
			self.internalLEDOn = self.LEDStateFromResponsePacket(responseData)!
		}
	}
	
	func serialPortWasOpened(_ serialPort: ORSSerialPort) {
		self.pollingTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(SerialBoardController.pollingTimerFired(_:)), userInfo: nil, repeats: true)
		self.pollingTimer!.fire()
	}
	
	func serialPortWasClosed(_ serialPort: ORSSerialPort) {
		self.pollingTimer = nil
	}
	
	// MARK: - Properties
	
	fileprivate(set) internal var serialPort: ORSSerialPort? {
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
				port.rts = true
				port.open()
			}
		}
	}
	
	dynamic fileprivate(set) internal var temperature: Int = 0
	
	dynamic fileprivate var internalLEDOn = false
	
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
	
	fileprivate var pollingTimer: Timer? {
		willSet {
			if let timer = pollingTimer {
				timer.invalidate()
			}
		}
	}
}
