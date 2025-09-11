#ifndef whisper_ios_wrapper_h
#define whisper_ios_wrapper_h

#include <stdbool.h>
#include <stdint.h>

// Opaque pointer to the whisper_context
typedef struct whisper_context whisper_context;

// Struct to pass transcription segments back to Swift
struct CTranscriptionSegment_t {
    const char* text;
    int64_t t0;
    int64_t t1;
};

#ifdef __cplusplus
extern "C" {
#endif

whisper_context* whisper_ios_init(const char* model_path);
void whisper_ios_free(whisper_context* ctx);

// Returns a pointer to an array of CTranscriptionSegment_t and sets segment_count
struct CTranscriptionSegment_t* whisper_ios_transcribe(
    whisper_context* ctx,
    const float* audio_data,
    int data_len,
    int* segment_count
);

// Must be called from Swift to free the memory allocated for the segments
void whisper_ios_free_segments(struct CTranscriptionSegment_t* segments, int count);

#ifdef __cplusplus
}
#endif

#endif /* whisper_ios_wrapper_h */