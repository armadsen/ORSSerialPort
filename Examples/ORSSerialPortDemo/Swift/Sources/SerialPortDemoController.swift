//
//  SerialPortDemoController.swift
//  ORSSerialPortSwiftDemo
//
//  Created by Andrew Madsen on 10/31/14.
//  Copyright (c) 2014 Open Reel Software. All rights reserved.
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

class SerialPortDemoController: NSObject, ORSSerialPortDelegate, NSUserNotificationCenterDelegate {
	
	let serialPortManager = ORSSerialPortManager.sharedSerialPortManager()
	let availableBaudRates = [300, 1200, 2400, 4800, 9600, 14400, 19200, 28800, 38400, 57600, 115200, 230400]
	var shouldAddLineEnding = false
	
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
	@IBOutlet weak var lineEndingPopUpButton: NSPopUpButton!
	var lineEndingString: String {
		let map = [0: "\r", 1: "\n", 2: "\r\n"]
		if let result = map[self.lineEndingPopUpButton.selectedTag()] {
			return result
		} else {
			return "\n"
		}
	}
	
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
	
	@IBAction func send(_: AnyObject) {
		var string = self.sendTextField.stringValue
		if self.shouldAddLineEnding && !string.hasSuffix("\n") {
			string += self.lineEndingString
		}
		if let data = string.dataUsingEncoding(NSUTF8StringEncoding) {
			self.serialPort?.sendData(data)
		}
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
	
	func serialPortWasOpened(serialPort: ORSSerialPort) {
		self.openCloseButton.title = "Close"
	}
	
	func serialPortWasClosed(serialPort: ORSSerialPort) {
		self.openCloseButton.title = "Open"
	}
	
	func serialPort(serialPort: ORSSerialPort, didReceiveData data: NSData) {
		if let string = NSString(data: data, encoding: NSUTF8StringEncoding) {
			self.receivedDataTextView.textStorage?.mutableString.appendString(string as String)
			self.receivedDataTextView.needsDisplay = true
		}
	}
	
	func serialPortWasRemovedFromSystem(serialPort: ORSSerialPort) {
		self.serialPort = nil
		self.openCloseButton.title = "Open"
	}
	
	func serialPort(serialPort: ORSSerialPort, didEncounterError error: NSError) {
		print("SerialPort \(serialPort) encountered an error: \(error)")
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
			print("Ports were connected: \(connectedPorts)")
			self.postUserNotificationForConnectedPorts(connectedPorts)
		}
	}
	
	func serialPortsWereDisconnected(notification: NSNotification) {
		if let userInfo = notification.userInfo {
			let disconnectedPorts: [ORSSerialPort] = userInfo[ORSDisconnectedSerialPortsKey] as! [ORSSerialPort]
			print("Ports were disconnected: \(disconnectedPorts)")
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