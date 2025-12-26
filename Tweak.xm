#import <Foundation/Foundation.h>
#include <sys/sysctl.h>
#include <mach/mach.h>

/**
 * A11ZeroAuto - Performance Core Limiter
 * Targeting A11 Bionic (T8015) on iOS 16
 * * This tweak uses IOKit to talk to the AppleARMCPU nodes
 * because the standard sysctl OIDs are restricted on iOS 16.
 */

typedef mach_port_t io_object_t;
typedef io_object_t io_registry_entry_t;
typedef io_object_t io_service_t;

extern "C" {
    // IOKit function declarations for the compiler
    io_service_t IOServiceGetMatchingService(mach_port_t mainPort, CFDictionaryRef matching);
    CFMutableDictionaryRef IOServiceMatching(const char *name);
    kern_return_t IORegistryEntrySetCFProperty(io_registry_entry_t entry, CFStringRef name, CFTypeRef value);
    kern_return_t IOObjectRelease(io_object_t object);
}

%ctor {
    @autoreleasepool {
        NSLog(@"[A11ZeroAuto] Initialization Started.");

        int limit = 0; // 0 = Minimum Performance Core Usage
        
        // --- Strategy 1: Sysctl (High Level) ---
        // We try both the legacy and the iOS 16 potential OIDs
        if (sysctlbyname("kern.perfcontrol.migration_limit", NULL, NULL, &limit, sizeof(limit)) == 0) {
            NSLog(@"[A11ZeroAuto] Success: Migration limit set via sysctl.");
        } 
        else {
            NSLog(@"[A11ZeroAuto] Sysctl failed or OID unknown. Moving to Hardware Level.");

            // --- Strategy 2: IOKit (Hardware Level) ---
            // We search for 'AppleARMCPU' which we found in your ioreg (T8015)
            CFMutableDictionaryRef matching = IOServiceMatching("AppleARMCPU");
            
            if (matching) {
                // Get the service handle for the CPU cluster
                io_service_t service = IOServiceGetMatchingService(0, matching);
                
                if (service) {
                    // Create a CFNumber representing 0 (Off/Low)
                    CFNumberRef val = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &limit);
                    
                    // Directly set the 'cpu-performance-degree' property in the registry
                    kern_return_t kr = IORegistryEntrySetCFProperty(service, CFSTR("cpu-performance-degree"), val);
                    
                    if (kr == KERN_SUCCESS) {
                        NSLog(@"[A11ZeroAuto] Success: CPU Performance Degree set to 0.");
                    } else {
                        NSLog(@"[A11ZeroAuto] Error: Failed to set hardware property (Code: %d).", kr);
                    }
                    
                    if (val) CFRelease(val);
                    IOObjectRelease(service);
                } else {
                    NSLog(@"[A11ZeroAuto] Error: Could not find AppleARMCPU service.");
                }
                // Note: IOServiceMatching returns a dictionary that is consumed by IOServiceGetMatchingService
            }
        }
    }
}
