//
//  MainViewController.swift
//  RequestResponseDemo
//
//  Created by Andrew Madsen on 3/14/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

import Cocoa
import ORSSerial

class MainViewController: NSViewController {

	@IBOutlet weak var temperaturePlotView: TemperaturePlotView!
	let serialPortManager = ORSSerialPortManager.sharedSerialPortManager()
	let boardController = SerialBoardController()
	
	override func viewDidLoad() {
		self.boardController.addObserver(self, forKeyPath: "temperature", options: NSKeyValueObservingOptions.allZeros, context: MainViewControllerKVOContext)
	}
	
	// MARK: KVO
	
	let MainViewControllerKVOContext = UnsafeMutablePointer<()>()
	override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
		if context != MainViewControllerKVOContext {
			super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
		}
		
		if object as NSObject == self.boardController && keyPath == "temperature" {
			self.temperaturePlotView.addTemperature(self.boardController.temperature)
		}
	}

}

