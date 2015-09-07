//
//  ORSMainViewController.m
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

#import "ORSMainViewController.h"
#import "ORSSerialBoardController.h"
@import ORSSerial;
#import "ORSTemperaturePlotView.h"

static void *ORSMainViewControllerKVOContext = &ORSMainViewControllerKVOContext;

@interface ORSMainViewController ()

@property (nonatomic, strong, readwrite) ORSSerialBoardController *boardController;

@end

@implementation ORSMainViewController

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		self.boardController = [[ORSSerialBoardController alloc] init];
	}
	return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
		self.boardController = [[ORSSerialBoardController alloc] init];
	}
	return self;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context != ORSMainViewControllerKVOContext) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}
	
	if (object == self.boardController && [keyPath isEqualToString:@"temperature"]) {
		[self.temperaturePlotView addTemperature:self.boardController.temperature];
	}
}

#pragma mark - Properties

- (ORSSerialPortManager *)serialPortManager { return [ORSSerialPortManager sharedSerialPortManager]; }

- (void)setBoardController:(ORSSerialBoardController *)boardController
{
	if (boardController != _boardController) {
		[_boardController removeObserver:self forKeyPath:@"temperature"];
		_boardController = boardController;
		[_boardController addObserver:self forKeyPath:@"temperature" options:0 context:ORSMainViewControllerKVOContext];
	}
}

@end
