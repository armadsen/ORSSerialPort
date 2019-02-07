//
//  MainViewController.swift
//  PacketParsingDemo
//
//  Created by Andrew Madsen on 8/10/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

import Cocoa
import ORSSerial

class MainViewController: NSViewController {

	let serialPortManager = ORSSerialPortManager.shared()
	let serialCommunicator = SerialCommunicator()

}

