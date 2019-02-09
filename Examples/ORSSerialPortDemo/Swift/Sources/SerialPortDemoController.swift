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
import ORSSerial

class SerialPortDemoController: NSObject, ORSSerialPortDelegate, NSUserNotificationCenterDelegate {
	
	@objc let serialPortManager = ORSSerialPortManager.shared()
	@objc let availableBaudRates = [300, 1200, 2400, 4800, 9600, 14400, 19200, 28800, 38400, 57600, 115200, 230400]
	@objc dynamic var shouldAddLineEnding = false
	
	@objc dynamic var serialPort: ORSSerialPort? {
		didSet {
			oldValue?.close()
			oldValue?.delegate = nil
			serialPort?.delegate = self
		}
	}
	
	@IBOutlet weak var sendTextField: NSTextField!
	@IBOutlet weak var sendButton: NSButton!
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
		
		let nc = NotificationCenter.default
		nc.addObserver(self, selector: #selector(serialPortsWereConnected(_:)), name: NSNotification.Name.ORSSerialPortsWereConnected, object: nil)
		nc.addObserver(self, selector: #selector(serialPortsWereDisconnected(_:)), name: NSNotification.Name.ORSSerialPortsWereDisconnected, object: nil)
		
		NSUserNotificationCenter.default.delegate = self
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	// MARK: - Actions
	
	@IBAction func send(_: Any) {
		var string = self.sendTextField.stringValue
		if self.shouldAddLineEnding && !string.hasSuffix("\n") {
			string += self.lineEndingString
		}
		if let data = string.data(using: String.Encoding.utf8) {
			self.serialPort?.send(data)
		}
	}
	
	@IBAction func returnPressedInTextField(_ sender: Any) {
		sendButton.performClick(sender)
	}
	
	@IBAction func openOrClosePort(_ sender: Any) {
		if let port = self.serialPort {
			if (port.isOpen) {
				port.close()
			} else {
				port.open()
				self.receivedDataTextView.textStorage?.mutableString.setString("");
			}
		}
	}
	
	@IBAction func clear(_ sender: Any) {
		self.receivedDataTextView.string = ""
	}
	
	// MARK: - ORSSerialPortDelegate
	
	func serialPortWasOpened(_ serialPort: ORSSerialPort) {
		self.openCloseButton.title = "Close"
	}
	
	func serialPortWasClosed(_ serialPort: ORSSerialPort) {
		self.openCloseButton.title = "Open"
	}
	
	func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
		if let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
			self.receivedDataTextView.textStorage?.mutableString.append(string as String)
			self.receivedDataTextView.needsDisplay = true
		}
	}
	
	func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
		self.serialPort = nil
		self.openCloseButton.title = "Open"
	}
	
	func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
		print("SerialPort \(serialPort) encountered an error: \(error)")
	}
	
	// MARK: - NSUserNotifcationCenterDelegate
	
	func userNotificationCenter(_ center: NSUserNotificationCenter, didDeliver notification: NSUserNotification) {
		let popTime = DispatchTime.now() + Double(Int64(3.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
		DispatchQueue.main.asyncAfter(deadline: popTime) { () -> Void in
			center.removeDeliveredNotification(notification)
		}
	}
	
	func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
		return true
	}
	
	// MARK: - Notifications
	
	@objc func serialPortsWereConnected(_ notification: Notification) {
		if let userInfo = notification.userInfo {
			let connectedPorts = userInfo[ORSConnectedSerialPortsKey] as! [ORSSerialPort]
			print("Ports were connected: \(connectedPorts)")
			self.postUserNotificationForConnectedPorts(connectedPorts)
		}
	}
	
	@objc func serialPortsWereDisconnected(_ notification: Notification) {
		if let userInfo = notification.userInfo {
			let disconnectedPorts: [ORSSerialPort] = userInfo[ORSDisconnectedSerialPortsKey] as! [ORSSerialPort]
			print("Ports were disconnected: \(disconnectedPorts)")
			self.postUserNotificationForDisconnectedPorts(disconnectedPorts)
		}
	}
	
	func postUserNotificationForConnectedPorts(_ connectedPorts: [ORSSerialPort]) {
		let unc = NSUserNotificationCenter.default
		for port in connectedPorts {
			let userNote = NSUserNotification()
			userNote.title = NSLocalizedString("Serial Port Connected", comment: "Serial Port Connected")
			userNote.informativeText = "Serial Port \(port.name) was connected to your Mac."
			userNote.soundName = nil;
			unc.deliver(userNote)
		}
	}
	
	func postUserNotificationForDisconnectedPorts(_ disconnectedPorts: [ORSSerialPort]) {
		let unc = NSUserNotificationCenter.default
		for port in disconnectedPorts {
			let userNote = NSUserNotification()
			userNote.title = NSLocalizedString("Serial Port Disconnected", comment: "Serial Port Disconnected")
			userNote.informativeText = "Serial Port \(port.name) was disconnected from your Mac."
			userNote.soundName = nil;
			unc.deliver(userNote)
		}
	}
}
