#Serial Testbed
Serial Testbed is a Swift application for OS X meant to be used in conjunction with the unit tests in the ORSSerial.framework project. Because the entire purpose of ORSSerialPort is to work with hardware, much of its functionality can not be tested with "traditional" unit tests. Therefore, many of its unit tests rely on the presence of a connected serial port with this Serial Testbed program running on the other end of the connection.

While the source code for this app may be instructive, it is not meant primarily as an example of ORSSerialPort's use.

##Setup

The typical setup for using Serial Testbed and running ORSSerialPort's unit tests is to connect two USB to serial adapters together with a null modem cable. The two adapters can be attached to the same, or different Macs. Serial Testbed is launched and told to connect to one of the available serial ports. Then, the unit tests are run, and will connect to the serial port at the other end of the connection.

##What Does Serial Testbed Do Exactly?

Serial Testbed simply listens to its serial port and responds to certain incoming commands that are sent out by the ORSSerialPort unit tests. These commands are described below:

###Hello?

When Serial Testbed receives the ASCII string "Hello?", it will enable further communications and respond with a single ACK character (hex 0x06). Other commands sent before "Hello?" are ignored. See also Goodbye!

###Goodbye!

When Serial Testbed receives the ASCII string "Goodbye!", it will disable further communications and respond with a single ACK character (hex 0x06). Other commands sent after a "Goodbye!" are ignored until another "Hello?" os received. See also Hello?.

###RTS;

The command "RTSx;" is used to set the state of Serial Testbed's serial port's RTS pin. "RTS0;" sets the pin low, while "RTS1;" will set the pin high. This is used to test ORSSerialPort's ability to read the corresponding CTS pin on the other end of the connection.

###DTR;

The command "DTRx;" is used to set the state of Serial Testbed's serial port's DTR pin. It behaves just like the "RTSx;" command, and is used to test ORSSerialPort's corresponding DSR and DCD pin properties at the other end of the connection.

###CTS?

The command "CTS?" reads the state of Serial Testbed's serial port's CTS pin. A packet of the format "CTSx;" where x is 0 or 1 depending on the CTS pin's state is sent in response. It as part of testing ORSSerialPort's ability to set the RTS pin at the other end of the connection.

###DSR?

The command "DSR?" reads the state of Serial Testbed's serial port's DSR pin. A packet of the format "DSRx;" where x is 0 or 1 depending on the DSR pin's state is sent in response. It as part of testing ORSSerialPort's ability to set the DTR pin at the other end of the connection.