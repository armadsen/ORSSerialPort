//
//  SerialPortDemoController.swift
//  ORSSerialPortSwiftDemo
//
//  Created by Andrew Madsen on 10/31/14.
//  Copyright (c) 2014 Open Reel Software. All rights reserved.
//

import Cocoa

class SerialPortDemoController: NSObject, ORSSerialPortDelegate, NSUserNotificationCenterDelegate {
	
	let serialPortManager = ORSSerialPortManager.sharedSerialPortManager()
	let availableBaudRates = [300, 1200, 2400, 4800, 9600, 14400, 19200, 28800, 38400, 57600, 115200, 230400]
	
	var serialPort: ORSSerialPort? {
		didSet {
			oldValue?.close()
			oldValue?.delegate = nil
			serialPort?.delegate = self
		}
	}
	
	@IBOutlet weak var sendTextField: NSTextField!
	@IBOutlet var receivedDataTextView: NSTextView!
	@IBOutlet weak var openCloseButton: NSButton!
	
	override init() {
		super.init()
		
		let nc = NSNotificationCenter.defaultCenter()
		nc.addObserver(self, selector: "serialPortsWereConnected:", name: ORSSerialPortsWereConnectedNotification, object: nil)
		nc.addObserver(self, selector: "serialPortsWereDisconnected:", name: ORSSerialPortsWereDisconnectedNotification, object: nil)
		
		NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self
	}
	
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	// MARK: - Actions
	
	@IBAction func send(AnyObject) {
		let data = self.sendTextField.stringValue.dataUsingEncoding(NSUTF8StringEncoding)
		self.serialPort?.sendData(data)
	}
	
	@IBAction func openOrClosePort(sender: AnyObject) {
		if let port = self.serialPort {
			if (port.open) {
				port.close()
			} else {
				port.open()
				self.receivedDataTextView.textStorage?.mutableString.setString("");
			}
		}
	}
	
	// MARK: - ORSSerialPortDelegate
	
	func serialPortWasOpened(serialPort: ORSSerialPort!) {
		self.openCloseButton.title = "Close"
	}
	
	func serialPortWasClosed(serialPort: ORSSerialPort!) {
		self.openCloseButton.title = "Open"
	}
	
	func serialPort(serialPort: ORSSerialPort!, didReceiveData data: NSData!) {
		if let string = NSString(data: data, encoding: NSUTF8StringEncoding) {
			self.receivedDataTextView.textStorage?.mutableString.appendString(string as String)
			self.receivedDataTextView.needsDisplay = true
		}
	}
	
	func serialPortWasRemovedFromSystem(serialPort: ORSSerialPort!) {
		self.serialPort = nil
		self.openCloseButton.title = "Open"
	}
	
	func serialPort(serialPort: ORSSerialPort!, didEncounterError error: NSError!) {
		println("SerialPort \(serialPort) encountered an error: \(error)")
	}
	
	// MARK: - NSUserNotifcationCenterDelegate
	
	func userNotificationCenter(center: NSUserNotificationCenter, didDeliverNotification notification: NSUserNotification) {
		let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64(3.0 * Double(NSEC_PER_SEC)))
		dispatch_after(popTime, dispatch_get_main_queue()) { () -> Void in
			center.removeDeliveredNotification(notification)
		}
	}
	
	func userNotificationCenter(center: NSUserNotificationCenter, shouldPresentNotification notification: NSUserNotification) -> Bool {
		return true
	}
	
	// MARK: - Notifications
	
	func serialPortsWereConnected(notification: NSNotification) {
		if let userInfo = notification.userInfo {
			let connectedPorts = userInfo[ORSConnectedSerialPortsKey] as! [ORSSerialPort]
			println("Ports were connected: \(connectedPorts)")
			self.postUserNotificationForConnectedPorts(connectedPorts)
		}
	}
	
	func serialPortsWereDisconnected(notification: NSNotification) {
		if let userInfo = notification.userInfo {
			let disconnectedPorts: [ORSSerialPort] = userInfo[ORSDisconnectedSerialPortsKey] as! [ORSSerialPort]
			println("Ports were disconnected: \(disconnectedPorts)")
			self.postUserNotificationForDisconnectedPorts(disconnectedPorts)
		}
	}
	
	func postUserNotificationForConnectedPorts(connectedPorts: [ORSSerialPort]) {
		let unc = NSUserNotificationCenter.defaultUserNotificationCenter()
		for port in connectedPorts {
			let userNote = NSUserNotification()
			userNote.title = NSLocalizedString("Serial Port Connected", comment: "Serial Port Connected")
			userNote.informativeText = "Serial Port \(port.name) was connected to your Mac."
			userNote.soundName = nil;
			unc.deliverNotification(userNote)
		}
	}
	
	func postUserNotificationForDisconnectedPorts(disconnectedPorts: [ORSSerialPort]) {
		let unc = NSUserNotificationCenter.defaultUserNotificationCenter()
		for port in disconnectedPorts {
			let userNote = NSUserNotification()
			userNote.title = NSLocalizedString("Serial Port Disconnected", comment: "Serial Port Disconnected")
			userNote.informativeText = "Serial Port \(port.name) was disconnected from your Mac."
			userNote.soundName = nil;
			unc.deliverNotification(userNote)
		}
	}
}