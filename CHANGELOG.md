# Change Log
All notable changes to ORSSerialPort are documented in this file. This project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]
This section is for changes commited to the ORSSerialPort repository, but not yet included in an official release.

## [2.0.2] - 2016-03-14

### CHANGED
- Refactored packet descriptor buffer parsing to pave the way for future improvements (thanks @nathanntg!)
- Clarified distinction between packet parsing API and request/response API in documentation for `ORSSerialPacketDescriptor`.
- Refactored modem line control code (see Issue #86 and commit 6fc0c9e)

### FIXED
- Fixed error building framework project in Xcode 4.6 on 10.7.5
- Fixed bug where PacketParsingDemo and RequestResponseDemo apps didn't work on 10.11
- Fixed incorrect nullability annotation on `ORSSerialRequest`'s `responseDescriptor` property

## [2.0.1] - 2015-09-26

### ADDED
- Added CHANGELOG.md file
- Travis CI now builds and tests changes to ORSSerialPort's public repository

### FIXED
- Fixed error when building framework project (tests target specifically) in versions of Xcode before support for nullability annotations were introduced.

## [2.0.0] - 2015-09-21

Version 2.0.0 is a major update to ORSSerialPort. It includes enhancements including a new packet parsing API, bug fixes, performance improvements, and additional example code.

It is mostly API compatible with previous releases, requiring no code changes on the part of most users. The exception is that the methods for creating an ORSSerialRequest object have changed slightly. The old methods are deprecated, but still available.

Important note: Due to a change to the underlying system API used by ORSSerialPort, as of this release, it only supports deploying to OS X 10.7 or later. If you require support for OS X 10.6, use version 1.8.2. The requirements for building ORSSerialPort (Xcode 4.4+ on 10.7+) have not changed.

### ADDED
- Added full featured packet parsing API. `ORSSerialPacketDescriptor`, etc. See []documentation](https://github.com/armadsen/ORSSerialPort/wiki/Packet-Parsing-API)
- Added ability to cancel pending requests
- Added Objective-C generics annotations for nicer usability from Swift
- Added PacketParsingDemo app (Swift and Objective-C)
- Added some unit tests

### DEPRECATED
No API has been _removed_, but a few methods have been deprecated their use should be replaced as soon as possible:

- Existing `ORSSerialRequest` initializer (and corresponding convenience method), `-[ORSSerialRequest initWithDataToSend:userInfo:timeoutInterval:responseEvaluator:]` has been deprecated. Use `-initWithDataToSend:userInfo:timeoutInterval:responseDescriptor:` instead.
- Deprecated `-[ORSSerialRequest dataIsValidRespone:]`. If this functionality is needed, use the request's packet descriptor's `-dataIsValidPacket:` method instead.

### REMOVED
- Removed support for deploying to Mac OS X 10.6 Snow Leopard. Those who need to continue deploying to 10.6 should use version 1.8.2. Version 2.0.0 will deploy to 10.7 or higher.


### CHANGED
- Request / response API response detection has been rewritten to use new packet parsing API.
- `ORSSerialPort` now uses a dispatch source for reading from the underlying serial device
- Converted all Swift demo apps to Swift 2.0


## [1.8.2] - 2015-08-10

Note that this is the last release of ORSSerialPort to support deploying to OS X 10.6.

### FIXED
- Minor memory leak when targeting 10.6 or 10.7

## [1.8.1] - 2015-07-06
### CHANGED
- Made some usability enhancements in ORSSerialPortDemo

### FIXED
- Nullability annotations are now conditional, fixing building in older versions of Xcode
- Fixed build errors and warnings in Swift RequestResponseDemo project

## [1.8.0] - 2015-04-13
### ADDED
- Added support for non-standard baud rates (depends on adapter driver)
- Added nullability annotations for nicer Swift integration
- Added Swift version of CommandLineDemo app

### CHANGED
- Updated ORSSerialPortSwiftDemo to Swift 1.2
- Unified Objective-C and Swift versions of GUI demo into a single ORSSerialPortDemo folder


## [1.7.1] - 2015-04-05
### ADDED
- Added `-[ORSSerialPortManager availablePortWithName:]`

### FIXED
- Fixed possible hang due to deadlock when removing a port while it is still open
- Framework project builds on 10.7
- Fixes for building examples projects in Xcode 4.6 on 10.7

## [1.7.0] - 2015-03-15
### ADDED
- Added demo app for Request / Response API (Swift and Objective-C)
- Added `queuedRequests` property used to obtain requests waiting to be sent

### CHANGED
- When building from source and targeting OS X 10.8, `ORSSerialPort`'s `delegate` property is now weak
- `ORSSerialPortDelegate` now inherits from `NSObject` protocol
- Shortened readme, and moved more documentation into wiki

### FIXED
- Fixed failure to automatically close open ports when host application quits
- 


## [1.5.4] - 2015-02-08
### ADDED
- Added contribution guidelines (CONTRIBUTING.md)

### FIXED
- Better handling of requests for which a response is not expected
- Request response API works in Foundation-only programs
- Fixed possible deadlock in request response timeout logic
- Fixed broken automatic machine sleep/wake handling

## [1.5.3] - 2014-12-21
### CHANGED
- Changed framework name to ORSSerial.framework

### FIXED
- Fixed framework header visibility

## [1.5.2] - 2014-12-20
### ADDED
- Project to build ORSSerialPort.framework

### FIXED
- Build error
- Minor bugs in Swift demo

## [1.5.1] - 2014-11-03
### CHANGED
- Updated and improved documentation

### FIXED
- Fixed possible failure to send all data when `-sendData:` was called with a lot of data

## [1.5.0] - 2014-11-01
### ADDED
- Request / Response API (`ORSSerialRequest`, etc.) See [documentation](https://github.com/armadsen/ORSSerialPort/wiki/Request-Response-API)
- Swift demo app

### CHANGED
- Delegate method `-serialPort:didReceiveData:` is now optional

## [1.0.4] - 2014-10-31

### ADDED
- Podspec file for built in CocoaPods support

### CHANGED
- Updated to modern Objective-C syntax
- Cleaned up unused code in ORSSerialPortDemo

### FIXED
- Fixed 100% CPU usage and failure to call `-serialPortWasRemovedFromSystem:` after removing a port when not using `ORSSerialPortManager`
- Compiler warnings when building in Xcode 6..1 on 10.10
- Fixed possibility of passing `NULL` to `dispatch_retain()`

## [1.0.3] - 2014-04-21
### CHANGED
- Updated documentation

### FIXED
- Bluetooth ports are no longer filtered from `-availablePorts`
- Baud rate declarations
- Possibly incorrect error codes in errors passed to delegate error notification method
- Incorrect compile-time check for whether GCD objects participate in ARC
- Various other minor bugs

## [1.0.2] - 2013-12-14
### FIXED
- Problem where `+[ORSSerialPort initialize]` could be called multiple times
- Extraneous line (copy/paste error) that caused build failure

## [1.0.1] - 2013-08-31
### ADDED
- Complete documentation

## [1.0.0] - 2013-03-10
### ADDED
- Support for modem devices
- Support for passing dialin (tty.*) paths to `-serialPortWithPath:`
- NSNotifications are posted when ports are added to/removed from the system
- Support for using ORSSerialPort in Foundation-only command line programs
- Command line example program
- Access to underlying IOKit device
- README and documentation improvements

### FIXED
- KVO notifications for `-availablePorts` include old/new keys in change dictionary
- Fixed bug where changing number of stop bits didn't work
- An error is generated if ORSSerialPort is compiled with ARC turned off


## [0.0.1] - 2012-06-27
### ADDED
Initial release