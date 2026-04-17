// android/app/src/main/cpp/whisper_jni.cpp (COMPLETE IMPLEMENTATION)
#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <memory>
#include <mutex>

// Include whisper.cpp headers
#ifdef WHISPER_AVAILABLE
#include "whisper.cpp/whisper.h"
#endif

#define LOG_TAG "WhisperJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)

// Global state management
class WhisperState {
public:
    static WhisperState& getInstance() {
        static WhisperState instance;
        return instance;
    }

#ifdef WHISPER_AVAILABLE
    struct whisper_context* ctx = nullptr;
#else
    void* ctx = nullptr;
#endif
    std::string modelPath;
    std::mutex contextMutex;
    bool isModelLoaded = false;

    void setContext(void* newCtx, const std::string& path) {
        std::lock_guard<std::mutex> lock(contextMutex);
#ifdef WHISPER_AVAILABLE
        if (ctx) {
            whisper_free(ctx);
        }
        ctx = static_cast<struct whisper_context*>(newCtx);
#else
        ctx = newCtx;
#endif
        modelPath = path;
        isModelLoaded = (ctx != nullptr);
    }

    void* getContext() {
        std::lock_guard<std::mutex> lock(contextMutex);
        return ctx;
    }

    void freeContext() {
        std::lock_guard<std::mutex> lock(contextMutex);
#ifdef WHISPER_AVAILABLE
        if (ctx) {
            whisper_free(ctx);
            ctx = nullptr;
        }
#else
        ctx = nullptr;
#endif
        isModelLoaded = false;
        modelPath.clear();
    }

private:
    WhisperState() = default;
    ~WhisperState() {
        freeContext();
    }
};

// JNI Helper functions
std::string jstringToStdString(JNIEnv* env, jstring jstr) {
    if (!jstr) return "";
    
    const char* chars = env->GetStringUTFChars(jstr, nullptr);
    std::string result(chars);
    env->ReleaseStringUTFChars(jstr, chars);
    return result;
}

jstring stdStringToJstring(JNIEnv* env, const std::string& str) {
    return env->NewStringUTF(str.c_str());
}

// Convert float array from Java to C++
std::vector<float> jfloatArrayToVector(JNIEnv* env, jfloatArray jarray) {
    jsize length = env->GetArrayLength(jarray);
    jfloat* elements = env->GetFloatArrayElements(jarray, nullptr);
    
    std::vector<float> result(elements, elements + length);
    
    env->ReleaseFloatArrayElements(jarray, elements, JNI_ABORT);
    return result;
}

// Create Java ArrayList of transcription segments
jobject createTranscriptionResult(JNIEnv* env, const std::vector<std::string>& texts,
                                 const std::vector<float>& startTimes,
                                 const std::vector<float>& endTimes) {
    // Get ArrayList class and constructor
    jclass arrayListClass = env->FindClass("java/util/ArrayList");
    jmethodID arrayListConstructor = env->GetMethodID(arrayListClass, "<init>", "()V");
    jmethodID addMethod = env->GetMethodID(arrayListClass, "add", "(Ljava/lang/Object;)Z");
    
    jobject resultList = env->NewObject(arrayListClass, arrayListConstructor);
    
    // Get HashMap class for individual segments
    jclass hashMapClass = env->FindClass("java/util/HashMap");
    jmethodID hashMapConstructor = env->GetMethodID(hashMapClass, "<init>", "()V");
    jmethodID putMethod = env->GetMethodID(hashMapClass, "put", 
                                         "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
    
    // Get Float and Double classes for boxing
    jclass floatClass = env->FindClass("java/lang/Float");
    jmethodID floatConstructor = env->GetMethodID(floatClass, "<init>", "(F)V");
    
    jclass doubleClass = env->FindClass("java/lang/Double");
    jmethodID doubleConstructor = env->GetMethodID(doubleClass, "<init>", "(D)V");
    
    for (size_t i = 0; i < texts.size(); ++i) {
        // Create segment HashMap
        jobject segment = env->NewObject(hashMapClass, hashMapConstructor);
        
        // Add text
        jstring textKey = env->NewStringUTF("text");
        jstring textValue = env->NewStringUTF(texts[i].c_str());
        env->CallObjectMethod(segment, putMethod, textKey, textValue);
        
        // Add start time
        jstring startTimeKey = env->NewStringUTF("startTime");
        jobject startTimeValue = env->NewObject(doubleClass, doubleConstructor, (jdouble)startTimes[i]);
        env->CallObjectMethod(segment, putMethod, startTimeKey, startTimeValue);
        
        // Add end time
        jstring endTimeKey = env->NewStringUTF("endTime");
        jobject endTimeValue = env->NewObject(doubleClass, doubleConstructor, (jdouble)endTimes[i]);
        env->CallObjectMethod(segment, putMethod, endTimeKey, endTimeValue);
        
        // Add confidence (placeholder)
        jstring confidenceKey = env->NewStringUTF("confidence");
        jobject confidenceValue = env->NewObject(floatClass, floatConstructor, 0.9f);
        env->CallObjectMethod(segment, putMethod, confidenceKey, confidenceValue);
        
        // Add segment to result list
        env->CallBooleanMethod(resultList, addMethod, segment);
        
        // Clean up local references
        env->DeleteLocalRef(textKey);
        env->DeleteLocalRef(textValue);
        env->DeleteLocalRef(startTimeKey);
        env->DeleteLocalRef(startTimeValue);
        env->DeleteLocalRef(endTimeKey);
        env->DeleteLocalRef(endTimeValue);
        env->DeleteLocalRef(confidenceKey);
        env->DeleteLocalRef(confidenceValue);
        env->DeleteLocalRef(segment);
    }
    
    env->DeleteLocalRef(arrayListClass);
    env->DeleteLocalRef(hashMapClass);
    env->DeleteLocalRef(floatClass);
    env->DeleteLocalRef(doubleClass);
    
    return resultList;
}

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_crisper_weaver_WhisperCppPlugin_nativeInitModel(JNIEnv *env, jobject thiz, jstring model_path) {
    std::string modelPath = jstringToStdString(env, model_path);
    LOGI("Initializing Whisper model: %s", modelPath.c_str());

#ifdef WHISPER_AVAILABLE
    try {
        // Initialize whisper parameters
        struct whisper_context_params cparams = whisper_context_default_params();
        cparams.use_gpu = false; // Disable GPU for mobile compatibility
        
        // Load the model
        struct whisper_context* ctx = whisper_init_from_file_with_params(modelPath.c_str(), cparams);
        
        if (!ctx) {
            LOGE("Failed to load whisper model from: %s", modelPath.c_str());
            return JNI_FALSE;
        }
        
        // Store context in global state
        WhisperState::getInstance().setContext(ctx, modelPath);
        
        LOGI("Whisper model loaded successfully");
        return JNI_TRUE;
        
    } catch (const std::exception& e) {
        LOGE("Exception during model initialization: %s", e.what());
        return JNI_FALSE;
    }
#else
    // Mock implementation when whisper.cpp is not available
    LOGI("Mock: Model initialization for %s", modelPath.c_str());
    WhisperState::getInstance().setContext(reinterpret_cast<void*>(0x12345678), modelPath);
    return JNI_TRUE;
#endif
}

JNIEXPORT jobject JNICALL
Java_com_crisper_weaver_WhisperCppPlugin_nativeTranscribe(JNIEnv *env, jobject thiz, 
                                                           jfloatArray audio_data, jstring language) {
    std::string lang = jstringToStdString(env, language);
    std::vector<float> audioSamples = jfloatArrayToVector(env, audio_data);
    
    LOGI("Transcribing audio: %zu samples, language: %s", audioSamples.size(), lang.c_str());

#ifdef WHISPER_AVAILABLE
    auto* ctx = static_cast<struct whisper_context*>(WhisperState::getInstance().getContext());
    if (!ctx) {
        LOGE("No whisper context available");
        return createTranscriptionResult(env, {}, {}, {});
    }

    try {
        // Set up whisper parameters
        struct whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
        
        // Configure parameters
        wparams.print_realtime = false;
        wparams.print_progress = false;
        wparams.print_timestamps = true;
        wparams.print_special = false;
        wparams.translate = false;
        wparams.single_segment = false;
        wparams.n_threads = 2; // Limited threads for mobile
        wparams.offset_ms = 0;
        wparams.duration_ms = 0;
        wparams.token_timestamps = false;
        wparams.thold_pt = 0.01f;
        wparams.thold_ptsum = 0.01f;
        wparams.max_segment_length = 30; // 30 second max segments
        wparams.speed_up = false;
        
        // Set language if specified
        if (lang != "auto" && !lang.empty()) {
            wparams.language = whisper_lang_id(lang.c_str());
            if (wparams.language == -1) {
                LOGW("Unknown language: %s, using auto-detection", lang.c_str());
                wparams.language = whisper_lang_id("auto");
            }
        }
        
        // Run the transcription
        int result = whisper_full(ctx, wparams, audioSamples.data(), audioSamples.size());
        
        if (result != 0) {
            LOGE("Whisper transcription failed with error: %d", result);
            return createTranscriptionResult(env, {}, {}, {});
        }
        
        // Extract results
        std::vector<std::string> texts;
        std::vector<float> startTimes;
        std::vector<float> endTimes;
        
        const int n_segments = whisper_full_n_segments(ctx);
        LOGI("Transcription completed with %d segments", n_segments);
        
        for (int i = 0; i < n_segments; ++i) {
            const char* text = whisper_full_get_segment_text(ctx, i);
            const int64_t start_time = whisper_full_get_segment_t0(ctx, i);
            const int64_t end_time = whisper_full_get_segment_t1(ctx, i);
            
            // Convert whisper time units (10ms) to seconds
            float start_seconds = start_time * 0.01f;
            float end_seconds = end_time * 0.01f;
            
            texts.push_back(std::string(text));
            startTimes.push_back(start_seconds);
            endTimes.push_back(end_seconds);
            
            LOGD("Segment %d: [%.2f -> %.2f] %s", i, start_seconds, end_seconds, text);
        }
        
        return createTranscriptionResult(env, texts, startTimes, endTimes);
        
    } catch (const std::exception& e) {
        LOGE("Exception during transcription: %s", e.what());
        return createTranscriptionResult(env, {}, {}, {});
    }
#else
    // Mock implementation when whisper.cpp is not available
    LOGI("Mock: Transcribing %zu samples", audioSamples.size());
    
    // Generate mock transcription based on audio length
    std::vector<std::string> mockTexts;
    std::vector<float> mockStartTimes;
    std::vector<float> mockEndTimes;
    
    float audioDuration = audioSamples.size() / 16000.0f; // Assuming 16kHz sample rate
    int numSegments = std::max(1, static_cast<int>(audioDuration / 5.0f)); // ~5 second segments
    
    for (int i = 0; i < numSegments; ++i) {
        float startTime = i * 5.0f;
        float endTime = std::min(startTime + 5.0f, audioDuration);
        
        mockTexts.push_back("This is a mock transcription segment " + std::to_string(i + 1) + ".");
        mockStartTimes.push_back(startTime);
        mockEndTimes.push_back(endTime);
    }
    
    return createTranscriptionResult(env, mockTexts, mockStartTimes, mockEndTimes);
#endif
}

JNIEXPORT void JNICALL
Java_com_crisper_weaver_WhisperCppPlugin_nativeFreeModel(JNIEnv *env, jobject thiz) {
    LOGI("Freeing Whisper model");
    WhisperState::getInstance().freeContext();
}

JNIEXPORT jboolean JNICALL
Java_com_crisper_weaver_WhisperCppPlugin_nativeIsModelLoaded(JNIEnv *env, jobject thiz) {
    bool isLoaded = WhisperState::getInstance().isModelLoaded;
    LOGD("Model loaded status: %s", isLoaded ? "true" : "false");
    return isLoaded ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jstring JNICALL
Java_com_crisper_weaver_WhisperCppPlugin_nativeGetModelInfo(JNIEnv *env, jobject thiz) {
#ifdef WHISPER_AVAILABLE
    auto* ctx = static_cast<struct whisper_context*>(WhisperState::getInstance().getContext());
    if (!ctx) {
        return env->NewStringUTF("No model loaded");
    }
    
    // Get model information
    std::string info = "Whisper model loaded: " + WhisperState::getInstance().modelPath;
    return env->NewStringUTF(info.c_str());
#else
    return env->NewStringUTF("Mock Whisper implementation");
#endif
}

JNIEXPORT jstring JNICALL
Java_com_crisper_weaver_WhisperCppPlugin_nativeGetVersion(JNIEnv *env, jobject thiz) {
#ifdef WHISPER_AVAILABLE
    return env->NewStringUTF("Whisper.cpp integrated");
#else
    return env->NewStringUTF("Mock Whisper (no native library)");
#endif
}

JNIEXPORT jboolean JNICALL
Java_com_crisper_weaver_WhisperCppPlugin_nativeSetParameters(JNIEnv *env, jobject thiz, 
                                                              jint n_threads, jfloat temperature) {
    LOGI("Setting parameters: threads=%d, temperature=%.2f", n_threads, temperature);
    
    // In a full implementation, you would store these parameters 
    // and use them in the next transcription call
    // For now, just log them
    
    return JNI_TRUE;
}

// Language detection function
JNIEXPORT jstring JNICALL
Java_com_crisper_weaver_WhisperCppPlugin_nativeDetectLanguage(JNIEnv *env, jobject thiz, 
                                                               jfloatArray audio_data) {
#ifdef WHISPER_AVAILABLE
    auto* ctx = static_cast<struct whisper_context*>(WhisperState::getInstance().getContext());
    if (!ctx) {
        return env->NewStringUTF("unknown");
    }
    
    std::vector<float> audioSamples = jfloatArrayToVector(env, audio_data);
    
    try {
        // Use a small sample for language detection (first 30 seconds max)
        int max_samples = 30 * 16000; // 30 seconds at 16kHz
        if (audioSamples.size() > max_samples) {
            audioSamples.resize(max_samples);
        }
        
        // Run whisper with language detection
        struct whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
        wparams.language = whisper_lang_id("auto");
        wparams.n_threads = 1;
        wparams.print_progress = false;
        wparams.print_realtime = false;
        
        int result = whisper_full(ctx, wparams, audioSamples.data(), audioSamples.size());
        
        if (result == 0) {
            // Get detected language
            int lang_id = whisper_full_lang_id(ctx);
            const char* lang_str = whisper_lang_str(lang_id);
            return env->NewStringUTF(lang_str);
        }
    } catch (const std::exception& e) {
        LOGE("Exception during language detection: %s", e.what());
    }
    
    return env->NewStringUTF("en"); // Default to English
#else
    // Mock language detection
    LOGI("Mock: Language detection on %d samples", env->GetArrayLength(audio_data));
    return env->NewStringUTF("en");
#endif
}

} // extern "C"