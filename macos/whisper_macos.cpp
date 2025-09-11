#include <TargetConditionals.h>

#if TARGET_OS_OSX
#include "whisper.cpp/whisper.h"
#include <Accelerate/Accelerate.h>
#include <Metal/Metal.h>

// macOS-specific implementation
extern "C" {
    // Similar to iOS but with macOS optimizations
}
#endif