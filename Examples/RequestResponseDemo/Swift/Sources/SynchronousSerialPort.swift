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
	case PortIsClosed
	case PortError(NSError)
	case Unknown
}

class SynchronousSerialPort: NSObject, ORSSerialPortDelegate {
	
	var serialPort: ORSSerialPort?
	init(port: ORSSerialPort) {
		serialPort = port
		
		super.init()
		
		serialPort?.delegate = self
		serialPort?.delegateQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
	}
	
	let semaphore = dispatch_semaphore_create(0);
	private var responseData: NSData?
	private var portError: SynchronousSerialPortError?
	func sendRequestToPort(request: ORSSerialRequest) throws -> NSData {
		guard let port = serialPort where port.open else {
			throw SynchronousSerialPortError.PortIsClosed
		}
		self.responseData = nil
		self.portError = nil
		
		self.serialPort?.sendRequest(request)
		
		dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
		
		switch (responseData, portError) {
		case (_, let error?):
			throw error
		case (let data?, _):
			return data
		default:
			fatalError() // Shouldn't actually ever happen
		}
	}
	
	func serialPortWasRemovedFromSystem(serialPort: ORSSerialPort) {
		self.serialPort = nil
		self.portError = .PortWasRemoved
		dispatch_semaphore_signal(semaphore)
	}
	
	func serialPort(serialPort: ORSSerialPort, didEncounterError error: NSError) {
		self.portError = .PortError(error)
		dispatch_semaphore_signal(semaphore)
	}
	
	func serialPort(serialPort: ORSSerialPort, requestDidTimeout request: ORSSerialRequest) {
		self.portError = .RequestTimedOut
		dispatch_semaphore_signal(semaphore)
	}
	
	func serialPort(serialPort: ORSSerialPort, didReceiveResponse responseData: NSData, toRequest request: ORSSerialRequest) {
		self.responseData = responseData
		dispatch_semaphore_signal(semaphore)
	}
}