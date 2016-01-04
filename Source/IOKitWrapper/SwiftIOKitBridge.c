//
//  SwiftIOKitBridge.c
//  ORSSerialPort
//
//  Created by Andrew Madsen on 12/21/15.
//  Copyright © 2015 Open Reel Software. All rights reserved.
//

#include "SwiftIOKitBridge.h"
#include <sys/fcntl.h>
#include <sys/ioctl.h>
#include <IOKit/serial/ioss.h>

int fcntlClearFlags(int fd)
{
	return fcntl(fd, F_SETFL, 0);
}

int ioctlSetSpeed(int fd, int speed)
{
	return ioctl(fd, IOSSIOSPEED &speed, 1);
}

int ioctlGetModemLinesState(int fd, int *modemLines)
{
	return ioctl(fd, TIOCMGET, modemLines);
}