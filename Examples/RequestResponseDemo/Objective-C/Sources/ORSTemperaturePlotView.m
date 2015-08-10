//
//  ORSTemperaturePlotView.m
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

#import "ORSTemperaturePlotView.h"

@interface ORSTemperaturePlotView ()

@property (nonatomic, strong) NSMutableArray *temperatures;

@end

@implementation ORSTemperaturePlotView

- (void)commonInit
{
	_temperatures = [NSMutableArray array];
	_plotColor = [NSColor blueColor];
	_drawsLines = YES;
	_drawsPoints = YES;
	_minTemperatureValue = 0;
	_maxTemperatureValue = 100;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		[self commonInit];
	}
	return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self) {
		[self commonInit];
	}
	return self;
}

#pragma mark IBDESIGNABLE Support

- (void)prepareForInterfaceBuilder
{
	self.temperatures = [@[@17, @17, @18, @20, @23, @24, @25, @25, @24, @23, @21, @19, @18, @18, @16, @16, @17, @16, @18, @16, @17, @15, @17, @19, @25, @27, @30, @28, @23, @20, @20] mutableCopy];
}

#pragma mark - Properties

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
	[[NSColor colorWithCalibratedWhite:0.82 alpha:1.0] set];
	NSRectFill(dirtyRect);
	
	if (![self.temperatures count]) return;
	
	if (self.drawsLines) {
		// Draw lines
		[self.plotColor set];
		NSBezierPath *linePath = [NSBezierPath bezierPath];
		linePath.lineWidth = 1.5;
		[linePath moveToPoint:[[self pointForTemperatureAtIndex:0] pointValue]];
		for (NSUInteger i=0; i<[self.temperatures count]; i++) {
			NSValue *pointValue = [self pointForTemperatureAtIndex:i];
			if (!pointValue) continue;
			NSPoint point = [pointValue pointValue];
			[linePath lineToPoint:point];
		}
		[linePath stroke];
	}
	
	if (self.drawsPoints) {
		// Draw points
		[self.plotColor set];
		for (NSUInteger i=0; i<[self.temperatures count]; i++) {
			NSRect temperatureRect = [self rectForTemperatureAtIndex:i];
			NSRectFill(temperatureRect);
		}
	}
}

#pragma mark - Public

- (void)addTemperature:(NSInteger)temperature
{
	NSUInteger maxNumTemperatures = (NSUInteger)(NSWidth([self bounds]) / 10.0);
	if ([self.temperatures count] >= maxNumTemperatures) {
		[self.temperatures removeAllObjects];
	}
	[self.temperatures addObject:@(temperature)];
	[self setNeedsDisplay:YES];
}

#pragma mark - Private

- (NSRect)rectForTemperatureAtIndex:(NSUInteger)index
{
	if (index >= [self.temperatures count]) return NSZeroRect;
	CGPoint point = [[self pointForTemperatureAtIndex:index] pointValue];
	if (point.x < 0) return NSZeroRect;
	CGFloat rectWidth = 5.0;
	return NSMakeRect(point.x-rectWidth/2.0, point.y-rectWidth/2.0, rectWidth, rectWidth);
}

- (NSValue *)pointForTemperatureAtIndex:(NSUInteger)index
{
	if (index >= [self.temperatures count]) return nil;
	
	NSInteger temperature = [self.temperatures[index] integerValue];
	
	CGFloat scaledTemp = (CGFloat)(temperature - self.minTemperatureValue) / (CGFloat)(self.maxTemperatureValue - self.minTemperatureValue);
	return [NSValue valueWithPoint:NSMakePoint(index * 10.0, NSHeight([self bounds]) * scaledTemp)];
}

#pragma mark - Properties

- (void)setMinTemperatureValue:(NSInteger)minTemperatureValue
{
	if (minTemperatureValue != _minTemperatureValue) {
		_minTemperatureValue = minTemperatureValue;
		[self setNeedsDisplay:YES];
	}
}

- (void)setMaxTemperatureValue:(NSInteger)maxTemperatureValue
{
	if (maxTemperatureValue != _maxTemperatureValue) {
		_maxTemperatureValue = maxTemperatureValue;
		[self setNeedsDisplay:YES];
	}
}

@end
