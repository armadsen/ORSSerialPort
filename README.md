# ORSSerialPort


ORSSerialPort is my take on a modern, easy-to-use Objective-C serial port library. It's a simple, Cocoa-like set of Objective-C classes useful for programmers writing Objective-C or Swift apps for the Mac that must communicate with external devices through a serial port (most commonly RS-232). Using ORSSerialPort to open a port and send data can be as simple as this:

```objective-c
ORSSerialPort *serialPort = [ORSSerialPort serialPortWithPath:@"/dev/cu.KeySerial1"];
serialPort.baudRate = @4800;
[serialPort open];
[serialPort sendData:someData]; // someData is an NSData object
[serialPort close]; // Later, when you're done with the port
```
    
ORSSerialPort is released under an MIT license, meaning you're free to use it in both closed and open source projects. However, even in a closed source project, you must include a publicly-accessible copy of ORSSerialPort's copyright notice, which you can find in the LICENSE file.

If you have any questions about, suggestions for, or contributions to ORSSerialPort, please [contact me](mailto:andrew@openreelsoftware.com). I'd also love to hear about any cool projects you're using it in.

This readme provides an overview of the ORSSerialPort library and is meant to provide enough information to get up and running quickly. You can read complete technical documentation for ORSSerialPort on [http://cocoadocs.org/docsets/ORSSerialPort/](http://cocoadocs.org/docsets/ORSSerialPort/).

The example code in this readme is in Objective-C. However, ORSSerialPort can also easily be used from Swift code. For Swift examples, see the ORSSerialPortSwiftDemo project in the Examples folder.

# How to Use ORSSerialPort

There are a number of ways to add ORSSerialPort to your project. You can use the included framework project, [Carthage](https://github.com/Carthage), [CocoaPods](http://cocoapods.org), or manually include the ORSSerialPort source code in your project. See the [Guide to Installing ORSSerialPort](https://github.com/armadsen/ORSSerialPort/wiki/Installing-ORSSerialPort) for detailed instructions for each of these methods.

### Opening a Port and Setting It Up

You can get an `ORSSerialPort` instance either of two ways. The easiest is to use `ORSSerialPortManager`'s `availablePorts` array (explained below). The other way is to get a new `ORSSerialPort` instance using the serial port's BSD device path:

```objective-c
ORSSerialPort *port = [ORSSerialPort serialPortWithPath:@"/dev/cu.KeySerial1"];
```

Note that you must give `+serialPortWithPath:` the full path to the device, as shown in the example above.

After you've got a port instance, you can open it with the `-open` method. When you're done using the port, close it using the `-close` method.

Port settings such as baud rate, number of stop bits, parity, and flow control settings can be set using the various properties `ORSSerialPort` provides.

For more information, see the [Getting Started Guide](https://github.com/armadsen/ORSSerialPort/wiki/Getting-Started#opening-a-port-and-setting-it-up).

### Sending Data

Send raw data by passing an `NSData` object to the `-sendData:` method:

```objective-c
NSData *dataToSend = [self.sendTextField.stringValue dataUsingEncoding:NSUTF8StringEncoding];
[self.serialPort sendData:dataToSend];
```

### Receiving Data

To receive data, you can implement the `ORSSerialPortDelegate` protocol's `-serialPort:didReceiveData:` method, and set the `ORSSerialPort` instance's delegate property. As noted below, this method is always called on the main queue. An example implementation is included below:

```objective-c
- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self.receivedDataTextView.textStorage.mutableString appendString:string];
    [self.receivedDataTextView setNeedsDisplay:YES];
}
```

### ORSSerialPortDelegate 

`ORSSerialPort` includes a delegate property, and a delegate protocol called `ORSSerialPortDelegate`. A port uses informs its delegate of events including receipt of data, port open/close events, removal from the system, and errors. For more information, see the [Getting Started Guide](https://github.com/armadsen/ORSSerialPort/wiki/Getting-Started#orsserialportdelegate), or read the documentation in [ORSSerialPort.h](https://github.com/armadsen/ORSSerialPort/blob/master/Source/ORSSerialPort.h#L443).

### ORSSerialPortManager

`ORSSerialPortManager` is a singleton class (one instance per application) that can be used to get a list of available serial ports. It will also handle closing open serial ports when the Mac goes to sleep, and reopening them automatically on wake. This prevents problems I've seen with serial port drivers that can hang if the port is left open when putting the machine to sleep. Note that using `ORSSerialPortManager` is optional. It provides some nice functionality, but only `ORSSerialPort` is necessary to simply send and received data.

For more information about ORSSerialPortManager, see the [Getting Started Guide](https://github.com/armadsen/ORSSerialPort/wiki/Getting-Started#orsserialportmanager), or read the documentation in [ORSSerialPortManager.h](https://github.com/armadsen/ORSSerialPort/blob/master/Source/ORSSerialPortManager.h).

### ORSSerialRequest

Incoming serial data is delivered to your application as it is received. A low level library like ORSSerialPort has no way of knowing anything about the structure and format of the data you're sending and receiving. For example, you may be expecting a complete packet of data, but receive callbacks for each byte. Normally, this requires you to maintain a buffer which you fill up with incoming data, only processing it when a complete packet has been received. In order to eliminate the need for manual management and buffering of incoming data, ORSSerialPort includes a request/response API. This is implemented by ORSSerialRequest.

For more information about ORSSerialPort's request/response API, see the [Request/Response API Guide](https://github.com/armadsen/ORSSerialPort/wiki/Request-Response-API), or read the documentation in [ORSSerialRequest.h](https://github.com/armadsen/ORSSerialPort/blob/master/Source/ORSSerialPortRequest.h).

# Example Projects

Included with ORSSerialPort is a folder called Examples, containing Xcode projects for small programs demonstrating the use of ORSSerialPort. Currently, it contains three examples to demonstrate using ORSSerialPort in Objective-C and Swift Cocoa apps, as well as using it in command line apps. You can read more about these three examples on the [ORSSerialPort wiki](https://github.com/armadsen/ORSSerialPort/wiki):

- ORSSerialPortCocoaDemo(https://github.com/armadsen/ORSSerialPort/wiki/Cocoa-Demo) - Objective-C GUI app.
- ORSSerialPortSwiftDemo(https://github.com/armadsen/ORSSerialPort/wiki/Swift-Demo) - Swift GUI app.
- ORSSerialPortCommandLineDemo(https://github.com/armadsen/ORSSerialPort/wiki/Command-Line-Demo) - Objective-C command line app.

# Contributing

Contributions to ORSSerialPort are very welcome. However, contributors are encouraged to read the [contribution guidelines](CONTRIBUTING.md) before starting work on any contributions. Please also feel free to open a GitHub issue or [email](mailto:andrew@openreelsoftware.com) with questions about specific contributions.