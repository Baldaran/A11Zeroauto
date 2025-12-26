#import <UIKit/UIKit.h>
#import <sys/sysctl.h>
#import <IOKit/IOKitLib.h>

#define CLPC_LIMIT "kern.perfcontrol.migration_limit"

static int last_limit = -1;
static BOOL thermal_throttle_active = NO;

// Direct IOKit read for battery temperature
float get_battery_temp() {
    CFMutableDictionaryRef matching = IOServiceMatching("IOPMPowerSource");
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, matching);
    if (!service) return 0.0f;
    
    CFMutableDictionaryRef properties = NULL;
    IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0);
    
    float temperature = 0.0f;
    if (properties) {
        NSDictionary *dict = (__bridge NSDictionary *)properties;
        temperature = [dict[@"Temperature"] floatValue] / 100.0f;
        CFRelease(properties);
    }
    IOObjectRelease(service);
    return temperature;
}

void apply_kernel_limit(int limit) {
    if (limit == last_limit) return;
    sysctlbyname(CLPC_LIMIT, NULL, NULL, &limit, sizeof(limit));
    last_limit = limit;
}

static void run_orchestrator() {
    float temp = get_battery_temp();
    double load[1];
    getloadavg(load, 1);
    float cpu_load = (float)load[0];

    if (temp >= 42.0f) {
        apply_kernel_limit(4);
        thermal_throttle_active = YES;
        return;
    }
    
    thermal_throttle_active = NO;

    if (cpu_load > 2.2) apply_kernel_limit(6);
    else if (cpu_load < 1.2) apply_kernel_limit(5);
}

%hook SBBacklightController
- (void)setBacklightFactor:(float)factor {
    %orig;
    if (factor < 0.1) apply_kernel_limit(4);
    else if (!thermal_throttle_active) apply_kernel_limit(5);
}
%end

%ctor {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC, 1.0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{ run_orchestrator(); });
    dispatch_resume(timer);
}
