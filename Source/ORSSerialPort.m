//
//  ORSSerialPort.m
//  Aether
//
//  Created by Andrew R. Madsen on 08/6/11.
//	Copyright (c) 2011-2012 Andrew R. Madsen (andrew@openreelsoftware.com)
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
	
#if !__has_feature(objc_arc)
	#error ORSSerialPort.m must be compiled with ARC. Either turn on ARC for the project or set the -fobjc-arc flag for ORSSerialPort.m in the Build Phases for this target
#endif

#if OS_OBJECT_HAVE_OBJC_SUPPORT && __has_feature(objc_arc)
	#define ORS_GCD_RELEASE(x)
	#define ORS_GCD_RETAIN(x)
#else
	#define ORS_GCD_RELEASE(x) dispatch_release(x)
	#define ORS_GCD_RETAIN(x) dispatch_retain(x)
#endif

#import "ORSSerialPort.h"
#import <IOKit/serial/IOSerialKeys.h>
#import <IOKit/serial/ioss.h>
#import <sys/param.h>
#import <sys/filio.h>
#import <sys/ioctl.h>

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

+ (void)addSerialPort:(ORSSerialPort *)port;
+ (void)removeSerialPort:(ORSSerialPort *)port;
+ (ORSSerialPort *)existingPortWithPath:(NSString *)path;

- (void)receiveData:(NSData *)data;

- (void)setPortOptions;
+ (io_object_t)deviceFromBSDPath:(NSString *)bsdPath;
+ (NSString *)stringPropertyOf:(io_object_t)aDevice forIOSerialKey:(NSString *)key;
+ (NSString *)bsdCalloutPathFromDevice:(io_object_t)aDevice;
+ (NSString *)bsdDialinPathFromDevice:(io_object_t)aDevice;
+ (NSString *)baseNameFromDevice:(io_object_t)aDevice;
+ (NSString *)serviceTypeFromDevice:(io_object_t)aDevice;
+ (NSString *)modemNameFromDevice:(io_object_t)aDevice;
+ (NSString *)suffixFromDevice:(io_object_t)aDevice;

- (void)notifyDelegateOfPosixError;

@property (nonatomic, readwrite) io_object_t device;

@property (copy, readwrite) NSString *path;
@property (copy, readwrite) NSString *name;

@property (strong) NSMutableData *writeBuffer;
@property int fileDescriptor;

@property (nonatomic, readwrite) BOOL CTS;
@property (nonatomic, readwrite) BOOL DSR;
@property (nonatomic, readwrite) BOOL DCD;

#if OS_OBJECT_HAVE_OBJC_SUPPORT
@property (nonatomic, strong) dispatch_source_t pinPollTimer;
#else
@property (nonatomic) dispatch_source_t pinPollTimer;
#endif

@end

@implementation ORSSerialPort

+ (void)initialize
{
	allSerialPorts = [[NSMutableArray alloc] init];
}

+ (void)addSerialPort:(ORSSerialPort *)port;
{
	NSValue *value = [NSValue valueWithNonretainedObject:port];
	[allSerialPorts addObject:value];
}

+ (void)removeSerialPort:(ORSSerialPort *)port;
{
	NSValue *valueToRemove = nil;
	for (NSValue *value in allSerialPorts) 
	{
		if ([value nonretainedObjectValue] == port) 
		{
			valueToRemove = value;
		}
	}
	if (valueToRemove != nil) [allSerialPorts removeObject:valueToRemove];
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

- (id)initWithPath:(NSString *)devicePath
{
 	io_object_t device = [[self class] deviceFromBSDPath:devicePath];
 	if (device == 0) 
 	{
 		self = nil;
 		return self;
 	}
 	
 	return [self initWithDevice:device];
}

- (id)initWithDevice:(io_object_t)device;
{
	NSAssert(device != 0, @"%s requires non-zero device argument.", __PRETTY_FUNCTION__);
	
	NSString *bsdPath = [[self class] bsdCalloutPathFromDevice:device];
	ORSSerialPort *existingPort = [[self class] existingPortWithPath:bsdPath];
	
	if (existingPort != nil)
	{
		self = nil;
        // the raw device object changes even when its paths do not
        if (device != existingPort.device) existingPort.device = device;
		return existingPort;
	}
	
	self = [super init];
	
	if (self != nil)
	{
        IOObjectRetain(device);
        self.device = device;
		self.path = bsdPath;
		self.name = [[self class] modemNameFromDevice:device];
		self.writeBuffer = [NSMutableData data];
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

- (id)init
{
    NSAssert(0, @"ORSSerialPort must be init'd using -initWithPath:");
	return nil;
}

- (void)dealloc
{
	[[self class] removeSerialPort:self];
	IOObjectRelease(_device);

	if (_pinPollTimer) {
		
		dispatch_source_cancel(_pinPollTimer);
		ORS_GCD_RELEASE(_pinPollTimer);
	}
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
		dispatch_async(mainQueue,  ^{ [self notifyDelegateOfPosixError]; });
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
		dispatch_async(mainQueue, ^{[self notifyDelegateOfPosixError];});
	}
	
	BOOL desiredRTS = self.RTS;
	BOOL desiredDTR = self.DTR;
	self.RTS = modemLines & TIOCM_RTS;
	self.DTR = modemLines & TIOCM_DTR;
	self.RTS = desiredRTS;
	self.DTR = desiredDTR;
	
	dispatch_async(mainQueue, ^{
		if ([(id)self.delegate respondsToSelector:@selector(serialPortWasOpened:)])
		{
			[self.delegate serialPortWasOpened:self];
		}
	});
	
	// Start a read poller in the background
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		int localPortFD = self.fileDescriptor;
		struct timeval timeout;
		int result=0;
		
		while (self.isOpen) 
		{
			fd_set localReadFDSet;
			FD_ZERO(&localReadFDSet);
			FD_SET(descriptor, &localReadFDSet);

			timeout.tv_sec = 0; 
			timeout.tv_usec = 100000; // Check to see if port closed every 100ms
			
			result = select(localPortFD+1, &localReadFDSet, NULL, NULL, &timeout);
			if (!self.isOpen) break; // Port closed while select call was waiting
			if (result < 0) 
			{
				dispatch_sync(mainQueue, ^{[self notifyDelegateOfPosixError];});
				continue;
			}
			
			if (result == 0 || !FD_ISSET(localPortFD, &localReadFDSet)) continue;
			
			// Data is available
			char buf[1024];
			long lengthRead = read(localPortFD, buf, sizeof(buf));
			if (lengthRead>0)
			{
				NSData *readData = [NSData dataWithBytes:buf length:lengthRead];
				if (readData != nil) dispatch_async(dispatch_get_main_queue(), ^{
					[self receiveData:readData];
				});
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
		if (ioctl(self.fileDescriptor, TIOCMGET, &modemLines) < 0)
		{
			dispatch_sync(mainQueue, ^{[self notifyDelegateOfPosixError];});
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
	
	[self.writeBuffer replaceBytesInRange:NSMakeRange(0, [self.writeBuffer length]) withBytes:NULL length:0];
	
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
		return NO;
	}
	
	if ([(id)self.delegate respondsToSelector:@selector(serialPortWasClosed:)])
	{
		[self.delegate serialPortWasClosed:self];
	}
	return YES;
}

- (void)cleanup;
{
	[self close];
	if ([(id)self.delegate respondsToSelector:@selector(serialPortWasRemovedFromSystem:)])
	{
		[self.delegate serialPortWasRemovedFromSystem:self];
	}
}

- (BOOL)sendData:(NSData *)data;
{
	if (!self.isOpen) return NO;
	
	[self.writeBuffer appendData:data];
	
	if ([self.writeBuffer length] < 1) return YES;
	
	long numBytesWritten = write(self.fileDescriptor, [self.writeBuffer bytes], [self.writeBuffer length]);
	if (numBytesWritten < 0)
	{
		LOG_SERIAL_PORT_ERROR(@"Error writing to serial port:%d", errno);
		[self notifyDelegateOfPosixError];
		return NO;
	}
	if (numBytesWritten > 0) [self.writeBuffer replaceBytesInRange:NSMakeRange(0, numBytesWritten) withBytes:NULL length:0];
	
	return YES;
}

#pragma mark - Private Methods

#pragma mark Port Read/Write

- (void)receiveData:(NSData *)data;
{
	if ([(id)[self delegate] respondsToSelector:@selector(serialPort:didReceiveData:)])
	{
		[[self delegate] serialPort:self didReceiveData:data];
	}
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
	
	// TODO: Call delegate error handling method if this fails
	int result = tcsetattr(self.fileDescriptor, TCSANOW, &options);
	if (result != 0) NSLog(@"Unable to set options on %@: %i", self, result);
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

- (void)notifyDelegateOfPosixError;
{
	if (![(id)self.delegate respondsToSelector:@selector(serialPort:didEncounterError:)]) return;
	
	NSDictionary *errDict = @{NSLocalizedDescriptionKey: @(strerror(errno)),
							 NSFilePathErrorKey: self.path};
	NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain
										 code:errno
									 userInfo:errDict];
	[self.delegate serialPort:self didEncounterError:error];
}

#pragma mark - Properties

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	if ([key isEqualToString:@"isOpen"])
	{
		keyPaths = [keyPaths setByAddingObject:@"fileDescriptor"];
	}
	
	return keyPaths;
}

@synthesize delegate = _delegate;
@synthesize device = _device;

#pragma mark Port Properties

- (BOOL)isOpen { return self.fileDescriptor != 0; }

@synthesize path = _path;
@synthesize name = _name;

@synthesize baudRate = _baudRate;
- (void)setBaudRate:(NSNumber *)rate
{
	if (rate != _baudRate)
	{
		_baudRate = [rate copy];
		
		[self setPortOptions];
	}
}

@synthesize numberOfStopBits = _numberOfStopBits;
- (void)setNumberOfStopBits:(NSUInteger)num
{
	if (num != _numberOfStopBits)
	{
		_numberOfStopBits = num;		
		[self setPortOptions];
	}
}

@synthesize shouldEchoReceivedData = _shouldEchoReceivedData;
- (void)setShouldEchoReceivedData:(BOOL)flag
{
	if (flag != _shouldEchoReceivedData)
	{
		_shouldEchoReceivedData = flag;
		[self setPortOptions];
	}
}

@synthesize parity = _parity;
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

@synthesize usesRTSCTSFlowControl = _usesRTSCTSFlowControl;
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

@synthesize usesDTRDSRFlowControl = _usesDTRDSRFlowControl;
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

@synthesize usesDCDOutputFlowControl = _usesDCDOutputFlowControl;
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

@synthesize RTS = _RTS;
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
			dispatch_async(dispatch_get_main_queue(), ^{[self notifyDelegateOfPosixError];});
		}
	}
}

@synthesize DTR = _DTR;
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
			dispatch_async(dispatch_get_main_queue(), ^{[self notifyDelegateOfPosixError];});
		}
	}
}

@synthesize CTS = _CTS;
@synthesize DSR = _DSR;
@synthesize DCD = _DCD;

#pragma mark Private Properties
@synthesize writeBuffer = _writeBuffer;
@synthesize fileDescriptor = _fileDescriptor;
@synthesize pinPollTimer = _pinPollTimer;
- (void)setPinPollTimer:(dispatch_source_t)timer
{
	if (timer != _pinPollTimer)
	{
		if (_pinPollTimer) { ORS_GCD_RELEASE(_pinPollTimer); }
		
		ORS_GCD_RETAIN(timer);
		_pinPollTimer = timer;
	}
}

@end
