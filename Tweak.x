#import <Foundation/Foundation.h>
#include <sys/sysctl.h>

// IOKit functions are usually private, so we declare what we need
extern "C" {
    typedef mach_port_t io_connect_t;
    typedef mach_port_t io_service_t;
    typedef mach_port_t io_iterator_t;
    typedef mach_port_t io_object_t;
    
    io_service_t IOServiceGetMatchingService(mach_port_t mainPort, CFDictionaryRef matching);
    CFMutableDictionaryRef IOServiceMatching(const char *name);
    kern_return_t IORegistryEntrySetCFProperty(io_registry_entry_t entry, CFStringRef name, CFTypeRef value);
}

%ctor {
    NSLog(@"[A11ZeroAuto] Genius Mode Initialized - Target: T8015 (A11)");

    // Method 1: The "Soft" Limit (New iOS 16 OID attempt)
    // Apple sometimes uses .1 instead of the name in newer kernels
    int limit = 0; // Set to 0 to minimize performance core usage
    if (sysctlbyname("kern.perfcontrol.migration_limit", NULL, NULL, &limit, sizeof(limit)) != 0) {
        NSLog(@"[A11ZeroAuto] Sysctl failed, attempting IOKit hardware override...");
        
        // Method 2: Hardware Level Override
        // We look for the AppleARMCPU nodes we saw in your ioreg
        CFMutableDictionaryRef matching = IOServiceMatching("AppleARMCPU");
        io_service_t service = IOServiceGetMatchingService(0, matching);
        
        if (service) {
            // We tell the scheduler that the "Performance Degree" of these cores is now 0
            // This effectively tells iOS: "Treat these like low-power efficiency cores"
            CFNumberRef val = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &limit);
            IORegistryEntrySetCFProperty(service, CFSTR("cpu-performance-degree"), val);
            CFRelease(val);
            
            NSLog(@"[A11ZeroAuto] Hardware performance degree set to 0.");
        } else {
            NSLog(@"[A11ZeroAuto] Critical Error: Could not find AppleARMCPU hardware node.");
        }
    } else {
        NSLog(@"[A11ZeroAuto] Sysctl limit applied successfully.");
    }
}
