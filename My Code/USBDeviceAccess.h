/*
 *  USBDeviceAccess.h
 *  Ascent
 *
 *  Created by Rob Boyer on 8/21/10.
 *  Copyright 2010 Montebello Software, LLC. All rights reserved.
 *
 */

enum tDeviceEvent
{
	kDeviceAppeared,
	kDeviceDisappeared
};

typedef void (*tDeviceNotificationCallback)(void* p, tDeviceEvent iEvent, int iVendorID, int iProductID, bool iIsMassStorage);

int		StartDeviceCallbacks(tDeviceNotificationCallback iCB, void* iP);
void	StopDeviceCallbacks();
