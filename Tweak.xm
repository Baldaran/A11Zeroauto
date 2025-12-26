#import <Foundation/Foundation.h>

extern "C" {
    typedef mach_port_t io_iterator_t;
    typedef mach_port_t io_service_t;
    typedef mach_port_t io_object_t;
    kern_return_t IOServiceGetMatchingServices(mach_port_t, CFDictionaryRef, io_iterator_t*);
    CFMutableDictionaryRef IOServiceMatching(const char*);
    io_object_t IOIteratorNext(io_iterator_t);
    kern_return_t IORegistryEntrySetCFProperty(io_service_t, CFStringRef, CFTypeRef);
    CFTypeRef IORegistryEntryCreateCFProperty(io_service_t, CFStringRef, CFAllocatorRef, uint32_t);
    kern_return_t IOObjectRelease(io_object_t);
}

void applyHardwareLimit() {
    io_iterator_t iter;
    if (IOServiceGetMatchingServices(0, IOServiceMatching("AppleARMCPU"), &iter) == KERN_SUCCESS) {
        io_service_t cpu;
        while ((cpu = IOIteratorNext(iter))) {
            CFNumberRef num = (CFNumberRef)IORegistryEntryCreateCFProperty(cpu, CFSTR("IOCPUNumber"), kCFAllocatorDefault, 0);
            if (num) {
                int cpuID;
                CFNumberGetValue(num, kCFNumberIntType, &cpuID);
                if (cpuID == 4 || cpuID == 5) { // The A11 Performance Cores
                    int zero = 0;
                    CFNumberRef val = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &zero);
                    
                    // We attempt to 'Force' these properties into the registry
                    // If one fails, the next might hit a driver-supported key
                    IORegistryEntrySetCFProperty(cpu, CFSTR("cpu-performance-degree"), val);
                    IORegistryEntrySetCFProperty(cpu, CFSTR("performance-state"), val);
                    
                    NSLog(@"[A11ZeroAuto] Capped Core %d", cpuID);
                    CFRelease(val);
                }
                CFRelease(num);
            }
            IOObjectRelease(cpu);
        }
        IOObjectRelease(iter);
    }
}

%ctor {
    // Run once at startup
    applyHardwareLimit();
    
    // Also listen for screen-on events to re-apply (iOS 16 often resets these on wake)
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)applyHardwareLimit, CFSTR("com.apple.iokit.hid.displayStatus"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
