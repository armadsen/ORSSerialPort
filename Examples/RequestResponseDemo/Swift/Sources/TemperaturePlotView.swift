//
//  TemperaturePlotView.swift
//  RequestResponseDemo
//
//  Created by Andrew Madsen on 3/14/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

import Cocoa

@IBDesignable class TemperaturePlotView: NSView {
	
	// MARK: IBDesignable Support
	
	override func prepareForInterfaceBuilder() {
		self.temperatures = [17, 17, 18, 20, 23, 24, 25, 25, 24, 23, 21, 19, 18, 18, 16, 16, 17, 16, 18, 16, 17, 15, 17, 19, 25, 27, 30, 28, 23, 20, 20]
	}
	
	// MARK: Drawing
	override func drawRect(dirtyRect: NSRect) {
		super.drawRect(dirtyRect)
		
		NSColor(calibratedWhite: 0.82, alpha: 1.0).set()
		NSRectFill(dirtyRect)
		
		if self.temperatures.count == 0 {
			return
		}
		
		if self.drawsLines {
			self.plotColor.set()
			let linePath = NSBezierPath()
			linePath.lineWidth = 1.5
			linePath.moveToPoint(self.pointForTemperatureAtIndex(0)!)
			for i in 1..<self.temperatures.count {
				linePath.lineToPoint(self.pointForTemperatureAtIndex(i)!)
			}
			linePath.stroke()
		}
		
		if self.drawsPoints {
			self.plotColor.set()
			for i in 1..<self.temperatures.count {
				NSRectFill(self.rectForTemperatureAtIndex(i)!)
			}
		}
	}
	
	// MARK: Public
	
	func addTemperature(temperature: Int) {
		let maxNumTemperatures = Int(NSWidth(self.bounds) / 10.0)
		if self.temperatures.count >= maxNumTemperatures {
			self.temperatures.removeAll(keepCapacity: false)
		}
		self.temperatures.append(temperature)
		self.needsDisplay = true
	}
	
	// MARK: Private
	
	func rectForTemperatureAtIndex(index: Int) -> NSRect? {
		let point = self.pointForTemperatureAtIndex(index)
		if let point = point  {
			let rectWidth: CGFloat = 5.0
			return NSRect(x: point.x - rectWidth/2.0, y: point.y - rectWidth/2.0, width: rectWidth, height: rectWidth)
		} else {
			return nil
		}
	}
	
	func pointForTemperatureAtIndex(index: Int) -> NSPoint? {
		if index >= self.temperatures.count {
			return nil
		}
		let temperature = self.temperatures[index]
		let scaledTemp = CGFloat(temperature - self.minTemperatureValue) / CGFloat(self.maxTemperatureValue - self.minTemperatureValue)
		return NSPoint(x: CGFloat(index) * 10.0, y: NSHeight(self.bounds) * scaledTemp)
	}
	
	// MARK: Properties
	
	// Public
	@IBInspectable var plotColor = NSColor.blueColor()
	@IBInspectable var drawsPoints = true
	@IBInspectable var drawsLines = true
	@IBInspectable var minTemperatureValue = 0
	@IBInspectable var maxTemperatureValue = 100
	
	// Private
	private var temperatures: [Int] = []
}
