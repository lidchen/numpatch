#include "TouchBridge.h"
#include <dlfcn.h>
#include <stddef.h>
_Static_assert(sizeof(MTTouch) == 96, "Unexpected touch ABI layout");
static void *library, *device;
static TouchCallback listener;
static void (*unregisterCallback)(void *, TouchCallback);
static int (*stopDevice)(void *);
static void (*releaseDevice)(void *);
const char *TBStart(TouchCallback callback) {
    if (device) return "Listener already started";
    if (!library) library = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    if (!library) return "Cannot load MultitouchSupport.framework";
    void *(*create)(void) = dlsym(library, "MTDeviceCreateDefault");
    void (*registerCallback)(void *, TouchCallback) = dlsym(library, "MTRegisterContactFrameCallback");
    int (*start)(void *, int) = dlsym(library, "MTDeviceStart");
    unregisterCallback = dlsym(library, "MTUnregisterContactFrameCallback");
    stopDevice = dlsym(library, "MTDeviceStop");
    releaseDevice = dlsym(library, "MTDeviceRelease");
    if (!create || !registerCallback || !start || !unregisterCallback || !stopDevice || !releaseDevice)
        return "Required private API symbols are unavailable";
    device = create();
    if (!device) return "No default multitouch trackpad found";
    listener = callback;
    registerCallback(device, listener);
    if (start(device, 0) != 0) { TBStop(); return "Could not start trackpad"; }
    return NULL;
}
void TBStop(void) {
    if (!device) return;
    stopDevice(device);
    unregisterCallback(device, listener);
    releaseDevice(device);
    device = NULL;
    listener = NULL;
    // Keep the framework loaded: a final callback may still be unwinding.
}
uint64_t TBDeviceIdentifier(void) {
    if (!device || !library) return 0;
    int (*getID)(void *, uint64_t *) = dlsym(library, "MTDeviceGetDeviceID");
    uint64_t identifier = 0;
    if (!getID || getID(device, &identifier) != 0) return 0;
    return identifier;
}
