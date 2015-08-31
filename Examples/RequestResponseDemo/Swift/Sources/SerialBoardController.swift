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
		let command = "$TEMP?;".dataUsingEncoding(NSASCIIStringEncoding)!
		let request = ORSSerialRequest(dataToSend: command,
			userInfo: SerialBoardRequestType.ReadTemperature.rawValue,
			timeoutInterval: 0.5) { (data) -> ObjCBool in
				return ObjCBool(self.temperatureFromResponsePacket(data!) != nil)
		}
		self.serialPort?.sendRequest(request)
	}
	
	private func readLEDState() {
		let command = "$LED?;".dataUsingEncoding(NSASCIIStringEncoding)!
		let request = ORSSerialRequest(dataToSend: command,
			userInfo: SerialBoardRequestType.ReadLED.rawValue,
			timeoutInterval: kTimeoutDuration) { (data) -> ObjCBool in
				return ObjCBool(self.LEDStateFromResponsePacket(data!) != nil)
		}
		self.serialPort?.sendRequest(request)
	}
	
	private func sendCommandToSetLEDToState(state: Bool) {
		let commandString = NSString(format: "$LED%@;", (state ? "1" : "0"))
		let command = commandString.dataUsingEncoding(NSASCIIStringEncoding)!
		let request = ORSSerialRequest(dataToSend: command,
			userInfo: SerialBoardRequestType.SetLED.rawValue,
			timeoutInterval: kTimeoutDuration) { (data) -> ObjCBool in
				return ObjCBool(self.LEDStateFromResponsePacket(data!) != nil)
		}
		self.serialPort?.sendRequest(request)
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
	
	func serialPort(serialPort: ORSSerialPort, didEncounterError error: NSError) {
		print("Serial port \(serialPort) encountered an error: \(error)")
	}
	
	func serialPort(serialPort: ORSSerialPort, didReceiveResponse responseData: NSData, toRequest request: ORSSerialRequest) {
		let requestType = SerialBoardRequestType(rawValue: request.userInfo as! Int)!
		switch requestType {
		case .ReadTemperature:
			self.temperature = self.temperatureFromResponsePacket(responseData)!
		case .ReadLED, .SetLED:
			self.internalLEDOn = self.LEDStateFromResponsePacket(responseData)!
		}
	}
	
	func serialPortWasOpened(serialPort: ORSSerialPort) {
		self.pollingTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "pollingTimerFired:", userInfo: nil, repeats: true)
		self.pollingTimer!.fire()
	}
	
	func serialPortWasClosed(serialPort: ORSSerialPort) {
		self.pollingTimer = nil
	}
	
	// MARK: - Properties
	
	private(set) internal var serialPort: ORSSerialPort? {
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
