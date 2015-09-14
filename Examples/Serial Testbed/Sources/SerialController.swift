//
//  SerialController.swift
//  Serial Testbed
//
//  Created by Andrew Madsen on 9/7/15.
//  Copyright © 2015 Open Reel Software. All rights reserved.
//

import Cocoa
import ORSSerial

class SerialController: NSObject, ORSSerialPortDelegate {
	
	override init() {
		super.init()
		
		// self.serialPort = self.availablePorts.first
		//self.serialPort = ORSSerialPort(path: "/dev/cu.UPSH112I14433P1.1")
	}
	
	// MARK: Public
	
	// Actions
	
	@IBAction func clearLog(sender: AnyObject) {
		self.clearLogOutput()
	}
	
	// MARK: Private
	
	private enum PacketType: String {
		case Hello
		case Goodbye
		case ChangeRTS
		case ChangeDTR
		case CTSState
		case DSRState
	}
	
	private let helloDescriptor = ORSSerialPacketDescriptor(packetData: "Hello?".dataUsingEncoding(NSASCIIStringEncoding)!, userInfo: PacketType.Hello.rawValue)
	private let goodbyeDescriptor = ORSSerialPacketDescriptor(packetData: "Goodbye!".dataUsingEncoding(NSASCIIStringEncoding)!, userInfo: PacketType.Goodbye.rawValue)
	private let changeRTSDescriptor = ORSSerialPacketDescriptor(prefixString: "RTS", suffixString: ";", maximumPacketLength: 5, userInfo: PacketType.ChangeRTS.rawValue)
	private let changeDTRDescriptor = ORSSerialPacketDescriptor(prefixString: "DTR", suffixString: ";", maximumPacketLength: 5, userInfo: PacketType.ChangeDTR.rawValue)
	private let CTSStateDescriptor = ORSSerialPacketDescriptor(packetData: "CTS?".dataUsingEncoding(NSASCIIStringEncoding)!, userInfo: PacketType.CTSState.rawValue)
	private let DSRStateDescriptor = ORSSerialPacketDescriptor(packetData: "DSR?".dataUsingEncoding(NSASCIIStringEncoding)!, userInfo: PacketType.DSRState.rawValue)
	
	private func startListening() {
		self.serialPort?.startListeningForPacketsMatchingDescriptor(self.helloDescriptor)
		self.serialPort?.startListeningForPacketsMatchingDescriptor(self.goodbyeDescriptor)
		self.serialPort?.startListeningForPacketsMatchingDescriptor(self.changeRTSDescriptor)
		self.serialPort?.startListeningForPacketsMatchingDescriptor(self.changeDTRDescriptor)
		self.serialPort?.startListeningForPacketsMatchingDescriptor(self.CTSStateDescriptor)
		self.serialPort?.startListeningForPacketsMatchingDescriptor(self.DSRStateDescriptor)
		self.logOutput("Started listening for incoming packets")
	}
	
	// Logging
	
	private func logOutput(var string: String, appendNewline: Bool = true) {
		if appendNewline { string += "\n" }
		
		let color = NSColor(calibratedRed: 0.355, green: 1.000, blue: 0.697, alpha: 1.000)
		let font = NSFont(name: "Monaco", size: 12.0) ?? NSFont.systemFontOfSize(12.0)
		let attrs = [NSForegroundColorAttributeName : color,
			NSFontAttributeName : font]
		let attrString = NSAttributedString(string: string, attributes: attrs)
		self.diagnosticTextView.textStorage?.appendAttributedString(attrString)
	}
	
	private func clearLogOutput() {
		self.diagnosticTextView.textStorage?.mutableString.setString("")
	}
	
	// Send/Receive
	
	private func send(data: NSData) {
		guard communicationEnabled else { return }
		
		let logString = String(data: data, encoding: NSASCIIStringEncoding) ?? ""
		
		self.logOutput("Sending \(logString) (\(data))")
		self.serialPort?.sendData(data)
	}
	
	private func send(string: String) {
		if let data = string.dataUsingEncoding(NSASCIIStringEncoding) {
			self.send(data)
		}
	}
	
	// Command Handlers
	
	private func handleChangeRTSCommand(data: NSData) {
		guard let string = String(data: data, encoding: NSASCIIStringEncoding) else {
			return // Bad command
		}
		self.serialPort?.RTS = string[string.startIndex.advancedBy(3)] == "1"
	}
	
	private func handleChangeDTRCommand(data: NSData) {
		guard let string = String(data: data, encoding: NSASCIIStringEncoding) else {
			return // Bad command
		}
		self.serialPort?.DTR = string[string.startIndex.advancedBy(3)] == "1"
	}
	
	// MARK: ORSSerialPortDelegate
	
	func serialPortWasRemovedFromSystem(serialPort: ORSSerialPort) {
		self.serialPort = nil
	}
	
	func serialPortWasOpened(serialPort: ORSSerialPort) {
		self.logOutput("Opened port \(serialPort.name)")
		self.startListening()
	}
	
	func serialPortWasClosed(serialPort: ORSSerialPort) {
		let packetDescriptors = serialPort.packetDescriptors
		for descriptor in packetDescriptors { serialPort.stopListeningForPacketsMatchingDescriptor(descriptor) }
	}
	
	func serialPort(serialPort: ORSSerialPort, didReceivePacket packetData: NSData, matchingDescriptor descriptor: ORSSerialPacketDescriptor) {
		if let packetTypeString = descriptor.userInfo as? String,
			packetType = PacketType(rawValue: packetTypeString) {
				
				self.logOutput("Received \(String(data: packetData, encoding:NSASCIIStringEncoding)) ", appendNewline: false)
				
				switch packetType {
				case .Hello:
					communicationEnabled = true
					self.send(NSData(bytes: [0x06] as [UInt8], length: 1))
				case .Goodbye:
					self.send(NSData(bytes: [0x06] as [UInt8], length: 1))
					communicationEnabled = false
				case .ChangeRTS:
					self.handleChangeRTSCommand(packetData)
					self.logOutput("")
				case .ChangeDTR:
					self.handleChangeDTRCommand(packetData)
					self.logOutput("")
				case .CTSState:
					self.send("CTS" + NSNumber(bool: serialPort.CTS).stringValue + ";")
				case .DSRState:
					self.send("DSR" + NSNumber(bool: serialPort.DSR).stringValue + ";")
				}
		}
	}
	
	// MARK: Properties
	
	private var communicationEnabled = false
	
	private dynamic let serialPortManager = ORSSerialPortManager.sharedSerialPortManager()
	
	class func keyPathsForValuesAffectingAvailablePorts() -> Set<String> {
		return Set(["serialPortManager.availablePorts"])
	}
	
	dynamic var availablePorts: [ORSSerialPort] {
		return serialPortManager.availablePorts.filter { return $0.name.lowercaseString.rangeOfString("bluetooth") == nil }
	}
	
	dynamic var serialPort: ORSSerialPort? {
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
	
	@IBOutlet var diagnosticTextView: NSTextView!
}
