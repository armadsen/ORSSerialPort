ORSSerialPort
=============

ORSSerialPort is my take on a modern, easy-to-use Objective-C serial port library. It's a simple, Cocoa-like set of Objective-C classes useful for programmers writing Objective-C Cocoa apps that must communicate with external devices through a serial port (most commonly RS-232). Using ORSSerialPort to open a port and send data can be as simple as this:

    ORSSerialPort *serialPort = [ORSSerialPort serialPortWithPath:@"/dev/cu.KeySerial1"];
    serialPort.baudRate = @4800;
    [serialPort open];
    [serialPort sendData:someData]; // someData is an NSData object
    [serialPort close]; // Later, when you're done with the port
    
ORSSerialPort is released under an MIT license, meaning you're free to use it in both closed and open source projects. However, even in a closed source project, you must include a publicly-accessible copy of ORSSerialPort's copyright notice, which you can find in the LICENSE file.

If you have any questions about, suggestions for, or contributions to ORSSerialPort, please [contact me](mailto:andrew@openreelsoftware.com). I'd also love to hear about any cool projects you're using it in.

This readme provides an overview of the ORSSerialPort library and is meant to provide enough information to get up and running quickly. You can read complete documentation for ORSSerialPort here: [http://cocoadocs.org/docsets/ORSSerialPort/](http://cocoadocs.org/docsets/ORSSerialPort/)

How to Use ORSSerialPort
========================

The ORSSerialPort library consists of only two classes: `ORSSerialPort` and `ORSSerialPortManager`. To begin using ORSSerialPort in your project, drag the files in the "Source" folder into your Xcode project. ORSSerialPort.h/m are required, while ORSSerialPortManager.h/m are optional, but useful (see below). Next, add `#import "ORSSerialPort.h"` and `#import "ORSSerialPortManager.h"` to the top of the source code files in which you'd like to use ORSSerialPort. 

ORSSerialPort relies on IOKit.framework. If you're using Xcode 5 or later, you can use its support for Objective-C modules to avoid having to manually link in the IOKit framework. To use this, you must make sure Objective-C module support is turned on in your target/project's build settings (see [here](http://stackoverflow.com/a/18947634/344733)). Alternatively, if you're using an older version of Xcode, or can't enable Objective-C module support for some reason, you must add the IOKit framework to the "Link Binary With Libraries" build phase for your target. In your project's settings, select your application's target, then click on the "Build Phases" tab. Expand the "Link Binary With Libraries" section, then click the "+" button in the lower left corner to add a new Framework. In the list that appears, find and select IOKit.framework, then click "Add".

ORSSerialPort can be used in 64-bit applications targeting Mac OS X 10.6.8 and later. However, due to its use of ARC (see note below) and modern Objective-C syntax, it must be compiled on a machine running Mac OS X 10.7 Lion or later, with the LLVM 4.0 or later compiler, which is included in Xcode 4.4 and later. The example projects require Xcode 5.0 or later due to their use of LLVM 5.0's Objective-C modules support.

*Important Note:* ORSSerialPort relies on Automatic Reference Counting (ARC). If you'd like to use it in a non-ARC project, you'll need to open the "Compile Sources" build phase for the target(s) you're using it in, and add the -fobjc-arc flag to the "Compiler Flags" column for ORSSerialPort.m and ORSSerialPortManager.m. ORSSerialPort will generate a compiler error if ARC is not enabled.

Opening a Port and Setting It Up
--------------------------------

You can get an `ORSSerialPort` instance either of two ways. The easiest is to use `ORSSerialPortManager`'s `availablePorts` array (explained below). The other way is to get a new `ORSSerialPort` instance using the serial port's BSD device path:

    ORSSerialPort *port = [ORSSerialPort serialPortWithPath:@"/dev/cu.KeySerial1"];

Note that you must give `+serialPortWithPath:` the full path to the device, as shown in the example above.

Each instance of `ORSSerialPort` represents a serial port device. That is, there is a 1:1 correspondence between port devices on the system and instances of `ORSSerialPort`. That means that repeated requests for a port object for a given device or device path will return the same instance of `ORSSerialPort`.

After you've got a port instance, you can open it with the `-open` method. When you're done using the port, close it using the `-close` method.

Port settings such as baud rate, number of stop bits, parity, and flow control settings can be set using the various properties `ORSSerialPort` provides. Note that all of these properties are Key Value Observing (KVO) compliant. This KVO compliance also applies to read-only properties for reading the state of the CTS, DSR and DCD pins. Among other things, this means it's easy to be notified when the state of one of these pins changes, without having to continually poll them, as well as making them easy to connect to a UI with Cocoa bindings.

Sending Data
------------

Send data by passing an `NSData` object to the `-sendData:` method:

    NSData *dataToSend = [self.sendTextField.stringValue dataUsingEncoding:NSUTF8StringEncoding];
    [self.serialPort sendData:dataToSend];

Receiving Data
--------------

To receive data, you must implement the `ORSSerialPortDelegate` protocol's `-serialPort:didReceiveData:` method, and set the `ORSSerialPort` instance's delegate property. As noted below, this method is always called on the main queue. An example implementation is included below:

    - (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
    {
    	NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    	[self.receivedDataTextView.textStorage.mutableString appendString:string];
    	[self.receivedDataTextView setNeedsDisplay:YES];
    }

ORSSerialPortDelegate
---------------------

`ORSSerialPort` includes a delegate property, and a delegate protocol called `ORSSerialPortDelegate`. The `ORSSerialPortDelegate` protocol includes two required methods:

    - (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data;
    - (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort;
    
Also included are 3 optional methods:

    - (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error;
    - (void)serialPortWasOpened:(ORSSerialPort *)serialPort;
    - (void)serialPortWasClosed:(ORSSerialPort *)serialPort;

*Note:* All `ORSSerialPortDelegate` methods are always called on the main queue. If you need to handle them on a background queue, you must dispatch your handling to a background queue in your implementation of the delegate method.

As its name implies, `-serialPort:didReceiveData:` is called when data is received from the serial port. Internally, ORSSerialPort receives data on a background queue to avoid burdening the main queue with waiting for data. As with all other delegate methods, `-serialPort:didReceiveData:` is called on the main queue.

`-serialPortserialPortWasRemovedFromSystem:` is called when a serial port is removed from the system, for example because a USB to serial adapter was unplugged. This method is required because you must release your reference to an `ORSSerialPort` instance when it is removed. The behavior of `ORSSerialPort` instances whose underlying serial port has been removed from the system is undefined.

The three optional methods' function can easily be discerned from their name. Note that `-serialPort:didEncounterError:` is always used to report errors. None of ORSSerialPort's methods take an NSError object passed in by reference.

How to Use ORSSerialPortManager
===============================

`ORSSerialPortManager` is a singleton class (one instance per application) that can be used to get a list of available serial ports. It will also handle closing open serial ports when the Mac goes to sleep, and reopening them automatically on wake. This prevents problems I've seen with serial port drivers that can hang if the port is left open when putting the machine to sleep. Note that using `ORSSerialPortManager` is optional. It provides some nice functionality, but only `ORSSerialPort` is necessary to simply send and received data.

Using `ORSSerialPortManager` is simple. To get the shared serial port manager:

    ORSSerialPortManager *portManager = [ORSSerialPortManager sharedSerialPortManager];

To get a list of available ports:

    NSArray *availablePorts = portManager.availablePorts;

`ORSSerialPortManager` is Key-Value Observing (KVO) compliant for its `availablePorts` property. This means that you can observe `availablePorts` to be notified when ports are added to or removed from the system. This also means that you can easily bind UI elements to the serial port manager's `availablePorts` property using Cocoa-bindings. This makes it easy to create a popup menu that displays available serial ports and updates automatically, for example.

`ORSSerialPortManager`'s close-on-sleep, reopen-on-wake functionality is automatic. The only thing necessary to enable it is to make sure that the singleton instance of `ORSSerialPortManager` has been created by calling `+sharedSerialPortManager` at least once. Note that this behavior is only available in Cocoa apps, and is disabled when ORSSerialPort is used in a command-line only app.

Example Projects
===============

Included with ORSSerialPort is a folder called Examples, containing Xcode projects for small programs demonstrating the use of ORSSerialPort. Currently, it contains two examples to demonstrate using ORSSerialPort in both Cocoa apps, as well as in command line apps.

ORSSerialPortCocoaDemo
----------------------

The first, and primary example is called ORSSerialPortCocoaDemo, and is found in the Cocoa subfolder of Examples. This is a very simple serial terminal program with a graphical user interface (GUI). It demonstrates how to use ORSSerialPort, and may also be useful for simple testing of serial hardware.

ORSSerialPortCocoaDemo includes a dropdown menu containing all available ports on the system, controls to set baud rate, parity, number of stop bits, and flow control settings. Also included are two text fields. One is for typing characters to be sent to the serial port, the other for displaying received characters. Finally, it includes checkboxes corresponding to the RTS, DTR, CTS, DSR, and DCD pins. For the output pins (RTS, DTR), their state can be toggled using their checkbox. The input pins (CTS, DSR, DCD) are read only. 

This application demonstrates that it is possible to setup and use a serial port with ORSSerialPort without writing a lot of "glue" code. Nearly all of the UI is implemented using Cocoa bindings. With the exception of two lines in ORSAppDelegate.m, the source code for entire application is contained in ORSSerialPortDemoController.h/m.

ORSSerialPortCommandLineDemo
----------------------------

The CommandLine subfolder of Examples contains ORSSerialPortCommandLineDemo. This is a Foundation-based command line program demonstrating the use of ORSSerialPort in applications without a GUI. ORSSerialPortCommandLineDemo is a very simple serial terminal. It lists the available ports, allows the user to select one, and enter a baud rate. After that, typed input is sent out on the serial port, and data received from the port is printed to the console. It was written very quickly and is intended simply as demonstration that such an app is possible rather than as a starting point for production code. The source code for the entire program is contained in main.m.