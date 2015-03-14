//
//  ORSMainViewController.m
//  RequestResponseDemo
//
//  Created by Andrew Madsen on 3/14/15.
//  Copyright (c) 2015 Open Reel Software. All rights reserved.
//

#import "ORSMainViewController.h"
#import "ORSSerialBoardController.h"
@import ORSSerial;

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
		NSLog(@"Temperature: %@", @(self.boardController.temperature));
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
