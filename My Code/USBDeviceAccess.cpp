/*
 *  USBDeviceAccess.cpp
 *  Ascent
 *
 *  Created by Rob Boyer on 8/21/10.
 *  Copyright 2010 Montebello Software, LLC. All rights reserved.
 *
 */

#include "USBDeviceAccess.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/IOMessage.h>

#include <unistd.h>



// Set this flag to get more status messages
#define VERBOSE 1&&ASCENT_DBG

#define GARMIN_VENDORID		0x91e

// Set this flag to match directly to interface, without finding device first.
#define MATCH_INTERFACE 0

static void noCB(void*, tDeviceEvent, int, int, bool) {}

tDeviceNotificationCallback gNotificationCallback = noCB;
void* gP = 0;


void printInterpretedError(const char *s, IOReturn err)
{
	
	UInt32 system, sub, code;
    
    fprintf(stderr, "%s (0x%08X) ", s, err);
    
    system = err_get_system(err);
    sub = err_get_sub(err);
    code = err_get_code(err);
    
    if(system == err_get_system(sys_iokit))
    {
        if(sub == err_get_sub(sub_iokit_usb))
        {
            fprintf(stderr, "USB error %d(0x%X) ", (int)code, (unsigned int)code);
        }
        else if(sub == err_get_sub(sub_iokit_common))
        {
            fprintf(stderr, "IOKit common error %d(0x%X) ", (int)code, (unsigned int)code);
        }
        else
        {
            fprintf(stderr, "IOKit error %d(0x%X) from subsytem %d(0x%X) ", (int)code, (unsigned int)code, (int)sub, (unsigned int)sub);
        }
    }
    else
    {
        fprintf(stderr, "error %d(0x%X) from system %d(0x%X) - subsytem %d(0x%X) ", (int)code, (unsigned int)code, (int)system, (unsigned int)system, (int)sub, (unsigned int)sub);
    }
}



void useUSBInterface(IOUSBInterfaceInterface245 **intf)
{
    printf("Now we actually get to do something with this device, wow!!!!\n");
    ///finallyDoSomethingWithThisDevice(intf);
}

UInt32 openUSBInterface(IOUSBInterfaceInterface245 **intf)
{
	IOReturn ret;
	
#if VERBOSE
	UInt8 n;
	int i;
	UInt8 direction;
	UInt8 number;
	UInt8 transferType;
	UInt16 maxPacketSize;
	UInt8 interval;
	static const char * types[]={
        "Control",
        "Isochronous",
        "Bulk",
        "Interrupt"};
	static const char *directionStr[]={
        "Out",
        "In",
        "Control"};
#endif
	
    ret = (*intf)->USBInterfaceOpen(intf);
    if(ret != kIOReturnSuccess)
    {
        printInterpretedError("Could not set configuration on device", ret);
        return(-1);
    }
    
#if VERBOSE
    // We don't use the endpoints in our device, but it has some anyway
    
    ret = (*intf)->GetNumEndpoints(intf, &n);
    if(ret != kIOReturnSuccess)
    {
        printInterpretedError("Could not get number of endpoints in interface", ret);
        return(0);
    }
    
    printf("%d endpoints found\n", n);
    
    for(i = 1; i<=n; i++)
    {
        ret = (*intf)->GetPipeProperties(intf, i, &direction, &number, &transferType, &maxPacketSize, &interval);
        if(ret != kIOReturnSuccess)
        {
            fprintf(stderr, "Endpoint %d -", n);
            printInterpretedError("Could not get endpoint properties", ret);
            return(0);
        }
        printf("Endpoint %d: %s %s %d, max packet %d, interval %d\n", i, types[transferType], directionStr[direction], number, maxPacketSize, interval);
    }
    
    
#endif
    return(0);
}


IOUSBInterfaceInterface245 **getUSBInterfaceInterface(io_service_t usbInterface)
{
	IOReturn err;
	IOCFPlugInInterface **plugInInterface=NULL;
	IOUSBInterfaceInterface245 **intf=NULL;
	SInt32 score;
	HRESULT res;
	
    // There is no documentation for IOCreatePlugInInterfaceForService or QueryInterface, you have to use sample code.
	
    err = IOCreatePlugInInterfaceForService(usbInterface, 
											kIOUSBInterfaceUserClientTypeID, 
											kIOCFPlugInInterfaceID,
											&plugInInterface, 
											&score);
    (void)IOObjectRelease(usbInterface);                // done with the usbInterface object now that I have the plugin
    if ((kIOReturnSuccess != err) || (plugInInterface == nil) )
    {
        printInterpretedError("Unable to create plug in interface for USB interface", err);
        return(nil);
    }
    
    res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID245), (LPVOID*)&intf);
    IODestroyPlugInInterface(plugInInterface);          // done with this
    
    if (res || !intf)
    {
        fprintf(stderr, "Unable to create interface with QueryInterface %X\n", (unsigned int)res);
        return(nil);
    }
    return(intf);
}


Boolean isThisTheInterfaceYoureLookingFor(IOUSBInterfaceInterface245 **intf)
{
    //  Check to see if this is the interface you're interested in
    //  This code is only expecting one interface, so returns true
    //  the first time.
    //  You code could check the nature and type of endpoints etc
	
	static Boolean foundOnce  = false;
    if(foundOnce)
    {
        fprintf(stderr, "Subsequent interface found, we're only intersted in 1 of them\n");
        return(false);
    }
    foundOnce = true;
    return(true);
}


int iterateinterfaces(io_iterator_t interfaceIterator)
{
	io_service_t usbInterface;
	int err = 0;
	IOReturn ret;
	IOUSBInterfaceInterface245 **intf=NULL;
	
    usbInterface = IOIteratorNext(interfaceIterator);
    if(usbInterface == IO_OBJECT_NULL)
    {
        fprintf(stderr, "Unable to find an Interface\n");
        return(-1);
    }
    
    while(usbInterface != IO_OBJECT_NULL)
    {
        intf = getUSBInterfaceInterface(usbInterface);
        
        if(intf != nil)
        {
			// Don't release the interface here. That's one too many releases and causes set alt interface to fail
            if(isThisTheInterfaceYoureLookingFor(intf))
            {
                err = openUSBInterface(intf);
                if(err == 0)
                {
                    useUSBInterface(intf);
                    ret = (*intf)->USBInterfaceClose(intf);
                }
				
                ret = (*intf)->Release(intf);
                // Not worth bothering with errors here
                return(err);
            }
        }
        usbInterface = IOIteratorNext(interfaceIterator);
    }
	
    fprintf(stderr, "No interesting interfaces found\n");
    IOObjectRelease(usbInterface);
    return(-1);
}


void useUSBDevice(IOUSBDeviceInterface245 **dev, UInt32 configuration)
{
	io_iterator_t interfaceIterator;
	IOUSBFindInterfaceRequest req;
	IOReturn err;
	
    err = (*dev)->SetConfiguration(dev, configuration);
    if(err != kIOReturnSuccess)
    {
        printInterpretedError("Could not set configuration on device", err);
        return;
    }
	
    req.bInterfaceClass = kIOUSBFindInterfaceDontCare;
    req.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
    req.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    req.bAlternateSetting = kIOUSBFindInterfaceDontCare;
    
    err = (*dev)->CreateInterfaceIterator(dev, &req, &interfaceIterator);
    if(err != kIOReturnSuccess)
    {
        printInterpretedError("Could not create interface iterator", err);
        return;
    }
	
    
    err = iterateinterfaces(interfaceIterator);
	
    IOObjectRelease(interfaceIterator);
	
	
}


SInt32 openUSBDevice(IOUSBDeviceInterface245 **dev)
{
	UInt8 numConfig;
	IOReturn err;
	IOUSBConfigurationDescriptorPtr desc;
	
    err = (*dev)->GetNumberOfConfigurations(dev, &numConfig);
    if(err != kIOReturnSuccess)
    {
        printInterpretedError("Could not number of configurations from device", err);
        return(-1);
    }
    if(numConfig != 1)
    {
        fprintf(stderr, "This does not look like the right device, it has %d configurations (we want 1)\n", numConfig);
        return(-1);
    }
    
    err = (*dev)->GetConfigurationDescriptorPtr(dev, 0, &desc);
    if(err != kIOReturnSuccess)
    {
        printInterpretedError("Could not get configuration descriptor from device", err);
        return(-1);
    }
	
#if VERBOSE
    printf("Configuration value is %d\n", desc->bConfigurationValue);
#endif
    
    // We should really try to do classic arbitration here
    
    err = (*dev)->USBDeviceOpen(dev);
    if(err == kIOReturnExclusiveAccess)
    {
#if VERBOSE
        printf("Exclusive error opening device, we may come back to this later\n");
#endif
        return(-2);
    }
    if(err != kIOReturnSuccess)
    {
        printInterpretedError("Could not open device", err);
        return(-1);
    }
    
    
    return(desc->bConfigurationValue);
}

io_object_t gNotificationObject;
static IONotificationPortRef    gNotifyPort;


//================================================================================================
//
//  DeviceNotification
//
//  This routine will get called whenever any kIOGeneralInterest notification happens.  We are
//  interested in the kIOMessageServiceIsTerminated message so that's what we look for.  Other
//  messages are defined in IOMessage.h.
//
//================================================================================================
void DeviceNotification(void *refCon, io_service_t service, natural_t messageType, void *messageArgument)
{
    kern_return_t   kr;
   /// MyPrivateData   *privateDataRef = (MyPrivateData *) refCon;
    

    if (messageType == kIOMessageServiceIsTerminated)
	{
        ///printf("Device removed.\n");
		
#if 0
        // Dump our private data to stderr just to see what it looks like.
        fprintf(stderr, "privateDataRef->deviceName: ");
        CFShow(privateDataRef->deviceName);
        fprintf(stderr, "privateDataRef->locationID: 0x%lx.\n\n", privateDataRef->locationID);
		
        // Free the data we're no longer using now that the device is going away
        CFRelease(privateDataRef->deviceName);
        
        if (privateDataRef->deviceInterface) {
            kr = (*privateDataRef->deviceInterface)->Release(privateDataRef->deviceInterface);
        }
#endif        
       /// kr = IOObjectRelease(privateDataRef->notification);
        kr = IOObjectRelease(gNotificationObject);
        
        ///free(privateDataRef);
    }
}


IOUSBDeviceInterface245 **getUSBDevice(io_object_t usbDevice)
{
	IOReturn err;
	IOCFPlugInInterface **plugInInterface=NULL;
	IOUSBDeviceInterface245 **dev=NULL;
	SInt32 score;
	HRESULT res;
	
    // There is no documentation for IOCreatePlugInInterfaceForService or QueryInterface, you have to use sample code.
	
    err = IOCreatePlugInInterfaceForService(usbDevice, 
											kIOUSBDeviceUserClientTypeID, 
											kIOCFPlugInInterfaceID,
											&plugInInterface, 
											&score);
    if ((kIOReturnSuccess != err) || (plugInInterface == nil) )
    {
        printInterpretedError("Unable to create plug in interface for USB device", err);
        return(nil);
    }
    
    res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID245), (LPVOID*)&dev);
    IODestroyPlugInInterface(plugInInterface);          // done with this
    
    if (res || !dev)
    {
        fprintf(stderr, "Unable to create USB device with QueryInterface\n");
        return(nil);
    }
	
#if VERBOSE
    {
		UInt16 VID, PID, REL;
        err = (*dev)->GetDeviceVendor(dev, &VID);
        err = (*dev)->GetDeviceProduct(dev, &PID);
        err = (*dev)->GetDeviceReleaseNumber(dev, &REL);
		io_name_t       deviceName;
		CFStringRef     deviceNameAsCFString;   
		// Get the USB device's name.
		kern_return_t               kr;
		kr = IORegistryEntryGetName(usbDevice, deviceName);
		if (KERN_SUCCESS != kr) {
			deviceName[0] = '\0';
		}
		
		deviceNameAsCFString = CFStringCreateWithCString(kCFAllocatorDefault, deviceName, 
														 kCFStringEncodingASCII);
		
        printf("Found device VID 0x%04X (%d), PID 0x%04X (%d), release %d\n", VID, VID, PID, PID, REL);
 
	
	
	}
#endif
	
    return(dev);
}



Boolean CheckInterfaces(IOUSBDeviceInterface **device)
{
    IOReturn                    kr;
    IOUSBFindInterfaceRequest   request;
    io_iterator_t               iterator;
    io_service_t                usbInterface;
    IOCFPlugInInterface         **plugInInterface = NULL;
    IOUSBInterfaceInterface     **interface = NULL;
    HRESULT                     result;
    SInt32                      score;
    UInt8                       interfaceClass;
    UInt8                       interfaceSubClass;
    ///UInt8                       interfaceNumEndpoints;
    ///int                         pipeRef;
	Boolean						isMassStorage = false;
#ifndef USE_ASYNC_IO
    ///UInt32                      numBytesRead;
    ///UInt32                      i;
#else
    CFRunLoopSourceRef          runLoopSource;
#endif
	
    //Placing the constant kIOUSBFindInterfaceDontCare into the following
    //fields of the IOUSBFindInterfaceRequest structure will allow you
    //to find all the interfaces
    request.bInterfaceClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    request.bAlternateSetting = kIOUSBFindInterfaceDontCare;
	
    //Get an iterator for the interfaces on the device
    kr = (*device)->CreateInterfaceIterator(device,
											&request, &iterator);
    while ((usbInterface = IOIteratorNext(iterator)))
    {
        //Create an intermediate plug-in
        kr = IOCreatePlugInInterfaceForService(usbInterface,
											   kIOUSBInterfaceUserClientTypeID,
											   kIOCFPlugInInterfaceID,
											   &plugInInterface, &score);
        //Release the usbInterface object after getting the plug-in
        kr = IOObjectRelease(usbInterface);
        if ((kr != kIOReturnSuccess) || !plugInInterface)
        {
            printf("Unable to create a plug-in (%08x)\n", kr);
            break;
        }
		
        //Now create the device interface for the interface
        result = (*plugInInterface)->QueryInterface(plugInInterface,
													CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID),
													(LPVOID *) &interface);
        //No longer need the intermediate plug-in
        (*plugInInterface)->Release(plugInInterface);
		
        if (result || !interface)
        {
            printf("Couldn’t create a device interface for the interface (%08x)\n", (int) result);
            break;
        }
		
        //Get interface class and subclass
        kr = (*interface)->GetInterfaceClass(interface,
											 &interfaceClass);
        kr = (*interface)->GetInterfaceSubClass(interface,
                                                &interfaceSubClass);
		
#if VERBOSE
        printf("Interface class %d, subclass %d\n", interfaceClass,
			   interfaceSubClass);
#endif		
		if (interfaceClass == 8) isMassStorage = true;
		
#if 0
        //Now open the interface. This will cause the pipes associated with
        //the endpoints in the interface descriptor to be instantiated
        kr = (*interface)->USBInterfaceOpen(interface);
        if (kr != kIOReturnSuccess)
        {
            printf("Unable to open interface (%08x)\n", kr);
			printInterpretedError("FindInterfaces", kr);
            (void) (*interface)->Release(interface);
            continue;
        }
		
        //Get the number of endpoints associated with this interface
        kr = (*interface)->GetNumEndpoints(interface,
										   &interfaceNumEndpoints);
        if (kr != kIOReturnSuccess)
        {
            printf("Unable to get number of endpoints (%08x)\n", kr);
            (void) (*interface)->USBInterfaceClose(interface);
            (void) (*interface)->Release(interface);
            break;
        }
		
        printf("Interface has %d endpoints\n", interfaceNumEndpoints);
        //Access each pipe in turn, starting with the pipe at index 1
        //The pipe at index 0 is the default control pipe and should be
        //accessed using (*usbDevice)->DeviceRequest() instead
        for (pipeRef = 1; pipeRef <= interfaceNumEndpoints; pipeRef++)
        {
            IOReturn        kr2;
            UInt8           direction;
            UInt8           number;
            UInt8           transferType;
            UInt16          maxPacketSize;
            UInt8           interval;
            const char      *message;
			
            kr2 = (*interface)->GetPipeProperties(interface,
												  pipeRef, &direction,
												  &number, &transferType,
												  &maxPacketSize, &interval);
            if (kr2 != kIOReturnSuccess)
                printf("Unable to get properties of pipe %d (%08x)\n",
					   pipeRef, kr2);
            else
            {
                printf("PipeRef %d: ", pipeRef);
                switch (direction)
                {
                    case kUSBOut:
                        message = "out";
                        break;
                    case kUSBIn:
                        message = "in";
                        break;
                    case kUSBNone:
                        message = "none";
                        break;
                    case kUSBAnyDirn:
                        message = "any";
                        break;
                    default:
                        message = "???";
                }
                printf("direction %s, ", message);
				
                switch (transferType)
                {
                    case kUSBControl:
                        message = "control";
                        break;
                    case kUSBIsoc:
                        message = "isoc";
                        break;
                    case kUSBBulk:
                        message = "bulk";
                        break;
                    case kUSBInterrupt:
                        message = "interrupt";
                        break;
                    case kUSBAnyType:
                        message = "any";
                        break;
                    default:
                        message = "???";
                }
                printf("transfer type %s, maxPacketSize %d\n", message,
					   maxPacketSize);
            }
        }


		
		
#ifndef USE_ASYNC_IO    //Demonstrate synchronous I/O
        kr = (*interface)->WritePipe(interface, 2, kTestMessage,
									 strlen(kTestMessage));
        if (kr != kIOReturnSuccess)
        {
            printf("Unable to perform bulk write (%08x)\n", kr);
            (void) (*interface)->USBInterfaceClose(interface);
            (void) (*interface)->Release(interface);
            break;
        }
		
        printf("Wrote \"%s\" (%ld bytes) to bulk endpoint\n", kTestMessage,
			   (UInt32) strlen(kTestMessage));
		
        numBytesRead = sizeof(gBuffer) - 1; //leave one byte at the end
											//for NULL termination
        kr = (*interface)->ReadPipe(interface, 9, gBuffer,
									&numBytesRead);
        if (kr != kIOReturnSuccess)
        {
            printf("Unable to perform bulk read (%08x)\n", kr);
            (void) (*interface)->USBInterfaceClose(interface);
            (void) (*interface)->Release(interface);
            break;
        }
		
        //Because the downloaded firmware echoes the one’s complement of the
        //message, now complement the buffer contents to get the original data
        for (i = 0; i < numBytesRead; i++)
            gBuffer[i] = ~gBuffer[i];
		
        printf("Read \"%s\" (%ld bytes) from bulk endpoint\n", gBuffer,
			   numBytesRead);
		
#else   //Demonstrate asynchronous I/O
        //As with service matching notifications, to receive asynchronous
        //I/O completion notifications, you must create an event source and
        //add it to the run loop
        kr = (*interface)->CreateInterfaceAsyncEventSource(
														   interface, &runLoopSource);
        if (kr != kIOReturnSuccess)
        {
            printf("Unable to create asynchronous event source
				   (%08x)\n", kr);
            (void) (*interface)->USBInterfaceClose(interface);
            (void) (*interface)->Release(interface);
            break;
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource,
						   kCFRunLoopDefaultMode);
        printf("Asynchronous event source added to run loop\n");
        bzero(gBuffer, sizeof(gBuffer));
        strcpy(gBuffer, kTestMessage);
        kr = (*interface)->WritePipeAsync(interface, 2, gBuffer,
										  strlen(gBuffer),
										  WriteCompletion, (void *) interface);
        if (kr != kIOReturnSuccess)
        {
            printf("Unable to perform asynchronous bulk write (%08x)\n",
				   kr);
            (void) (*interface)->USBInterfaceClose(interface);
            (void) (*interface)->Release(interface);
            break;
        }
#endif
        //For this test, just use first interface, so exit loop
        break;
#endif
    }
    return isMassStorage;
}


static io_iterator_t            gRawAddedIter;
///static io_iterator_t            gRawRemovedIter;
///static io_iterator_t            gBulkTestAddedIter;
///static io_iterator_t            gBulkTestRemovedIter;
void RawDeviceAdded(void *refCon, io_iterator_t iterator)
{
	bool						haveGarmin = false;
    kern_return_t               kr;
    io_service_t                usbDevice;
    IOCFPlugInInterface         **plugInInterface = NULL;
    IOUSBDeviceInterface        **dev = NULL;
    HRESULT                     result;
    SInt32                      score;
    UInt16                      vendor;
    UInt16                      product;
    UInt16                      release;
	
    while ((usbDevice = IOIteratorNext(iterator)))
    {
        //Create an intermediate plug-in
        kr = IOCreatePlugInInterfaceForService(usbDevice,
											   kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID,
											   &plugInInterface, &score);
         if ((kIOReturnSuccess != kr) || !plugInInterface)
        {
            printf("Unable to create a plug-in (%08x)\n", kr);
            continue;
        }
        //Now create the device interface
        result = (*plugInInterface)->QueryInterface(plugInInterface,
													CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
													(LPVOID *)&dev);
        //Don’t need the intermediate plug-in after device interface
        //is created
        (*plugInInterface)->Release(plugInInterface);
		
        if (result || !dev)
        {
            printf("Couldn’t create a device interface (%08x)\n",
				   (int) result);
            continue;
        }
		
        //Check these values for confirmation
        kr = (*dev)->GetDeviceVendor(dev, &vendor);
        kr = (*dev)->GetDeviceProduct(dev, &product);
        kr = (*dev)->GetDeviceReleaseNumber(dev, &release);
		
		UInt8 devClass, devSubClass, devProtocol;
		
        kr = (*dev)->GetDeviceClass(dev, &devClass);
        kr = (*dev)->GetDeviceSubClass(dev, &devSubClass);
        kr = (*dev)->GetDeviceProtocol(dev, &devProtocol);
		
		
		io_name_t       deviceName;
        CFStringRef     deviceNameAsCFString;   
		kr = IORegistryEntryGetName(usbDevice, deviceName);
        if (KERN_SUCCESS != kr) {
            deviceName[0] = '\0';
        }
        
        deviceNameAsCFString = CFStringCreateWithCString(kCFAllocatorDefault, deviceName, 
                                                         kCFStringEncodingASCII);
		
		
		char localBuffer[64];
		CFStringGetCString(deviceNameAsCFString, localBuffer, 64, kCFStringEncodingMacRoman);
		
#if VERBOSE
		printf("\nFOUND: %s vendor:0x%0x (%d)  product:%d  class:%d subclass:%d protocol:%d\n", 
			   localBuffer, vendor, vendor, product, devClass, devSubClass, devProtocol);
#endif		
		if (vendor == GARMIN_VENDORID)
		{
			// Register for an interest notification of this device being removed. Use a reference to our
			// private data as the refCon which will be passed to the notification callback.
			kr = IOServiceAddInterestNotification(gNotifyPort,                      // notifyPort
												  usbDevice,                        // service
												  kIOGeneralInterest,               // interestType
												  DeviceNotification,               // callback
												  NULL,                   // refCon
												  &gNotificationObject);
			
			printf("...GARMIN product %d registered for general interest notification...\n", product);
			
			bool isMassStorage = CheckInterfaces(dev);
			gNotificationCallback(gP, kDeviceAppeared, vendor, product, isMassStorage);
			haveGarmin = true;
		}
		//Don’t need the device object anymore
        kr = IOObjectRelease(usbDevice);
#if 0
       //Open the device to change its state
        kr = (*dev)->USBDeviceOpen(dev);
        if (kr != kIOReturnSuccess)
        {
            printf("Unable to open device: %08x\n", kr);
            (void) (*dev)->Release(dev);
            continue;
        }
		//Configure device
        kr = ConfigureDevice(dev);
        if (kr != kIOReturnSuccess)
        {
            printf("Unable to configure device: %08x\n", kr);
            (void) (*dev)->USBDeviceClose(dev);
            (void) (*dev)->Release(dev);
            continue;
        }
		
        //Download firmware to device
        kr = DownloadToDevice(dev);
        if (kr != kIOReturnSuccess)
        {
            printf("Unable to download firmware to device: %08x\n", kr);
            (void) (*dev)->USBDeviceClose(dev);
            (void) (*dev)->Release(dev);
            continue;
        }
		
        //Close this device and release object
        kr = (*dev)->USBDeviceClose(dev);
#endif
        kr = (*dev)->Release(dev);
    }
	int* hg = (int*)refCon;
	*hg = haveGarmin ? 1 : 0;
}


void RawDeviceRemoved(void *refCon, io_iterator_t iterator)
{
    kern_return_t   kr;
    io_service_t    object;
#if VERBOSE
	printf("RAW REMOVED\n");
#endif
    while ((object = IOIteratorNext(iterator)))
    {
        kr = IOObjectRelease(object);
        if (kr != kIOReturnSuccess)
        {
            printf("Couldn’t release raw device object: %08x\n", kr);
            continue;
        }
		else
		{
#if VERBOSE
			printf("\nRELEASED RAW DEVICE\n");
#endif
		}
    }
	
}

void StopDeviceCallbacks()
{
	CFRunLoopSourceRef runLoopSource = IONotificationPortGetRunLoopSource(gNotifyPort);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource,
						  kCFRunLoopDefaultMode);
}

int StartDeviceCallbacks(tDeviceNotificationCallback iCB, void* iP)
{
	gNotificationCallback = iCB;
	gP = iP;
	IOReturn err = 0;
	mach_port_t masterPort;
	CFMutableDictionaryRef dict;
	
    err = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if(err != kIOReturnSuccess)
    {
        printInterpretedError("Could not get master port", err);
        return(-1);
    }
	
	// creates dictionary, must be released somewhere below
    dict = IOServiceMatching(kIOUSBDeviceClassName);
    if (dict == nil)
    {
        fprintf(stderr, "Could create matching dictionary\n");
        return(-1);
    }
	
	kern_return_t           kr;
    CFRunLoopSourceRef      runLoopSource;
	//To set up asynchronous notifications, create a notification port and
    //add its run loop event source to the program’s run loop
    gNotifyPort = IONotificationPortCreate(masterPort);
    runLoopSource = IONotificationPortGetRunLoopSource(gNotifyPort);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource,
					   kCFRunLoopDefaultMode);
	
    //Retain additional dictionary references because each call to
    //IOServiceAddMatchingNotification consumes one reference
	//dict = (CFMutableDictionaryRef) CFRetain(dict);
    //dict = (CFMutableDictionaryRef) CFRetain(dict);
    //dict = (CFMutableDictionaryRef) CFRetain(dict);
	
    //Now set up two notifications: one to be called when a raw device
    //is first matched by the I/O Kit and another to be called when the
    //device is terminated
    //Notification of first match:
	// CONSUMES a reference to 'dict'!!!
	int hg = 0;
    kr = IOServiceAddMatchingNotification(gNotifyPort,
										  kIOFirstMatchNotification, dict,
										  RawDeviceAdded, &hg, &gRawAddedIter);
    //Iterate over set of matching devices to access already-present devices
    //and to arm the notification
	RawDeviceAdded(&hg, gRawAddedIter);
#if 0
	//Notification of termination:
    kr = IOServiceAddMatchingNotification(gNotifyPort,
										  kIOTerminatedNotification, dict,
										  RawDeviceRemoved, NULL, &gRawRemovedIter);
#endif	
	
    return hg;
}
