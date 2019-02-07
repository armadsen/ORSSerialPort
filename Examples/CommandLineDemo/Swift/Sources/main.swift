//
//  main.swift
//  CommandLineDemo
//
//  Created by Andrew Madsen on 4/13/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
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

enum ApplicationState {
	case initializationState
	case waitingForPortSelectionState([ORSSerialPort])
	case waitingForBaudRateInputState
	case waitingForUserInputState
}

// MARK: User prompts

struct UserPrompter {
	func printIntroduction() {
		print("This program demonstrates the use of ORSSerialPort")
		print("in a Foundation-based command-line tool.")
		print("Please see http://github.com/armadsen/ORSSerialPort/\nor email andrew@openreelsoftware.com for more information.\n")
	}
	
	func printPrompt() {
		print("\n> ", terminator: "")
	}
	
	func promptForSerialPort() {
		print("\nPlease select a serial port: \n")
		let availablePorts = ORSSerialPortManager.shared().availablePorts 
		var i = 0
		for port in availablePorts {
			print("\(i). \(port.name)")
			i += 1
		}
		printPrompt()
	}
	
	func promptForBaudRate() {
		print("\nPlease enter a baud rate: ", terminator: "");
	}
}

class StateMachine : NSObject, ORSSerialPortDelegate {
	var currentState = ApplicationState.initializationState
	let standardInputFileHandle = FileHandle.standardInput
	let prompter = UserPrompter()
	
	var serialPort: ORSSerialPort? {
		didSet {
			serialPort?.delegate = self;
			serialPort?.open()
		}
	}
	
	func runProcessingInput() {
		setbuf(stdout, nil)
		standardInputFileHandle.readabilityHandler = { (fileHandle: FileHandle) in
			let data = fileHandle.availableData
			DispatchQueue.main.async {
				self.handleUserInput(data)
			}
		}
		
		prompter.printIntroduction()
		
		let availablePorts = ORSSerialPortManager.shared().availablePorts 
		if availablePorts.count == 0 {
			print("No connected serial ports found. Please connect your USB to serial adapter(s) and run the program again.\n")
			exit(EXIT_SUCCESS)
		}
		prompter.promptForSerialPort()
		currentState = .waitingForPortSelectionState(availablePorts)

		RunLoop.current.run() // Required to receive data from ORSSerialPort and to process user input
	}
	
	// MARK: Port Settings
	func setupAndOpenPortWithSelectionString(_ selectionString: String, availablePorts: [ORSSerialPort]) -> Bool {
		var selectionString = selectionString
		selectionString = selectionString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
		if let index = Int(selectionString) {
			let clampedIndex = min(max(index, 0), availablePorts.count-1)
			self.serialPort = availablePorts[clampedIndex]
			return true
		} else {
			return false
		}
	}
	
	func setBaudRateOnPortWithString(_ selectionString: String) -> Bool {
		var selectionString = selectionString
		selectionString = selectionString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
		if let baudRate = Int(selectionString) {
			self.serialPort?.baudRate = NSNumber(value: baudRate)
			print("Baud rate set to \(baudRate)", terminator: "")
			return true
		} else {
			return false
		}
	}
	
	// MARK: Data Processing
	func handleUserInput(_ dataFromUser: Data) {
		if let string = NSString(data: dataFromUser, encoding: String.Encoding.utf8.rawValue) as? String {
			
			if string.lowercased().hasPrefix("exit") ||
				string.lowercased().hasPrefix("quit") {
					print("Quitting...")
					exit(EXIT_SUCCESS)
			}
			
			switch self.currentState {
			case .waitingForPortSelectionState(let availablePorts):
				if !setupAndOpenPortWithSelectionString(string, availablePorts: availablePorts) {
					print("\nError: Invalid port selection.", terminator: "")
					prompter.promptForSerialPort()
					return
				}
			case .waitingForBaudRateInputState:
				if !setBaudRateOnPortWithString(string) {
					print("\nError: Invalid baud rate. Baud rate should consist only of numeric digits.", terminator: "")
					prompter.promptForBaudRate();
					return;
				}
				currentState = .waitingForUserInputState
				prompter.printPrompt()
			case .waitingForUserInputState:
				self.serialPort?.send(dataFromUser)
				prompter.printPrompt()
			default:
				break;
			}
		}
	}
	
	// ORSSerialPortDelegate
	
	func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
		if let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
			print("\nReceived: \"\(string)\" \(data)", terminator: "")
		}
		prompter.printPrompt()
	}
	
	func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
		self.serialPort = nil
	}
	
	func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
		print("Serial port (\(serialPort)) encountered error: \(error)")
	}
	
	func serialPortWasOpened(_ serialPort: ORSSerialPort) {
		print("Serial port \(serialPort) was opened", terminator: "")
		prompter.promptForBaudRate()
		currentState = .waitingForBaudRateInputState
	}
}

StateMachine().runProcessingInput()
