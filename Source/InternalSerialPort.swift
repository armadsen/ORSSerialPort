//
//  InternalSerialPort.swift
//  ORSSerialPort
//
//  Created by Andrew Madsen on 12/12/15.
//  Copyright © 2015 Open Reel Software. All rights reserved.
//

import Foundation
import IOKit
import Darwin.POSIX.termios

// FIXME: This isn't really viable long term. For one thing NSThread.isMainThread() doesn't existing in OS Swift's Foundation.
private func doOnMainThreadAndWait(closure: (Void) -> Void) {
	if NSThread.isMainThread() {
		closure()
	} else {
		dispatch_sync(dispatch_get_main_queue(), closure)
	}
}

class SerialPortRegistry {
	class Weak {
		weak var serialPort: _SerialPort?
		init(_ port: _SerialPort) {
			self.serialPort = port
		}
	}
	
	var allSerialPorts = [Weak]()
	
	func addSerialPort(port: _SerialPort) {
		self.allSerialPorts.append(Weak(port))
	}
	
	// Probably not really needed now that we're using zeroing weak references
	func removeSerialPort(portToRemove: _SerialPort) {
		var indexToRemove = -1
		for (index, weakPort) in self.allSerialPorts.enumerate() {
			guard let port = weakPort.serialPort else { continue }
			if port === portToRemove {
				indexToRemove = index
				break
			}
		}
		if indexToRemove >= 0 {
			self.allSerialPorts.removeAtIndex(indexToRemove)
		}
	}
	
	func existingPortWithPath(path: String) -> _SerialPort? {
		return self.allSerialPorts.flatMap({ $0.serialPort }).filter({ $0.path == path }).first
	}
}

let serialPortRegistry = SerialPortRegistry()

class _SerialPort: NSObject {
	
	convenience init?(path: String) {
		let device = io_object_t(bsdPath: path)
		if device == 0 { return nil }
		self.init(device:device)
	}
	
	required init?(device: io_object_t) {
		guard let bsdPath = device.bsdCalloutPath,
			name = device.modemName else {
				self.path = ""
				self.IOKitDevice = 0
				self.name = ""
				super.init()
				return nil
		}
		
		self.path = bsdPath
		self.IOKitDevice = device
		self.name = name
		
		super.init()
		
		serialPortRegistry.addSerialPort(self)
	}
	
	deinit {
		if let readPollSource = self.readPollSource {
			dispatch_source_cancel(readPollSource)
		}
		
		if let pinPollTimer = self.pinPollTimer {
			dispatch_source_cancel(pinPollTimer)
		}
	}
	
	override var hashValue: Int { return self.path.hashValue }
	
	// MARK: - "Public" Methods
	
	func open() {
		if self.isOpen { return }
		
		let mainQueue = dispatch_get_main_queue()
		
		let descriptor = Darwin.open(self.path.cStringUsingEncoding(NSASCIIStringEncoding)!, O_RDWR | O_NOCTTY | O_EXLOCK | O_NONBLOCK)
		if descriptor < 1 {
			self.notifyDelegateOfPosixError()
			return
		}
		
		// Now that the device is open, clear the O_NONBLOCK flag so subsequent I/O will block.
		// See fcntl(2) ("man 2 fcntl") for details.
		if fcntlClearFlags(descriptor) == -1 {
			LOG_SERIAL_PORT_ERROR("Error clearing O_NONBLOCK \(self.path) - \(strerror(errno))(\(errno)).\n")
		}
		
		self.fileDescriptor = descriptor
		doOnMainThreadAndWait { self.isOpen = true }
		
		// Port opened successfully, set options
		var originalPortAttrs = termios()
		tcgetattr(descriptor, &originalPortAttrs) // Get original options so they can be reset later
		self.originalPortAttributes = originalPortAttrs
		self.setOptionsOnPort()
		
		// Get status of RTS and DTR lines
		var modemLines: CInt = 0
		if (ioctlGetModemLinesState(self.fileDescriptor, &modemLines) < 0) {
			LOG_SERIAL_PORT_ERROR("Error reading modem lines status")
			self.notifyDelegateOfPosixError()
		}
		
		let desiredRTS = self.RTS
		let desiredDTR = self.DTR
		self.RTS = modemLines & TIOCM_RTS != 0
		self.DTR = modemLines & TIOCM_DTR != 0
		self.RTS = desiredRTS
		self.DTR = desiredDTR
		
		dispatch_async(mainQueue) { () -> Void in
			guard let host = self.host else { return }
			host.delegate?.serialPortWasOpened?(host)
		}
		
		// Start a read dispatch source in the background
		let readPollSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(self.fileDescriptor), 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
		dispatch_source_set_event_handler(readPollSource) {
			
			let localPortFD = self.fileDescriptor
			guard self.isOpen else { return }
			
			// Data is available
			var buf = Array<UInt8>(count: 1024, repeatedValue: 0)
			let lengthRead = read(localPortFD, &buf, 1024)
			if lengthRead > 0 {
				self.receiveData(NSData(bytes: buf, length: lengthRead))
			}
		}
		dispatch_source_set_cancel_handler(readPollSource, self.reallyClosePort)
		dispatch_resume(readPollSource)
		self.readPollSource = readPollSource
		
		// Start another poller to check status of CTS and DSR
		let pollQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
		let timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, pollQueue)
		dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), 10*NSEC_PER_MSEC, 5*NSEC_PER_MSEC)
		dispatch_source_set_event_handler(timer) {
			guard self.isOpen else {
				dispatch_async(pollQueue) { dispatch_source_cancel(timer) }
				return
			}
			
			var modemLines: CInt = 0
			let result = ioctlGetModemLinesState(self.fileDescriptor, &modemLines)
			if result < 0 {
				self.notifyDelegateOfPosixErrorWaitingUntilDone(errno == ENXIO)
				if errno == ENXIO {
					self.cleanupAfterSystemRemoval()
				}
				return
			}
			
			let CTSPin = (modemLines & TIOCM_CTS) != 0
			let DSRPin = (modemLines & TIOCM_DSR) != 0
			let DCDPin = (modemLines & TIOCM_CAR) != 0
			
			if CTSPin != self.CTS { dispatch_sync(mainQueue) { self.CTS = CTSPin } }
			if DSRPin != self.DSR { dispatch_sync(mainQueue) { self.DSR = DSRPin } }
			if DCDPin != self.DCD { dispatch_sync(mainQueue) { self.DCD = DCDPin } }
		}
		self.pinPollTimer = timer
		dispatch_resume(timer)
	}
	
	func close() {
		if !self.isOpen { return }
		self.readPollSource = nil // Cancel read dispatch source. Cancel handler will call -reallyClosePort
	}
	
	func sendData(data: NSData) -> Bool {
		guard self.isOpen else { return false }
		guard data.length > 0 else { return true }
		
		let writeBuffer = data.mutableCopy() as! NSMutableData
		while writeBuffer.length > 0 {
			let numBytesWritten = write(self.fileDescriptor, writeBuffer.bytes, writeBuffer.length)
			if numBytesWritten < 0 {
				LOG_SERIAL_PORT_ERROR("Error writing to serial port: \(errno)")
				self.notifyDelegateOfPosixError()
				return false
			} else if numBytesWritten > 0 {
				writeBuffer.replaceBytesInRange(NSRange(location: 0, length: numBytesWritten), withBytes: nil, length: 0)
			}
		}
		
		return true
	}
	
	// MARK: Packet Parsing
	
	func startListeningForPacketsMatchingDescriptor(descriptor: SerialPacketDescriptor) {
		if self.packetDescriptorsAndBuffers.objectForKey(descriptor) != nil { return } // Already listening
		
		#if os(OSX)
			self.willChangeValueForKey("packetDescriptorsAndBuffers")
		#endif
		dispatch_sync(self.requestHandlingQueue) {
			let buffer = SerialBuffer(maximumLength: descriptor.maximumPacketLength)
			self.packetDescriptorsAndBuffers.setObject(buffer, forKey: descriptor)
		}
		#if os(OSX)
			self.didChangeValueForKey("packetDescriptorsAndBuffers")
		#endif
	}
	
	func stopListeningForPacketsMatchingDescriptor(descriptor: SerialPacketDescriptor) {
		#if os(OSX)
			self.willChangeValueForKey("packetDescriptorsAndBuffers")
		#endif
		dispatch_sync(self.requestHandlingQueue) {
			self.packetDescriptorsAndBuffers.removeObjectForKey(descriptor)
		}
		#if os(OSX)
			self.didChangeValueForKey("packetDescriptorsAndBuffers")
		#endif
	}
	
	// MARK: Request / Response
	
	func sendRequest(request: SerialRequest) -> Bool {
		var success = false
		dispatch_sync(self.requestHandlingQueue) {
			success = self.reallySendRequest(request)
		}
		return success
	}
	
	func cancelQueuedRequest(request: SerialRequest) {
		dispatch_async(self.requestHandlingQueue) {
			if request == self.pendingRequest { return } // Too late to cancel
			if let requestIndex = self.requestsQueue.indexOf(request) {
				#if os(OSX)
					self.willChangeValueForKey("queuedRequests")
				#endif
				self.queuedRequests.removeAtIndex(requestIndex)
				#if os(OSX)
					self.didChangeValueForKey("queuedRequests")
				#endif
			}
		}
	}
	
	func cancelAllQueuedRequests() {
		dispatch_async(self.requestHandlingQueue) {
			self.requestsQueue = [SerialRequest]()
		}
	}
	
	// MARK: - Private Methods
	
	// MARK: Port Closure
	
	private func reallyClosePort() {
		self.pinPollTimer = nil // Stop polling CTS/DSR/DCD pins
		
		// The next tcsetattr() call can fail if the port is waiting to send data. This is likely to happen
		// e.g. if flow control is on and the CTS line is low. So, turn off flow control before proceeding
		var options = termios()
		tcgetattr(self.fileDescriptor, &options)
		options.usesRTSCTSFlowControl = false
		options.usesDTRDSRFlowControl = false
		options.usesDCDOutputFlowControl = false
		tcsetattr(self.fileDescriptor, TCSANOW, &options)
		
		// Set port back the way it was before we used it
		if let originalPortAttributes = self.originalPortAttributes {
			var attrs = originalPortAttributes
			tcsetattr(self.fileDescriptor, TCSADRAIN, &attrs)
		}
		
		if Darwin.close(self.fileDescriptor) != 0 {
			LOG_SERIAL_PORT_ERROR("Error closing serial port with file descriptor \(self.fileDescriptor): \(errno)")
			self.notifyDelegateOfPosixError()
			return
		}
		
		self.fileDescriptor = 0
		doOnMainThreadAndWait { self.isOpen = false }
		
		if let host = self.host,
			delegateCall = host.delegate?.serialPortWasClosed {
				doOnMainThreadAndWait {
					delegateCall(host)
				}
		}
		dispatch_async(self.requestHandlingQueue, {
			self.requestsQueue.removeAll() // Cancel all queued requests
			self.pendingRequest = nil // Discard pending request
		})
	}
	
	func cleanupAfterSystemRemoval() {
		if let host = self.host {
			host.delegate?.serialPortWasRemovedFromSystem(host)
		}
		self.close()
	}
	
	// MARK: Port Read/Write
	
	private dynamic func receiveData(data: NSData) {
		if let host = self.host {
			dispatch_async(dispatch_get_main_queue(), {
				host.delegate?.serialPort?(host, didReceiveData: data)
			})
		}
		
		dispatch_async(self.requestHandlingQueue) {
			let bytes = UnsafePointer<UInt8>(data.bytes)
			for i in 0..<data.length {
				let ptr = UnsafeMutablePointer<UInt8>(bytes.advancedBy(i))
				let byte = NSData(bytesNoCopy: ptr, length: 1, freeWhenDone: false)
				for descriptor in self.packetDescriptors {
					guard let buffer = self.packetDescriptorsAndBuffers.objectForKey(descriptor) as? SerialBuffer else { continue }
					
					// Append byte to buffer
					buffer.appendData(byte)
					
					// Check for complete packet
					guard let completePacket = self.packetMatchingDescriptor(descriptor, atEndOfBuffer: buffer.data)
						where completePacket.length > 0 else { continue }
					
					// Complete packet received, so notify delegate then clear buffer
					if let host = self.host {
						dispatch_async(dispatch_get_main_queue()) {
							host.delegate?.serialPort?(host, didReceivePacket: completePacket, matchingDescriptor: descriptor)
						}
					}
					buffer.clearBuffer()
				}
				
				// Also check for response to pending request
				self.checkResponseToPendingRequestAndContinueIfValidWithReceivedByte(byte)
			}
		}
	}
	
	// MARK: Packet Parsing
	
	private func packetMatchingDescriptor(descriptor: SerialPacketDescriptor, atEndOfBuffer buffer: NSData) -> NSData? {
		for i in 1...buffer.length {
			let window = buffer.subdataWithRange(NSRange(location: buffer.length-i, length: i))
			if descriptor.dataIsValidPacket(window) { return window }
		}
		return nil
	}
	
	// MARK: Request / Response
	
	// Must only be called on requestHandlingQueue (ie. wrap call to this method in dispatch())
	private func reallySendRequest(request: SerialRequest) -> Bool {
		if self.pendingRequest != nil {
			// Queue it up to be sent after the pending request is responded to, or times out.
			#if os(OSX)
				self.willChangeValueForKey("requestsQueue")
			#endif
			self.requestsQueue.append(request)
			#if os(OSX)
				self.didChangeValueForKey("requestsQueue")
			#endif
			return true
		}
		
		// Send immediately
		if let responseDescriptor = request.responseDescriptor {
			let bufferLength = responseDescriptor.maximumPacketLength
			self.requestResponseReceiveBuffer = SerialBuffer(maximumLength: bufferLength)
		}
		
		self.pendingRequest = request
		if request.timeoutInterval > 0 {
			let timeoutInterval = request.timeoutInterval
			let timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.requestHandlingQueue)
			let timerInterval = timeoutInterval * NSTimeInterval(NSEC_PER_SEC)
			dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, Int64(timerInterval)), UInt64(timerInterval), 10*NSEC_PER_MSEC)
			dispatch_source_set_event_handler(timer, self.pendingRequestDidTimeout)
			self.pendingRequestTimeoutTimer = timer
			dispatch_resume(timer)
		}
		let success = self.sendData(request.dataToSend)
		if success { self.checkResponseToPendingRequestAndContinueIfValidWithReceivedByte(nil) }
		return success
	}
	
	// Must only be called on requestHandlingQueue
	private func sendNextRequest() {
		self.pendingRequest = nil
		guard let nextRequest = self.requestsQueue.first else { return }
		self.requestsQueue.removeAtIndex(0)
		self.reallySendRequest(nextRequest)
	}
	
	// Will only be called on requestHandlingQueue
	private func pendingRequestDidTimeout() {
		self.pendingRequestTimeoutTimer = nil
		
		guard let request = self.pendingRequest else { return }
		if let host = self.host, delegateCall: (SerialPort, SerialRequest) -> () = host.delegate?.serialPort {
			dispatch_async(dispatch_get_main_queue()) {
				delegateCall(host, request)
				dispatch_async(self.requestHandlingQueue, self.sendNextRequest)
			}
			delegateCall(host, request)
		} else {
			self.sendNextRequest()
		}
	}
	
	// Must only be called on requestHandlingQueue
	private func checkResponseToPendingRequestAndContinueIfValidWithReceivedByte(byte: NSData?) {
		guard let pendingRequest = self.pendingRequest else { return } // Nothing to do
		guard let packetDescriptor = pendingRequest.responseDescriptor else {
			self.sendNextRequest()
			return
		}
		guard let byte = byte, buffer = self.requestResponseReceiveBuffer else { return }
		
		buffer.appendData(byte)
		guard let responseData = self.packetMatchingDescriptor(packetDescriptor, atEndOfBuffer: buffer.data) else {
			return
		}
		
		self.pendingRequestTimeoutTimer = nil
		if let host = self.host, delegateCall: ((SerialPort, NSData, SerialRequest) -> Void) = host.delegate?.serialPort
			where responseData.length != 0 {
				dispatch_async(dispatch_get_main_queue()) {
					delegateCall(host, responseData, pendingRequest)
				}
		}
		self.sendNextRequest()
	}
	
	// MARK: Port Properties Methods
	
	private func setOptionsOnPort() {
		if self.fileDescriptor < 1 { return }
		
		var options = termios()
		tcgetattr(self.fileDescriptor, &options)
		
		cfmakeraw(&options)
		options.setControlCharacter(VMIN, value: 1) // Wait for at least 1 character before returning
		options.setControlCharacter(VTIME, value: 2) // Wait 200 milliseconds between bytes before returning from read
		
		// Set 8 data bits
		options.c_cflag &= ~tcflag_t(CSIZE)
		options.c_cflag |= tcflag_t(CS8)
		
		options.parity = self.parity
		options.numberOfStopBits = self.numberOfStopBits
		options.usesRTSCTSFlowControl = self.usesRTSCTSFlowControl
		options.usesDTRDSRFlowControl = self.usesDTRDSRFlowControl
		options.usesDCDOutputFlowControl = self.usesDCDOutputFlowControl
		
		options.c_cflag |= tcflag_t(HUPCL) // Turn on hangup on close
		options.c_cflag |= tcflag_t(CLOCAL) // Set local mode on
		options.c_cflag |= tcflag_t(CREAD) // Enable receiver
		options.c_lflag &= ~tcflag_t(ICANON | ISIG) // Turn off canonical mode and signals
		
		// Set baud rate
		cfsetspeed(&options, speed_t(self.baudRate))
		
		var result = tcsetattr(self.fileDescriptor, TCSANOW, &options)
		if result != 0 {
			if self.allowsNonStandardBaudRates {
				result = ioctlSetSpeed(self.fileDescriptor, CInt(self.baudRate))
			}
			if result != 0 {
				self.notifyDelegateOfPosixError()
			}
		}
	}
	
	// MARK: Port Properties Methods
	
	private func notifyDelegateOfPosixError() {
		notifyDelegateOfPosixErrorWaitingUntilDone(false)
	}
	
	private func notifyDelegateOfPosixErrorWaitingUntilDone(shouldWait: Bool) {
		guard let host = self.host else { return }
		var userInfo = [NSFilePathErrorKey : self.path]
		if let errorDesc = String.fromCString(strerror(errno)) {
			userInfo[NSLocalizedDescriptionKey] = errorDesc
		}
		let error = NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: userInfo)
		
		let notify: (Void) -> Void = { host.delegate?.serialPort?(host, didEncounterError: error) }
		if shouldWait {
			doOnMainThreadAndWait(notify)
		} else {
			dispatch_async(dispatch_get_main_queue(), notify)
		}
	}
	
	// MARK: - Properties
	
	// MARK: "Public"
	
	weak var delegate: SerialPortDelegate?
	
	let path: String
	let IOKitDevice: io_object_t
	let name: String
	var baudRate = Int(B19200)
	var allowsNonStandardBaudRates = false
	private(set) var isOpen: Bool = false
	var numberOfStopBits = UInt(1)
	var shouldEchoReceivedData = false
	var parity: SerialPortParity = .None
	var usesRTSCTSFlowControl = false
	var usesDTRDSRFlowControl = false
	var usesDCDOutputFlowControl = false
	var RTS = false
	var DTR = false
	private(set) var CTS = false
	private(set) var DSR = false
	private(set) var DCD = false
	
	// Request Response
	
	private(set) var pendingRequest: SerialRequest?
	private(set) var queuedRequests = [SerialRequest]()
	
	weak var host: SerialPort?
	
	// MARK: Private
	
	private var fileDescriptor: CInt = 0
	
	private var originalPortAttributes: termios?
	
	private var readPollSource: dispatch_source_t? {
		willSet {
			if let source = readPollSource {
				dispatch_source_cancel(source)
			}
		}
	}
	
	private var pinPollTimer: dispatch_source_t? {
		willSet {
			if let timer = pinPollTimer {
				dispatch_source_cancel(timer)
			}
		}
	}
	
	// Packet Handling
	private let packetDescriptorsAndBuffers = NSMapTable.strongToStrongObjectsMapTable()
	#if os(OSX)
	dynamic class func keyPathsForValuesAffectingPacketDescriptors() -> Set<String> {
		return ["packetDescriptorsAndBuffers"]
	}
	#endif
	var packetDescriptors: [SerialPacketDescriptor] {
		return self.packetDescriptorsAndBuffers.keyEnumerator().allObjects as? [SerialPacketDescriptor] ?? []
	}
	
	// Request Response
	private var requestsQueue = [SerialRequest]()
	private let requestHandlingQueue = dispatch_queue_create("com.openreelsoftware.ORSSerialPort.requestHandlingQueue", DISPATCH_QUEUE_SERIAL)
	private var requestResponseReceiveBuffer: SerialBuffer?
	private var pendingRequestTimeoutTimer: dispatch_source_t? {
		willSet {
			if let timer = pendingRequestTimeoutTimer {
				dispatch_source_cancel(timer)
			}
		}
	}
}

// MARK: -

func ==(lhs: _SerialPort, rhs: _SerialPort) -> Bool {
	return lhs.path == rhs.path
}

extension io_object_t {
	init(bsdPath: String) {
		if bsdPath == "TestDummy" { self = io_object_t.max; return }
		self = 0
		let matchingDict = IOServiceMatching(kIOSerialBSDServiceValue) as NSMutableDictionary
		matchingDict[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes
		var portIterator: io_iterator_t = 0
		let err = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &portIterator)
		guard err == 0 else { return }
		
		var device: io_object_t = IOIteratorNext(portIterator)
		repeat {
			if let calloutPath = device.bsdCalloutPath,
				dialinPath = device.bsdDialinPath {
					if bsdPath == calloutPath || bsdPath == dialinPath {
						self = device
						break
					}
			}
			IOObjectRelease(device)
			device = IOIteratorNext(portIterator)
		} while device != 0
		IOObjectRelease(portIterator)
	}
}


extension io_object_t {
	func stringPropertyForSerialKey(key: String) -> String? {
		guard self >= 0 else { return nil }
		if self == io_object_t.max { return "TestDummy" } // For 'dummy' testing port
		return IORegistryEntryCreateCFProperty(self, key, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
	}
	
	var bsdCalloutPath: String? { return stringPropertyForSerialKey(kIOCalloutDeviceKey) }
	var bsdDialinPath: String? { return stringPropertyForSerialKey(kIODialinDeviceKey) }
	var baseName: String? { return stringPropertyForSerialKey(kIOTTYBaseNameKey) }
	var serviceType: String? { return stringPropertyForSerialKey(kIOSerialBSDTypeKey) }
	var modemName: String? { return stringPropertyForSerialKey(kIOTTYDeviceKey) }
	var suffix: String? { return stringPropertyForSerialKey(kIOTTYSuffixKey) }
}
