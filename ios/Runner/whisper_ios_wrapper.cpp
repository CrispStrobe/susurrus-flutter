#include "whisper_ios_wrapper.h"
#include "whisper.h" // Assuming whisper.cpp source is in a known include path
#include <string>
#include <vector>
#include <cstdlib>

whisper_context* whisper_ios_init(const char* model_path) {
    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = true; // Enable Metal on iOS
    return whisper_init_from_file_with_params(model_path, cparams);
}

void whisper_ios_free(whisper_context* ctx) {
    if (ctx) {
        whisper_free(ctx);
    }
}

struct CTranscriptionSegment_t* whisper_ios_transcribe(
    whisper_context* ctx,
    const float* audio_data,
    int data_len,
    int* segment_count
) {
    if (!ctx) {
        *segment_count = 0;
        return nullptr;
    }

    struct whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    wparams.print_progress = false;
    wparams.print_timestamps = true;
    wparams.n_threads = 4; // Use a reasonable number of threads for mobile

    if (whisper_full(ctx, wparams, audio_data, data_len) != 0) {
        *segment_count = 0;
        return nullptr;
    }

    const int n_segments = whisper_full_n_segments(ctx);
    *segment_count = n_segments;

    if (n_segments == 0) {
        return nullptr;
    }

    // Allocate memory that Swift will be responsible for freeing
    CTranscriptionSegment_t* result = (CTranscriptionSegment_t*)malloc(n_segments * sizeof(CTranscriptionSegment_t));

    for (int i = 0; i < n_segments; ++i) {
        const char* text = whisper_full_get_segment_text(ctx, i);
        result[i].text = strdup(text); // Duplicate the string
        result[i].t0 = whisper_full_get_segment_t0(ctx, i);
        result[i].t1 = whisper_full_get_segment_t1(ctx, i);
    }
    
    return result;
}

void whisper_ios_free_segments(struct CTranscriptionSegment_t* segments, int count) {
    if (!segments) return;
    for (int i = 0; i < count; ++i) {
        free((void*)segments[i].text); // Free the duplicated strings
    }
    free(segments); // Free the main array
}