//
//  SerialPortManager.swift
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
import IOKit
import IOKit.serial
import Cocoa

/// Set to true to enable error logging
public var SerialPortErrorLoggingEnabled = false

/// Posted when a serial port is connected to the system
public let SerialPortsWereConnectedNotification = "SerialPortWasConnectedNotification"

/// Posted when a serial port is disconnected from the system
public let SerialPortsWereDisconnectedNotification = "SerialPortsWereDisconnectedNotification"

/// Key for connected port in SerialPortWasConnectedNotification userInfo dictionary
public let ConnectedSerialPortsKey = "ConnectedSerialPortsKey"
/// Key for disconnected port in SerialPortWasDisconnectedNotification userInfo dictionary
public let DisconnectedSerialPortsKey = "DisconnectedSerialPortsKey"

public extension SerialPort {
	public class var ORSSerialPortsWereConnectedNotification: String { return SerialPortsWereConnectedNotification }
	public class var ORSSerialPortsWereDisconnectedNotification: String { return SerialPortsWereDisconnectedNotification }
	public class var ORSConnectedSerialPortsKey: String { return ConnectedSerialPortsKey }
	public class var ORSDisconnectedSerialPortsKey: String { return DisconnectedSerialPortsKey }
}

/**
*  `SerialPortManager` is a singleton class (one instance per
*  application) that can be used to get a list of available serial ports.
*  It will also handle closing open serial ports when the Mac goes to
*  sleep, and reopening them automatically on wake. This prevents problems
*  I've seen with serial port drivers that can hang if the port is left
*  open when putting the machine to sleep. Note that using
*  `SerialPortManager` is optional. It provides some nice functionality,
*  but only `ORSSerialPort` is necessary to simply send and received data.
*
*  Using SerialPortManager
*  --------------------------
*
*  To get the shared serial port
*  manager:
*
*      SerialPortManager *portManager = [SerialPortManager sharedSerialPortManager];
*
*  To get a list of available ports:
*
*      NSArray *availablePorts = portManager.availablePorts;
*
*  Notifications
*  -------------
*
*  `SerialPortManager` posts notifications when a port is added to or removed from the system.
*  `SerialPortsWereConnectedNotification` is posted when one or more ports
*  are added to the system. `SerialPortsWereDisconnectedNotification` is posted when
*  one ore more ports are removed from the system. The user info dictionary for each
*  notification contains the list of ports added or removed. The keys to access these array
*  are `ConnectedSerialPortsKey`, and `DisconnectedSerialPortsKey` respectively.
*
*  KVO Compliance (OS X Only)
*  --------------
*
*  `SerialPortManager` is Key-Value Observing (KVO) compliant for its
*  `availablePorts` property. This means that you can observe
*  `availablePorts` to be notified when ports are added to or removed from
*  the system. This also means that you can easily bind UI elements to the
*  serial port manager's `availablePorts` property using Cocoa-bindings.
*  This makes it easy to create a popup menu that displays available serial
*  ports and updates automatically, for example.
*
*  Close-On-Sleep (OS X Only)
*  --------------
*
*  `SerialPortManager`'s close-on-sleep, reopen-on-wake functionality is
*  automatic. The only thing necessary to enable it is to make sure that
*  the singleton instance of `SerialPortManager` has been created by
*  calling `+sharedSerialPortManager` at least once. Note that this
*  behavior is only available in Cocoa apps, and is disabled when
*  ORSSerialPort is used in a command-line only app.
*/
@objc(ORSSerialPortManager) public class SerialPortManager : NSObject {
	
	/**
	*  The shared (singleton) serial port manager object.
	*/
	public static let sharedSerialPortManager = SerialPortManager()
	
	public override init() {
		super.init()
		
		self.retrieveAvailablePortsAndRegisterForChangeNotifications()
		self.registerForNotifications()
	}
	
	deinit {
		let nc = NSNotificationCenter.defaultCenter()
		nc.removeObserver(self)
		if let termObserver = self.terminationObserver {
			nc.removeObserver(termObserver)
		}
		#if NSAppKitVersionNumber10_0
			let wsnc = NSWorkspace.sharedWorkspace().notificationCenter
			wsnc.removeObserver(self)
		#endif
		
		if portPublishedNotificationIterator != 0 { IOObjectRelease(portPublishedNotificationIterator) }
		if portTerminatedNotificationIterator != 0 { IOObjectRelease(portTerminatedNotificationIterator) }
	}
	
	// MARK: - Public
	
	// MARK: - Private
	
	private func registerForNotifications() {
		let terminationBlock = { [self]
			for port in self.availablePorts { port.cleanupAfterSystemRemoval() }
			self.availablePorts.removeAll()
		}
		
		#if NSAppKitVersionNumber10_0
			let nc = NSNotificationCenter.defaultCenter()
			self.terminationObserver = nc.addObserverForName(NSApplicationWillTerminateNotification, object: nil, queue: nil) { (n: NSNotification) -> Void in
				terminationBlock()
			}
			
			let wsnc = NSWorkspace.sharedWorkspace().notificationCenter
			wsnc.addObserver(self, selector: "systemWillSleep:", name: NSWorkspaceWillSleepNotification, object: nil)
			wsnc.addObserver(self, selector: "systemDidWake:", name: NSWorkspaceDidWakeNotification, object: nil)
		#else
			if atexit_b(terminationBlock) != 0 {
				NSLog("ORSSerialPort was unable to register its termination handler for serial port cleanup: \(errno)");
			}
		#endif
	}
	
	// MARK: Sleep/Wake Management
	
	private dynamic func systemWillSleep(notification: NSNotification) {
		for port in self.availablePorts where port.isOpen {
			self.portsToReopenAfterSleep.append(port)
		}
	}
	
	private dynamic func systemWillWake(notification: NSNotification) {
		for port in self.portsToReopenAfterSleep {
			port.open()
		}
		self.portsToReopenAfterSleep.removeAll()
	}
	
	// MARK: Port Notifications
	
	private func retrieveAvailablePortsAndRegisterForChangeNotifications() {
		let publicationNotificationPort = IONotificationPortCreate(kIOMasterPortDefault)
		let publicationSource = IONotificationPortGetRunLoopSource(publicationNotificationPort).takeUnretainedValue()
		CFRunLoopAddSource(CFRunLoopGetCurrent(), publicationSource, kCFRunLoopDefaultMode)
		
		let matchingDict = IOServiceMatching(kIOSerialBSDServiceValue) as NSMutableDictionary
		matchingDict[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes
		
		var publicationPortIterator: io_iterator_t = 0
		let pResult = IOServiceAddMatchingNotification(publicationNotificationPort,
			kIOPublishNotification,
			matchingDict,
			{ (pointer: UnsafeMutablePointer<Void>, iterator: io_iterator_t) -> Void in
				let localSelf: SerialPortManager = objectFromPointer(pointer)
				localSelf.serialPortsWerePublished(iterator)
			},
			pointerFromObject(self),
			&publicationPortIterator)
		defer {
			if publicationPortIterator != 0 { IOObjectRelease(publicationPortIterator) }
		}
		guard pResult == 0 else {
			LOG_SERIAL_PORT_ERROR("Error getting serial port list: \(pResult)")
			return
		}
		self.portPublishedNotificationIterator = publicationPortIterator
		
		self.availablePorts = portsFromIterator(publicationPortIterator)
		
		// Register for removal
		let terminationNotificationPort = IONotificationPortCreate(kIOMasterPortDefault)
		let terminationSource = IONotificationPortGetRunLoopSource(terminationNotificationPort).takeUnretainedValue()
		CFRunLoopAddSource(CFRunLoopGetCurrent(), terminationSource, kCFRunLoopDefaultMode)
		
		var terminationPortIterator: io_iterator_t = 0
		let tResult = IOServiceAddMatchingNotification(terminationNotificationPort,
			kIOTerminatedNotification,
			matchingDict,
			{ (pointer: UnsafeMutablePointer<Void>, iterator: io_iterator_t) -> Void in
				let localSelf: SerialPortManager = objectFromPointer(pointer)
				localSelf.serialPortsWereTerminated(iterator)
			},
			pointerFromObject(self),
			&terminationPortIterator)
		defer {
			if terminationPortIterator != 0 { IOObjectRelease(terminationPortIterator) }
		}
		guard tResult == 0 else {
			LOG_SERIAL_PORT_ERROR("Error registering for serial port termination notification: \(tResult).")
			return
		}
		self.portTerminatedNotificationIterator = terminationPortIterator
		
		while (IOIteratorNext(terminationPortIterator) != 0) {} // Run out the iterator to start notifications
	}
	
	private func portsFromIterator(iterator: io_iterator_t) -> [SerialPort] {
		var result = [SerialPort]()
		var device: io_object_t = IOIteratorNext(iterator)
		repeat {
			if let port = SerialPort(device: device) {
				result.append(port)
			}
			IOObjectRelease(device)
			device = IOIteratorNext(iterator)
		} while device != 0
		return result
	}
	
	private func serialPortsWerePublished(iterator: io_iterator_t) {
		let newlyConnectedPorts = portsFromIterator(iterator)
		for port in newlyConnectedPorts {
			print("new port: \(port.path)")
		}
		
		var ports = self.availablePorts
		ports.appendContentsOf(newlyConnectedPorts)
		self.availablePorts = ports
		
		let nc = NSNotificationCenter.defaultCenter()
		let userInfo = [ConnectedSerialPortsKey : newlyConnectedPorts]
		nc.postNotificationName(SerialPortsWereConnectedNotification, object: self, userInfo: userInfo)
	}
	
	private func serialPortsWereTerminated(iterator: io_iterator_t) {
		let newlyDisconnectedPorts = portsFromIterator(iterator)
		
		var ports = self.availablePorts
		for port in newlyDisconnectedPorts {
			print("removed port: \(port.path)")
			if let index = ports.indexOf(port) {
				ports.removeAtIndex(index)
			}
		}
		self.availablePorts = ports
		
		let nc = NSNotificationCenter.defaultCenter()
		let userInfo = [DisconnectedSerialPortsKey : newlyDisconnectedPorts]
		nc.postNotificationName(SerialPortsWereDisconnectedNotification, object: self, userInfo: userInfo)
	}
	
	// MARK: - Properties
	
	/**
	*  An array containing SerialPort instances representing the
	*  serial ports available on the system. (read-only)
	*
	*  As explained above, on OS X, this property is Key Value Observing
	*  compliant, and can be bound to for example an NSPopUpMenu
	*  to easily give the user a way to select an available port
	*  on the system.
	*/
	public private(set) dynamic var availablePorts = [SerialPort]()
	
	// Private Properties
	
	private var portsToReopenAfterSleep = [SerialPort]()
	private var terminationObserver: AnyObject?
	
	private var portPublishedNotificationIterator: io_iterator_t = 0 {
		didSet {
			if portPublishedNotificationIterator != 0 { IOObjectRetain(portPublishedNotificationIterator) }
			if oldValue != 0 { IOObjectRelease(oldValue) }
		}
	}
	private var portTerminatedNotificationIterator: io_iterator_t = 0 {
		didSet {
			if portTerminatedNotificationIterator != 0 { IOObjectRetain(portTerminatedNotificationIterator) }
			if oldValue != 0 { IOObjectRelease(oldValue) }
		}
		
	}
}

private func pointerFromObject<T: AnyObject>(object: T) -> UnsafeMutablePointer<Void> {
	return UnsafeMutablePointer(Unmanaged.passUnretained(object).toOpaque())
}

private func objectFromPointer<T: AnyObject>(pointer: UnsafePointer<Void>) -> T {
	return Unmanaged<T>.fromOpaque(COpaquePointer(pointer)).takeUnretainedValue()
}

func LOG_SERIAL_PORT_ERROR(string: String) {
	if SerialPortErrorLoggingEnabled {
		NSLog(string)
	}
}