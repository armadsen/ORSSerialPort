//
//  SerialPortManager.swift
//  ORSSerialPort
//
//  Created by Andrew Madsen on 12/7/15.
//  Copyright © 2015 Open Reel Software. All rights reserved.
//

import Foundation
import IOKit
import Cocoa

/// Posted when a serial port is connected to the system
public let SerialPortsWereConnectedNotification = "SerialPortWasConnectedNotification"

/// Posted when a serial port is disconnected from the system
public let SerialPortsWereDisconnectedNotification = "SerialPortsWereDisconnectedNotification"

/// Key for connected port in ORSSerialPortWasConnectedNotification userInfo dictionary
public let ConnectedSerialPortsKey = "ConnectedSerialPortsKey"
/// Key for disconnected port in ORSSerialPortWasDisconnectedNotification userInfo dictionary
public let DisconnectedSerialPortsKey = "DisconnectedSerialPortsKey"

/**
*  `ORSSerialPortManager` is a singleton class (one instance per
*  application) that can be used to get a list of available serial ports.
*  It will also handle closing open serial ports when the Mac goes to
*  sleep, and reopening them automatically on wake. This prevents problems
*  I've seen with serial port drivers that can hang if the port is left
*  open when putting the machine to sleep. Note that using
*  `ORSSerialPortManager` is optional. It provides some nice functionality,
*  but only `ORSSerialPort` is necessary to simply send and received data.
*
*  Using ORSSerialPortManager
*  --------------------------
*
*  To get the shared serial port
*  manager:
*
*      ORSSerialPortManager *portManager = [ORSSerialPortManager sharedSerialPortManager];
*
*  To get a list of available ports:
*
*      NSArray *availablePorts = portManager.availablePorts;
*
*  Notifications
*  -------------
*
*  `ORSSerialPort` posts notifications when a port is added to or removed from the system.
*  `ORSSerialPortsWereConnectedNotification` is posted when one or more ports
*  are added to the system. `ORSSerialPortsWereDisconnectedNotification` is posted when
*  one ore more ports are removed from the system. The user info dictionary for each
*  notification contains the list of ports added or removed. The keys to access these array
*  are `ORSConnectedSerialPortsKey`, and `ORSDisconnectedSerialPortsKey` respectively.
*
*  KVO Compliance
*  --------------
*
*  `ORSSerialPortManager` is Key-Value Observing (KVO) compliant for its
*  `availablePorts` property. This means that you can observe
*  `availablePorts` to be notified when ports are added to or removed from
*  the system. This also means that you can easily bind UI elements to the
*  serial port manager's `availablePorts` property using Cocoa-bindings.
*  This makes it easy to create a popup menu that displays available serial
*  ports and updates automatically, for example.
*
*  Close-On-Sleep
*  --------------
*
*  `ORSSerialPortManager`'s close-on-sleep, reopen-on-wake functionality is
*  automatic. The only thing necessary to enable it is to make sure that
*  the singleton instance of `ORSSerialPortManager` has been created by
*  calling `+sharedSerialPortManager` at least once. Note that this
*  behavior is only available in Cocoa apps, and is disabled when
*  ORSSerialPort is used in a command-line only app.
*/
public class SerialPortManager : NSObject {
	
	/**
	*  The shared (singleton) serial port manager object.
	*/
	public static let sharedSerialPortManager = SerialPortManager()
	
	public override init() {
		super.init()
		
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
	
	func systemWillSleep(notification: NSNotification) {
		for port in self.availablePorts where port.open {
			if port.close() { self.portsToReopenAfterSleep.append(port) }
		}
	}
	
	func systemWillWake(notification: NSNotification) {
		for port in self.portsToReopenAfterSleep {
			port.open()
		}
		self.portsToReopenAfterSleep.removeAll()
	}
	
	// MARK: Port Notifications
	
	private func retrieveAvailablePortsAndRegisterForChangeNotifications() {
		let notificationPort = IONotificationPortCreate(kIOMasterPortDefault)
		let source = IONotificationPortGetRunLoopSource(notificationPort)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode)
	}
	
	// MARK: - Properties
	
	/**
	*  An array containing ORSSerialPort instances representing the
	*  serial ports available on the system. (read-only)
	*
	*  As explained above, this property is Key Value Observing
	*  compliant, and can be bound to for example an NSPopUpMenu
	*  to easily give the user a way to select an available port
	*  on the system.
	*/
	public private(set) var availablePorts = [ORSSerialPort]()
	
	// Private Properties
	
	private var portsToReopenAfterSleep = [ORSSerialPort]()
	private var terminationObserver: AnyObject?
	
	private var portPublishedNotificationIterator: io_iterator_t?
	private var portTerminatedNotificationIterator: io_iterator_t?
}
