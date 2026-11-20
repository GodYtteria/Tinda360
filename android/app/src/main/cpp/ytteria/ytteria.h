#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int ytteria_load(const char* gguf_path);

void ytteria_unload();

int ytteria_is_loaded();

int ytteria_generate(const int* input_ids, int n_input,
                     int* output_ids, int max_new,
                     int eos_id, int stop_id2, int prefix_len);

#ifdef __cplusplus
}
#endif
