ORSSerialPort
=============

ORSSerialPort is my take on a modern, easy-to-use Objective-C serial port library. It's is a simple, Cocoa-like set of Objective-C classes useful for programmers writing Objective-C Cocoa apps that must communicate with external devices through a serial port (most commonly RS-232). Using ORSSerialPort to open a port and send data can be as simple as this:

    ORSSerialPort *serialPort = [ORSSerialPort serialPortWithWithPath:@"/dev/cu.KeySerial1"];
    serialPort.baudRate = [NSNumber numberWithInteger:4800];
    [serialPort open];
    [serialPort sendData:someData]; // someData is an NSData object
    [serialPort close];
    
ORSSerialPort is released under an MIT license, meaning you're free to use it in both closed and open source projects. However, even in a closed source project, you must include a publicly-accessible copy of ORSSerialPort's copyright notice, which you can find in the LICENSE file.

If you have any questions about, suggestions for, or contributions to ORSSerialPort, please [contact me](mailto:andrew@openreelsoftware.com). I'd also love to hear about any cool projects you're using it in.

How to Use ORSSerialPort
========================

To begin using ORSSerialPort in your project, simply drag the files in the "Source" folder into your Xcode project. ORSSerialPort.h/m are required, while ORSSerialPortManager.h/m are optional, but useful (see below). Next, add `#import "ORSSerialPort.h"` and '#import "ORSSerialPortManager.h"' to the top of the source code files in which you'd like to use ORSSerialPort.

*Important Note:* ORSSerialPort relies Automatic Reference Counting (ARC). If you'd like to use it in a non-ARC project, you'll need to open the Build Phases for the target(s) you're using it in, and add the -fobjc-arc flag to the Compiler Flags column for ORSSerialPort.m and ORSSerialPortManager.m. ORSSerialPort will generate a compiler error if ARC is not enabled.

The ORSSerialPort library consists of only two classes: `ORSSerialPort` and `ORSSerialPortManager`. As its name implies, each instance of `ORSSerialPort` represents a serial port device. There is a 1:1 correspondence between port devices on the system and instances of `ORSSerialPort`. That means that repeated requests for a port object for a given device will return the same instance of `ORSSerialPort`.

Opening a Port and Setting It Up
--------------------------------

You can get an `ORSSerialPort` instance either of two ways. The easiest is to use `ORSSerialPortManager`'s `availablePorts` array (explained below). The other way is to get a new `ORSSerialPort` instance using the serial port's BSD device path:

    ORSSerialPort *port = [ORSSerialPort serialPortWithPath:@"/dev/cu.KeySerial1"];

Note that you must give `+serialPortWithPath:` the full callout ("cu.*") path to the device, as shown in the example above.

After you've got a port instance, you can open it with the `-open` method. When you're done using the port, close it using the `-close` method.

Port settings such as baud rate, number of stop bits, parity, and flow control settings can be set using the various properties `ORSSerialPort` provides. Note that all of these properties are Key Value Observing (KVO) compliant. This KVO compliance also applies to read-only properties for reading the state of the CTS, DSR and DCD pins. Among other things, this means it's easy to be notified when the state of one of these pins changes, without having to continually poll them, as well as making them easy to connect to a UI with Cocoa bindings.

Sending Data
------------

Send data by passing an `NSData` object to the `-sendData:` method:

    NSData *dataToSend = [self.sendTextField.stringValue dataUsingEncoding:NSUTF8StringEncoding];
    [self.serialPort sendData:dataToSend];

Receiving Data
--------------

To receive data, you must implement the `ORSSerialPortDelegate` protocol's `-serialPort:didReceiveData:` method, and set the `ORSSerialPort` instance's delegate property. As noted below, this method is always called on the main queue. An an example implementation is included below:

    - (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
    {
    	NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    	[self.receivedDataTextView.textStorage.mutableString appendString:string];
    	[self.receivedDataTextView setNeedsDisplay:YES];
    }

ORSSerialPortDelegate
---------------------

ORSSerialPort includes a delegate property, and a delegate protocol called `ORSSerialPortDelegate`. The `ORSSerialPortDelegate` protocol includes two required methods:

    - (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data;
    - (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort;
    
Also included are 3 optional methods:

    - (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error;
    - (void)serialPortWasOpened:(ORSSerialPort *)serialPort;
    - (void)serialPortWasClosed:(ORSSerialPort *)serialPort;

*Note:* All `ORSSerialPortDelegate` methods are always called on the main queue. If you need to handle them on a background queue, you must dispatch your handling to a background queue in your implementations of the delegate method.

As its name implies, `-serialPort:didReceiveData:` is called when data is received from the serial port. Internally, ORSSerialPort receives data on a background queue to avoid burdening the main queue to simply received data. As with all other delegate methods, `-serialPort:didReceiveData:` is called on the main queue.

`-serialPortserialPortWasRemovedFromSystem:` is called when a serial port is removed from the system, for example because a USB to serial adapter was unplugged. This method is required because you must release your reference to an `ORSSerialPort` instance when it is removed. The behavior of `ORSSerialPort` instances whose underlying serial port has been removed from the system is undefined.

The three optional methods' function can easily be discerned from their name. Note that `-serialPort:didEncounterError:` is always used to report errors. None of ORSSerialPort's methods take an NSError object passed in by reference.

How to Use ORSSerialPortManager
===============================

`ORSSerialPortManager` is a singleton class (one instance per application) that can be used to get a list of available serial ports. It will also handle closing open serial ports when the Mac goes to sleep, and reopening them automatically on wake. This prevents problems I've seen with serial port drivers that can hang if the port is left open when putting the machine to sleep. Note that using `ORSSerialPortManager` is optional. It provides some nice functionality, but only `ORSSerialPort` is necessary to simply send and received data.

Using `ORSSerialPortManager` is simple. To get the shared serial port manager:

    ORSerialPortManager *portManager = [ORSSerialPortManager sharedSerialPortManager];

To get a list of available ports:

    NSArray *availablePorts = portManager.availablePorts;

`ORSSerialPortManager` is Key-Value Observing (KVO) compliant for its `availablePorts` property. This means that you can observe `availablePorts` to be notified when ports are added to or removed from the system. This also means that you can easily bind UI elements to the serial port manager's `availablePorts` property using Cocoa-bindings. This makes it easy to create a popup menu that displays available serial ports and updates automatically, for example.

`ORSSerialPortManager`'s close-on-sleep, reopen-on-wake functionality is automatic. The only thing necessary to enable it is to make sure that the singleton instance of `ORSSerialPortManager` has been created by calling `+sharedSerialPortManager` at least once.

Example Project
===============

Included with ORSSerialPort is a demo application called ORSSerialPortDemo. This is a very simple serial terminal program. It demonstrates how to use ORSSerialPort, and may also be useful for simple testing of serial hardware.

ORSSerialPortDemo includes a dropdown menu containing all available ports on the system, controls to set baud rate, parity, number of stop bits, and flow control settings. Also included are two text fields. One is for typing characters to be sent to the serial port, the other for displaying received characters. Finally, it includes checkboxes corresponding to the RTS, DTR, CTS, DSR, and DCD pins. For the output pins (RTS, DTR), their state can be toggled using their checkbox. The input pins (CTS, DSR, DCD) are read only. 

The demo application demonstrates that it is possible to setup and use a serial port with ORSSerialPort without writing a lot of "glue" code. Nearly all of the UI is implemented using Cocoa bindings. With the exception of two lines in ORSAppDelegate.m, the source code for entire application is contained in ORSSerialPortDemoController.h/m.