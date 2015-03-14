//
//  ORSTemperaturePlotView.h
//  RequestResponseDemo
//
//  Created by Andrew Madsen on 3/14/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

IB_DESIGNABLE @interface ORSTemperaturePlotView : NSView

- (void)addTemperature:(NSInteger)temperature;

@property (nonatomic, strong) IBInspectable NSColor *plotColor;
@property (nonatomic) IBInspectable BOOL drawsPoints;
@property (nonatomic) IBInspectable BOOL drawsLines;
@property (nonatomic) IBInspectable NSInteger minTemperatureValue;
@property (nonatomic) IBInspectable NSInteger maxTemperatureValue;

@end
