//
//  ORSIOKitWrappers.h
//  ORSSerialPort
//
//  Created by Andrew Madsen on 12/21/15.
//  Copyright © 2015 Open Reel Software. All rights reserved.
//

#ifndef ORSIOKitWrappers_h
#define ORSIOKitWrappers_h

int fcntlClearFlags(int fd);
int ioctlSetSpeed(int fd, int speed);
int ioctlGetModemLinesState(int fd, int *modemLines);

#endif /* ORSIOKitWrappers_h */
