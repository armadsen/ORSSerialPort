//
//  PlatformSupport.swift
//  ORSSerialPort
//
//  Created by Andrew Madsen on 12/24/15.
//  Copyright © 2015 Open Reel Software. All rights reserved.
//

/*
This file contains code required to accomodate differences between ORSSerialPort on OS X vs. other platforms (e.g. Linux).
*/

import Foundation

extension SerialPort {
	public override class func keyPathsForValuesAffectingValueForKey(key: String) -> Set<String> {
		var result = super.keyPathsForValuesAffectingValueForKey(key)
		
		let internalKeys: Set<String> = ["isOpen", "path", "IOKitDevice", "name", "baudRate", "allowsNonStandardBaudRates", "numberOfStopBits", "shouldEchoReceivedData", "parity", "usesRTSCTSFlowControl", "usesDTRDSRFlowControl", "usesDCDOutputFlowControl", "RTS", "DTR", "CTS", "DSR", "DCD", "packetDescriptors", "pendingRequest", "queuedRequests"]
		
		if internalKeys.contains(key) {
			result.insert("_port" + "." + key)
		}
		
		return result
	}
}
