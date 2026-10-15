#pragma once
#include <stdbool.h>
// Private ABI declarations verified against OpenMultitouchSupport (MIT).
// https://github.com/Kyome22/OpenMultitouchSupport/blob/main/Framework/OpenMultitouchSupportXCF/OpenMTInternal.h
typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTVector;
typedef struct {
    int frame; double timestamp;
    int identifier, state, fingerId, handId;
    MTVector normalizedPosition;
    float total, pressure, angle, majorAxis, minorAxis;
    MTVector absolutePosition;
    int field14, field15;
    float density;
} MTTouch;
typedef void (*TouchCallback)(void *, MTTouch *, int, double, int);
// One device / listener per process. Call start/stop on the main thread.
const char *TBStart(TouchCallback callback);
void TBStop(void);
// Zero means the private framework cannot identify the current default device.
#include <stdint.h>
uint64_t TBDeviceIdentifier(void);
