//
//  ORSSerialPort.m
//  ORSSerialPort
//
//  Created by Andrew R. Madsen on 08/6/11.
//	Copyright (c) 2011-2014 Andrew R. Madsen (andrew@openreelsoftware.com)
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

#import "ORSSerialPort.h"
#import "ORSSerialRequest.h"
#import <IOKit/serial/IOSerialKeys.h>
#import <IOKit/serial/ioss.h>
#import <sys/param.h>
#import <sys/filio.h>
#import <sys/ioctl.h>

#if !__has_feature(objc_arc)
#error ORSSerialPort.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for ORSSerialPort.m in the Build Phases for this target
#endif

#if OS_OBJECT_USE_OBJC && __has_feature(objc_arc)
#define ORS_GCD_RELEASE(x)
#define ORS_GCD_RETAIN(x)
#else
#define ORS_GCD_RELEASE(x) if (x) { dispatch_release(x); }
#define ORS_GCD_RETAIN(x) if (x) { dispatch_retain(x); }
#endif

#ifdef LOG_SERIAL_PORT_ERRORS
#define LOG_SERIAL_PORT_ERROR(fmt, ...) NSLog(fmt, ## __VA_ARGS__)
#else
#define LOG_SERIAL_PORT_ERROR(fmt, ...)
#endif

static __strong NSMutableArray *allSerialPorts;

@interface ORSSerialPort ()
{
	struct termios originalPortAttributes;
}

@property (copy, readwrite) NSString *path;
@property (readwrite) io_object_t IOKitDevice;
@property int fileDescriptor;
@property (copy, readwrite) NSString *name;

@property (strong) NSMutableData *receiveBuffer;

// Request handling
@property (nonatomic, strong) NSMutableArray *requestsQueue;
@property (nonatomic, strong, readwrite) ORSSerialRequest *pendingRequest;

@property (nonatomic, readwrite) BOOL CTS;
@property (nonatomic, readwrite) BOOL DSR;
@property (nonatomic, readwrite) BOOL DCD;

#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong) dispatch_source_t pinPollTimer;
@property (nonatomic, strong) dispatch_source_t pendingRequestTimeoutTimer;
@property (nonatomic, strong) dispatch_queue_t requestHandlingQueue;
@property (nonatomic, strong) dispatch_semaphore_t selectSemaphore;
#else
@property (nonatomic) dispatch_source_t pinPollTimer;
@property (nonatomic) dispatch_source_t pendingRequestTimeoutTimer;
@property (nonatomic) dispatch_queue_t requestHandlingQueue;
@property (nonatomic) dispatch_semaphore_t selectSemaphore;
#endif

@end

@implementation ORSSerialPort

+ (void)initialize
{
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		allSerialPorts = [[NSMutableArray alloc] init];
	});
}

+ (void)addSerialPort:(ORSSerialPort *)port;
{
	[allSerialPorts addObject:[NSValue valueWithNonretainedObject:port]];
}

+ (void)removeSerialPort:(ORSSerialPort *)port;
{
	NSValue *valueToRemove = nil;
	for (NSValue *value in allSerialPorts)
	{
		if ([value nonretainedObjectValue] == port)
		{
			valueToRemove = value;
			break;
		}
	}
	if (valueToRemove) [allSerialPorts removeObject:valueToRemove];
}

+ (ORSSerialPort *)existingPortWithPath:(NSString *)path;
{
	ORSSerialPort *existingPort = nil;
	for (NSValue *value in allSerialPorts)
	{
		ORSSerialPort *port = [value nonretainedObjectValue];
		if ([port.path isEqualToString:path])
		{
			existingPort = port;
			break;
		}
	}
	
	return existingPort;
}

+ (ORSSerialPort *)serialPortWithPath:(NSString *)devicePath
{
	return [[self alloc] initWithPath:devicePath];
}

+ (ORSSerialPort *)serialPortWithDevice:(io_object_t)device;
{
	return [[self alloc] initWithDevice:device];
}

- (instancetype)initWithPath:(NSString *)devicePath
{
	io_object_t device = [[self class] deviceFromBSDPath:devicePath];
	if (device == 0) return nil;
	
	return [self initWithDevice:device];
}

- (instancetype)initWithDevice:(io_object_t)device;
{
	NSAssert(device != 0, @"%s requires non-zero device argument.", __PRETTY_FUNCTION__);
	
	NSString *bsdPath = [[self class] bsdCalloutPathFromDevice:device];
	ORSSerialPort *existingPort = [[self class] existingPortWithPath:bsdPath];
	
	if (existingPort != nil)
	{
		self = nil;
		return existingPort;
	}
	
	self = [super init];
	
	if (self != nil)
	{
		self.ioKitDevice = device;
		self.path = bsdPath;
		self.name = [[self class] modemNameFromDevice:device];
		self.receiveBuffer = [NSMutableData data];
		self.requestHandlingQueue = dispatch_queue_create("com.openreelsoftware.ORSSerialPort.requestHandlingQueue", 0);
		self.requestsQueue = [NSMutableArray array];
		self.selectSemaphore = dispatch_semaphore_create(1);
		self.baudRate = @B19200;
		self.numberOfStopBits = 1;
		self.parity = ORSSerialPortParityNone;
		self.shouldEchoReceivedData = NO;
		self.usesRTSCTSFlowControl = NO;
		self.usesDTRDSRFlowControl = NO;
		self.usesDCDOutputFlowControl = NO;
		self.RTS = NO;
		self.DTR = NO;
	}
	
	[[self class] addSerialPort:self];
	
	return self;
}

- (instancetype)init
{
	self = [self initWithPath:nil]; // To keep compiler happy.
	NSAssert(0, @"ORSSerialPort must be init'd using -initWithPath:");
	return self;
}

- (void)dealloc
{
	[[self class] removeSerialPort:self];
	self.IOKitDevice = 0;
	
	if (_pinPollTimer) {
		dispatch_source_cancel(_pinPollTimer);
		ORS_GCD_RELEASE(_pinPollTimer);
	}
	
	self.requestHandlingQueue = nil;
	self.selectSemaphore = nil;
}

- (NSString *)description
{
	return self.name;
	//	io_object_t device = [[self class] deviceFromBSDPath:self.path];
	//	return [NSString stringWithFormat:@"BSD Path:%@, base name:%@, modem name:%@, suffix:%@, service type:%@", [[self class] bsdCalloutPathFromDevice:device], [[self class] baseNameFromDevice:device], [[self class] modemNameFromDevice:device], [[self class] suffixFromDevice:device], [[self class] serviceTypeFromDevice:device]];
}

- (NSUInteger)hash
{
	return [self.path hash];
}

- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:[self class]]) return NO;
	if (![object respondsToSelector:@selector(path)]) return NO;
	
	return [self.path isEqual:[object path]];
}

#pragma mark - Public Methods

- (void)open;
{
	if (self.isOpen) return;
	
	dispatch_queue_t mainQueue = dispatch_get_main_queue();
	
	int descriptor=0;
	descriptor = open([self.path cStringUsingEncoding:NSASCIIStringEncoding], O_RDWR | O_NOCTTY | O_EXLOCK | O_NONBLOCK);
	if (descriptor < 1)
	{
		// Error
		[self notifyDelegateOfPosixError];
		return;
	}
	
	// Now that the device is open, clear the O_NONBLOCK flag so subsequent I/O will block.
	// See fcntl(2) ("man 2 fcntl") for details.
	
	if (fcntl(descriptor, F_SETFL, 0) == -1)
	{
		LOG_SERIAL_PORT_ERROR(@"Error clearing O_NONBLOCK %@ - %s(%d).\n", self.path, strerror(errno), errno);
	}
	
	self.fileDescriptor = descriptor;
	
	// Port opened successfully, set options
	tcgetattr(descriptor, &originalPortAttributes); // Get original options so they can be reset later
	[self setPortOptions];
	
	// Get status of RTS and DTR lines
	int modemLines=0;
	if (ioctl(self.fileDescriptor, TIOCMGET, &modemLines) < 0)
	{
		LOG_SERIAL_PORT_ERROR(@"Error reading modem lines status");
		[self notifyDelegateOfPosixError];
	}
	
	BOOL desiredRTS = self.RTS;
	BOOL desiredDTR = self.DTR;
	self.RTS = modemLines & TIOCM_RTS;
	self.DTR = modemLines & TIOCM_DTR;
	self.RTS = desiredRTS;
	self.DTR = desiredDTR;
	
	if ([self.delegate respondsToSelector:@selector(serialPortWasOpened:)])
	{
		dispatch_async(mainQueue, ^{
			[self.delegate serialPortWasOpened:self];
		});
	}
	
	// Start a read poller in the background
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		int localPortFD = self.fileDescriptor;
		struct timeval timeout;
		int result=0;
		
		while (self.isOpen)
		{
			fd_set localReadFDSet;
			FD_ZERO(&localReadFDSet);
			FD_SET(localPortFD, &localReadFDSet);
			
			timeout.tv_sec = 0;
			timeout.tv_usec = 100000; // Check to see if port closed every 100ms
			
			dispatch_semaphore_wait(self.selectSemaphore, DISPATCH_TIME_FOREVER);
			result = select(localPortFD+1, &localReadFDSet, NULL, NULL, &timeout);
			dispatch_semaphore_signal(self.selectSemaphore);
			if (!self.isOpen) break; // Port closed while select call was waiting
			if (result < 0)
			{
				[self notifyDelegateOfPosixError];
				continue;
			}
			
			if (result == 0 || !FD_ISSET(localPortFD, &localReadFDSet)) continue;
			
			// Data is available
			char buf[1024];
			long lengthRead = read(localPortFD, buf, sizeof(buf));
			if (lengthRead>0)
			{
				NSData *readData = [NSData dataWithBytes:buf length:lengthRead];
				if (readData != nil) [self receiveData:readData];
			}
		}
	});
	
	// Start another poller to check status of CTS and DSR
	dispatch_queue_t pollQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, pollQueue);
	dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), 10*NSEC_PER_MSEC, 5*NSEC_PER_MSEC);
	dispatch_source_set_event_handler(timer, ^{
		if (!self.isOpen) {
			dispatch_async(pollQueue, ^{ dispatch_source_cancel(timer); });
			return;
		}
		
		int32_t modemLines=0;
		int result = ioctl(self.fileDescriptor, TIOCMGET, &modemLines);
		if (result < 0)
		{
			[self notifyDelegateOfPosixErrorWaitingUntilDone:(errno == ENXIO)];
			if (errno == ENXIO)
			{
				[self cleanupAfterSystemRemoval];
			}
			return;
		}
		
		BOOL CTSPin = (modemLines & TIOCM_CTS) != 0;
		BOOL DSRPin = (modemLines & TIOCM_DSR) != 0;
		BOOL DCDPin = (modemLines & TIOCM_CAR) != 0;
		
		if (CTSPin != self.CTS)
			dispatch_sync(mainQueue, ^{self.CTS = CTSPin;});
		if (DSRPin != self.DSR)
			dispatch_sync(mainQueue, ^{self.DSR = DSRPin;});
		if (DCDPin != self.DCD)
			dispatch_sync(mainQueue, ^{self.DCD = DCDPin;});
	});
	self.pinPollTimer = timer;
	dispatch_resume(self.pinPollTimer);
	ORS_GCD_RELEASE(timer);
}

- (BOOL)close;
{
	if (!self.isOpen) return YES;
	
	self.pinPollTimer = nil; // Stop polling CTS/DSR/DCD pins
	
	dispatch_semaphore_wait(self.selectSemaphore, DISPATCH_TIME_FOREVER);
	// The next tcsetattr() call can fail if the port is waiting to send data. This is likely to happen
	// e.g. if flow control is on and the CTS line is low. So, turn off flow control before proceeding
	struct termios options;
	tcgetattr(self.fileDescriptor, &options);
	options.c_cflag &= ~CRTSCTS; // RTS/CTS Flow Control
	options.c_cflag &= ~(CDTR_IFLOW | CDSR_OFLOW); // DTR/DSR Flow Control
	options.c_cflag &= ~CCAR_OFLOW; // DCD Flow Control
	tcsetattr(self.fileDescriptor, TCSANOW, &options);
	
	// Set port back the way it was before we used it
	tcsetattr(self.fileDescriptor, TCSADRAIN, &originalPortAttributes);
	
	int localFD = self.fileDescriptor;
	self.fileDescriptor = 0; // So other threads know that the port should be closed and can stop I/O operations
	
	if (close(localFD))
	{
		self.fileDescriptor = localFD;
		LOG_SERIAL_PORT_ERROR(@"Error closing serial port with file descriptor %i:%i", self.fileDescriptor, errno);
		[self notifyDelegateOfPosixError];
		return NO;
	}
	dispatch_semaphore_signal(self.selectSemaphore);
	
	if ([self.delegate respondsToSelector:@selector(serialPortWasClosed:)])
	{
		[(id)self.delegate performSelectorOnMainThread:@selector(serialPortWasClosed:) withObject:self waitUntilDone:YES];
		dispatch_async(self.requestHandlingQueue, ^{
			self.requestsQueue = [NSMutableArray array]; // Cancel all queued requests
			self.pendingRequest = nil; // Discard pending request
		});
	}
	return YES;
}

- (void)cleanup;
{
	NSLog(@"WARNING: Cleanup is deprecated and was never intended to be called publicly. You should update your code to avoid calling this method.");
	[self cleanupAfterSystemRemoval];
}

- (void)cleanupAfterSystemRemoval
{
	if ([self.delegate respondsToSelector:@selector(serialPortWasRemovedFromSystem:)])
	{
		[(id)self.delegate performSelectorOnMainThread:@selector(serialPortWasRemovedFromSystem:) withObject:self waitUntilDone:YES];
	}
	[self close];
}

- (BOOL)sendData:(NSData *)data;
{
	if (!self.isOpen) return NO;
	if ([data length] == 0) return YES;
	
	NSMutableData *writeBuffer = [data mutableCopy];
	while ([writeBuffer length] > 0)
	{
		long numBytesWritten = write(self.fileDescriptor, [writeBuffer bytes], [writeBuffer length]);
		if (numBytesWritten < 0)
		{
			LOG_SERIAL_PORT_ERROR(@"Error writing to serial port:%d", errno);
			[self notifyDelegateOfPosixError];
			return NO;
		}
		else if (numBytesWritten > 0)
		{
			[writeBuffer replaceBytesInRange:NSMakeRange(0, numBytesWritten) withBytes:NULL length:0];
		}
	}
	
	return YES;
}

- (BOOL)sendRequest:(ORSSerialRequest *)request
{
	__block BOOL success = NO;
	dispatch_sync(self.requestHandlingQueue, ^{
		success = [self reallySendRequest:request];
	});
	return success;
}

#pragma mark - Private Methods

// Must only be called on requestHandlingQueue (ie. wrap call to this method in dispatch())
- (BOOL)reallySendRequest:(ORSSerialRequest *)request
{
	if (!self.pendingRequest)
	{
		[self.receiveBuffer replaceBytesInRange:NSMakeRange(0, [self.receiveBuffer length])
									  withBytes:NULL
										 length:0];
		
		// Send immediately
		self.pendingRequest = request;
		if (request.timeoutInterval > 0) {
			NSTimeInterval timeoutInterval = request.timeoutInterval;
			dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.requestHandlingQueue);
			dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, timeoutInterval * NSEC_PER_SEC), timeoutInterval * NSEC_PER_SEC, timeoutInterval/10.0 * NSEC_PER_SEC);
			dispatch_source_set_event_handler(timer, ^{ [self pendingRequestDidTimeout]; });
			self.pendingRequestTimeoutTimer = timer;
			dispatch_resume(self.pendingRequestTimeoutTimer);
		}
		BOOL success = [self sendData:request.dataToSend];
		// Immediately send next request if this one doesn't require a response
		if (success) [self checkResponseToPendingRequestAndContinueIfValid];
		return success;
	}
	
	// Queue it up to be sent after the pending request is responded to, or times out.
	[self insertObject:request inRequestsQueueAtIndex:[self.requestsQueue count]];
	return YES;
}

// Must only be called on requestHandlingQueue
- (void)sendNextRequest
{
	self.pendingRequest = nil;
	if (![self.requestsQueue count]) return;
	ORSSerialRequest *nextRequest = self.requestsQueue[0];
	[self removeObjectFromRequestsQueueAtIndex:0];
	[self reallySendRequest:nextRequest];
}

// Will only be called on requestHandlingQueue
- (void)pendingRequestDidTimeout
{
	self.pendingRequestTimeoutTimer = nil;
	
	ORSSerialRequest *request = self.pendingRequest;
	
	if (![self.delegate respondsToSelector:@selector(serialPort:requestDidTimeout:)])
	{
		[self sendNextRequest];
		return;
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.delegate serialPort:self requestDidTimeout:request];
		dispatch_async(self.requestHandlingQueue, ^{
			[self sendNextRequest];
		});
	});
}

// Must only be called on requestHandlingQueue
- (void)checkResponseToPendingRequestAndContinueIfValid
{
	NSData *responseData = [self.receiveBuffer copy];
	if (![self.pendingRequest dataIsValidResponse:responseData]) return;
	
	self.pendingRequestTimeoutTimer = nil;
	ORSSerialRequest *request = self.pendingRequest;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		if ([responseData length] &&
			[self.delegate respondsToSelector:@selector(serialPort:didReceiveResponse:toRequest:)])
		{
			[self.delegate serialPort:self didReceiveResponse:responseData toRequest:request];
		}
	});
	
	[self sendNextRequest];
}

#pragma mark Port Read/Write

- (void)receiveData:(NSData *)data;
{
	if ([self.delegate respondsToSelector:@selector(serialPort:didReceiveData:)])
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.delegate serialPort:self didReceiveData:data];
		});
	}
	
	dispatch_async(self.requestHandlingQueue, ^{
		[self.receiveBuffer appendData:data];
		[self checkResponseToPendingRequestAndContinueIfValid];
	});
}

#pragma mark Port Propeties Methods

- (void)setPortOptions;
{
	if ([self fileDescriptor] < 1) return;
	
	struct termios options;
	
	tcgetattr(self.fileDescriptor, &options);
	
	cfmakeraw(&options);
	options.c_cc[VMIN] = 1; // Wait for at least 1 character before returning
	options.c_cc[VTIME] = 2; // Wait 200 milliseconds between bytes before returning from read
	
	// Set 8 data bits
	options.c_cflag &= ~CSIZE;
	options.c_cflag |= CS8;
	
	// Set parity
	switch (self.parity) {
		case ORSSerialPortParityNone:
			options.c_cflag &= ~PARENB;
			break;
		case ORSSerialPortParityEven:
			options.c_cflag |= PARENB;
			options.c_cflag &= ~PARODD;
			break;
		case ORSSerialPortParityOdd:
			options.c_cflag |= PARENB;
			options.c_cflag |= PARODD;
			break;
		default:
			break;
	}
	
	options.c_cflag = [self numberOfStopBits] > 1 ? options.c_cflag | CSTOPB : options.c_cflag & ~CSTOPB; // number of stop bits
	options.c_lflag = [self shouldEchoReceivedData] ? options.c_lflag | ECHO : options.c_lflag & ~ECHO; // echo
	options.c_cflag = [self usesRTSCTSFlowControl] ? options.c_cflag | CRTSCTS : options.c_cflag & ~CRTSCTS; // RTS/CTS Flow Control
	options.c_cflag = [self usesDTRDSRFlowControl] ? options.c_cflag | (CDTR_IFLOW | CDSR_OFLOW) : options.c_cflag & ~(CDTR_IFLOW | CDSR_OFLOW); // DTR/DSR Flow Control
	options.c_cflag = [self usesDCDOutputFlowControl] ? options.c_cflag | CCAR_OFLOW : options.c_cflag & ~CCAR_OFLOW; // DCD Flow Control
	
	options.c_cflag |= HUPCL; // Turn on hangup on close
	options.c_cflag |= CLOCAL; // Set local mode on
	options.c_cflag |= CREAD; // Enable receiver
	options.c_lflag &= ~(ICANON /*| ECHO*/ | ISIG); // Turn off canonical mode and signals
	
	// Set baud rate
	cfsetspeed(&options, [[self baudRate] unsignedLongValue]);
	
	int result = tcsetattr(self.fileDescriptor, TCSANOW, &options);
    if (result != 0) {
        // Try to set baud rate via ioctl if normal port settings fail
        int new_baud = [[self baudRate] intValue];
        result = ioctl(self.fileDescriptor, IOSSIOSPEED, &new_baud, 1);
        if (result == -1) {
            // Notify delegate of port error stored in errno
            [self notifyDelegateOfPosixError];
        }
    }
}

+ (io_object_t)deviceFromBSDPath:(NSString *)bsdPath;
{
	if ([bsdPath length] < 1) return 0;
	
	CFMutableDictionaryRef matchingDict = NULL;
	
	matchingDict = IOServiceMatching(kIOSerialBSDServiceValue);
	CFRetain(matchingDict); // Need to use it twice
	
	CFDictionaryAddValue(matchingDict, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDAllTypes));
	
	io_iterator_t portIterator = 0;
	kern_return_t err = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &portIterator);
	CFRelease(matchingDict);
	if (err) return 0;
	
	io_object_t eachPort = 0;
	io_object_t result = 0;
	while ((eachPort = IOIteratorNext(portIterator)))
	{
		NSString *calloutPath = [self bsdCalloutPathFromDevice:eachPort];
		NSString *dialinPath = [self bsdDialinPathFromDevice:eachPort];
		if ([bsdPath isEqualToString:calloutPath] ||
			[bsdPath isEqualToString:dialinPath])
		{
			result = eachPort;
			break;
		}
		IOObjectRelease(eachPort);
	}
	IOObjectRelease(portIterator);
	
	return result;
}

+ (NSString *)stringPropertyOf:(io_object_t)aDevice forIOSerialKey:(NSString *)key;
{
	CFStringRef string = (CFStringRef)IORegistryEntryCreateCFProperty(aDevice,
																	  (__bridge CFStringRef)key,
																	  kCFAllocatorDefault,
																	  0);
	return (__bridge_transfer NSString *)string;
}

+ (NSString *)bsdCalloutPathFromDevice:(io_object_t)aDevice;
{
	return [self stringPropertyOf:aDevice forIOSerialKey:(NSString*)CFSTR(kIOCalloutDeviceKey)];
}

+ (NSString *)bsdDialinPathFromDevice:(io_object_t)aDevice;
{
	return [self stringPropertyOf:aDevice forIOSerialKey:(NSString*)CFSTR(kIODialinDeviceKey)];
}

+ (NSString *)baseNameFromDevice:(io_object_t)aDevice;
{
	return [self stringPropertyOf:aDevice forIOSerialKey:(NSString*)CFSTR(kIOTTYBaseNameKey)];
}

+ (NSString *)serviceTypeFromDevice:(io_object_t)aDevice;
{
	return [self stringPropertyOf:aDevice forIOSerialKey:(NSString*)CFSTR(kIOSerialBSDTypeKey)];
}

+ (NSString *)modemNameFromDevice:(io_object_t)aDevice;
{
	return [self stringPropertyOf:aDevice forIOSerialKey:(NSString*)CFSTR(kIOTTYDeviceKey)];
}

+ (NSString *)suffixFromDevice:(io_object_t)aDevice;
{
	return [self stringPropertyOf:aDevice forIOSerialKey:(NSString*)CFSTR(kIOTTYSuffixKey)];
}

#pragma mark Helper Methods

- (void)notifyDelegateOfPosixError
{
	[self notifyDelegateOfPosixErrorWaitingUntilDone:NO];
}

- (void)notifyDelegateOfPosixErrorWaitingUntilDone:(BOOL)shouldWait;
{
	if (![self.delegate respondsToSelector:@selector(serialPort:didEncounterError:)]) return;
	
	NSDictionary *errDict = @{NSLocalizedDescriptionKey: @(strerror(errno)),
							  NSFilePathErrorKey: self.path};
	NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain
										 code:errno
									 userInfo:errDict];
	
	void (^notifyBlock)(void) = ^{
		[self.delegate serialPort:self didEncounterError:error];
	};
	
	if ([NSThread isMainThread]) {
		notifyBlock();
	} else if (shouldWait) {
		dispatch_sync(dispatch_get_main_queue(), notifyBlock);
	} else {
		dispatch_async(dispatch_get_main_queue(), notifyBlock);
	}
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	if ([key isEqualToString:@"isOpen"])
	{
		keyPaths = [keyPaths setByAddingObject:@"fileDescriptor"];
	}
	
	if ([key isEqualToString:@"queuedRequests"]) {
		keyPaths = [keyPaths setByAddingObject:@"requestsQueue"];
	}
	
	return keyPaths;
}

#pragma mark Port Properties

- (void)insertObject:(ORSSerialRequest *)request inRequestsQueueAtIndex:(NSUInteger)index
{
	[self.requestsQueue insertObject:request atIndex:index];
}

- (void)removeObjectFromRequestsQueueAtIndex:(NSUInteger)index
{
	[self.requestsQueue removeObjectAtIndex:index];
}

- (NSArray *)queuedRequests
{
	return [self.requestsQueue copy];
}

- (BOOL)isOpen { return self.fileDescriptor != 0; }

- (void)setIoKitDevice:(io_object_t)device
{
	if (device != _IOKitDevice) {
		if (_IOKitDevice) IOObjectRelease(_IOKitDevice);
		_IOKitDevice = device;
		if (_IOKitDevice) IOObjectRetain(_IOKitDevice);
	}
}

- (void)setBaudRate:(NSNumber *)rate
{
	if (rate != _baudRate)
	{
		_baudRate = [rate copy];
		
		[self setPortOptions];
	}
}

- (void)setNumberOfStopBits:(NSUInteger)num
{
	if (num != _numberOfStopBits)
	{
		_numberOfStopBits = num;
		[self setPortOptions];
	}
}

- (void)setShouldEchoReceivedData:(BOOL)flag
{
	if (flag != _shouldEchoReceivedData)
	{
		_shouldEchoReceivedData = flag;
		[self setPortOptions];
	}
}

- (void)setParity:(ORSSerialPortParity)aParity
{
	if (aParity != _parity)
	{
		if (aParity != ORSSerialPortParityNone &&
			aParity != ORSSerialPortParityOdd &&
			aParity != ORSSerialPortParityEven)
		{
			aParity = ORSSerialPortParityNone;
		}
		
		_parity = aParity;
		[self setPortOptions];
	}
}

- (void)setUsesRTSCTSFlowControl:(BOOL)flag
{
	if (flag != _usesRTSCTSFlowControl)
	{
		// Turning flow control one while the port is open doesn't seem to work right,
		// at least with some drivers, so close it then reopen it if needed
		BOOL shouldReopen = self.isOpen;
		[self close];
		
		_usesRTSCTSFlowControl = flag;
		
		[self setPortOptions];
		if (shouldReopen) [self open];
	}
}

- (void)setUsesDTRDSRFlowControl:(BOOL)flag
{
	if (flag != _usesDTRDSRFlowControl)
	{
		// Turning flow control one while the port is open doesn't seem to work right,
		// at least with some drivers, so close it then reopen it if needed
		BOOL shouldReopen = self.isOpen;
		[self close];
		
		_usesDTRDSRFlowControl = flag;
		[self setPortOptions];
		if (shouldReopen) [self open];
	}
}

- (void)setUsesDCDOutputFlowControl:(BOOL)flag
{
	if (flag != _usesDCDOutputFlowControl)
	{
		// Turning flow control one while the port is open doesn't seem to work right,
		// at least with some drivers, so close it then reopen it if needed
		BOOL shouldReopen = self.isOpen;
		[self close];
		
		_usesDCDOutputFlowControl = flag;
		
		[self setPortOptions];
		if (shouldReopen) [self open];
	}
}

- (void)setRTS:(BOOL)flag
{
	if (flag != _RTS)
	{
		_RTS = flag;
		
		if (![self isOpen]) return;
		
		int bits;
		ioctl( self.fileDescriptor, TIOCMGET, &bits ) ;
		bits = _RTS ? bits | TIOCM_RTS : bits & ~TIOCM_RTS;
		if (ioctl( self.fileDescriptor, TIOCMSET, &bits ) < 0)
		{
			LOG_SERIAL_PORT_ERROR(@"Error in %s", __PRETTY_FUNCTION__);
			[self notifyDelegateOfPosixError];
		}
	}
}

- (void)setDTR:(BOOL)flag
{
	if (flag != _DTR)
	{
		_DTR = flag;
		
		if (![self isOpen]) return;
		
		int bits;
		ioctl( self.fileDescriptor, TIOCMGET, &bits ) ;
		bits = _DTR ? bits | TIOCM_DTR : bits & ~TIOCM_DTR;
		if (ioctl( self.fileDescriptor, TIOCMSET, &bits ) < 0)
		{
			LOG_SERIAL_PORT_ERROR(@"Error in %s", __PRETTY_FUNCTION__);
			[self notifyDelegateOfPosixError];
		}
	}
}

#pragma mark Private Properties

- (void)setPinPollTimer:(dispatch_source_t)timer
{
	if (timer != _pinPollTimer)
	{
		if (_pinPollTimer)
		{
			dispatch_source_cancel(_pinPollTimer);
			ORS_GCD_RELEASE(_pinPollTimer);
		}
		
		ORS_GCD_RETAIN(timer);
		_pinPollTimer = timer;
	}
}

- (void)setPendingRequestTimeoutTimer:(dispatch_source_t)pendingRequestTimeoutTimer
{
	if (pendingRequestTimeoutTimer != _pendingRequestTimeoutTimer) {
		if (_pendingRequestTimeoutTimer) {
			dispatch_source_cancel(_pendingRequestTimeoutTimer);
			ORS_GCD_RELEASE(_pendingRequestTimeoutTimer);
		}
		
		ORS_GCD_RETAIN(pendingRequestTimeoutTimer);
		_pendingRequestTimeoutTimer = pendingRequestTimeoutTimer;
	}
}

- (void)setRequestHandlingQueue:(dispatch_queue_t)requestHandlingQueue
{
	if (requestHandlingQueue != _requestHandlingQueue)
	{
		ORS_GCD_RELEASE(_requestHandlingQueue);
		ORS_GCD_RETAIN(requestHandlingQueue);
		_requestHandlingQueue = requestHandlingQueue;
	}
}

- (void)setSelectSemaphore:(dispatch_semaphore_t)selectSemaphore
{
	if (selectSemaphore != _selectSemaphore) {
		ORS_GCD_RELEASE(_selectSemaphore);
		ORS_GCD_RETAIN(selectSemaphore);
		_selectSemaphore = selectSemaphore;
	}
}

@end
