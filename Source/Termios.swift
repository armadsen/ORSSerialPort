//
//  Termios.swift
//  ORSSerialPort
//
//  Created by Andrew Madsen on 12/21/15.
//  Copyright © 2015 Open Reel Software. All rights reserved.
//

import Foundation
import Darwin.POSIX.termios

/** Extends termios to ease use from Swift code. */
extension termios {
	/**
	Set a value in the receiver's c_cc control characters array.
	This is bridged into Swift as a big tuple, requiring a bit of
	trickery to subscript into.
	
	- parameter character: A control character index into the c_cc array (e.g. VMIN, VTIME, etc.) See termios.h
	- parameter value:     The value to be set for the control character.
	*/
	func setControlCharacter(character: Int32, value: cc_t) {
		var cc = self.c_cc
		withUnsafeMutablePointer(&cc) { (tuplePtr) -> Void in
			let ccPtr = UnsafeMutablePointer<cc_t>(tuplePtr)
			ccPtr[Int(character)] = value
		}
	}
	
	var numberOfStopBits: UInt {
		get {
			return self.c_cflag & tcflag_t(CSTOPB) != 0 ? 2 : 1
		}
		set {
			if numberOfStopBits > 1 {
				self.c_cflag |= tcflag_t(CSTOPB)
			} else {
				self.c_cflag &= ~tcflag_t(CSTOPB)
			}
		}
	}
	
	var shouldEchoReceivedData: Bool {
		get {
			return self.c_lflag & tcflag_t(ECHO) != 0
		}
		set {
			if shouldEchoReceivedData {
				self.c_lflag |= tcflag_t(ECHO)
			} else {
				self.c_lflag &= ~tcflag_t(ECHO)
			}
		}
	}
	
	var usesRTSCTSFlowControl: Bool {
		get {
			return self.c_cflag & tcflag_t((CCTS_OFLOW | CRTS_IFLOW)) != 0
		}
		set {
			if usesRTSCTSFlowControl {
				self.c_cflag |= tcflag_t((CCTS_OFLOW | CRTS_IFLOW))
			} else {
				self.c_cflag &= ~tcflag_t((CCTS_OFLOW | CRTS_IFLOW))
			}
		}
	}
	
	var usesDTRDSRFlowControl: Bool {
		get {
			return self.c_cflag & tcflag_t((CDTR_IFLOW | CDSR_OFLOW)) != 0
		}
		set {
			if usesDTRDSRFlowControl {
				self.c_cflag |= tcflag_t((CDTR_IFLOW | CDSR_OFLOW))
			} else {
				self.c_cflag &= ~tcflag_t((CDTR_IFLOW | CDSR_OFLOW))
			}
		}
	}
	
	var usesDCDOutputFlowControl: Bool {
		get {
			return self.c_cflag & tcflag_t(CCAR_OFLOW) != 0
		}
		set {
			if usesDCDOutputFlowControl {
				self.c_cflag |= tcflag_t(CCAR_OFLOW)
			} else {
				self.c_cflag &= ~tcflag_t(CCAR_OFLOW)
			}
		}
	}
	
	/// Convenience property for getting/setting parity
	var parity: SerialPortParity {
		get {
			if self.c_cflag & tcflag_t(PARENB) == 0 {
				return .None
			}
			if self.c_cflag & tcflag_t(PARODD) == 0 {
				return .Even
			} else {
				return .Odd
			}
		}
		set {
			switch parity {
			case .None:
				self.c_cflag &= ~tcflag_t(PARENB);
				break;
			case .Even:
				self.c_cflag |= tcflag_t(PARENB);
				self.c_cflag &= ~tcflag_t(PARODD);
				break;
			case .Odd:
				self.c_cflag |= tcflag_t(PARENB);
				self.c_cflag |= tcflag_t(PARODD);
				break;
			}
		}
	}
}