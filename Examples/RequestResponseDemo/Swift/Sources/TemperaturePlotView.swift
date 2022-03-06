//
//  TemperaturePlotView.swift
//  RequestResponseDemo
//
//  Created by Andrew Madsen on 3/14/15.
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

import Cocoa

@IBDesignable class TemperaturePlotView: NSView {
	
	// MARK: IBDesignable Support
	
	override func prepareForInterfaceBuilder() {
		temperatures = [17, 17, 18, 20, 23, 24, 25, 25, 24, 23, 21, 19, 18, 18, 16, 16, 17, 16, 18, 16, 17, 15, 17, 19, 25, 27, 30, 28, 23, 20, 20]
	}
	
	// MARK: Drawing
	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)
		
		NSColor(calibratedWhite: 0.82, alpha: 1.0).set()
        dirtyRect.fill()

		if temperatures.count == 0 {
			return
		}
		
		if drawsLines {
			plotColor.set()
			let linePath = NSBezierPath()
			linePath.lineWidth = 1.5
			linePath.move(to: pointForTemperatureAtIndex(0)!)
			for i in 1..<temperatures.count {
				linePath.line(to: pointForTemperatureAtIndex(i)!)
			}
			linePath.stroke()
		}
		
		if drawsPoints {
			plotColor.set()
			for i in 1..<temperatures.count {
				rectForTemperatureAtIndex(i)!.fill()
			}
		}
	}
	
	// MARK: Public
	
	func addTemperature(_ temperature: Int) {
		let maxNumTemperatures = Int(NSWidth(bounds) / 10.0)
		if temperatures.count >= maxNumTemperatures {
			temperatures.removeAll(keepingCapacity: false)
		}
		temperatures.append(temperature)
		needsDisplay = true
	}
	
	// MARK: Private
	
	func rectForTemperatureAtIndex(_ index: Int) -> NSRect? {
		let point = pointForTemperatureAtIndex(index)
		if let point = point  {
			let rectWidth: CGFloat = 5.0
			return NSRect(x: point.x - rectWidth/2.0, y: point.y - rectWidth/2.0, width: rectWidth, height: rectWidth)
		} else {
			return nil
		}
	}
	
	func pointForTemperatureAtIndex(_ index: Int) -> NSPoint? {
		if index >= temperatures.count {
			return nil
		}
		let temperature = temperatures[index]
		let scaledTemp = CGFloat(temperature - minTemperatureValue) / CGFloat(maxTemperatureValue - minTemperatureValue)
		return NSPoint(x: CGFloat(index) * 10.0, y: NSHeight(bounds) * scaledTemp)
	}
	
	// MARK: Properties
	
	// Public
	@IBInspectable var plotColor = NSColor.blue
	@IBInspectable var drawsPoints = true
	@IBInspectable var drawsLines = true
	@IBInspectable var minTemperatureValue = 0
	@IBInspectable var maxTemperatureValue = 100
	
	// Private
	fileprivate var temperatures: [Int] = []
}
