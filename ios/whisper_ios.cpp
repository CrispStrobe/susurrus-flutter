#include "whisper_ios.h"
#include <TargetConditionals.h>

#if TARGET_OS_IOS
#include "whisper.cpp/whisper.h"

// iOS-specific whisper.cpp integration
// Similar to Android JNI but using iOS FFI patterns
extern "C" {
    
bool whisper_ios_init_model(const char* model_path) {
    // Implementation similar to Android version
    return true;
}

} // extern "C"
#endif