//
//  SynchronousSerialPort.swift
//  RequestResponseDemo
//
//  Created by Andrew Madsen on 10/3/15.
//  Copyright © 2015 Open Reel Software. All rights reserved.
//

import Foundation
import ORSSerial

enum SynchronousSerialPortError: ErrorType {
	case RequestTimedOut
	case PortWasRemoved
	case PortError(NSError)
	case Unknown
}

class SynchronousSerialPort: NSObject, ORSSerialPortDelegate {
	
	let serialPort: ORSSerialPort
	init(port: ORSSerialPort) {
		serialPort = port
		
		super.init()
		
		serialPort.delegate = self
	}
	
	private var responseData: NSData?
	private var portError: SynchronousSerialPortError?
	func sendRequestToPort(request: ORSSerialRequest) throws -> NSData {
		
		self.responseData = nil
		self.portError = nil
		
		self.serialPort.sendRequest(request)
		
		while responseData == nil && portError == nil {
			NSRunLoop.currentRunLoop().runMode(NSRunLoopCommonModes, beforeDate: NSDate(timeIntervalSinceNow: 1.0))
		}
		
		switch (responseData, portError) {
		case (let data?, _):
			return data
		case (_, let error?):
			throw error
		default:
			throw SynchronousSerialPortError.Unknown // Shouldn't actually ever happen
		}
	}
	
	func serialPortWasRemovedFromSystem(serialPort: ORSSerialPort) {
		self.portError = .PortWasRemoved
	}
	
	func serialPort(serialPort: ORSSerialPort, didEncounterError error: NSError) {
		self.portError = .PortError(error)
	}
	
	func serialPort(serialPort: ORSSerialPort, requestDidTimeout request: ORSSerialRequest) {
		self.portError = .RequestTimedOut
	}
	
	func serialPort(serialPort: ORSSerialPort, didReceiveResponse responseData: NSData, toRequest request: ORSSerialRequest) {
		self.responseData = responseData
	}
}