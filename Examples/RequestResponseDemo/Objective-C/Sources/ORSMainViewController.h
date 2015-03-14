//
//  ORSMainViewController.h
//  RequestResponseDemo
//
//  Created by Andrew Madsen on 3/14/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

@import Cocoa;

@class ORSSerialPortManager;
@class ORSSerialBoardController;

@interface ORSMainViewController : NSViewController

@property (nonatomic, readonly) ORSSerialPortManager *serialPortManager;
@property (nonatomic, strong, readonly) ORSSerialBoardController *boardController;

@end
